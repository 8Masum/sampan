import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/data/services/app_update_service.dart';

void main() {
  group('AppUpdateService version parsing & comparison', () {
    test('normalizes v-prefixes and build metadata', () {
      expect(AppUpdateService.normalizeVersion('v1.0.0'), equals('1.0.0'));
      expect(AppUpdateService.normalizeVersion('V2.3.4+12'), equals('2.3.4'));
      expect(AppUpdateService.normalizeVersion('  1.0.1  '), equals('1.0.1'));
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
                'https://github.com/themasum-com/sampan/releases/download/v1.2.0/Sampan-v1.2.0.apk',
          },
          <String, dynamic>{
            'name': 'Sampan.apk',
            'size': 20971520,
            'browser_download_url':
                'https://github.com/themasum-com/sampan/releases/download/v1.2.0/Sampan.apk',
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
          'https://github.com/themasum-com/sampan/releases/download/v1.2.0/Sampan.apk',
        ),
      );
      expect(info.formattedSize, equals('20.0 MB'));
    });

    test('marks draft or prerelease as not available for auto-update', () {
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
    });

    test('validates APK ZIP magic bytes and triggers installer', () async {
      final List<double> progressLog = <double>[];
      final AppUpdateService service = AppUpdateService(
        jsonFetcher: (Uri _) async => <String, dynamic>{
          'tag_name': 'v1.1.0',
          'name': 'Sampan v1.1.0',
          'body': 'OTA auto-update test release',
          'draft': false,
          'prerelease': false,
        },
        apkDownloader: ({
          required Uri url,
          required File destinationFile,
          void Function(double progress)? onProgress,
        }) async {
          onProgress?.call(0.5);
          // Write valid ZIP/APK header PK\x03\x04 followed by payload bytes
          await destinationFile.writeAsBytes(
            const <int>[0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00],
          );
          onProgress?.call(1.0);
          return destinationFile;
        },
      );

      final ReleaseUpdateInfo info = await service.checkForUpdate(
        currentVersionOverride: '1.0.0',
      );
      expect(info.isUpdateAvailable, isTrue);

      final String status = await service.downloadAndInstallUpdate(
        releaseInfo: info,
        onProgress: progressLog.add,
      );
      expect(status, equals('installer_launched'));
      expect(progressLog, contains(1.0));
    });

    test('rejects corrupted non-APK download lacking PK header', () async {
      final AppUpdateService badService = AppUpdateService(
        apkDownloader: ({
          required Uri url,
          required File destinationFile,
          void Function(double progress)? onProgress,
        }) async {
          await destinationFile.writeAsString('<html>404 Not Found</html>');
          return destinationFile;
        },
      );

      const ReleaseUpdateInfo dummyRelease = ReleaseUpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.1.0',
        tagName: 'v1.1.0',
        releaseTitle: 'v1.1.0',
        releaseNotes: 'Notes',
        apkDownloadUrl:
            'https://github.com/themasum-com/sampan/releases/latest/download/Sampan.apk',
        isUpdateAvailable: true,
      );

      expect(
        () => badService.downloadAndInstallUpdate(releaseInfo: dummyRelease),
        throwsFormatException,
      );
    });
  });
}
