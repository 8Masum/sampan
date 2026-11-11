import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Module 3: Minimalist Material Design 3 Expressive SoftAP Hotspot Hub.
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
    final bool isRunning = state.isSoftApRunning;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        // 1. M3 Expressive Hero Hub Card (inspired by Screenshot 2 "Payground" card)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isRunning
                ? SampanTheme.brandViolet
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    isRunning ? 'Hotspot Hub Live' : 'Browser Hub',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isRunning
                          ? SampanTheme.brandLime
                          : scheme.onPrimaryContainer.withAlpha(200),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isRunning
                          ? Colors.white.withAlpha(30)
                          : scheme.surface.withAlpha(180),
                      borderRadius:
                          BorderRadius.circular(SampanTheme.radiusPill),
                    ),
                    child: Text(
                      SampanConstants.softApDefaultSsid,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isRunning
                            ? Colors.white
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sculptural Portal Address Display
              Text(
                '$primaryIp:${state.softApPort}',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: isRunning ? Colors.white : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Anyone on your Wi-Fi can join in their browser.',
                style: textTheme.bodySmall?.copyWith(
                  color: isRunning
                      ? Colors.white.withAlpha(210)
                      : scheme.onPrimaryContainer.withAlpha(190),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Pill Action Buttons Row
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      key: const ValueKey<String>('toggle-softap-server-btn'),
                      onPressed: () => controller.toggleSoftApHub(),
                      style: FilledButton.styleFrom(
                        backgroundColor: isRunning
                            ? SampanTheme.brandLime
                            : SampanTheme.brandViolet,
                        foregroundColor: isRunning
                            ? SampanTheme.violet900
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: const StadiumBorder(),
                      ),
                      icon: Icon(
                        isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        isRunning ? 'Stop Hub' : 'Start Hub',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: portalUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied $portalUrl'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isRunning
                            ? Colors.white.withAlpha(32)
                            : scheme.surface,
                        foregroundColor: isRunning
                            ? Colors.white
                            : scheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text(
                        'Copy',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Sculptural Stat Row
        Row(
          children: <Widget>[
            Expanded(
              child: _HubStatCard(
                label: 'CONNECTED',
                value: '${state.softApClientsCount}',
                subtitle: 'In browser',
                onRefresh: controller.refreshSoftApStats,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HubStatCard(
                label: 'APP SHARES',
                value: '${state.softApApkDownloads}',
                subtitle: 'Offline APK',
                onRefresh: controller.refreshSoftApStats,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Expressive Lime Highlight Card (Direct Offline APK Sharing)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SampanTheme.brandLime,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: SampanTheme.violet900,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: SampanTheme.brandLime,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Instant Offline App Share',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: SampanTheme.violet900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Friends without Sampan can chat in their browser or download the app directly from your phone.',
                      style: textTheme.bodySmall?.copyWith(
                        color: SampanTheme.violet900.withAlpha(215),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Minimal 3-Step Guide
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'How it works',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const _StepRow(
                number: '1',
                title: 'Turn on phone hotspot',
                description: 'No mobile data or internet needed.',
              ),
              const SizedBox(height: 12),
              const _StepRow(
                number: '2',
                title: 'Tap Start Hub',
                description: 'Opens a local chat room on your Wi-Fi.',
              ),
              const SizedBox(height: 12),
              _StepRow(
                number: '3',
                title: 'Open $portalUrl',
                description: 'Friends join instantly from Chrome or Safari.',
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
    required this.onRefresh,
  });

  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onRefresh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
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
          backgroundColor: SampanTheme.brandViolet,
          foregroundColor: SampanTheme.brandLime,
          child: Text(
            number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
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
