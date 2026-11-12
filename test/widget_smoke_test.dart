import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/app.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/state/sampan_providers.dart';
import 'package:sampan/ui/home/home_shell.dart';

// Paris: proves nothing in the app is tied to one country or city.
const double _userLat = 48.8566;
const double _userLon = 2.3522;
const String _peerId =
    'aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66';

PeerModel _testPeer({bool drifted = false}) {
  return PeerModel(
    id: _peerId,
    displayName: 'Lea Martin',
    avatarIcon: '🎒',
    colorHex: 0xFF00A896,
    role: 'traveler',
    lastLatitude: 48.8600, // ~380 m due north of the user
    lastLongitude: _userLon,
    lastSeen: DateTime.now(),
    rssiDbm: drifted ? -92 : -60,
    isLeashFrozen: drifted,
  );
}

AppUpdateService _mockUpdateService(String tag) {
  return AppUpdateService(
    jsonFetcher: (Uri _) async => <String, dynamic>{
      'tag_name': tag,
      'name': 'Sampan (সাম্পান) $tag',
      'body': 'OTA GitHub Release auto-update test',
      'draft': false,
      'prerelease': false,
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Sampan.apk',
          'size': 22020096,
          'browser_download_url':
              'https://github.com/8Masum/sampan/releases/download/$tag/Sampan.apk',
        },
      ],
    },
  );
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(HomeShell)));
}

SampanController _controllerOf(WidgetTester tester) {
  return _containerOf(tester).read(sampanControllerProvider.notifier);
}

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Closes the top-most bottom sheet / dialog.
Future<void> _closeTopSheet(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Full v3 flow: onboarding, profile chip, people row, leash, spots, '
      'chat & SOS, scan-to-join hub QR, and OTA update',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final LocalDatabase testDb = LocalDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDatabaseProvider.overrideWithValue(testDb),
          appUpdateServiceProvider
              .overrideWithValue(_mockUpdateService('v3.6.0')),
        ],
        child: const SampanApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Onboarding: empty name field, no demo name prefilled.
    expect(find.textContaining('Stay together'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('onboarding-display-name')),
      'Maya',
    );
    await _tapVisible(tester, 'create-offline-identity-btn');

    // 2. Fresh install: compass, my chip, nobody nearby, no demo people.
    expect(
      find.byKey(const ValueKey<String>('compass-homing-dial')),
      findsOneWidget,
    );
    expect(testDb.currentPeers, isEmpty);
    expect(find.text('0 nearby'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('radar-invite-btn')),
      findsOneWidget,
    );

    // 3. Profile chip opens the editor; identity keys stay the same.
    final String originalKey = testDb.identity!.publicKeyHex;
    await _tapVisible(tester, 'my-profile-chip');
    await tester.enterText(
      find.byKey(const ValueKey<String>('profile-name-input')),
      'Maya Lopez',
    );
    await _tapVisible(tester, 'save-profile-btn');
    final IdentityProfile updated = testDb.identity!;
    expect(updated.displayName, equals('Maya Lopez'));
    expect(updated.publicKeyHex, equals(originalKey));

    // 4. A real person nearby shows up in the merged header row.
    final SampanController controller = _controllerOf(tester);
    controller.updateUserLocation(latitude: _userLat, longitude: _userLon);
    await testDb.upsertPeer(_testPeer());
    await tester.pumpAndSettle();
    expect(find.text('1 nearby'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('target-chip-$_peerId')),
      findsOneWidget,
    );
    expect(find.textContaining('Straight ahead'), findsOneWidget);

    // 5. Safety Leash alert can be acknowledged.
    await testDb.upsertPeer(_testPeer(drifted: true));
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'acknowledge-leash-btn');
    expect(testDb.getPeerById(_peerId)!.isLeashFrozen, isFalse);

    // 6. Outdoor contrast lives in the overflow menu.
    await _tapVisible(tester, 'open-overflow-menu-btn');
    await _tapVisible(tester, 'toggle-sunlight-mode-btn');

    // 7. Save a spot from the first-time example, then let it guide us.
    await _tapVisible(tester, 'open-spots-btn');
    await _tapVisible(tester, 'spot-example-0');
    await _tapVisible(tester, 'confirm-save-spot-btn');
    expect(testDb.currentSpots.length, equals(1));
    final SpotModel spot = testDb.currentSpots.first;
    expect(spot.name, equals('Meeting point'));
    expect(spot.latitude, closeTo(_userLat, 0.0001));
    await _tapVisible(tester, 'spot-guide-${spot.id}');
    expect(
      find.byKey(const ValueKey<String>('clear-spot-target-btn')),
      findsOneWidget,
    );
    await _tapVisible(tester, 'clear-spot-target-btn');

    // 8. Chat: share the spot with one tap, then SOS.
    await tester.tap(find.byKey(const ValueKey<String>('nav-chat')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'spot-chip-${spot.id}');
    expect(find.textContaining('Meeting point ·'), findsWidgets);

    await _tapVisible(tester, 'open-sos-megaphone-btn');
    await _tapVisible(tester, 'confirm-sos-broadcast-btn');
    expect(
      find.byKey(const ValueKey<String>('active-sos-alert-banner')),
      findsOneWidget,
    );
    await _tapVisible(tester, 'dismiss-sos-alert-btn');
    await _tapVisible(tester, 'spot-chip-${spot.id}');
    expect(
      find.byKey(const ValueKey<String>('active-sos-alert-banner')),
      findsNothing,
    );

    // 9. Hub: how-it-works when off, themed scan-to-join QR when live.
    await tester.tap(find.byKey(const ValueKey<String>('nav-hub')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('hub-how-it-works')),
      findsOneWidget,
    );
    await tester.runAsync(() => controller.toggleSoftApHub(port: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('join-qr-card')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('join-qr-code')), findsOneWidget);

    await _tapVisible(tester, 'qr-mode-wifi');
    await _tapVisible(tester, 'add-hotspot-btn');
    await tester.enterText(
      find.byKey(const ValueKey<String>('hotspot-ssid-input')),
      'Maya Phone',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('hotspot-password-input')),
      'test-pass',
    );
    await _tapVisible(tester, 'save-hotspot-btn');
    expect(testDb.hotspotSsid, equals('Maya Phone'));
    expect(find.textContaining('Maya Phone'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('join-qr-code')), findsOneWidget);
    await tester.runAsync(() => controller.toggleSoftApHub(port: 0));
    await tester.pumpAndSettle();

    // 10. Updates: check in the app, install via the browser.
    await _tapVisible(tester, 'open-update-sheet-btn');
    expect(find.text('App updates'), findsOneWidget);
    expect(find.textContaining('v3.6.0'), findsWidgets);
    await _tapVisible(tester, 'download-install-update-btn');
    expect(find.text('App updates'), findsNothing);
    expect(
      _containerOf(tester).read(sampanControllerProvider).updateStatusMessage,
      contains('browser'),
    );

    // Missed the browser's install prompt? The banner returns on resume.
    await _tapVisible(tester, 'dismiss-update-banner-btn');
    expect(
      find.byKey(const ValueKey<String>('update-available-banner')),
      findsNothing,
    );
    controller.onAppResumed();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('update-available-banner')),
      findsOneWidget,
    );

    await testDb.dispose();
  });

  testWidgets(
      'Narrow 320x640 viewport with 1.5x text scale renders onboarding, '
      'all tabs, sheets, and the live hub QR with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final LocalDatabase narrowDb = LocalDatabase();
    await narrowDb.upsertPeer(_testPeer());
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDatabaseProvider.overrideWithValue(narrowDb),
          appUpdateServiceProvider
              .overrideWithValue(_mockUpdateService('v3.5.1')),
        ],
        child: const SampanApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('onboarding-display-name')),
      'Alexandria Montgomery',
    );
    await _tapVisible(tester, 'create-offline-identity-btn');
    final SampanController controller = _controllerOf(tester);
    controller.updateUserLocation(latitude: _userLat, longitude: _userLon);
    await tester.pumpAndSettle();

    // Radar with a person, then the people and profile sheets.
    expect(
      find.byKey(const ValueKey<String>('compass-homing-dial')),
      findsOneWidget,
    );
    await _tapVisible(tester, 'nearby-people-chip');
    await _closeTopSheet(tester);
    await _tapVisible(tester, 'my-profile-chip');
    await _closeTopSheet(tester);

    // Spots sheet + editor.
    await _tapVisible(tester, 'open-spots-btn');
    await _tapVisible(tester, 'save-current-spot-btn');
    await _tapVisible(tester, 'confirm-save-spot-btn');
    expect(narrowDb.currentSpots.length, equals(1));
    await _closeTopSheet(tester);

    // Chat tab.
    await tester.tap(find.byKey(const ValueKey<String>('nav-chat')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('chat-message-input')),
      findsOneWidget,
    );

    // Hub tab, off and live (QR card).
    await tester.tap(find.byKey(const ValueKey<String>('nav-hub')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('toggle-softap-server-btn')),
      findsOneWidget,
    );
    await tester.runAsync(() => controller.toggleSoftApHub(port: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('join-qr-card')), findsOneWidget);
    await _tapVisible(tester, 'qr-mode-wifi');
    await tester.runAsync(() => controller.toggleSoftApHub(port: 0));
    await tester.pumpAndSettle();

    // Update sheet.
    await _tapVisible(tester, 'open-update-sheet-btn');
    expect(find.text('App updates'), findsOneWidget);

    await narrowDb.dispose();
  });
}
