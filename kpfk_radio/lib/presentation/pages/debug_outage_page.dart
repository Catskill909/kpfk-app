import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/testing/debug_stream_override.dart';
import '../../domain/models/stream_notice.dart';
import '../bloc/stream_bloc.dart';
import '../theme/font_constants.dart';

/// Rehearse every outage the app can hit — without taking the station off air.
///
/// Two levels of fidelity:
///  • **Redirect the stream** to a broken endpoint, then press play on the home
///    screen. This exercises the REAL pipeline (`.m3u` resolve → health probe →
///    classification → notice), so a pass here means the detection genuinely
///    works, not just that the modal can be drawn.
///  • **Show a notice directly**, for checking wording and layout on a real
///    screen without waiting for a probe.
///
/// Debug builds only — [SettingsPage] never links here in release, and
/// [DebugStreamOverride] refuses to hold an override outside [kDebugMode].
class DebugOutagePage extends StatefulWidget {
  const DebugOutagePage({super.key});

  @override
  State<DebugOutagePage> createState() => _DebugOutagePageState();
}

class _DebugOutagePageState extends State<DebugOutagePage> {
  Future<void> _showPresetConfirmation(DebugOutagePreset preset) async {
    final isLive = preset.url == null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1C1413),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isLive ? Colors.green : const Color(0xFFE53935))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLive ? Icons.radio_rounded : Icons.science_outlined,
                  color: isLive ? Colors.green : const Color(0xFFE53935),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isLive ? 'Live stream restored' : 'Test ready',
                textAlign: TextAlign.center,
                style: AppTextStyles.drawerTitle,
              ),
              const SizedBox(height: 10),
              Text(
                isLive
                    ? 'The app is pointing at the real KPFK stream again. '
                        'Return to the player and press Play.'
                    : '${preset.label} is selected. The loaded audio source '
                        'has been cleared, so the next Play will run this test.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Go to player'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Keep testing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = DebugStreamOverride.activeLabel;

    return Scaffold(
      appBar: AppBar(
          title: Text('Outage Testing', style: AppTextStyles.drawerTitle)),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: active == null
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.2),
            padding: const EdgeInsets.all(16),
            child: Text(
              active == null
                  ? 'Pointing at the LIVE stream.'
                  : 'REDIRECTED → $active\n'
                      'The live stream is untouched; only this app is looking '
                      'elsewhere. Reset to Live when you are done.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              '1 · REDIRECT THE STREAM, THEN PRESS PLAY',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Pick one, go back, and press play. The app runs its real '
              'detection against a dead endpoint. No listener is affected.',
            ),
          ),
          ...DebugOutagePreset.all.map((preset) {
            final selected = preset.url == DebugStreamOverride.url;
            return ListTile(
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(preset.label, style: AppTextStyles.bodyMedium),
              subtitle:
                  Text('${preset.description}\nExpect: ${preset.expected}'),
              isThreeLine: true,
              onTap: () async {
                setState(() {
                  if (preset.url == null) {
                    DebugStreamOverride.clear();
                  } else {
                    DebugStreamOverride.apply(preset);
                  }
                });
                // iOS normally resumes an already-loaded source in place to
                // avoid a lock-screen artwork flash. For outage rehearsal that
                // would keep playing the old live source after the override
                // changes, making the selected preset appear ineffective.
                // Stop first so the next Play performs a cold load from the
                // newly selected URL.
                context.read<StreamBloc>().add(StopStream());
                await _showPresetConfirmation(preset);
              },
            );
          }),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              '2 · SHOW A NOTICE DIRECTLY',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Skips detection — for checking wording, layout and the buttons. '
              'The connection variant is otherwise hard to trigger on purpose, '
              'since it needs something like a captive-portal Wi-Fi.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wifi_tethering_off_rounded),
            title: Text('Show OUTAGE notice', style: AppTextStyles.bodyMedium),
            subtitle: const Text('"We\'ll be right back" + Got it'),
            onTap: () {
              context.read<StreamBloc>().add(StreamNoticeRaised(
                    const StreamNotice.outage(
                        detail: 'Simulated: stream not found on server'),
                  ));
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_off_rounded),
            title:
                Text('Show CONNECTION notice', style: AppTextStyles.bodyMedium),
            subtitle:
                const Text('"Can\'t reach the stream" + Try again / Dismiss'),
            onTap: () {
              context
                  .read<StreamBloc>()
                  .add(StreamNoticeRaised(const StreamNotice.connection()));
              Navigator.of(context).pop();
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Also worth checking: with the live stream selected, play and '
              'pause a few times and let it run through a rebuffer. No modal '
              'should EVER appear. A false alarm is worse than silence.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
