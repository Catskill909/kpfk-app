import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/audio_state_manager.dart';
import '../../core/services/audio_server_health_checker.dart';
import '../../domain/models/stream_metadata.dart';
import '../../services/audio_service/kpfk_audio_handler.dart';
import '../../services/metadata_service.dart';
import '../../services/metadata_service_native.dart';
import '../../services/ios_lockscreen_service.dart';
import '../../core/constants/stream_constants.dart';

enum StreamState {
  initial,
  loading,
  buffering,
  connecting,
  playing,
  paused,
  stopped,
  error,
}

class StreamRepository {
  final KPFKAudioHandler _audioHandler;
  final MetadataService _metadataService;
  final NativeMetadataService _nativeMetadataService;
  StreamSubscription? _metadataSubscription;
  StreamSubscription? _playbackStateSubscription;

  // PHASE 5: connecting watchdog. Playback starts immediately (no blocking
  // pre-flight), but if it never reaches `playing` within this window we probe
  // the server: if it's down, surface the error modal and halt reconnects;
  // if it's healthy, keep waiting (slow connection, not a dead server).
  Timer? _connectingWatchdog;
  static const Duration _connectingTimeout = Duration(seconds: 8);

  final _stateController = StreamController<StreamState>.broadcast();
  final _metadataController = StreamController<StreamMetadata>.broadcast();
  // Emits a message when a server-specific error occurs (Icecast down, stream
  // not found, etc.) and null when it's cleared. Drives the server-error modal,
  // distinct from generic playback errors. See play-button-fix.md Phase 9.
  final _serverErrorController = StreamController<String?>.broadcast();

  StreamState _currentState = StreamState.initial;
  StreamMetadata? _currentMetadata;

  // True between a play() request and the player actually reaching `playing`.
  // During this window the source can momentarily report `ready` before its
  // `playing` flag flips true; without this guard that instant is mapped to
  // `paused`, which flashes the play icon between the spinner and the pause
  // icon. While awaiting play we keep it a spinner (buffering) state instead.
  bool _awaitingPlay = false;

  StreamRepository({
    required KPFKAudioHandler audioHandler,
    required MetadataService metadataService,
  })  : _audioHandler = audioHandler,
        _metadataService = metadataService,
        _nativeMetadataService = NativeMetadataService() {
    _initialize();
  }

  /// Fully stop audio and return to a cold-start state.
  /// This is used by the Sleep Timer to guarantee a pristine audio state.
  ///
  /// [preserveMetadata] - If true, keeps current metadata and images intact
  /// while still resetting the audio pipeline. Used for pause operations
  /// to maintain visual continuity.
  Future<void> stopAndColdReset({bool preserveMetadata = false}) async {
    try {
      LoggerService.info(
          '🎵 StreamRepository: stopAndColdReset started (preserveMetadata: $preserveMetadata)');

      // Store current metadata before any operations if preserving
      StreamMetadata? savedMetadata;
      if (preserveMetadata) {
        savedMetadata = _currentMetadata;
        LoggerService.info(
            '🎵 StreamRepository: Preserving current metadata: ${savedMetadata?.current.showName}');
      }

      // Stop playback and metadata polling
      await _audioHandler.stop();
      _metadataService.stopFetching();

      // CONDITIONAL: Only clear lockscreen if NOT preserving metadata
      if (!preserveMetadata) {
        // Clear native lockscreen (safe no-op on Android)
        try {
          final iosLock = IOSLockscreenService();
          await iosLock.clearLockscreen();
          LoggerService.info(
              '🎵 StreamRepository: Lockscreen cleared (full reset)');
        } catch (_) {}
      } else {
        LoggerService.info(
            '🎵 StreamRepository: Skipping lockscreen clear to preserve metadata');
      }

      // Reset just_audio pipeline to cold-start
      await _audioHandler.resetToColdStart();

      // CONDITIONAL: Reset repository state based on preserve flag
      if (!preserveMetadata) {
        // Full reset - clear everything
        _currentMetadata = null;
        LoggerService.info('🎵 StreamRepository: Full metadata reset');
      } else {
        // Preserve metadata - restore saved metadata
        _currentMetadata = savedMetadata;
        LoggerService.info(
            '🎵 StreamRepository: Metadata preserved and restored');

        // If we have preserved metadata, update the lockscreen with paused state
        if (_currentMetadata != null) {
          _updateMediaMetadata(_currentMetadata!);
        }
      }

      _updateState(StreamState.initial);
      _metadataService.startFetching();

      LoggerService.info(
          '🎵 StreamRepository: stopAndColdReset completed (preserveMetadata: $preserveMetadata)');
    } catch (e) {
      LoggerService.streamError('Error during stopAndColdReset', e);
      _updateState(StreamState.error);
      rethrow;
    }
  }

  // Public streams
  Stream<StreamState> get stateStream => _stateController.stream;
  Stream<StreamMetadata> get metadataStream => _metadataController.stream;
  Stream<String?> get serverErrorStream => _serverErrorController.stream;

  // Current values
  StreamState get currentState => _currentState;
  StreamMetadata? get currentMetadata => _currentMetadata;

  void _initialize() {
    LoggerService.info(
        '🎵 StreamRepository: Initializing and starting metadata fetch');

    // REMOVED: Force audio reinitialize - let normal initialization work
    // Future.delayed(const Duration(milliseconds: 500), () {
    //   forceAudioReinitialize();
    // });

    // Start fetching metadata immediately
    _metadataService.startFetching();

    // Listen for metadata updates
    _metadataSubscription = _metadataService.metadataStream.listen(
      (metadata) {
        LoggerService.info(
            '🎵 StreamRepository: RECEIVED METADATA: Show=${metadata.current.showName}, Host=${metadata.current.host}');
        _currentMetadata = metadata;
        _metadataController.add(metadata);
        _updateMediaMetadata(metadata);
      },
      onError: (error) {
        LoggerService.streamError('Metadata error', error);
        _updateState(StreamState.error);
      },
    );

    // Listen for playback state changes
    _playbackStateSubscription = _audioHandler.playbackState.listen(
      (playbackState) {
        final isPlaying = playbackState.playing;
        final processingState = playbackState.processingState;

        // Update stream state based on playback state
        switch (processingState) {
          case AudioProcessingState.loading:
            _updateState(StreamState.loading);
            break;
          case AudioProcessingState.buffering:
            _updateState(StreamState.buffering);
            break;
          case AudioProcessingState.ready:
            if (isPlaying) {
              _awaitingPlay = false;
              _updateState(StreamState.playing);
            } else if (_awaitingPlay) {
              // Startup blip: the source is ready but the player's `playing`
              // flag hasn't flipped true yet. Stay on a spinner (buffering)
              // state so the play icon never flashes between the spinner and
              // the pause icon — we only reach `playing` next.
              _updateState(StreamState.buffering);
            } else {
              _updateState(StreamState.paused);
            }
            break;
          case AudioProcessingState.completed:
            _updateState(StreamState.stopped);
            break;
          case AudioProcessingState.idle:
            _updateState(StreamState.initial);
            break;
          case AudioProcessingState.error:
            // PHASE 10: the handler emits this after its bounded reconnect is
            // exhausted (e.g. a mid-stream Icecast drop). Classify it so a real
            // server outage surfaces the modal, not just a generic error.
            _onPlayerError();
            break;
        }

        // REMOVED: Direct lockscreen update on every playback state change
        // This was causing excessive updates (multiple times per second)
        // Now we only update metadata when the actual metadata changes
        // The playback state is still tracked and passed to the native layer
        if (Platform.isIOS && _currentMetadata != null) {
          LoggerService.info('🎵 Playback state changed: playing=$isPlaying');
          // We don't call _updateLockscreenOnPlaybackChange here anymore
        }
      },
    );

    // Initial refresh
    refreshMetadata();
  }

  // REMOVED: _updateLockscreenOnPlaybackChange method
  // This method was causing excessive metadata updates
  // Now we only update metadata when actual metadata changes in _updateMediaMetadata

  Future<void> play({AudioCommandSource? source}) async {
    try {
      LoggerService.info(
          '🎵 StreamRepository: Play requested from ${source ?? 'UI'} - starting immediately');

      // PHASE 2: No blocking pre-flight health check. Reflect activity in the
      // UI immediately and let the player connect. The old pre-flight GET added
      // ~2s of fixed latency in front of every play; just_audio surfaces real
      // connection/stream errors which we classify on the failure path below.
      _awaitingPlay = true;
      _updateState(StreamState.connecting);

      // iOS LOCK-SCREEN: reclaim the Now Playing slot INSTANTLY — before the
      // audio handler tears down/rebuilds the player to reconnect. This is what
      // stops the previously-used audio app (Spotify/Music) from flashing on the
      // lock screen during the reconnect gap: we grab the slot with KPFK's
      // title/artist + cached artwork the moment play is pressed.
      if (_currentMetadata != null) {
        _pushNativeLockscreen(_currentMetadata!,
            isPlaying: true, forceUpdate: true);
      }

      // PHASE 5: arm the watchdog in case the connection silently stalls (the
      // audio handler swallows connect failures into a background reconnect
      // loop, so they never throw here).
      _startConnectingWatchdog();

      // CRITICAL FIX: Handle lockscreen-initiated commands
      if (source == AudioCommandSource.lockscreen) {
        LoggerService.info(
            '🎵 StreamRepository: Lockscreen-initiated playback detected');
        // UI will be updated through normal playback state listener
      }

      await _audioHandler.play();
      // State will be updated by the playback state listener
    } catch (e) {
      LoggerService.streamError('Error playing stream', e);
      _cancelConnectingWatchdog();
      await _handlePlaybackFailure(e);
      rethrow;
    }
  }

  /// PHASE 5: Arm a watchdog that fires if playback hasn't reached `playing`
  /// within [_connectingTimeout]. On a healthy-but-slow server it does nothing;
  /// on a down server it shows the error modal and halts the reconnect loop.
  void _startConnectingWatchdog() {
    _connectingWatchdog?.cancel();
    _connectingWatchdog = Timer(_connectingTimeout, _onConnectingTimeout);
  }

  void _cancelConnectingWatchdog() {
    _connectingWatchdog?.cancel();
    _connectingWatchdog = null;
  }

  // PHASE 10: guard against re-entrancy while classifying a player error
  // (the classification itself drives more playback-state transitions).
  bool _handlingPlayerError = false;

  /// Classify a player error (reconnect exhausted) and surface it: a real
  /// server outage shows the modal; anything else stays a generic error.
  Future<void> _onPlayerError() async {
    if (_handlingPlayerError) return;
    _handlingPlayerError = true;
    try {
      _cancelConnectingWatchdog();
      _updateState(StreamState.error);
      LoggerService.warning(
          '🎵 StreamRepository: Player error - probing server to classify');
      final health = await AudioServerHealthChecker.checkServerHealth(
          StreamConstants.streamUrl);
      if (!health.isHealthy) {
        LoggerService.info(
            '🎵 StreamRepository: Player error is a server outage (${health.errorType}) - showing modal');
        await _handleServerError(health);
      }
    } on NetworkConnectivityException catch (ne) {
      // Network issue, not a server issue — leave as a generic error.
      LoggerService.info(
          '🎵 StreamRepository: Player error during network issue: $ne');
    } catch (e) {
      LoggerService.streamError('Error classifying player error', e);
    } finally {
      _handlingPlayerError = false;
    }
  }

  Future<void> _onConnectingTimeout() async {
    // Already playing? Nothing to do (watchdog also gets cancelled on `playing`,
    // this is just belt-and-suspenders).
    if (_currentState == StreamState.playing) return;

    LoggerService.warning(
        '🎵 StreamRepository: Connecting watchdog fired (state=$_currentState) - probing server health');
    try {
      final health = await AudioServerHealthChecker.checkServerHealth(
          StreamConstants.streamUrl);
      if (!health.isHealthy) {
        LoggerService.info(
            '🎵 StreamRepository: Watchdog confirmed server down (${health.errorType}) - showing modal, halting reconnect');
        _audioHandler.haltReconnect();
        await _handleServerError(health);
      } else {
        LoggerService.info(
            '🎵 StreamRepository: Watchdog - server healthy, continuing to wait for connection');
      }
    } on NetworkConnectivityException catch (ne) {
      // Network issue, not a server issue — surface a plain error, no modal.
      LoggerService.info(
          '🎵 StreamRepository: Watchdog network connectivity issue: $ne');
      _audioHandler.haltReconnect();
      _updateState(StreamState.error);
    }
  }

  /// Classify and surface a playback failure. Tries to classify directly from
  /// the thrown error first; if that's inconclusive, consults the health
  /// checker to distinguish a server outage from a generic error — but only on
  /// the failure path, so the happy path carries no pre-flight latency.
  Future<void> _handlePlaybackFailure(Object e) async {
    final directType = _classifyPlaybackError(e);
    if (directType != null) {
      await _handleServerError(AudioServerHealthResult(
        isHealthy: false,
        errorType: directType,
        message: 'Playback failed: $e',
      ));
      return;
    }

    // Inconclusive — probe the server to tell "server down" from "other".
    try {
      final health = await AudioServerHealthChecker.checkServerHealth(
          StreamConstants.streamUrl);
      if (!health.isHealthy) {
        await _handleServerError(health);
        return;
      }
    } on NetworkConnectivityException catch (ne) {
      // Network issue, not a server issue — no server-error modal.
      LoggerService.info(
          '🎵 StreamRepository: Network connectivity issue during failure classification: $ne');
    }

    _updateState(StreamState.error);
  }

  Future<void> pause({AudioCommandSource? source}) async {
    try {
      LoggerService.info(
          '🎵 StreamRepository: Pause requested - SPOTIFY SIMPLE APPROACH');
      // A deliberate pause ends any in-flight play attempt, so a subsequent
      // `ready` event should map to `paused` normally again.
      _awaitingPlay = false;

      // iOS LOCK-SCREEN FIX: Use pause() instead of stop() to keep the audio
      // session active and preserve Now Playing status on iOS. stop() was
      // nuking mediaItem and deactivating the session, which let another app's
      // metadata flash on the lock screen during the next play→reconnect gap.
      await _audioHandler.pause();
      _updateState(StreamState.paused);

      LoggerService.info(
          '🎵 StreamRepository: Pause completed - simple stop, ready for fresh start');
    } catch (e) {
      LoggerService.streamError('Error pausing stream', e);
      _updateState(StreamState.error);
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      _awaitingPlay = false;
      await _audioHandler.stop();
      _updateState(StreamState.stopped);
      _metadataService.stopFetching();
    } catch (e) {
      LoggerService.streamError('Error stopping stream', e);
      _updateState(StreamState.error);
      rethrow;
    }
  }

  Future<void> retry() async {
    try {
      await stop();
      await Future.delayed(const Duration(seconds: 1));
      await play();
    } catch (e) {
      LoggerService.streamError('Error retrying stream', e);
      _updateState(StreamState.error);
      rethrow;
    }
  }

  void _updateState(StreamState newState) {
    if (_currentState != newState) {
      LoggerService.info('Stream state changed: $_currentState -> $newState');
      _currentState = newState;
      _stateController.add(newState);

      // PHASE 5: once playback settles, the connecting watchdog is done.
      if (newState == StreamState.playing ||
          newState == StreamState.paused ||
          newState == StreamState.stopped ||
          newState == StreamState.error ||
          newState == StreamState.initial) {
        _cancelConnectingWatchdog();
      }

      // A play attempt is over once we actually start playing or it fails
      // outright. (Deliberately NOT cleared on `initial`, which the iOS source
      // rebuild churns through mid-play.)
      if (newState == StreamState.playing ||
          newState == StreamState.stopped ||
          newState == StreamState.error) {
        _awaitingPlay = false;
      }
    }
  }

  /// Manual refresh of metadata
  Future<void> refreshMetadata() async {
    LoggerService.info(
        '🎵 StreamRepository: MANUAL REFRESH of metadata - Explicitly fetching');
    try {
      final metadata = await _metadataService.fetchMetadataOnce();
      if (metadata != null) {
        LoggerService.info(
            '🎵 METADATA FOUND! Show=${metadata.current.showName}, Host=${metadata.current.host}');
        _currentMetadata = metadata;
        _metadataController.add(metadata);
        _updateMediaMetadata(metadata);
        // REMOVED: Second delayed update that was causing race conditions
      } else {
        LoggerService.error('🎵 METADATA MISSING! Fetch returned null');
      }
    } catch (e) {
      LoggerService.streamError('Error refreshing metadata', e);
    }
  }

  /// Restart metadata service after network recovery
  void restartMetadataService() {
    LoggerService.info(
        '🎵 StreamRepository: Restarting metadata service after network recovery');
    _metadataService.startFetching();
    // Also trigger an immediate refresh to get current metadata
    refreshMetadata();
  }

  void _updateMediaMetadata(StreamMetadata metadata) {
    final showInfo = metadata.current;

    // CRITICAL DEBUG: Log exactly what metadata we have
    LoggerService.info(
        '🎵 RAW METADATA: Show="${showInfo.showName}", Host="${showInfo.host}"');
    if (showInfo.hasSongInfo) {
      LoggerService.info(
          '🎵 SONG INFO: Title="${showInfo.songTitle}", Artist="${showInfo.songArtist}"');
    }

    // Create explicit title and artist fields based on available info
    // CRITICAL: Show name must be the primary title for lockscreen
    final String title = showInfo.showName.isNotEmpty
        ? showInfo.showName
        : 'KPFK Radio'; // Fallback only if empty

    // Artist field will show host info and song if available
    String artist;
    if (showInfo.hasSongInfo &&
        showInfo.songTitle != null &&
        showInfo.songTitle!.isNotEmpty) {
      // If we have song info, include it with the host
      artist = showInfo.songArtist != null && showInfo.songArtist!.isNotEmpty
          ? 'Playing: ${showInfo.songTitle} - ${showInfo.songArtist}'
          : 'Playing: ${showInfo.songTitle}';
    } else {
      // Just show host name
      artist =
          showInfo.host.isNotEmpty ? 'Host: ${showInfo.host}' : 'KPFK 90.7 FM';
    }

    // Create a MediaItem with the show information
    final mediaItem = MediaItem(
      id: 'kpfk_live',
      title: title,
      artist: artist,
      album: 'KPFK 90.7 FM',
      displayTitle: title,
      displaySubtitle: artist,
      artUri:
          showInfo.hostImage != null ? Uri.parse(showInfo.hostImage!) : null,
    );

    LoggerService.info(
        '🎵 SENDING TO LOCKSCREEN: Title="$title", Artist="$artist"');

    // audio_service drives Android + is the iOS fallback.
    _audioHandler.updateMediaItem(mediaItem);

    // iOS: also push to the native channel that owns MPNowPlayingInfoCenter
    // with cached artwork. Keeping it in sync here means the cache is warm, so
    // the instant reclaim on play() (below) repaints with the real image.
    _pushNativeLockscreen(metadata,
        isPlaying: _audioHandler.playbackState.value.playing);
  }

  /// iOS only: push the current show straight to the native lock-screen channel
  /// (MPNowPlayingInfoCenter). With [forceUpdate] it bypasses the native
  /// debounce and reclaims the Now Playing slot immediately — used at the start
  /// of play() so the previously-used audio app can't flash during the
  /// reconnect gap. No-op on Android (audio_service handles that).
  void _pushNativeLockscreen(StreamMetadata metadata,
      {required bool isPlaying, bool forceUpdate = false}) {
    if (!Platform.isIOS) return;
    final showInfo = metadata.current;
    final String title =
        showInfo.showName.isNotEmpty ? showInfo.showName : 'KPFK 90.7 FM';
    final String artist;
    if (showInfo.hasSongInfo &&
        showInfo.songTitle != null &&
        showInfo.songTitle!.isNotEmpty) {
      artist = showInfo.songArtist != null && showInfo.songArtist!.isNotEmpty
          ? 'Playing: ${showInfo.songTitle} - ${showInfo.songArtist}'
          : 'Playing: ${showInfo.songTitle}';
    } else {
      artist =
          showInfo.host.isNotEmpty ? 'Host: ${showInfo.host}' : 'KPFK 90.7 FM';
    }
    _nativeMetadataService.updateLockscreenMetadata(
      title: title,
      artist: artist,
      artworkUrl: showInfo.hostImage,
      isPlaying: isPlaying,
      forceUpdate: forceUpdate,
    );
  }

  /// Handle server-specific errors and reset audio controls
  Future<void> _handleServerError(AudioServerHealthResult healthResult) async {
    LoggerService.info(
        '🎵 StreamRepository: Handling server error: ${healthResult.errorType}');

    // Map server error types to audio states
    GlobalAudioState audioState;
    String errorMessage;

    switch (healthResult.errorType) {
      case AudioServerErrorType.serverUnavailable:
        audioState = GlobalAudioState.serverUnavailable;
        errorMessage = 'Audio server is temporarily unavailable';
        break;
      case AudioServerErrorType.streamNotFound:
        audioState = GlobalAudioState.streamNotFound;
        errorMessage = 'Stream not found on server';
        break;
      case AudioServerErrorType.serverOverloaded:
        audioState = GlobalAudioState.serverUnavailable;
        errorMessage = 'Server is temporarily overloaded';
        break;
      case AudioServerErrorType.connectionTimeout:
        audioState = GlobalAudioState.serverError;
        errorMessage = 'Connection to server timed out';
        break;
      case AudioServerErrorType.authenticationError:
        audioState = GlobalAudioState.serverError;
        errorMessage = 'Access denied by server';
        break;
      case AudioServerErrorType.serverError:
        audioState = GlobalAudioState.serverError;
        errorMessage = 'Server error occurred';
        break;
      case AudioServerErrorType.unknownError:
      case null:
        audioState = GlobalAudioState.serverError;
        errorMessage = healthResult.message ?? 'Unknown server error';
        break;
    }

    // Reset audio controls and clear lockscreen
    await _resetAudioControlsForServerError();

    // Update audio state manager
    AudioStateManager().handleServerError(audioState, errorMessage);

    // Signal the UI to show the server-error modal (distinct from a generic
    // playback error). The bloc maps this to showServerErrorModal.
    _serverErrorController.add(errorMessage);

    // Update local stream state
    _updateState(StreamState.error);
  }

  /// Reset audio controls when server errors occur
  /// This ensures play button, lockscreen, and system controls are cleared
  Future<void> _resetAudioControlsForServerError() async {
    try {
      LoggerService.info(
          '🎵 StreamRepository: Resetting audio controls for server error');

      // Stop audio handler and clear controls
      await _audioHandler.stop();

      // Clear iOS lockscreen (safe no-op on Android)
      if (Platform.isIOS) {
        try {
          final iosLock = IOSLockscreenService();
          await iosLock.clearLockscreen();
          LoggerService.info('🎵 StreamRepository: iOS lockscreen cleared');
        } catch (e) {
          LoggerService.error('Error clearing iOS lockscreen: $e');
        }
      }

      // Reset audio handler to cold start state
      await _audioHandler.resetToColdStart();

      LoggerService.info('🎵 StreamRepository: Audio controls reset completed');
    } catch (e) {
      LoggerService.streamError('Error resetting audio controls', e);
    }
  }

  /// Classify playback errors to determine if they're server-related
  AudioServerErrorType? _classifyPlaybackError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socketexception') ||
        errorString.contains('connection refused')) {
      return AudioServerErrorType.serverUnavailable;
    } else if (errorString.contains('timeout')) {
      return AudioServerErrorType.connectionTimeout;
    } else if (errorString.contains('404') ||
        errorString.contains('not found')) {
      return AudioServerErrorType.streamNotFound;
    } else if (errorString.contains('503') ||
        errorString.contains('service unavailable')) {
      return AudioServerErrorType.serverOverloaded;
    } else if (errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('unauthorized')) {
      return AudioServerErrorType.authenticationError;
    }

    // Return null for non-server errors (network, codec, etc.)
    return null;
  }

  /// Clear server error state and allow retry
  void clearServerError() {
    LoggerService.info('🎵 StreamRepository: Clearing server error state');
    AudioStateManager().clearServerError();
    AudioServerHealthChecker
        .clearCache(); // Clear health check cache for fresh retry
    _serverErrorController.add(null); // Hide the server-error modal
    _updateState(StreamState.initial);
  }

  /// Force complete audio system reinitialize - use when audio is completely broken
  Future<void> forceAudioReinitialize() async {
    try {
      LoggerService.info(
          '🎵 StreamRepository: FORCE AUDIO REINITIALIZE - Complete system reset');

      // Stop everything
      await _audioHandler.stop();
      _metadataService.stopFetching();

      // Force reinitialize audio handler
      await _audioHandler.forceReinitialize();

      // Reset repository state
      _currentMetadata = null;
      _updateState(StreamState.initial);

      // Restart metadata service
      _metadataService.startFetching();

      LoggerService.info(
          '🎵 StreamRepository: Force audio reinitialize complete');
    } catch (e) {
      LoggerService.streamError('Error during force audio reinitialize', e);
      _updateState(StreamState.error);
      rethrow;
    }
  }

  @mustCallSuper
  @mustCallSuper
  void dispose() {
    _cancelConnectingWatchdog();
    _metadataSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _stateController.close();
    _metadataController.close();
    _serverErrorController.close();
    _metadataService.dispose();
    // Also dispose the native metadata service to clean up any active timers
    _nativeMetadataService.dispose();
    _audioHandler.customAction('dispose');
  }
}
