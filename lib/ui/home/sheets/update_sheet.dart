import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/state/sampan_providers.dart';

/// Shows the GitHub Releases updater (check, download, install).
void showAppUpdateSheet(BuildContext context, WidgetRef ref) {
  final SampanAppState current = ref.read(sampanControllerProvider);
  if (current.availableUpdate == null && !current.isCheckingForUpdate) {
    ref.read(sampanControllerProvider.notifier).checkForAppUpdate();
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext ctx, WidgetRef sheetRef, Widget? _) {
          final SampanAppState liveState =
              sheetRef.watch(sampanControllerProvider);
          final SampanController notifier =
              sheetRef.read(sampanControllerProvider.notifier);
          final ColorScheme scheme = Theme.of(ctx).colorScheme;
          final ReleaseUpdateInfo? release = liveState.availableUpdate;
          final bool hasUpdate = liveState.hasAvailableUpdate;
          final int pct =
              (liveState.updateDownloadProgress * 100).round().clamp(0, 100);

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
                          'GitHub Release Auto-Update',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
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
                          'Installed: v${liveState.installedVersion}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          release != null
                              ? 'Latest: ${release.tagName} (${release.formattedSize})'
                              : '${SampanConstants.githubOwner}/${SampanConstants.githubRepo}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        if (liveState.updateStatusMessage != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            liveState.updateStatusMessage!,
                            key: const ValueKey<String>(
                              'update-status-message-text',
                            ),
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
                  if (release != null &&
                      release.releaseNotes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      release.releaseTitle,
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 110),
                      child: SingleChildScrollView(
                        child: Text(
                          release.releaseNotes,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                  if (liveState.isDownloadingUpdate) ...<Widget>[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: liveState.updateDownloadProgress > 0
                          ? liveState.updateDownloadProgress
                          : null,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Downloading... $pct%',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey<String>('check-for-update-btn'),
                          onPressed: (liveState.isCheckingForUpdate ||
                                  liveState.isDownloadingUpdate)
                              ? null
                              : () => notifier.checkForAppUpdate(
                                    silent: false,
                                  ),
                          icon: liveState.isCheckingForUpdate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            liveState.isCheckingForUpdate
                                ? 'Checking...'
                                : 'Check',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey<String>(
                            'download-install-update-btn',
                          ),
                          onPressed: liveState.isDownloadingUpdate
                              ? null
                              : notifier.downloadAndInstallAppUpdate,
                          icon: const Icon(
                            Icons.download_for_offline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            hasUpdate
                                ? 'Update (${release!.tagName})'
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
        },
      );
    },
  );
}
