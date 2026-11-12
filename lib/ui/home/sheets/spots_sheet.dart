import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sampan/core/constants/spot_presets.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/theme/sampan_theme.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/home/home_tab_provider.dart';

/// Opens "Your spots": saved places you can share or walk back to.
Future<void> showSpotsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) => const _SpotsSheet(),
  );
}

/// Opens the editor that saves a new spot at the current position,
/// optionally prefilled from one of the [SpotPresets.examples].
Future<SpotModel?> showSpotEditorSheet(
  BuildContext context, {
  SpotPreset? preset,
}) {
  return showModalBottomSheet<SpotModel?>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) => _SpotEditorSheet(preset: preset),
  );
}

class _SpotsSheet extends ConsumerWidget {
  const _SpotsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.38,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          children: <Widget>[
            Text(
              'Your spots',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Save places to find again — offline, anywhere.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey<String>('save-current-spot-btn'),
              onPressed: () => showSpotEditorSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: SampanTheme.brandViolet,
                foregroundColor: SampanTheme.brandLime,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: const Text(
                'Save where I am',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 16),
            if (state.spots.isEmpty)
              const SpotExamples()
            else
              ...state.spots.map((SpotModel spot) => _SpotTile(spot: spot)),
          ],
        );
      },
    );
  }
}

/// The two first-time examples. Tapping one opens the editor prefilled.
class SpotExamples extends StatelessWidget {
  const SpotExamples({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SampanTheme.brandLime,
        borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Try one',
            style: textTheme.labelLarge?.copyWith(
              color: SampanTheme.violet900,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < SpotPresets.examples.length; i++)
                ActionChip(
                  key: ValueKey<String>('spot-example-$i'),
                  backgroundColor: Colors.white,
                  avatar: Text(SpotPresets.examples[i].emoji),
                  label: Text(
                    SpotPresets.examples[i].name,
                    style: const TextStyle(
                      color: SampanTheme.violet900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => showSpotEditorSheet(
                    context,
                    preset: SpotPresets.examples[i],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotTile extends ConsumerWidget {
  const _SpotTile({required this.spot});

  final SpotModel spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final SampanController controller =
        ref.read(sampanControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    String subtitle =
        GeoMath.formatCoordinates(spot.latitude, spot.longitude);
    if (state.hasLocationFix) {
      final double dist = GeoMath.calculateHaversineDistanceMeters(
        startLat: state.userLatitude,
        startLon: state.userLongitude,
        endLat: spot.latitude,
        endLon: spot.longitude,
      );
      subtitle = '${GeoMath.formatDistance(dist)} away';
    }

    return Container(
      key: ValueKey<String>('spot-tile-${spot.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SampanTheme.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Text(spot.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  spot.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            key: ValueKey<String>('spot-guide-${spot.id}'),
            tooltip: 'Guide me there',
            style: IconButton.styleFrom(
              backgroundColor: SampanTheme.brandViolet,
              foregroundColor: SampanTheme.brandLime,
            ),
            icon: const Icon(Icons.explore_rounded, size: 20),
            onPressed: () {
              controller.selectTargetSpot(spot.id);
              ref.read(homeTabIndexProvider.notifier).state = HomeTab.radar;
              Navigator.of(context).pop();
            },
          ),
          IconButton(
            key: ValueKey<String>('spot-share-${spot.id}'),
            tooltip: 'Share with group',
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            onPressed: () async {
              await controller.shareSpot(spot);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Shared ${spot.name} with the group')),
              );
            },
          ),
          IconButton(
            key: ValueKey<String>('spot-delete-${spot.id}'),
            tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: () => controller.deleteSpot(spot.id),
          ),
        ],
      ),
    );
  }
}

class _SpotEditorSheet extends ConsumerStatefulWidget {
  const _SpotEditorSheet({this.preset});

  final SpotPreset? preset;

  @override
  ConsumerState<_SpotEditorSheet> createState() => _SpotEditorSheetState();
}

class _SpotEditorSheetState extends ConsumerState<_SpotEditorSheet> {
  late final TextEditingController _nameController;
  late String _emoji;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset?.name ?? '');
    _emoji = widget.preset?.emoji ?? SpotPresets.emojis.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final SpotModel? spot =
        await ref.read(sampanControllerProvider.notifier).createSpot(
              name: _nameController.text,
              emoji: _emoji,
            );
    if (!mounted) return;
    Navigator.of(context).pop(spot);
  }

  @override
  Widget build(BuildContext context) {
    final SampanAppState state = ref.watch(sampanControllerProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool canSave = state.hasLocationFix && !_isSaving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Save this spot',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey<String>('spot-name-input'),
              controller: _nameController,
              autofocus: widget.preset == null,
              maxLength: SpotModel.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Name it (e.g. Meeting point)',
                counterText: '',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SpotPresets.emojis.map((String emoji) {
                  final bool isSelected = emoji == _emoji;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey<String>('spot-emoji-$emoji'),
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(emoji, style: const TextStyle(fontSize: 18)),
                      onSelected: (_) => setState(() => _emoji = emoji),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Icon(
                  state.hasLocationFix
                      ? Icons.my_location_rounded
                      : Icons.satellite_alt_rounded,
                  size: 18,
                  color: state.hasLocationFix ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.hasLocationFix
                        ? 'Saves at ${GeoMath.formatCoordinates(state.userLatitude, state.userLongitude)}'
                        : 'Waiting for GPS — step under open sky.',
                    key: const ValueKey<String>('spot-location-status'),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey<String>('confirm-save-spot-btn'),
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: SampanTheme.brandViolet,
                foregroundColor: SampanTheme.brandLime,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Save spot',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
