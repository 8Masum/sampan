import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Shows the updater: checks GitHub Releases in the app, then hands the APK
/// to the browser, which downloads it fast and offers Android's own
/// "Install / Update" prompt.
void showAppUpdateSheet(BuildContext context, WidgetRef ref) {
  final SampanAppState current = ref.read(sampanControllerProvider);
  if (current.availableUpdate == null && !current.isCheckingForUpdate) {
    ref.read(sampanControllerProvider.notifier).checkForAppUpdate();
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ReleaseUpdateInfo? release = state.availableUpdate;
    final bool hasUpdate = state.hasAvailableUpdate;
    final String? status = state.updateStatusMessage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  hasUpdate
                      ? Icons.system_update_rounded
                      : Icons.verified_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'App updates',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Installed: v${state.installedVersion}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    release != null
                        ? 'Latest: ${release.tagName} (${release.formattedSize})'
                        : '${SampanConstants.githubOwner}/${SampanConstants.githubRepo}',
                    style: textTheme.bodySmall,
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      status,
                      key: const ValueKey<String>('update-status-message-text'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (release != null && release.releaseNotes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                release.releaseTitle,
                style:
                    textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: Text(release.releaseNotes, style: textTheme.bodySmall),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Icon(
                  Icons.open_in_browser_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Downloads in your browser — tap Install when it’s done.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('check-for-update-btn'),
                    onPressed: state.isCheckingForUpdate
                        ? null
                        : () => controller.checkForAppUpdate(),
                    icon: state.isCheckingForUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      state.isCheckingForUpdate ? 'Checking...' : 'Check',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('download-install-update-btn'),
                    onPressed: () async {
                      final bool opened =
                          await controller.openUpdateInBrowser();
                      if (opened && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SampanTheme.brandViolet,
                      foregroundColor: SampanTheme.brandLime,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      hasUpdate && release != null
                          ? 'Update (${release.tagName})'
                          : 'Reinstall',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
