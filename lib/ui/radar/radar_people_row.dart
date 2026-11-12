import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/home/sheets/people_sheet.dart';
import 'package:sampan/ui/home/sheets/profile_sheet.dart';

/// The single header row of the Radar: you (tap to edit your profile),
/// how many people are nearby (tap for the list), then each person
/// (tap to point the compass at them).
class RadarPeopleRow extends ConsumerWidget {
  const RadarPeopleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final String? targetPeerId = state.selectedTargetSpotId == null
        ? state.selectedTargetPeer?.id
        : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _MyProfileChip(
            identity: state.identity,
            onTap: () => showProfileSheet(context),
          ),
          const SizedBox(width: 8),
          _NearbyCountChip(
            count: state.peers.length,
            onTap: () => showPeopleSheet(context),
          ),
          ...state.peers.map((PeerModel peer) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                key: ValueKey<String>('target-chip-${peer.id}'),
                selected: peer.id == targetPeerId,
                onSelected: (_) => controller.selectTargetPeer(peer.id),
                avatar: Text(peer.avatarIcon),
                label: Text(
                  '${peer.displayName.split(' ').first}'
                  '${peer.isGuide ? ' · Guide' : ''}'
                  '${peer.isLeashFrozen ? ' ⚠️' : ''}',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MyProfileChip extends StatelessWidget {
  const _MyProfileChip({required this.identity, required this.onTap});

  final IdentityProfile? identity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String firstName =
        (identity?.displayName ?? 'You').split(' ').first;
    return Material(
      color: SampanTheme.brandLime,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey<String>('my-profile-chip'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 15,
                backgroundColor: Color(
                  identity?.colorHex ??
                      SampanConstants.identityColorHexes.first,
                ),
                child: Text(
                  identity?.avatarIcon ?? SampanConstants.avatarIcons.first,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  firstName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SampanTheme.violet900,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.edit_rounded,
                size: 14,
                color: SampanTheme.violet900,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyCountChip extends StatelessWidget {
  const _NearbyCountChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey<String>('nearby-people-chip'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: count > 0 ? SampanTheme.brandViolet : scheme.outline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count nearby',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
