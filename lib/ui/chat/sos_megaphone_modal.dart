import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/state/sampan_providers.dart';

/// High-priority Digital Megaphone (SOS) broadcast modal
/// (Section 4, Module 2 of `SAMPAN_BLUEPRINT.md`).
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
    'At Sugandha Beach main entrance — looking for Tour Guide!',
    'Need immediate medical / lifeguard assistance at my GPS coordinates!',
    'Battery below 10% — freezing my location at Kolatoli Dolphin Circle.',
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
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.campaign_rounded,
                    color: scheme.onError,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '🚨 DIGITAL MEGAPHONE (SOS)',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onError,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Broadcasts high-priority unencrypted alert + GPS bearing over BLE & SoftAP.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'One-Tap Emergency Callouts',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ..._presets.map((String preset) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ActionChip(
                  avatar: Icon(
                    Icons.bolt_rounded,
                    size: 18,
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
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('sos-custom-message-input'),
              controller: _textController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Emergency Broadcast Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey<String>('confirm-sos-broadcast-btn'),
              onPressed: _fireMegaphone,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.wifi_tethering_error_rounded),
              label: const Text(
                'FIRE SOS MEGAPHONE NOW',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
