import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/common/guide_line.dart';
import 'package:sampan/ui/home/home_tab_provider.dart';

/// Opens the list of people nearby, with a short how-to when it's empty.
Future<void> showPeopleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) => const _PeopleSheet(),
  );
}

class _PeopleSheet extends ConsumerWidget {
  const _PeopleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.56,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      builder: (BuildContext context, ScrollController scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          children: <Widget>[
            Text(
              'People nearby (${state.peers.length})',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              state.peers.isEmpty
                  ? 'Nobody yet — here’s how friends show up.'
                  : 'Tap someone to point your compass at them.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (state.peers.isEmpty)
              _EmptyPeopleGuide(
                onOpenHub: () {
                  ref.read(homeTabIndexProvider.notifier).state = HomeTab.hub;
                  Navigator.of(context).pop();
                },
              )
            else
              ...state.peers.map(
                (PeerModel peer) => _PeerTile(peer: peer, state: state),
              ),
          ],
        );
      },
    );
  }
}

class _PeerTile extends ConsumerWidget {
  const _PeerTile({required this.peer, required this.state});

  final PeerModel peer;
  final SampanAppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final double? lat = peer.lastLatitude;
    final double? lon = peer.lastLongitude;
    String whereText = 'Location unknown';
    if (state.hasLocationFix && lat != null && lon != null) {
      final double dist = GeoMath.calculateHaversineDistanceMeters(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: lat,
        endLon: lon,
      );
      final double bearing = GeoMath.calculateBearingDegrees(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: lat,
        endLon: lon,
      );
      whereText = '${GeoMath.formatDistance(dist)} · '
          '${GeoMath.cardinalDirectionFromBearing(bearing)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Color(peer.colorHex),
          child: Text(peer.avatarIcon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          peer.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${peer.isGuide ? 'Guide' : 'Traveler'} · $whereText',
        ),
        trailing: IconButton.filledTonal(
          tooltip: 'Message',
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          onPressed: () {
            controller.setActiveDmPeer(peer.id);
            ref.read(homeTabIndexProvider.notifier).state = HomeTab.chat;
            Navigator.of(context).pop();
          },
        ),
        onTap: () {
          controller.selectTargetPeer(peer.id);
          ref.read(homeTabIndexProvider.notifier).state = HomeTab.radar;
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _EmptyPeopleGuide extends StatelessWidget {
  const _EmptyPeopleGuide({required this.onOpenHub});

  final VoidCallback onOpenHub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SampanTheme.brandLime,
        borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const GuideLine(
            icon: Icons.bluetooth_searching_rounded,
            text: 'Friends with Sampan open nearby appear here on their own.',
          ),
          const SizedBox(height: 12),
          const GuideLine(
            icon: Icons.qr_code_2_rounded,
            text: 'No app yet? Start the Hub and let them scan your QR.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey<String>('people-open-hub-btn'),
            onPressed: onOpenHub,
            style: FilledButton.styleFrom(
              backgroundColor: SampanTheme.violet900,
              foregroundColor: SampanTheme.brandLime,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
            label: const Text(
              'Open Hub',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
