import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/chat/caravan_chat_tab.dart';
import 'package:sampan/ui/home/home_tab_provider.dart';
import 'package:sampan/ui/home/sheets/profile_sheet.dart';
import 'package:sampan/ui/home/sheets/signal_sheet.dart';
import 'package:sampan/ui/home/sheets/spots_sheet.dart';
import 'package:sampan/ui/home/sheets/update_sheet.dart';
import 'package:sampan/ui/hub/softap_hub_tab.dart';
import 'package:sampan/ui/radar/compass_radar_tab.dart';

/// Minimalist Material Design 3 Expressive home shell: app bar, alert
/// banners, and the Radar / Chat / Hub tabs.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final int selectedIndex = ref.watch(homeTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Image.asset(
              SampanConstants.logoAssetPath,
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return Text(
                  state.identity?.avatarIcon ?? '⛵',
                  style: const TextStyle(fontSize: 20),
                );
              },
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Sampan',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('open-spots-btn'),
            tooltip: 'Spots',
            onPressed: () => showSpotsSheet(context),
            icon: const Icon(Icons.push_pin_outlined, size: 22),
          ),
          IconButton(
            key: const ValueKey<String>('open-update-sheet-btn'),
            tooltip: 'Updates',
            onPressed: () => showAppUpdateSheet(context, ref),
            icon: Badge(
              isLabelVisible: state.hasAvailableUpdate,
              backgroundColor: SampanTheme.brandViolet,
              child: const Icon(Icons.system_update_rounded, size: 22),
            ),
          ),
          _HomeOverflowMenu(
            state: state,
            onEditProfile: () => showProfileSheet(context),
            onToggleSunlight: controller.toggleSunlightHighContrast,
            onToggleDarkMode: () => controller.setVisualMode(
              state.visualMode == SampanVisualMode.dark
                  ? SampanVisualMode.light
                  : SampanVisualMode.dark,
            ),
            onOpenSignalInfo: () => showSignalSheet(context, state),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (state.hasAvailableUpdate && !state.isUpdateBannerDismissed)
            _UpdateBanner(
              tagName: state.availableUpdate?.tagName ?? '',
              onUpdate: () {
                showAppUpdateSheet(context, ref);
                controller.downloadAndInstallAppUpdate();
              },
              onDismiss: controller.dismissUpdateBanner,
            ),
          if (state.activeSosAlert != null)
            _SosBanner(
              alert: state.activeSosAlert!,
              onDismiss: controller.dismissActiveSosAlert,
            ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: const <Widget>[
                CompassRadarTab(),
                CaravanChatTab(),
                SoftApHubTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          ref.read(homeTabIndexProvider.notifier).state = index;
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            key: ValueKey<String>('nav-radar'),
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Radar',
          ),
          NavigationDestination(
            key: ValueKey<String>('nav-chat'),
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            key: ValueKey<String>('nav-hub'),
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering_rounded),
            label: 'Hub',
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.tagName,
    required this.onUpdate,
    required this.onDismiss,
  });

  final String tagName;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('update-available-banner'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SampanTheme.brandLime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.auto_awesome_rounded,
            color: SampanTheme.violet900,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sampan $tagName is ready',
              style: const TextStyle(
                color: SampanTheme.violet900,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey<String>('banner-install-update-btn'),
            onPressed: onUpdate,
            child: const Text(
              'Update',
              style: TextStyle(
                color: SampanTheme.violet900,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('dismiss-update-banner-btn'),
            onPressed: onDismiss,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: SampanTheme.violet900,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SosBanner extends StatelessWidget {
  const _SosBanner({required this.alert, required this.onDismiss});

  final MessageModel alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('active-sos-alert-banner'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: scheme.onError),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert.content,
              style: TextStyle(
                color: scheme.onError,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('dismiss-sos-alert-btn'),
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, color: scheme.onError),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

enum _OverflowAction { profile, sunlight, darkMode, signalInfo }

/// Secondary actions tucked into one overflow menu to keep the top bar calm.
class _HomeOverflowMenu extends StatelessWidget {
  const _HomeOverflowMenu({
    required this.state,
    required this.onEditProfile,
    required this.onToggleSunlight,
    required this.onToggleDarkMode,
    required this.onOpenSignalInfo,
  });

  final SampanAppState state;
  final VoidCallback onEditProfile;
  final VoidCallback onToggleSunlight;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onOpenSignalInfo;

  @override
  Widget build(BuildContext context) {
    final bool isDark = state.visualMode == SampanVisualMode.dark;
    return PopupMenuButton<_OverflowAction>(
      key: const ValueKey<String>('open-overflow-menu-btn'),
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_OverflowAction action) {
        switch (action) {
          case _OverflowAction.profile:
            onEditProfile();
          case _OverflowAction.sunlight:
            onToggleSunlight();
          case _OverflowAction.darkMode:
            onToggleDarkMode();
          case _OverflowAction.signalInfo:
            onOpenSignalInfo();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_OverflowAction>>[
        const PopupMenuItem<_OverflowAction>(
          key: ValueKey<String>('open-profile-menu-item'),
          value: _OverflowAction.profile,
          child: _MenuRow(
            icon: Icons.person_outline_rounded,
            label: 'Edit profile',
          ),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<_OverflowAction>(
          key: const ValueKey<String>('toggle-sunlight-mode-btn'),
          value: _OverflowAction.sunlight,
          checked: state.isSunlightMode,
          child: const Text('Outdoor contrast'),
        ),
        CheckedPopupMenuItem<_OverflowAction>(
          key: const ValueKey<String>('toggle-dark-mode-btn'),
          value: _OverflowAction.darkMode,
          checked: isDark,
          child: const Text('Dark theme'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_OverflowAction>(
          key: ValueKey<String>('open-protocol-inspector-btn'),
          value: _OverflowAction.signalInfo,
          child: _MenuRow(icon: Icons.sensors_rounded, label: 'Signal info'),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}
