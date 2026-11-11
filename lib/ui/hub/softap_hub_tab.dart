import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Module 3: Zero-Install SoftAP Hotspot Portal
/// (Section 4, Module 3 of `SAMPAN_BLUEPRINT.md`).
class SoftApHubTab extends ConsumerWidget {
  const SoftApHubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String primaryIp =
        state.softApIps.isNotEmpty ? state.softApIps.first : '192.168.43.1';
    final String portalUrl = 'http://$primaryIp:${state.softApPort}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        // Hero Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: state.isSoftApRunning
                ? scheme.primary
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    state.isSoftApRunning
                        ? Icons.wifi_tethering_rounded
                        : Icons.portable_wifi_off_rounded,
                    size: 32,
                    color: state.isSoftApRunning
                        ? scheme.onPrimary
                        : scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state.isSoftApRunning
                              ? 'SOFTAP RENDEZVOUS HUB ACTIVE'
                              : 'ZERO-INSTALL SOFTAP HUB (STANDBY)',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: state.isSoftApRunning
                                ? scheme.onPrimary
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Embedded Dart shelf HTTP + SSE Server on Port ${state.softApPort}',
                          style: textTheme.bodySmall?.copyWith(
                            color: state.isSoftApRunning
                                ? scheme.primaryContainer
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hotspot SSID: ${SampanConstants.softApDefaultSsid}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: state.isSoftApRunning
                            ? Colors.white
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Browser Portal: $portalUrl',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: state.isSoftApRunning
                                  ? const Color(0xFFA1EFFF)
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy Portal URL',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: portalUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied $portalUrl to clipboard'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: state.isSoftApRunning
                                ? Colors.white
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('toggle-softap-server-btn'),
                  onPressed: () => controller.toggleSoftApHub(),
                  style: FilledButton.styleFrom(
                    backgroundColor: state.isSoftApRunning
                        ? scheme.secondary
                        : scheme.primary,
                    foregroundColor: state.isSoftApRunning
                        ? scheme.onSecondary
                        : scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    state.isSoftApRunning
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_fill_rounded,
                  ),
                  label: Text(
                    state.isSoftApRunning
                        ? 'Stop Embedded Shelf Server'
                        : 'Launch Embedded Shelf Server (Port 8080)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Metrics Row
        Row(
          children: <Widget>[
            Expanded(
              child: _HubStatCard(
                label: 'BROWSER GUESTS',
                value: '${state.softApClientsCount}',
                subtitle: 'Live SSE streams',
                icon: Icons.devices_other_rounded,
                onRefresh: controller.refreshSoftApStats,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HubStatCard(
                label: 'P2P APK TRANSFERS',
                value: '${state.softApApkDownloads}',
                subtitle: '25 MB/s local Wi-Fi',
                icon: Icons.bolt_rounded,
                onRefresh: controller.refreshSoftApStats,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Direct 25 MB/s P2P APK Download Feature Card (Section 4, Module 3)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.system_security_update_good_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚡ Direct 25 MB/s P2P APK Distribution',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Guests who have not pre-installed Sampan simply connect to your Wi-Fi hotspot and open $portalUrl in Chrome or Safari. They can immediately chat, send SOS alerts, or tap "Download Native Sampan App" ($portalUrl/download/sampan.apk) to receive the full Android APK in < 5 seconds without internet.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Step-by-Step Guide Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outline.withAlpha(100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Cold-Start Adoption Flow (Zero Internet)',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const _StepRow(
                number: '1',
                title: 'Enable Phone Wi-Fi Hotspot',
                description:
                    'Turn on your Android/iOS personal hotspot (no cellular data required).',
              ),
              const SizedBox(height: 8),
              const _StepRow(
                number: '2',
                title: 'Start Embedded Dart Shelf Server',
                description:
                    'Tap "Launch Embedded Shelf Server" above to bind 0.0.0.0:8080.',
              ),
              const SizedBox(height: 8),
              _StepRow(
                number: '3',
                title: 'Guests Connect & Open Browser',
                description:
                    'Travelers open $portalUrl for instant group chat, offline GPS sharing, and SOS alerts.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubStatCard extends StatelessWidget {
  const _HubStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onRefresh,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onRefresh,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline.withAlpha(110)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 13,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
