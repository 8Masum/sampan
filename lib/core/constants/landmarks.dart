/// Pre-loaded offline local landmark chips for one-tap situational sharing
/// in cellular blackout zones (Section 4, Module 2).
library;

class OfflineLandmark {
  const OfflineLandmark({
    required this.id,
    required this.name,
    required this.bengaliName,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.icon,
  });

  final String id;
  final String name;
  final String bengaliName;
  final double latitude;
  final double longitude;
  final String description;
  final String icon;
}

class OfflineLandmarks {
  const OfflineLandmarks._();

  static const List<OfflineLandmark> coxsBazarAndCoastal = <OfflineLandmark>[
    OfflineLandmark(
      id: 'laboni_point',
      name: 'Laboni Point',
      bengaliName: 'লাবণী পয়েন্ট',
      latitude: 21.4272,
      longitude: 91.9702,
      description: 'Main beach entrance & red lifeguard watchtower.',
      icon: '🏖️',
    ),
    OfflineLandmark(
      id: 'sugandha_beach',
      name: 'Sugandha Beach',
      bengaliName: 'সুগন্ধা সৈকত',
      latitude: 21.4195,
      longitude: 91.9756,
      description: 'Central seafront promenade & seafood market zone.',
      icon: '🌊',
    ),
    OfflineLandmark(
      id: 'kolatoli',
      name: 'Kolatoli Point',
      bengaliName: 'কলাতলী পয়েন্ট',
      latitude: 21.4112,
      longitude: 91.9825,
      description: 'Dolphin Circle junction & south beach access.',
      icon: '🐬',
    ),
    OfflineLandmark(
      id: 'inani_coral_reef',
      name: 'Inani Coral Reef',
      bengaliName: 'ইনানী প্রবাল সৈকত',
      latitude: 21.2314,
      longitude: 92.0468,
      description: 'Rocky coral shoreline along Marine Drive.',
      icon: '🪨',
    ),
    OfflineLandmark(
      id: 'himchari_waterfall',
      name: 'Himchari Waterfall',
      bengaliName: 'হিমছড়ি ঝর্ণা',
      latitude: 21.3536,
      longitude: 92.0241,
      description: 'Hilltop viewpoint & coastal cascade trail.',
      icon: '⛰️',
    ),
    OfflineLandmark(
      id: 'saint_martin_jetty',
      name: 'Saint Martin Jetty',
      bengaliName: 'সেন্টমার্টিন জেটি ঘাট',
      latitude: 20.6279,
      longitude: 92.3233,
      description: 'Main island boat landing pier & gathering hub.',
      icon: '⚓',
    ),
  ];
}
