import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/net/join_qr_payload.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/hub/join_qr_card.dart';

/// Module 3: Browser Hub — friends without the app join over the host's
/// hotspot by scanning a QR, then chat in any browser or grab the app.
class SoftApHubTab extends ConsumerWidget {
  const SoftApHubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final String primaryIp =
        state.softApIps.isNotEmpty ? state.softApIps.first : '192.168.43.1';
    final String hubUrl =
        JoinQrPayload.hubUrl(ip: primaryIp, port: state.softApPort);
    final bool isRunning = state.isSoftApRunning;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        _HubHeroCard(
          isRunning: isRunning,
          address: '$primaryIp:${state.softApPort}',
          onToggle: () => controller.toggleSoftApHub(),
          onCopy: () {
            Clipboard.setData(ClipboardData(text: hubUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied $hubUrl'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (isRunning) ...<Widget>[
          JoinQrCard(hubUrl: hubUrl),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _HubStatCard(
                  label: 'IN THE CHAT',
                  value: '${state.softApClientsCount}',
                  subtitle: 'Browsers',
                  onRefresh: controller.refreshSoftApStats,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HubStatCard(
                  label: 'APP SHARES',
                  value: '${state.softApApkDownloads}',
                  subtitle: 'Downloads',
                  onRefresh: controller.refreshSoftApStats,
                ),
              ),
            ],
          ),
        ] else
          const _HowItWorksCard(),
      ],
    );
  }
}

class _HubHeroCard extends StatelessWidget {
  const _HubHeroCard({
    required this.isRunning,
    required this.address,
    required this.onToggle,
    required this.onCopy,
  });

  final bool isRunning;
  final String address;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color ink = isRunning ? Colors.white : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isRunning ? SampanTheme.brandViolet : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Browser Hub',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color:
                        isRunning ? SampanTheme.brandLime : ink.withAlpha(200),
                  ),
                ),
              ),
              Container(
                key: const ValueKey<String>('hub-status-pill'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRunning
                      ? SampanTheme.brandLime
                      : scheme.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(SampanTheme.radiusPill),
                ),
                child: Text(
                  isRunning ? '● Live' : 'Off',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isRunning ? SampanTheme.violet900 : ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isRunning ? address : 'Chat without the app',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRunning
                ? 'Friends on your hotspot scan the QR below.'
                : 'Friends join from any browser — no internet needed.',
            style: textTheme.bodySmall?.copyWith(
              color: ink.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  key: const ValueKey<String>('toggle-softap-server-btn'),
                  onPressed: onToggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: isRunning
                        ? SampanTheme.brandLime
                        : SampanTheme.brandViolet,
                    foregroundColor:
                        isRunning ? SampanTheme.violet900 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isRunning ? 'Stop Hub' : 'Start Hub',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (isRunning) ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey<String>('copy-hub-link-btn'),
                    onPressed: onCopy,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text(
                      'Copy',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('hub-how-it-works'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SampanTheme.brandLime,
        borderRadius: BorderRadius.circular(SampanTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'How it works',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: SampanTheme.violet900,
                ),
          ),
          const SizedBox(height: 14),
          const _StepRow(
            number: '1',
            title: 'Turn on your phone’s hotspot',
            description: 'No mobile data or internet needed.',
          ),
          const SizedBox(height: 12),
          const _StepRow(
            number: '2',
            title: 'Tap Start Hub',
            description: 'A scan-to-join QR appears.',
          ),
          const SizedBox(height: 12),
          const _StepRow(
            number: '3',
            title: 'Friends scan it',
            description: 'They chat in the browser or grab the app.',
          ),
        ],
      ),
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
          color: scheme.primaryContainer,
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
                color: scheme.onPrimaryContainer.withAlpha(190),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withAlpha(200),
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 13,
          backgroundColor: SampanTheme.violet900,
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
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: SampanTheme.violet900,
                ),
              ),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: SampanTheme.violet900.withAlpha(200),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
