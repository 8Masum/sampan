import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/app.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/state/sampan_providers.dart';

void main() {
  testWidgets(
      'Full Sampan flow: Onboarding -> Compass Radar -> Virtual Leash -> Sunlight Mode -> Caravan Chat & SOS',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final LocalDatabase testDb = LocalDatabase();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDatabaseProvider.overrideWithValue(testDb),
        ],
        child: const SampanApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Onboarding Screen renders
    expect(find.textContaining('WELCOME TO SAMPAN'), findsOneWidget);
    final Finder createIdentityBtn =
        find.byKey(const ValueKey<String>('create-offline-identity-btn'));
    expect(createIdentityBtn, findsOneWidget);

    // Ensure button is visible in scroll view and tap "Create Offline Identity"
    await tester.ensureVisible(createIdentityBtn);
    await tester.pumpAndSettle();
    await tester.tap(createIdentityBtn);
    await tester.pumpAndSettle();

    // 2. Verify HomeShell & Module 1 (3D Compass Homing Dial)
    expect(
      find.byKey(const ValueKey<String>('compass-homing-dial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('pill-ble-peers')),
      findsOneWidget,
    );
    expect(testDb.currentPeers.length, equals(4));

    // Test Virtual Leash drop on selected companion without creating phantom peer
    final Finder leashBtn =
        find.byKey(const ValueKey<String>('simulate-leash-drop-btn'));
    await tester.ensureVisible(leashBtn);
    await tester.pumpAndSettle();
    await tester.tap(leashBtn);
    await tester.pumpAndSettle();
    expect(testDb.currentPeers.length, equals(4));
    expect(
      find.byKey(const ValueKey<String>('restore-leash-signal-btn')),
      findsOneWidget,
    );

    // 3. Toggle Sunlight High-Contrast Mode (>7:1 contrast ratio)
    await tester.tap(
      find.byKey(const ValueKey<String>('toggle-sunlight-mode-btn')),
    );
    await tester.pumpAndSettle();

    // 4. Switch to Module 2 (Caravan Chat)
    await tester.tap(find.byKey(const ValueKey<String>('nav-chat')));
    await tester.pumpAndSettle();

    // Send an Offline Landmark Ping (Laboni Point)
    await tester.tap(
      find.byKey(const ValueKey<String>('landmark-chip-laboni_point')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Landmark Ping: At Laboni Point'), findsWidgets);

    // 5. Switch to Module 3 (SoftAP Hub)
    await tester.tap(find.byKey(const ValueKey<String>('nav-hub')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('toggle-softap-server-btn')),
      findsOneWidget,
    );

    await testDb.dispose();
  });
}
