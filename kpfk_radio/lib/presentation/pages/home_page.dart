import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/stream_bloc.dart';
import '../../data/repositories/stream_repository.dart';
import '../theme/font_constants.dart';
import 'pacifica_apps_page.dart';
import '../widgets/app_drawer.dart';
import '../widgets/audio_server_error_modal.dart';
import '../widgets/show_info_modal.dart';
import '../bloc/connectivity_cubit.dart';
import '../widgets/donate_webview_sheet.dart';
import '../widgets/sleep_timer_overlay.dart';
import '../bloc/sleep_timer_cubit.dart';
import '../../core/di/service_locator.dart' as di;
import '../../core/services/logger_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showLocalLoading = false;
  // Becomes true once a play attempt has reached an in-progress state
  // (connecting/loading/buffering). Used so the spinner only clears on a
  // *settled* state (paused/stopped/initial) AFTER real progress — never on
  // the transient old-state emit that fires right when play is dispatched.
  bool _sawPlaybackProgress = false;
  bool _userPressedPause = false; // Track when user pressed pause button
  bool _showInfoModal = false; // Track info modal visibility

  // PHASE 1: Spinner timeout safety mechanism
  Timer? _spinnerTimeoutTimer;
  static const Duration _maxSpinnerDuration = Duration(seconds: 10);

  // Track last announced states to reduce repeated announcements
  StreamState? _lastAnnouncedPlayback;
  String? _lastAnnouncedShow;

  Widget _buildLoadingContainer(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PacificaAppsPage(),
      ),
    );
  }

  // PHASE 1: Spinner timeout safety methods
  void _startSpinnerTimeout() {
    _spinnerTimeoutTimer?.cancel();
    _spinnerTimeoutTimer = Timer(_maxSpinnerDuration, () {
      if (_showLocalLoading && mounted) {
        LoggerService.warning(
            '🔄 SPINNER TIMEOUT: Force reset loading state after ${_maxSpinnerDuration.inSeconds}s');
        setState(() {
          _showLocalLoading = false;
        });
      }
    });
  }

  void _cancelSpinnerTimeout() {
    _spinnerTimeoutTimer?.cancel();
    _spinnerTimeoutTimer = null;
  }

  @override
  void initState() {
    super.initState();
    // Removed auto-clear that was interfering with audio playback
  }

  @override
  void dispose() {
    _cancelSpinnerTimeout();
    super.dispose();
  }

  // PHASE 10: in-progress states where the play button should show a spinner
  // even without a local tap — e.g. a background reconnect after a stream drop.
  bool _isConnectingState(StreamState s) =>
      s == StreamState.connecting ||
      s == StreamState.loading ||
      s == StreamState.buffering;

  IconData _getPlaybackIcon(StreamState state) {
    switch (state) {
      case StreamState.playing:
        return Icons.pause_circle_filled;
      case StreamState.loading:
      case StreamState.buffering:
        return Icons.play_circle_filled;
      default:
        return Icons.play_circle_filled;
    }
  }

  // Helper function to detect iPad Pro specifically (large tablets)
  // iPad Pro 11" has shortestSide ~834, iPad Pro 12.9" has ~1024
  // Regular iPads and medium tablets have shortestSide ~768 or less
  bool _isLargeTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide > 800; // Only iPad Pro and similar large tablets
  }

  bool _isMediumTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide > 600 &&
        size.shortestSide <= 800; // Regular tablets
  }

  bool _isSmallPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide < 380; // Phones smaller than iPhone XR
  }

  // Measures the rendered height of the metadata text block (the leading gap +
  // title + time + song/next), matching the widgets below line-for-line. Used
  // ONLY to know how much room the stacked content needs, so the image can be
  // shrunk as a last resort when it doesn't fit — never to drive the image size
  // when there IS room. The gap constants here must match the SizedBoxes in the
  // text block below.
  double _measureMetadataHeight({
    required StreamBlocState state,
    required Size size,
    required bool small,
    required double maxWidth,
  }) {
    double measure(String text, TextStyle style, int maxLines) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      return tp.height;
    }

    if (state.metadata == null) {
      return 20.0 +
          measure('Loading stream information...', AppTextStyles.bodyMedium, 2);
    }

    final cur = state.metadata!.current;
    double h = small ? 8.0 : 20.0; // gap above title
    h += measure(cur.showName, AppTextStyles.showTitleForDevice(size), 2);
    h += 4.0;
    h += measure(cur.time, AppTextStyles.showTimeForDevice(size), 2);
    if (cur.hasSongInfo) {
      h += small ? 8.0 : 10.0;
      h += measure('Song: ${cur.songTitle} - ${cur.songArtist}',
          AppTextStyles.bodyLargeForDevice(size), 2);
    } else if (state.metadata!.next.showName.isNotEmpty) {
      h += small ? 8.0 : 10.0;
      h += measure('Next: ${state.metadata!.next.showName}',
          AppTextStyles.bodyMediumForDevice(size), 2);
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline =
        context.select<ConnectivityCubit, bool>((c) => c.state.isOnline);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        // Toolbar must be taller than the logo, otherwise the fixed-height
        // toolbar clips the image top/bottom. Centering the logo in this
        // taller bar also gives it breathing room from the top tray.
        // Phones keep the default 56 (logo is only ~40px there, never
        // clipped). Only the tablet bars are enlarged so the bigger logo
        // (60/70px) isn't clipped by the toolbar.
        toolbarHeight:
            _isLargeTablet(context) ? 96 : (_isMediumTablet(context) ? 84 : 56),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              size: _isLargeTablet(context)
                  ? 48
                  : (_isMediumTablet(context)
                      ? 38
                      : (_isSmallPhone(context) ? 26 : 30)),
              color: Colors.white,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset(
          'assets/images/header.png',
          height: _isLargeTablet(context)
              ? 70
              : (_isMediumTablet(context)
                  ? 60
                  : (_isSmallPhone(context) ? 34 : 40)),
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.radio,
              size: _isLargeTablet(context)
                  ? 48
                  : (_isMediumTablet(context)
                      ? 38
                      : (_isSmallPhone(context) ? 26 : 30)),
              color: Colors.white,
            ),
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<StreamBloc, StreamBlocState>(
          listener: (context, state) {
            // SPINNER DEBUG: Log state changes to understand the flow
            LoggerService.debug(
                '🔄 SPINNER: State changed to ${state.playbackState}, _showLocalLoading: $_showLocalLoading');

            // SPINNER FIX: Clear the spinner once playback settles, so it never
            // outlives the play attempt. We keep it during the in-progress
            // states (connecting/loading/buffering) and only treat a settled
            // state (paused/stopped/initial) as "done" after we've actually
            // seen progress — otherwise the transient old-state emit that fires
            // the moment play is dispatched would clear the spinner too early.
            if (_showLocalLoading) {
              final s = state.playbackState;
              final inProgress = s == StreamState.connecting ||
                  s == StreamState.loading ||
                  s == StreamState.buffering;
              if (inProgress) {
                _sawPlaybackProgress = true;
                LoggerService.debug(
                    '🔄 SPINNER: Keeping spinner - in-progress state is $s');
              } else if (s == StreamState.playing ||
                  s == StreamState.error ||
                  _sawPlaybackProgress) {
                // playing/error are definitive; paused/stopped/initial only
                // count once a real attempt has been observed.
                LoggerService.debug(
                    '🔄 SPINNER: Clearing spinner - state is $s');
                setState(() {
                  _showLocalLoading = false;
                });
                _sawPlaybackProgress = false;
                _cancelSpinnerTimeout();
              } else {
                LoggerService.debug(
                    '🔄 SPINNER: Keeping spinner - awaiting progress (state $s)');
              }
            }

            // NETWORK RECOVERY: Don't interfere with spinner during legitimate loading
            // The spinner timeout will handle stuck states if needed

            // Reset pause flag when pause completes
            if (_userPressedPause &&
                (state.playbackState == StreamState.paused ||
                    state.playbackState == StreamState.initial)) {
              setState(() {
                _userPressedPause = false;
              });
            }

            // Announce playback state transitions (polite)
            if (_lastAnnouncedPlayback != state.playbackState) {
              _lastAnnouncedPlayback = state.playbackState;
              final dir = Directionality.of(context);
              switch (state.playbackState) {
                case StreamState.playing:
                  SemanticsService.sendAnnouncement(
                      View.of(context), 'Playing KPFK stream', dir);
                  break;
                case StreamState.paused:
                  SemanticsService.sendAnnouncement(
                      View.of(context), 'Stream stopped and reset', dir);
                  break;
                case StreamState.loading:
                  SemanticsService.sendAnnouncement(
                      View.of(context), 'Loading audio', dir);
                  break;
                case StreamState.buffering:
                  SemanticsService.sendAnnouncement(
                      View.of(context), 'Buffering audio', dir);
                  break;
                case StreamState.error:
                  // error announcement happens below via error message if present
                  break;
                default:
                  break;
              }
            }

            // Announce metadata changes (show/song)
            final currentShow = state.metadata?.current.showName;
            if (currentShow != null &&
                currentShow.isNotEmpty &&
                currentShow != _lastAnnouncedShow) {
              _lastAnnouncedShow = currentShow;
              final dir = Directionality.of(context);
              final hasSong = state.metadata!.current.hasSongInfo;
              final msg = hasSong
                  ? 'Now playing ${state.metadata!.current.songTitle} by ${state.metadata!.current.songArtist} on ${state.metadata!.current.showName}'
                  : 'Now playing ${state.metadata!.current.showName}';
              SemanticsService.sendAnnouncement(View.of(context), msg, dir);
            }

            if (state.errorMessage != null && !state.showServerErrorModal) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage!,
                    style: AppTextStyles.bodyMedium,
                  ),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      context.read<StreamBloc>().add(RetryStream());
                    },
                  ),
                ),
              );
              // Announce error message for screen readers
              SemanticsService.sendAnnouncement(View.of(context),
                  state.errorMessage!, Directionality.of(context));
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                // Main content — a simple vertical stack: image, metadata, play
                // button. The image size is `clamp(spaceLeft, floor, bigWidth)`:
                //   • whenever there's room (spaceLeft ≥ bigWidth) the cap wins,
                //     so the image is the big width-based square and CANNOT be
                //     shrunk by text length — this is the guarantee every prior
                //     attempt lacked; and
                //   • only when the stacked content genuinely doesn't fit
                //     (spaceLeft < bigWidth, e.g. a small phone with wrapped
                //     text) does the image shrink, and by exactly the shortfall.
                // Wrapped in a scroll view purely as a last-ditch safety for
                // extreme accessibility font scaling.
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final mq = MediaQuery.of(context).size;
                      final bool small = _isSmallPhone(context);
                      final bool isTablet = mq.shortestSide > 600;
                      final double hPad = small ? 8.0 : 16.0;
                      // bottomReserve only has to clear the floating donate /
                      // alarm buttons, which are ~56px tall and sit in the
                      // CORNERS — the centered play button never reaches them —
                      // so it can be small. Keeping it at 90 was starving the
                      // image (it's subtracted from the image's space budget).
                      final double bottomReserve = small ? 40.0 : 48.0;
                      final double topGap = small ? 12.0 : 16.0;
                      final double gapAboveButton = small ? 20.0 : 28.0;
                      final double gapBelowButton = small ? 12.0 : 24.0;

                      // Play button footprint (must match the widget below).
                      final double buttonSize =
                          small ? 90.0 : (isTablet ? 150.0 : 120.0);
                      final double buttonMargin = small ? 4.0 : 8.0;
                      final double buttonBlock = buttonSize + buttonMargin * 2;

                      // The BIG width-based square — the size the image WANTS to
                      // be whenever there is room. This is the UPPER CAP of the
                      // clamp below, so the image can never grow past it and,
                      // crucially, can never be forced BELOW it while space
                      // remains.
                      final double bigWidthSize =
                          mq.width * (small ? 0.8 : (isTablet ? 0.72 : 0.85));

                      // Measure the real stacked content so we know how much
                      // vertical room is actually left for the image.
                      final double contentW = constraints.maxWidth - hPad * 2;
                      final double textBlockH = _measureMetadataHeight(
                        state: state,
                        size: mq,
                        small: small,
                        maxWidth: contentW,
                      );
                      final double viewportH =
                          constraints.maxHeight - bottomReserve;
                      final double spaceLeftForImage = viewportH -
                          topGap -
                          textBlockH -
                          gapAboveButton -
                          buttonBlock -
                          gapBelowButton;

                      // THE rule — big when it fits, shrink ONLY as a last resort:
                      //   • room to spare  → spaceLeft > bigWidthSize → cap wins
                      //                       → image = bigWidthSize (never shrinks)
                      //   • genuinely tight → spaceLeft < bigWidthSize
                      //                       → image = spaceLeft (shrinks to fit)
                      final double logoSize = spaceLeftForImage
                          .clamp(small ? 80.0 : 120.0, bigWidthSize)
                          .toDouble();
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: hPad,
                          right: hPad,
                          // Clear the floating donate / sleep-timer buttons.
                          bottom: bottomReserve,
                        ),
                        child: ConstrainedBox(
                          // Fill at least the viewport so the column can center
                          // its content vertically when there is room to spare.
                          // (Only a last-ditch scroll if even the floored image +
                          // content can't fit — e.g. huge accessibility fonts.)
                          constraints: BoxConstraints(minHeight: viewportH),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: topGap),
                              // Station image — fixed WIDTH-based square. Stays
                              // the same size across every show, regardless of
                              // how many lines the metadata wraps to.
                              SizedBox(
                                width: logoSize,
                                height: logoSize,
                                child: GestureDetector(
                                onTap: state.metadata != null
                                    ? () {
                                        setState(() {
                                          _showInfoModal = true;
                                        });
                                      }
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          const Color(0x1AFFFFFF), // ~10% white
                                      width: isTablet ? 1 : 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            red: 0,
                                            green: 0,
                                            blue: 0,
                                            alpha: 77), // ~0.3 opacity
                                        blurRadius: 8,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: state.metadata?.current
                                                .hasHostImage ==
                                            true
                                        ? Image.network(
                                            state.metadata!.current.hostImage!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    _buildLoadingContainer(
                                                        'Error loading image'),
                                          )
                                        : _buildLoadingContainer(
                                            'Loading stream information...'),
                                  ),
                                ),
                              ),
                            ),
                            // Show Information
                            if (state.metadata != null) ...[
                              SizedBox(height: small ? 8 : 20),
                              Text(
                                state.metadata!.current.showName,
                                style: AppTextStyles.showTitleForDevice(mq),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.metadata!.current.time,
                                style: AppTextStyles.showTimeForDevice(mq),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (state.metadata!.current.hasSongInfo) ...[
                                SizedBox(height: small ? 8 : 10),
                                Text(
                                  'Song: ${state.metadata!.current.songTitle} - ${state.metadata!.current.songArtist}',
                                  style: AppTextStyles.bodyLargeForDevice(mq),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else if (state
                                  .metadata!.next.showName.isNotEmpty) ...[
                                SizedBox(height: small ? 8 : 10),
                                Text(
                                  'Next: ${state.metadata!.next.showName}',
                                  style: AppTextStyles.bodyMediumForDevice(mq),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ] else ...[
                              const SizedBox(height: 20),
                              Text(
                                'Loading stream information...',
                                style: AppTextStyles.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                            // Breathing between the metadata and the play button.
                            SizedBox(height: gapAboveButton),
                            // Playback Control with Loading State
                            Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.symmetric(
                                  vertical: small ? 4.0 : 8.0),
                              child: Semantics(
                                button: true,
                                enabled: true,
                                label: _showLocalLoading
                                    ? 'Loading audio'
                                    : (state.playbackState ==
                                            StreamState.playing
                                        ? 'Stop stream and reset'
                                        : 'Play stream'),
                                hint: _showLocalLoading
                                    ? null
                                    : 'Double tap to ${state.playbackState == StreamState.playing ? 'stop and reset' : 'play'}',
                                liveRegion: _showLocalLoading,
                                child: Material(
                                  color: const Color(0xFF0F0404),
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: (!isOnline ||
                                            state.playbackState ==
                                                StreamState.loading ||
                                            state.playbackState ==
                                                StreamState.buffering ||
                                            _showLocalLoading)
                                        ? (!isOnline
                                            ? () {
                                                // Network alert will automatically appear via main.dart
                                                // No manual dialog needed with new system
                                                return;
                                              }
                                            : null)
                                        : () {
                                            if (state.playbackState ==
                                                StreamState.playing) {
                                              // PAUSE: Set flag to prevent spinner
                                              setState(() {
                                                _userPressedPause = true;
                                              });
                                              context
                                                  .read<StreamBloc>()
                                                  .add(PauseStream());
                                            } else {
                                              // PLAY: Show spinner - starting stream takes time
                                              LoggerService.debug(
                                                  '🔄 SPINNER: Play button pressed, current state: ${state.playbackState}');
                                              setState(() {
                                                _showLocalLoading = true;
                                                _sawPlaybackProgress = false;
                                                _userPressedPause = false;
                                              });
                                              LoggerService.debug(
                                                  '🔄 SPINNER: Spinner enabled, starting timeout');
                                              _startSpinnerTimeout();
                                              context
                                                  .read<StreamBloc>()
                                                  .add(StartStream());
                                            }
                                          },
                                    child: SizedBox(
                                      width: _isSmallPhone(context)
                                          ? 90.0
                                          : (MediaQuery.of(context)
                                                      .size
                                                      .shortestSide >
                                                  600
                                              ? 150.0
                                              : 120.0),
                                      height: _isSmallPhone(context)
                                          ? 90.0
                                          : (MediaQuery.of(context)
                                                      .size
                                                      .shortestSide >
                                                  600
                                              ? 150.0
                                              : 120.0),
                                      child: Center(
                                        child: (_showLocalLoading ||
                                                _isConnectingState(
                                                    state.playbackState))
                                            ? SizedBox(
                                                width: _isSmallPhone(context)
                                                    ? 38.0
                                                    : (MediaQuery.of(context)
                                                                .size
                                                                .shortestSide >
                                                            600
                                                        ? 64.0
                                                        : 50.0),
                                                height: _isSmallPhone(context)
                                                    ? 38.0
                                                    : (MediaQuery.of(context)
                                                                .size
                                                                .shortestSide >
                                                            600
                                                        ? 64.0
                                                        : 50.0),
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                  strokeWidth: 4.0,
                                                  strokeCap: StrokeCap.round,
                                                ),
                                              )
                                            : Icon(
                                                _getPlaybackIcon(
                                                    state.playbackState),
                                                size: _isSmallPhone(context)
                                                    ? 90.0
                                                    : (MediaQuery.of(context)
                                                                .size
                                                                .shortestSide >
                                                            600
                                                        ? 150.0
                                                        : 120.0),
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Error Display
                            if (state.errorMessage != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Card(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            state.errorMessage!,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          onPressed: () {
                                            context
                                                .read<StreamBloc>()
                                                .add(RetryStream());
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Breathing below the play button before the
                            // floating donate / sleep-timer strip.
                            SizedBox(height: gapBelowButton),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom-left Donate button
                Positioned(
                  left: _isSmallPhone(context) ? 12 : 16,
                  bottom: _isSmallPhone(context) ? 12 : 16,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      label: 'Donate',
                      button: true,
                      child: RawMaterialButton(
                        onPressed: () => _openDonateSheet(context),
                        elevation: 6,
                        fillColor: const Color(
                            0xFF1E1E1E), // dark gray chip background
                        shape: const CircleBorder(
                          side: BorderSide(
                              color: Color(0x1AFFFFFF),
                              width: 1), // subtle 10% white border
                        ),
                        constraints: BoxConstraints.tightFor(
                          width: _isSmallPhone(context)
                              ? 48
                              : (_isLargeTablet(context) ? 72 : 56),
                          height: _isSmallPhone(context)
                              ? 48
                              : (_isLargeTablet(context) ? 72 : 56),
                        ),
                        child: Icon(
                          Icons.volunteer_activism,
                          color: Colors.white,
                          size: _isSmallPhone(context)
                              ? 20
                              : (_isLargeTablet(context) ? 32 : 24),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom-right Alarm button (Sleep Timer)
                Positioned(
                  right: _isSmallPhone(context) ? 12 : 16,
                  bottom: _isSmallPhone(context) ? 12 : 16,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      label: 'Sleep timer',
                      button: true,
                      child: RawMaterialButton(
                        onPressed: () => _openAlarmSheet(context),
                        elevation: 6,
                        fillColor: const Color(0xFF1E1E1E),
                        shape: const CircleBorder(
                          side: BorderSide(color: Color(0x1AFFFFFF), width: 1),
                        ),
                        constraints: BoxConstraints.tightFor(
                          width: _isSmallPhone(context)
                              ? 48
                              : (_isLargeTablet(context) ? 72 : 56),
                          height: _isSmallPhone(context)
                              ? 48
                              : (_isLargeTablet(context) ? 72 : 56),
                        ),
                        child: BlocBuilder<SleepTimerCubit, SleepTimerState>(
                          bloc: di.getIt<SleepTimerCubit>(),
                          builder: (context, state) {
                            if (state is SleepTimerRunning ||
                                state is SleepTimerPaused) {
                              final cubit = di.getIt<SleepTimerCubit>();
                              final rem = cubit.remaining;
                              String two(int n) => n.toString().padLeft(2, '0');
                              final m = rem.inMinutes;
                              final s = rem.inSeconds % 60;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: Colors.white,
                                    size: _isSmallPhone(context)
                                        ? 16
                                        : (_isLargeTablet(context) ? 24 : 18),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$m:${two(s)}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _isSmallPhone(context)
                                          ? 9
                                          : (_isLargeTablet(context) ? 14 : 11),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Icon(
                              Icons.alarm,
                              color: Colors.white,
                              size: _isSmallPhone(context)
                                  ? 20
                                  : (_isLargeTablet(context) ? 32 : 24),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Audio Server Error Modal
                if (state.showServerErrorModal)
                  AudioServerErrorModal(
                    onDismiss: () {
                      context.read<StreamBloc>().add(ClearServerError());
                    },
                    customMessage: state.errorMessage,
                  ),

                // Show Info Modal
                if (_showInfoModal && state.metadata != null)
                  ShowInfoModal(
                    showName: state.metadata!.current.showName,
                    host: state.metadata!.current.host,
                    description: state.metadata!.current.description,
                    onClose: () {
                      setState(() {
                        _showInfoModal = false;
                      });
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDonateSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return const FractionallySizedBox(
          heightFactor: 0.9,
          child: DonateWebViewSheet(
            initialUrl: 'https://docs.pacifica.org/kpfk/donate/',
          ),
        );
      },
    );
  }

  void _openAlarmSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Sleep Timer',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, a1, a2) => const SleepTimerOverlay(),
      transitionBuilder: (ctx, anim, sec, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}
