import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/data/services/app_update_service.dart';
import 'package:sampan/data/services/native_bridge.dart';

void main() {
  group('AppUpdateService version parsing & comparison', () {
    test('normalizes v-prefixes and build metadata', () {
      expect(AppUpdateService.normalizeVersion('v1.0.0'), equals('1.0.0'));
      expect(AppUpdateService.normalizeVersion('V2.3.4+12'), equals('2.3.4'));
      expect(AppUpdateService.normalizeVersion('  1.0.1  '), equals('1.0.1'));
      expect(
        AppUpdateService.normalizeVersion('release-v1.2.0'),
        equals('1.2.0'),
      );
      expect(AppUpdateService.normalizeVersion(''), equals('0.0.0'));
    });

    test('detects strictly newer semantic versions', () {
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.0',
          latestVersion: 'v1.0.1',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.9',
          latestVersion: 'v1.1.0',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.9.9',
          latestVersion: 'v2.0.0',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.0',
          latestVersion: 'v1.0.0',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.2.0',
          latestVersion: 'v1.1.9',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.0',
          latestVersion: 'v1.0.0-beta.1',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.0-beta.1',
          latestVersion: 'v1.0.0',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.0-beta.1',
          latestVersion: 'v1.0.0-beta.2',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerVersion(
          currentVersion: '1.0.0',
          latestVersion: 'v1.0.0.1',
        ),
        isTrue,
      );
    });

    test('extracts release tag from GitHub HTML redirect URL', () {
      expect(
        AppUpdateService.extractTagFromRedirectUrl(
          'https://github.com/8Masum/sampan/releases/tag/v1.2.0',
        ),
        equals('v1.2.0'),
      );
      expect(
        AppUpdateService.extractTagFromRedirectUrl(
          'https://github.com/8Masum/sampan/releases/latest',
        ),
        isNull,
      );
    });
  });

  group('AppUpdateService GitHub Release JSON parsing & APK download', () {
    test('prefers Sampan.apk asset and extracts size and metadata', () {
      final Map<String, dynamic> releaseJson = <String, dynamic>{
        'tag_name': 'v1.2.0',
        'name': 'Sampan (সাম্পান) v1.2.0',
        'body': '### Coastal Mesh Upgrade\n- Faster SoftAP transfer',
        'draft': false,
        'prerelease': false,
        'published_at': '2026-11-12T06:00:00Z',
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sampan-v1.2.0.apk',
            'size': 20971520,
            'browser_download_url':
                'https://github.com/8Masum/sampan/releases/download/v1.2.0/Sampan-v1.2.0.apk',
          },
          <String, dynamic>{
            'name': 'Sampan.apk',
            'size': 20971520,
            'browser_download_url':
                'https://github.com/8Masum/sampan/releases/download/v1.2.0/Sampan.apk',
          },
        ],
      };

      final ReleaseUpdateInfo info = AppUpdateService.parseGitHubReleaseJson(
        releaseJson,
        currentVersion: '1.0.0',
      );

      expect(info.isUpdateAvailable, isTrue);
      expect(info.latestVersion, equals('1.2.0'));
      expect(info.tagName, equals('v1.2.0'));
      expect(
        info.apkDownloadUrl,
        equals(
          'https://github.com/8Masum/sampan/releases/download/v1.2.0/Sampan.apk',
        ),
      );
      expect(info.formattedSize, equals('20.0 MB'));
    });

    test('marks draft, prerelease, or release without APK asset as not ready',
        () {
      final Map<String, dynamic> draftJson = <String, dynamic>{
        'tag_name': 'v2.0.0',
        'draft': true,
        'prerelease': false,
      };
      final ReleaseUpdateInfo info = AppUpdateService.parseGitHubReleaseJson(
        draftJson,
        currentVersion: '1.0.0',
      );
      expect(info.isUpdateAvailable, isFalse);

      final Map<String, dynamic> noApkAssetsJson = <String, dynamic>{
        'tag_name': 'v2.0.0',
        'draft': false,
        'prerelease': false,
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'SHA256SUMS.txt',
            'size': 161,
            'browser_download_url':
                'https://github.com/8Masum/sampan/releases/download/v2.0.0/SHA256SUMS.txt',
          },
        ],
      };
      final ReleaseUpdateInfo noApkInfo =
          AppUpdateService.parseGitHubReleaseJson(
        noApkAssetsJson,
        currentVersion: '1.0.0',
      );
      expect(noApkInfo.isUpdateAvailable, isFalse);
    });

    test('hands the release APK link to the browser instead of downloading',
        () async {
      final _RecordingBridge bridge = _RecordingBridge();
      final AppUpdateService service = AppUpdateService(
        nativeBridge: bridge,
        jsonFetcher: (Uri _) async => <String, dynamic>{
          'tag_name': 'v3.5.0',
          'name': 'Sampan v3.5.0',
          'body': 'Browser install test release',
          'draft': false,
          'prerelease': false,
          'assets': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Sampan.apk',
              'size': 52807221,
              'browser_download_url':
                  'https://github.com/8Masum/sampan/releases/download/v3.5.0/Sampan.apk',
            },
          ],
        },
      );

      final ReleaseUpdateInfo info = await service.checkForUpdate(
        currentVersionOverride: '3.0.0',
      );
      expect(info.isUpdateAvailable, isTrue);

      final bool opened = await service.openReleaseInBrowser(info);
      expect(opened, isTrue);
      expect(
        bridge.openedUrls,
        equals(<String>[
          'https://github.com/8Masum/sampan/releases/download/v3.5.0/Sampan.apk',
        ]),
      );
    });
  });
}

/// Records browser hand-offs instead of launching a real browser.
class _RecordingBridge extends NativeBridge {
  _RecordingBridge();

  final List<String> openedUrls = <String>[];

  @override
  Future<bool> openUrlInBrowser(String url) async {
    openedUrls.add(url);
    return true;
  }
}
