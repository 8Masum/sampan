import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/net/join_qr_payload.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/state/sampan_providers.dart';

enum _JoinStep { wifi, hub }

/// Two-step "scan to join" QR for friends without the app:
/// 1 · join the host's Wi-Fi hotspot, 2 · open the Hub in the browser.
class JoinQrCard extends ConsumerStatefulWidget {
  const JoinQrCard({super.key, required this.hubUrl});

  final String hubUrl;

  @override
  ConsumerState<JoinQrCard> createState() => _JoinQrCardState();
}

class _JoinQrCardState extends ConsumerState<JoinQrCard> {
  _JoinStep? _step;

  @override
  Widget build(BuildContext context) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final String? ssid = state.hotspotSsid;
    final _JoinStep step =
        _step ?? (ssid == null ? _JoinStep.hub : _JoinStep.wifi);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final String? qrData = switch (step) {
      _JoinStep.wifi => ssid == null
          ? null
          : JoinQrPayload.wifi(ssid: ssid, password: state.hotspotPassword),
      _JoinStep.hub => widget.hubUrl,
    };
    final String caption = switch (step) {
      _JoinStep.wifi => ssid == null
          ? 'Add your hotspot once — friends join with one scan.'
          : 'Friends scan with their camera to join “$ssid”.',
      _JoinStep.hub => 'Then scan this to open the Hub in a browser.',
    };

    return Container(
      key: const ValueKey<String>('join-qr-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Scan to join',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SegmentedButton<_JoinStep>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<_JoinStep>>[
                ButtonSegment<_JoinStep>(
                  value: _JoinStep.wifi,
                  label: Text(
                    '1 · Wi-Fi',
                    key: ValueKey<String>('qr-mode-wifi'),
                  ),
                ),
                ButtonSegment<_JoinStep>(
                  value: _JoinStep.hub,
                  label: Text(
                    '2 · Hub',
                    key: ValueKey<String>('qr-mode-hub'),
                  ),
                ),
              ],
              selected: <_JoinStep>{step},
              onSelectionChanged: (Set<_JoinStep> next) =>
                  setState(() => _step = next.first),
            ),
          ),
          const SizedBox(height: 16),
          if (qrData != null)
            _ThemedQr(data: qrData)
          else
            _AddHotspotPrompt(onAdd: () => showHotspotDialog(context)),
          const SizedBox(height: 12),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (step == _JoinStep.wifi && ssid != null)
            TextButton(
              key: const ValueKey<String>('edit-hotspot-btn'),
              onPressed: () => showHotspotDialog(context),
              child: const Text('Edit hotspot'),
            ),
        ],
      ),
    );
  }
}

/// QR code in Sampan's violet & lime style with the logo in the center.
class _ThemedQr extends StatelessWidget {
  const _ThemedQr({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
        border: Border.all(color: SampanTheme.brandLime, width: 6),
      ),
      child: QrImageView(
        key: const ValueKey<String>('join-qr-code'),
        data: data,
        size: 200,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.circle,
          color: SampanTheme.violet900,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.circle,
          color: SampanTheme.brandViolet,
        ),
        embeddedImage: const AssetImage(SampanConstants.logoAssetPath),
        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
      ),
    );
  }
}

class _AddHotspotPrompt extends StatelessWidget {
  const _AddHotspotPrompt({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      height: 232,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SampanTheme.brandLime,
        borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.wifi_rounded,
            size: 40,
            color: SampanTheme.violet900,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey<String>('add-hotspot-btn'),
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: SampanTheme.violet900,
              foregroundColor: SampanTheme.brandLime,
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Add hotspot',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the phone hotspot's name & password (as shown in the phone's
/// hotspot settings) so Sampan can draw a Wi-Fi join QR.
Future<void> showHotspotDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => const _HotspotDialog(),
  );
}

class _HotspotDialog extends ConsumerStatefulWidget {
  const _HotspotDialog();

  @override
  ConsumerState<_HotspotDialog> createState() => _HotspotDialogState();
}

class _HotspotDialogState extends ConsumerState<_HotspotDialog> {
  late final TextEditingController _ssidController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final SampanAppState state = ref.read(sampanControllerProvider);
    _ssidController = TextEditingController(text: state.hotspotSsid ?? '');
    _passwordController =
        TextEditingController(text: state.hotspotPassword ?? '');
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(sampanControllerProvider.notifier).saveHotspotCredentials(
          ssid: _ssidController.text,
          password: _passwordController.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your hotspot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Copy these from your phone’s hotspot settings.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('hotspot-ssid-input'),
            controller: _ssidController,
            decoration: const InputDecoration(hintText: 'Hotspot name'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('hotspot-password-input'),
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Password (empty if open)',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('save-hotspot-btn'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
