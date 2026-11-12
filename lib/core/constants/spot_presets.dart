/// Starter ideas for user-created Spots. Nothing here is tied to a country or
/// city: every spot is saved at the user's own GPS position when they create
/// it, so the same presets work on a beach, a trail, or a festival anywhere.
library;

class SpotPreset {
  const SpotPreset({required this.name, required this.emoji});

  final String name;
  final String emoji;
}

class SpotPresets {
  const SpotPresets._();

  /// The two examples shown to first-time users before they save any spot.
  static const List<SpotPreset> examples = <SpotPreset>[
    SpotPreset(name: 'Meeting point', emoji: '📍'),
    SpotPreset(name: 'Parking', emoji: '🚗'),
  ];

  /// Emoji choices offered when naming a spot.
  static const List<String> emojis = <String>[
    '📍',
    '⛺',
    '🚗',
    '🏨',
    '🍽️',
    '🚻',
    '⛰️',
    '🏖️',
    '🚉',
    '⚓',
  ];
}
