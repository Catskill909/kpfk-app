import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/stream_constants.dart';
import '../../core/services/logger_service.dart';
import '../../core/utils/m3u_parser.dart';
import '../../data/models/stream_metadata.dart';
import '../samsung_media_session_service.dart';

/// Handles all audio-related operations including background playback
/// Modified to use a permanent dummy MediaItem to prevent just_audio_background
/// from controlling the iOS lockscreen metadata
class KPFKAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final String _streamUrl;
  StreamMetadata? _currentMetadata;

  // iOS only: same channel AppDelegate listens on. Used to tell the native side
  // to re-claim the lock-screen Now Playing slot the instant play() runs.
  static const MethodChannel _nativeChannel =
      MethodChannel('com.kpfkfm.radio/metadata');

  // Optional: track last buffering log time to reduce log noise
  DateTime? _lastBufferingUpdate;

  // SINGLE SOURCE OF TRUTH: One MediaItem field (like working Pacifica app)
  MediaItem? _currentMediaItem;

  // ANDROID: throttle diagnostic logs
  DateTime? _lastAndroidDiag;

  // PHASE 5: Gate the background reconnect loop. When the server is confirmed
  // down (by the repository's connecting watchdog), we halt reconnects so the
  // app isn't silently hammering a dead server behind the error modal. A fresh
  // play() re-enables it.
  bool _reconnectEnabled = true;

  // ANDROID LOCK-SCREEN BLANK FIX: True while play() is rebuilding the audio
  // source. setAudioSource() momentarily drops the player to ProcessingState.idle,
  // which would otherwise make _broadcastState push mediaItem.add(null) and blank
  // the notification/lock-screen to a placeholder (no art, no metadata) for ~95ms
  // before recovering. While this flag is set we keep showing the current
  // MediaItem through the transient idle. (iOS already never pushes null — this
  // brings Android to parity without touching the iOS path.)
  bool _rebuildingSource = false;

  // ANDROID LOCK-SCREEN ART FLICKER FIX: signature of the last MediaItem pushed
  // to the mediaItem stream, so _broadcastState can skip redundant identical
  // pushes that otherwise force audio_service to re-decode + re-parcel the
  // artwork bitmap on every state event (blanks the Samsung lock-screen image).
  String? _lastPushedMediaSignature;

  // PHASE 10: bounded reconnect with backoff. A radio app should retry a
  // dropped stream, but not silently forever — after _maxReconnectAttempts we
  // surface an error state so the repository can classify it (server modal).
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  /// Exponential backoff for reconnect attempt N (1-based): 2s, 4s, 8s … capped.
  static Duration reconnectBackoff(int attempt) {
    final clamped = attempt < 1 ? 1 : attempt;
    final seconds = (1 << clamped).clamp(2, 30); // 2,4,8,16,30…
    return Duration(seconds: seconds);
  }

  KPFKAudioHandler._(
    this._player,
    this._streamUrl,
  ) {
    // CRITICAL: Set initial MediaItem immediately (working pattern)
    _setInitialMediaItem();
    _init();
  }

  /// WORKING PATTERN: Set initial MediaItem immediately (from Pacifica app)
  void _setInitialMediaItem() {
    _currentMediaItem = MediaItem(
      id: "kpfk_live",
      album: "Live Radio",
      title: "KPFK 90.7 FM",
      artist: "Pacifica Radio",
      duration: const Duration(hours: 24),
      // REMOVED: Broken placeholder artwork that was causing 404 errors and overriding real artwork
      // artUri: Uri.parse("https://confessor.kpfk.org/playlist/images/kpfk_logo.png"),
    );

    // DELAY: Don't show generic player immediately - wait for real metadata
    // mediaItem.add(_currentMediaItem); // ← REMOVED: Causes generic player flash
    LoggerService.info(
        '🔍 INITIAL LOAD FIX: _setInitialMediaItem() called but NOT showing generic player');
    LoggerService.info(
        '🎯 INITIAL LOAD FIX: Waiting for real metadata before showing player');
  }

  static Future<KPFKAudioHandler> create() async {
    final player = AudioPlayer();

    LoggerService.info(
        '🎵 Initializing audio handler (single source of truth)');

    return KPFKAudioHandler._(
      player,
      StreamConstants.streamUrl,
    );
  }

  Future<void> _init() async {
    try {
      LoggerService.info(
          '🎵 AudioHandler: Initializing with EXPERT M3U parsing');

      // CRITICAL: Configure audio session for Samsung lockscreen controls
      // This is what Samsung J7 needs to show lockscreen controls
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      LoggerService.info(
          '🎯 SAMSUNG FIX: Audio session configured and activated for lockscreen controls');

      // EXPERT SOLUTION: Parse M3U playlist to get direct stream URL
      final directStreamUrl = await _resolveStreamUrl(_streamUrl);
      LoggerService.info(
          '🎵 AudioHandler: Resolved stream URL: $directStreamUrl');

      // Configure audio source with direct stream URL (industry standard)
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(directStreamUrl),
          // Android uses a real tag so just_audio_background can render notifications
          // iOS keeps using the dummy item to defer lockscreen to Swift
          tag: _currentMediaItem,
        ),
      );
      if (Platform.isAndroid) {
        // Removed: _lastAndroidTagApplied tracking (simplified)
        _debugDumpAndroidState('init:setAudioSource');
      }

      // Only update playback state, not metadata
      // Our Swift implementation will handle the lockscreen metadata
      Future.delayed(const Duration(milliseconds: 500), () {
        _updatePlaybackStateOnly();
      });

      // Set up event listeners
      _player.processingStateStream.listen(_handleProcessingState);

      // WORKING PATTERN: Connect event streams like Pacifica app.
      // onError is the documented just_audio way to catch async playback
      // errors (e.g. the server dropping the connection mid-stream, or an
      // async load failure). Without it those errors are silently unhandled.
      _player.playbackEventStream.listen(
        _broadcastState,
        onError: _handleStreamError,
      );
      _player.playerStateStream.listen(_handlePlayerState);

      // ANDROID: deep diagnostics - observe handler streams
      if (Platform.isAndroid) {
        mediaItem.listen((item) {
          final t = item?.title ?? '';
          final a = item?.artist ?? '';
          LoggerService.info(
              '🤖 ANDROID DIAG: mediaItem changed -> title="$t" artist="$a"');
        });
        playbackState.listen((state) {
          // throttle
          final now = DateTime.now();
          if (_lastAndroidDiag == null ||
              now.difference(_lastAndroidDiag!) > const Duration(seconds: 2)) {
            _lastAndroidDiag = now;
            _debugDumpAndroidState('listener:playbackState');
          }
        });
      }
    } catch (e) {
      LoggerService.audioError('Error initializing audio handler', e);
      _handleError(e);
    }
  }

  // CRITICAL: EXACT working pattern from Pacifica app (SINGLE SOURCE OF TRUTH)
  void _broadcastState([PlaybackEvent? event]) {
    // ANDROID LOCK-SCREEN BLANK — THE REAL CAUSE (proven by native logcat):
    // play() rebuilds the source via setAudioSource(), which momentarily drops
    // the player to ProcessingState.idle. Mapping that to AudioProcessingState.idle
    // makes audio_service push MediaSession PlaybackState=STATE_NONE. Samsung's
    // lock-screen widget (vol.MediaSessions) treats a NONE session as inactive and
    // *removes the whole session* — art + metadata vanish — then re-adds it ~100ms
    // later on buffering. While we're knowingly rebuilding, report `loading`
    // instead of `idle` so the session stays active and the lock screen never
    // drops it. (stop() still reports idle via its own direct playbackState.add.)
    final ProcessingState rawState = _player.processingState;
    final AudioProcessingState mappedState =
        (_rebuildingSource && rawState == ProcessingState.idle)
            ? AudioProcessingState.loading
            : const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[rawState]!;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
      },
      androidCompactActionIndices: const [0],
      processingState: mappedState,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    ));

    // PACIFICA PATTERN: Simple MediaItem management (SINGLE SOURCE OF TRUTH)
    // Only show player when we have real metadata or when actively playing
    // ANDROID LOCK-SCREEN BLANK FIX: treat the transient idle during a play
    // rebuild as "still showing" so we never push null mid-play. Without
    // `|| _rebuildingSource`, setAudioSource()'s momentary idle blanks the
    // notification to a placeholder before loading recovers.
    final shouldShowPlayer = (_player.processingState != ProcessingState.idle ||
            _rebuildingSource) &&
        _currentMediaItem != null &&
        (_currentMediaItem!.title != "KPFK 90.7 FM" || _player.playing);

    // The value we would push this cycle (iOS never pushes null; Android gates
    // on shouldShowPlayer).
    final MediaItem? effectiveItem =
        (Platform.isIOS && _currentMediaItem != null)
            ? _currentMediaItem
            : (shouldShowPlayer ? _currentMediaItem : null);

    // ANDROID LOCK-SCREEN ART FLICKER FIX: _broadcastState fires in a rapid burst
    // during play (idle→loading→loading→ready…). Previously it re-added the
    // MediaItem every time, so audio_service re-decoded + re-parceled the full
    // 1600x1600 artwork bitmap to the MediaSession on each call — which blanks &
    // redraws the Samsung lock-screen image repeatedly. Only push when the item
    // actually changes (title/artist/art or null↔item). iOS art is native, so it
    // never saw this, but deduping is harmless there too.
    final String pushSignature = effectiveItem == null
        ? '<null>'
        : '${effectiveItem.title}|${effectiveItem.artist}|${effectiveItem.artUri}';

    if (pushSignature != _lastPushedMediaSignature) {
      _lastPushedMediaSignature = pushSignature;
      mediaItem.add(effectiveItem);
      LoggerService.info(
          '🎯 ONE TRUTH: _broadcastState pushed MediaItem=${effectiveItem?.title ?? "<null>"}, playing=${_player.playing}, state=${_player.processingState}');
    } else {
      LoggerService.info(
          '🎯 ONE TRUTH: _broadcastState skipped redundant MediaItem push (unchanged) - playing=${_player.playing}, state=${_player.processingState}');
    }
  }

  void _handlePlayerState(PlayerState state) {
    if (state.playing && _currentMetadata != null) {
      _updateMediaItem(
        _currentMetadata!.currentSong,
        _currentMetadata!.artist,
      );
    }

    // REMOVED: Competing MediaItem.add() call that was causing oscillation
    // Let the real metadata system be the ONLY source of MediaItem updates
    // This was the root cause of the 500ms oscillation pattern

    // Handle errors through PlayerState
    if (!state.playing &&
        _player.processingState == ProcessingState.completed) {
      LoggerService.audioError('Playback ended unexpectedly');
      _handleError('Stream playback ended unexpectedly');
    }
  }

  void _handleProcessingState(ProcessingState state) {
    // Track streaming state for intelligent metadata updates
    switch (state) {
      case ProcessingState.idle:
        LoggerService.info('🎵 AUDIO STATE: Idle');
        break;
      case ProcessingState.loading:
        LoggerService.info('🎵 AUDIO STATE: Loading');
        break;
      case ProcessingState.buffering:
        // Limit buffering log frequency to avoid spam
        final now = DateTime.now();
        if (_lastBufferingUpdate == null ||
            now.difference(_lastBufferingUpdate!) >
                const Duration(seconds: 5)) {
          LoggerService.info('🎵 AUDIO STATE: Buffering');
          _lastBufferingUpdate = now;
        }
        break;
      case ProcessingState.ready:
        LoggerService.info('🎵 AUDIO STATE: Ready (actively streaming)');
        break;
      case ProcessingState.completed:
        LoggerService.info('🎵 AUDIO STATE: Completed');
        break;
    }
  }

  void _handleError(dynamic error) {
    LoggerService.audioError('Audio error', error);
  }

  // Samsung/Android: pressing a media button while the stream is loading causes
  // the native codec to flush with PlatformException(abort). This is a deliberate
  // platform-level interruption, not a network failure. Reconnecting on abort
  // triggers a 3-attempt error storm and surfaces a false "Stream playback error"
  // to the user. Detect it here and bail out early.
  bool _isAbortError(Object error) {
    final s = error.toString().toLowerCase();
    return s.contains('abort') || s.contains('connection aborted');
  }

  /// Handles async errors from the playback event stream (e.g. the server
  /// dropping the connection mid-stream). Triggers the gated reconnect loop;
  /// when reconnect has been halted (server confirmed down) we leave it alone.
  void _handleStreamError(Object error, StackTrace stackTrace) {
    LoggerService.audioError('Playback stream error', error);
    if (_isAbortError(error)) {
      LoggerService.info(
          '🎵 Stream aborted by platform (media button during load) — stopping, not reconnecting');
      return;
    }
    if (_reconnectEnabled) {
      _reconnect();
    }
  }

  /// PHASE 5: Stop the background reconnect loop. Called by the repository
  /// once the server is confirmed down, so we don't keep retrying behind the
  /// error modal. Re-enabled by the next play().
  void haltReconnect() {
    if (_reconnectEnabled) {
      LoggerService.info('🎵 Reconnect loop halted (server confirmed down)');
    }
    _reconnectEnabled = false;
  }

  Future<void> _reconnect() async {
    if (!_reconnectEnabled) {
      LoggerService.info('🎵 Reconnect skipped - loop is halted');
      return;
    }

    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      // PHASE 10: stop retrying and surface an error so the repository can
      // classify it (server modal) instead of reconnecting silently forever.
      LoggerService.audioError(
          '🎵 Reconnect exhausted after $_maxReconnectAttempts attempts - surfacing error',
          null);
      _reconnectEnabled = false;
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
      return;
    }

    try {
      LoggerService.info(
          '🎵 Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts...');

      // EXPERT: Reset with resolved direct stream URL
      await _player.pause();
      await _player.seek(Duration.zero);
      final directStreamUrl = await _resolveStreamUrl(_streamUrl);
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(directStreamUrl),
          tag: _currentMediaItem, // Use current MediaItem
        ),
      );

      // Resume playback
      await _player.play();
      _reconnectAttempts = 0; // success - reset the counter
      LoggerService.info('🎵 Reconnection successful');
    } catch (e) {
      LoggerService.audioError('Error during reconnection', e);
      _handleError(e);

      if (_isAbortError(e)) {
        LoggerService.info(
            '🎵 Reconnect aborted by platform — halting retry loop');
        _reconnectEnabled = false;
        return;
      }

      // Schedule another reconnect attempt with backoff (unless halted).
      final delay = reconnectBackoff(_reconnectAttempts);
      LoggerService.info(
          '🎵 Reconnect attempt failed - retrying in ${delay.inSeconds}s');
      Future.delayed(delay, () {
        if (_reconnectEnabled && !_player.playing) {
          _reconnect();
        }
      });
    }
  }

  @override
  Future<void> play() async {
    try {
      LoggerService.info('🎯 ONE TRUTH: Play button pressed - starting flow');

      // iOS LOCK-SCREEN FLASH FIX: This runs for EVERY play — the in-app button
      // AND the lock-screen button both reach here. Reclaim the Now Playing slot
      // for KPFK *immediately*, from the native cache, BEFORE the slow M3U fetch
      // + setAudioSource below. Without this, the lock-screen slot belongs to the
      // previously-used audio app (Spotify/Music) during the ~1s reconnect and
      // its art/metadata flash before KPFK appears.
      if (Platform.isIOS) {
        try {
          await _nativeChannel.invokeMethod('reassertNowPlaying');
        } catch (e) {
          LoggerService.error('reassertNowPlaying failed: $e');
        }
      }

      // PHASE 5/10: a fresh play attempt re-enables the reconnect loop that a
      // prior server-down may have halted, and resets the attempt counter.
      _reconnectEnabled = true;
      _reconnectAttempts = 0;

      // CRITICAL: Request audio focus before playing (Samsung requirement)
      final session = await AudioSession.instance;
      final success = await session.setActive(true);
      if (!success) {
        LoggerService.error(
            '🎯 SAMSUNG FIX: Failed to gain audio focus - lockscreen controls may not work');
        return;
      }
      LoggerService.info(
          '🎯 SAMSUNG FIX: Audio focus gained successfully - lockscreen controls should now work');

      // DEVICE-LOG-PROVEN FIX (2026-06-23): On iOS, `await setAudioSource()`
      // blocks ~2.5s while it connects + buffers a fresh live AVPlayerItem.
      // During that gap KPFK is not yet "playing", so iOS keeps the lock-screen
      // Now Playing slot on the previously-used audio app (Spotify/Music) — THAT
      // is the flash. Setting nowPlayingInfo can't override it; iOS only hands
      // the slot over once KPFK is actually playing audio.
      //
      // So: if the player still has a live source (we were paused, not stopped →
      // processingState != idle), RESUME IN PLACE. Playback restarts in
      // milliseconds, KPFK keeps/claims the slot instantly, and there's no gap
      // for the other app to fill. Only rebuild when the source is gone (idle,
      // after stop / cold start) or on Android (which relies on the fresh source).
      final bool sourceAlive = _player.audioSource != null &&
          _player.processingState != ProcessingState.idle;
      if (Platform.isIOS && sourceAlive) {
        LoggerService.info(
            '🎯 iOS RESUME-IN-PLACE: source alive (state=${_player.processingState}) - skipping rebuild, no buffering gap, no lock-screen flash');
      } else {
        LoggerService.info(
            '🎯 CACHE FIX: rebuilding AudioSource (idle/cold or Android)');
        // Guard the transient idle that setAudioSource emits so _broadcastState
        // keeps the current MediaItem on the notification instead of blanking it.
        _rebuildingSource = true;
        try {
          final directStreamUrl = await _resolveStreamUrl(_streamUrl);
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(directStreamUrl),
              tag: _currentMediaItem,
            ),
          );
          LoggerService.info('🎯 CACHE FIX: Fresh AudioSource set');
        } finally {
          _rebuildingSource = false;
        }
      }

      LoggerService.info(
          '🎯 ONE TRUTH: Calling _player.play() - event listener will trigger _broadcastState');
      await _player.play();

      // REMOVED: Manual _broadcastState call - this was causing oscillation
      // The event listener will handle state broadcasting automatically

      // CRITICAL: Use our dummy MediaItem to update playback state only
      // Our Swift implementation will handle the lockscreen metadata
      _updateMediaSession(_player.playing, _currentMediaItem!);

      // CRITICAL: Update Samsung MediaSession playback state
      // This is the native Android MediaSession that Samsung J7 requires
      await SamsungMediaSessionService.updatePlaybackState(true);

      // DELAY FIX: Wait for current metadata before showing Samsung notification
      if (_currentMetadata != null) {
        LoggerService.info(
            '🔍 METADATA DELAY FIX: Using existing metadata for Samsung notification');
        await SamsungMediaSessionService.updateMetadata(
          _currentMetadata!.currentSong,
          _currentMetadata!.artist,
        );
      } else {
        LoggerService.info(
            '🔍 METADATA DELAY FIX: No metadata available yet - Samsung will show static until metadata arrives');
      }

      // STANDARD BEHAVIOR: Show notification only when PLAYING starts
      await SamsungMediaSessionService.showNotification();
      LoggerService.info(
          '🔍 SAMSUNG DEBUG: Notification shown because PLAY was pressed (STANDARD)');

      if (Platform.isAndroid) {
        _debugDumpAndroidState('play:afterUpdateSession');
      }
    } catch (e) {
      LoggerService.audioError('Error playing stream', e);
      _handleError(e);
      if (!_isAbortError(e)) {
        _reconnect();
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      LoggerService.info('🎵 AudioHandler: Pause requested');
      await _player.pause();

      // REMOVED: Manual _broadcastState call - this was causing oscillation
      // The event listener will handle state broadcasting automatically

      // iOS LOCK-SCREEN FIX: Do NOT release the audio session on iOS pause.
      // Keeping it active makes iOS keep this app as the "Now Playing" app,
      // preventing another app's metadata from flashing on the lock screen
      // during the pause→play reconnect gap.
      // Android still releases focus (Samsung requirement).
      if (!Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.setActive(false);
        LoggerService.info('🎯 SAMSUNG FIX: Audio focus released on pause');
      }

      // CRITICAL: Use our dummy MediaItem to update playback state only
      // Our Swift implementation will handle the lockscreen metadata
      _updateMediaSession(_player.playing, _currentMediaItem!);

      // CRITICAL: Update Samsung MediaSession playback state
      // This is the native Android MediaSession that Samsung J7 requires
      await SamsungMediaSessionService.updatePlaybackState(false);

      // STANDARD BEHAVIOR: Hide notification when PAUSED (like other apps)
      await SamsungMediaSessionService.hideNotification();
      LoggerService.info(
          '🔍 SAMSUNG DEBUG: Notification hidden because PAUSE was pressed (STANDARD)');

      // Explicitly broadcast updated state so the notification button flips to
      // play when pause is triggered from the notification tray (the event
      // stream alone is not reliable enough on Android 8.x).
      _broadcastState();
    } catch (e) {
      LoggerService.audioError('Error pausing stream', e);
      _handleError(e);
    }
  }

  /// Called by audio_service when the app's task is swiped away from recents.
  /// The manifest's `android:stopWithTask="true"` alone is unreliable for an
  /// actively-playing foreground media service on Android 8.x — the system often
  /// keeps the service (and its notification) alive. Doing a full stop() here
  /// tears down playback and clears the notification regardless of whether we
  /// were playing or paused when the app was closed.
  @override
  Future<void> onTaskRemoved() async {
    LoggerService.info(
        '🎯 onTaskRemoved: app swiped from recents - stopping to clear notification tray');
    await stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> stop() async {
    try {
      LoggerService.info(
          '🎵 AudioHandler: Stop requested - REMOVING player from notification tray');

      // CRITICAL: Complete reset like app startup - clear AudioSource
      await _player.stop();
      LoggerService.info(
          '🎯 REAL FIX: AudioPlayer.stop() called - clears all cached audio data');

      // Release audio focus completely
      final session = await AudioSession.instance;
      await session.setActive(false);
      LoggerService.info('🎯 SAMSUNG FIX: Audio focus released on stop');

      // Hide Samsung notification completely
      await SamsungMediaSessionService.hideNotification();
      LoggerService.info(
          '🔍 SAMSUNG DEBUG: Notification hidden because STOP was pressed');

      // Set playback state to idle and clear MediaItem to remove from tray
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));

      // Clear MediaItem to remove player from notification tray completely
      mediaItem.add(null);
      // Keep the dedup signature in sync so a later play() is not skipped as
      // "unchanged" and correctly re-pushes the MediaItem.
      _lastPushedMediaSignature = '<null>';
      LoggerService.info(
          '🎯 STOP: Player removed from notification tray - MediaItem set to null');

      // CRITICAL: Use proper AudioHandler approach - set to stopped state
      // This signals the AudioService to remove the foreground notification
      playbackState.add(PlaybackState(
        controls: [],
        systemActions: const {},
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 0.0,
      ));
      LoggerService.info(
          '🎯 STOP: Set playback state to idle with no controls to remove service');
    } catch (e) {
      LoggerService.audioError('Error stopping and removing player', e);
      _handleError(e);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    // Seeking not supported in live streams
    LoggerService.info(
        '🎵 AudioHandler: Seek requested but not supported for live streams');
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      await _player.dispose();
    }
  }

  /// Updates the media session state without updating the MediaItem
  /// This ensures just_audio_background won't control the lockscreen
  Future<void> _updateMediaSession(bool playing, MediaItem mediaItem) async {
    LoggerService.info('🎵 AudioHandler: Updating media session state only');

    final controls = [
      playing ? MediaControl.pause : MediaControl.play,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );

    // CRITICAL FIX: Do NOT update the mediaItem stream
    // This prevents just_audio_background from controlling the lockscreen
    // Our Swift implementation is the single source of truth for metadata
    // this.mediaItem.add(mediaItem); // Intentionally commented out

    LoggerService.info(
        '🎵 AudioHandler: Updated playback state only, not metadata');
  }

  /// Updates the current MediaItem with real metadata (SINGLE SOURCE OF TRUTH)
  Future<void> _updateMediaItem(String title, String artist) async {
    LoggerService.info(
        '🎵 AudioHandler: Received metadata update: "$title" by "$artist"');

    // Skip empty or placeholder updates
    if (title.isEmpty ||
        title == 'Loading stream...' ||
        title == 'Connecting...') {
      LoggerService.info('🎵 AudioHandler: Skipping empty/placeholder update');
      return;
    }

    // PACIFICA PATTERN: Update _currentMediaItem with real metadata
    _currentMediaItem = MediaItem(
      id: "kpfk_live",
      album: "KPFK 90.7 FM",
      title: title,
      artist: artist,
      duration: const Duration(hours: 24),
      // ANDROID LOCK-SCREEN ART FIX: preserve the last-known real artwork.
      // This internal builder used to drop artUri entirely (the old hardcoded
      // kpfk_logo.png 404'd, so it was removed). But it also runs on play() via
      // _handlePlayerState — stripping the art from _currentMediaItem and blanking
      // the lock-screen image until the next metadata poll re-added it. Carrying
      // the existing artUri forward keeps the image stable through play (audio_
      // service reuses its cached bitmap for the unchanged URI = no reload flash).
      artUri: _currentMediaItem?.artUri,
    );

    // Let _broadcastState handle the mediaItem.add() call (SINGLE SOURCE OF TRUTH)
    LoggerService.info(
        '🔍 METADATA BATTLE: _updateMediaItem() called with REAL metadata: "$title" by "$artist"');
    LoggerService.info(
        '🎯 ONE TRUTH: Updated _currentMediaItem with real metadata: "$title" by "$artist"');
    LoggerService.info(
        '🎯 ONE TRUTH: Next _broadcastState call will use this updated MediaItem');

    // CRITICAL: Update Samsung MediaSession with real metadata
    LoggerService.info(
        '🔍 SAMSUNG DEBUG: Calling SamsungMediaSessionService.updateMetadata("$title", "$artist")');
    await SamsungMediaSessionService.updateMetadata(title, artist);
    LoggerService.info(
        '🔍 SAMSUNG DEBUG: SamsungMediaSessionService.updateMetadata() completed');
  }

  /// Updates only the playback state without changing metadata
  /// This prevents iOS from caching placeholder values
  Future<void> _updatePlaybackStateOnly() async {
    LoggerService.info('🎵 AudioHandler: Updating playback state only');

    // Force a playback state update
    playbackState.add(
      playbackState.value.copyWith(
        playing: _player.playing,
        processingState: playbackState.value.processingState,
        updatePosition: _player.position,
        speed: _player.speed,
      ),
    );

    LoggerService.info(
        '🎵 AudioHandler: Playback state updated, using Swift for lockscreen metadata');
  }

  /// Public: Reset the audio pipeline to a cold-start idle state
  /// - Stops playback
  /// - Re-sets the audio source with the permanent dummy MediaItem
  /// - Clears internal flags and cached metadata
  /// - Updates playback state to idle/ready as appropriate without starting playback
  Future<void> resetToColdStart() async {
    try {
      LoggerService.info('🎵 AudioHandler: Reset to cold-start requested');
      await _player.pause();
      await _player.seek(Duration.zero);

      // EXPERT: Use resolved direct stream URL
      final directStreamUrl = await _resolveStreamUrl(_streamUrl);
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(directStreamUrl),
          tag: _currentMediaItem,
        ),
      );
      _currentMetadata = null;

      // Force update of playback state to reflect idle
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.idle,
          updatePosition: Duration.zero,
          bufferedPosition: Duration.zero,
        ),
      );

      LoggerService.info('🎵 AudioHandler: Cold-start reset complete');
    } catch (e) {
      LoggerService.audioError('Error during cold-start reset', e);
      _handleError(e);
    }
  }

  /// Complete audio system reset - reinitializes everything from scratch
  Future<void> forceReinitialize() async {
    try {
      LoggerService.info(
          '🎵 AudioHandler: FORCE REINITIALIZE - Complete reset');

      // Stop and dispose current player state
      await _player.pause();
      await _player.seek(Duration.zero);

      // EXPERT: Reinitialize with resolved direct stream URL
      final directStreamUrl = await _resolveStreamUrl(_streamUrl);
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(directStreamUrl),
          tag: _currentMediaItem,
        ),
      );

      // Reset all internal state
      _currentMetadata = null;
      _lastBufferingUpdate = null;

      // Force clean playback state
      playbackState.add(
        PlaybackState(
          controls: [MediaControl.play],
          systemActions: const {
            MediaAction.play,
            MediaAction.pause,
          },
          androidCompactActionIndices: const [0],
          processingState: AudioProcessingState.idle,
          playing: false,
          updatePosition: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
        ),
      );

      LoggerService.info(
          '🎵 AudioHandler: Force reinitialize complete - ready for playback');
    } catch (e) {
      LoggerService.audioError('Error during force reinitialize', e);
      _handleError(e);
    }
  }

  /// EXPERT METHOD: Resolve M3U playlist to direct stream URL
  Future<String> _resolveStreamUrl(String url) async {
    try {
      // If it's already a direct stream URL, use it as-is
      if (!url.endsWith('.m3u')) {
        return url;
      }

      LoggerService.info('🎵 AudioHandler: Fetching M3U playlist from: $url');

      // Fetch M3U playlist content
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch M3U playlist: ${response.statusCode}');
      }

      // Parse M3U to extract direct stream URL
      final directUrl = M3UParser.parseStreamUrl(response.body);
      if (directUrl == null) {
        throw Exception('No stream URL found in M3U playlist');
      }

      LoggerService.info(
          '🎵 AudioHandler: Extracted direct stream URL: $directUrl');
      return directUrl;
    } catch (e) {
      LoggerService.audioError('Error resolving stream URL', e);
      // Fallback to original URL
      return url;
    }
  }

  /// Updates metadata from stream metadata
  void updateMetadata(StreamMetadata metadata) {
    LoggerService.info(
        '🎵 AudioHandler: Updating with LIVE metadata: ${metadata.currentSong}');
    _currentMetadata = metadata;
    _updateMediaItem(
      metadata.currentSong,
      metadata.artist,
    );
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    LoggerService.info(
        '✅ STANDARD FLUTTER: updateMediaItem() called with title="${mediaItem.title}", artist="${mediaItem.artist}"');

    // STANDARD APPROACH: Let audio_service handle lockscreen on ALL platforms!
    // This is how EVERY Flutter audio app works - audio_service handles:
    // - iOS: MPNowPlayingInfoCenter + artwork download
    // - Android: MediaSession + notification
    // - Lifecycle events, caching, everything!

    _currentMediaItem = mediaItem;

    // Dedup: skip the push when nothing changed so audio_service doesn't
    // re-decode/re-parcel the artwork bitmap (Samsung lock-screen flicker).
    // Shares the same signature as _broadcastState so the two paths stay in sync.
    final String pushSignature =
        '${mediaItem.title}|${mediaItem.artist}|${mediaItem.artUri}';
    if (pushSignature != _lastPushedMediaSignature) {
      _lastPushedMediaSignature = pushSignature;
      this.mediaItem.add(mediaItem); // ✅ LET THE FRAMEWORK DO ITS JOB!
    }

    LoggerService.info(
        '✅ STANDARD FLUTTER: MediaItem set - audio_service will handle lockscreen/notification');
    LoggerService.info(
        '✅ Artwork URL: ${mediaItem.artUri?.toString() ?? "none"}');
  }

  // ANDROID: deep diagnostics helper - does not change behavior
  void _debugDumpAndroidState(String where) {
    if (!Platform.isAndroid) return;
    try {
      final ps = _player.processingState;
      final isPlaying = _player.playing;
      final pb = playbackState.value;
      final mi = mediaItem.valueOrNull;
      final tag = _currentMediaItem; // Simplified: use current MediaItem
      LoggerService.info(
          '🤖 ANDROID DIAG [$where]: player.playing=$isPlaying, player.state=$ps, '
          'pb.playing=${pb.playing}, pb.state=${pb.processingState}, '
          'mi.title="${mi?.title ?? ''}", mi.artist="${mi?.artist ?? ''}", '
          'tag.title="${tag?.title ?? ''}"');
    } catch (e) {
      LoggerService.error('🤖 ANDROID DIAG [$where] failed: $e');
    }
  }
}
