import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/app.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/state/sampan_providers.dart';

void main() {
  testWidgets(
      'Full Sampan flow: Onboarding -> Compass Radar -> Virtual Leash -> Sunlight Mode -> Caravan Chat & SOS -> GitHub Auto-Update',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final LocalDatabase testDb = LocalDatabase();
    final AppUpdateService mockUpdateService = AppUpdateService(
      jsonFetcher: (Uri _) async => <String, dynamic>{
        'tag_name': 'v2.1.0',
        'name': 'Sampan (সাম্পান) v2.1.0',
        'body': 'OTA GitHub Release auto-update test',
        'draft': false,
        'prerelease': false,
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sampan.apk',
            'size': 22020096,
            'browser_download_url':
                'https://github.com/8Masum/sampan/releases/download/v2.1.0/Sampan.apk',
          },
        ],
      },
      apkDownloader: ({
        required Uri url,
        required File destinationFile,
        void Function(double progress)? onProgress,
      }) async {
        onProgress?.call(1.0);
        destinationFile.writeAsBytesSync(
          const <int>[0x50, 0x4B, 0x03, 0x04, 0x01, 0x02],
        );
        return destinationFile;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDatabaseProvider.overrideWithValue(testDb),
          appUpdateServiceProvider.overrideWithValue(mockUpdateService),
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

    // 3. Toggle Sunlight High-Contrast Mode (>7:1 contrast ratio) via the
    //    AppBar overflow menu
    await tester.tap(
      find.byKey(const ValueKey<String>('open-overflow-menu-btn')),
    );
    await tester.pumpAndSettle();
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

    // Fire SOS Digital Megaphone, verify banner, dismiss it, and ensure it stays dismissed
    await tester.tap(
      find.byKey(const ValueKey<String>('open-sos-megaphone-btn')),
    );
    await tester.pumpAndSettle();
    final Finder confirmSosBtn =
        find.byKey(const ValueKey<String>('confirm-sos-broadcast-btn'));
    await tester.ensureVisible(confirmSosBtn);
    await tester.pumpAndSettle();
    await tester.tap(confirmSosBtn);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('active-sos-alert-banner')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('dismiss-sos-alert-btn')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('active-sos-alert-banner')),
      findsNothing,
    );

    // Trigger another database update (landmark ping) and confirm dismissed SOS does not reappear
    await tester.tap(
      find.byKey(const ValueKey<String>('landmark-chip-laboni_point')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('active-sos-alert-banner')),
      findsNothing,
    );

    // 5. Switch to Module 3 (SoftAP Hub)
    await tester.tap(find.byKey(const ValueKey<String>('nav-hub')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('toggle-softap-server-btn')),
      findsOneWidget,
    );

    // 6. Open GitHub Release Auto-Update Sheet, check & trigger APK install
    await tester.tap(
      find.byKey(const ValueKey<String>('open-update-sheet-btn')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('GitHub Release Auto-Update'), findsOneWidget);
    expect(find.textContaining('v2.1.0'), findsWidgets);

    final Finder installBtn =
        find.byKey(const ValueKey<String>('download-install-update-btn'));
    await tester.ensureVisible(installBtn);
    await tester.pumpAndSettle();
    await tester.tap(installBtn);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Launching Android package installer'),
      findsOneWidget,
    );

    await testDb.dispose();
  });

  testWidgets(
      'Narrow 320x640 viewport with 1.5x text scale renders Onboarding and all 3 HomeShell tabs with zero RenderFlex overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final LocalDatabase narrowDb = LocalDatabase();
    final AppUpdateService mockUpdateService = AppUpdateService(
      jsonFetcher: (Uri _) async => <String, dynamic>{
        'tag_name': 'v2.0.2',
        'name': 'Sampan (সাম্পান) v2.0.2',
        'body': 'Compact layout verification',
        'draft': false,
        'prerelease': false,
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sampan.apk',
            'size': 22020096,
            'browser_download_url':
                'https://github.com/8Masum/sampan/releases/download/v2.0.2/Sampan.apk',
          },
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDatabaseProvider.overrideWithValue(narrowDb),
          appUpdateServiceProvider.overrideWithValue(mockUpdateService),
        ],
        child: const SampanApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Onboarding on 320dp @ 1.5x text scale
    final Finder startBtn =
        find.byKey(const ValueKey<String>('create-offline-identity-btn'));
    await tester.ensureVisible(startBtn);
    await tester.pumpAndSettle();
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    // 2. Radar tab on 320dp @ 1.5x text scale
    expect(
      find.byKey(const ValueKey<String>('compass-homing-dial')),
      findsOneWidget,
    );

    // 3. Chat tab on 320dp @ 1.5x text scale
    await tester.tap(find.byKey(const ValueKey<String>('nav-chat')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('chat-message-input')),
      findsOneWidget,
    );

    // 4. Hub tab on 320dp @ 1.5x text scale
    await tester.tap(find.byKey(const ValueKey<String>('nav-hub')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('toggle-softap-server-btn')),
      findsOneWidget,
    );

    // 5. Update bottom sheet on 320dp @ 1.5x text scale
    await tester.tap(
      find.byKey(const ValueKey<String>('open-update-sheet-btn')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('GitHub Release Auto-Update'), findsOneWidget);

    await narrowDb.dispose();
  });
}
