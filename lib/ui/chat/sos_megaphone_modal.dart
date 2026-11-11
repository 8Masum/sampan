import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Minimalist Material Design 3 Expressive SOS Broadcast Modal.
class SosMegaphoneModal extends ConsumerStatefulWidget {
  const SosMegaphoneModal({super.key});

  @override
  ConsumerState<SosMegaphoneModal> createState() => _SosMegaphoneModalState();
}

class _SosMegaphoneModalState extends ConsumerState<SosMegaphoneModal> {
  final TextEditingController _textController = TextEditingController(
    text: 'Separated near Laboni Point red lifeguard stand!',
  );

  static const List<String> _presets = <String>[
    'Separated near Laboni Point red lifeguard stand!',
    'Waiting at Sugandha Beach main entrance.',
    'Need help at my current location.',
    'Battery low — staying at Kolatoli Circle.',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fireMegaphone() async {
    final String msg = _textController.text.trim();
    if (msg.isEmpty) return;
    await ref
        .read(sampanControllerProvider.notifier)
        .broadcastSosMegaphone(emergencyMessage: msg);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.campaign_rounded,
                    color: scheme.onError,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Send SOS Alert',
                          style: textTheme.titleLarge?.copyWith(
                            color: scheme.onError,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Alerts everyone nearby with your exact direction.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onError.withAlpha(230),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Quick messages',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ..._presets.map((String preset) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ActionChip(
                  avatar: Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: scheme.error,
                  ),
                  label: Text(
                    preset,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    setState(() {
                      _textController.text = preset;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('sos-custom-message-input'),
              controller: _textController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'What happened?',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey<String>('confirm-sos-broadcast-btn'),
              onPressed: _fireMegaphone,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.wifi_tethering_error_rounded),
              label: const Text(
                'Send SOS Now',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
