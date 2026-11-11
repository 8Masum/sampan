import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/data/services/native_bridge.dart';

/// Metadata for a GitHub Release returned by the GitHub Releases API.
@immutable
class ReleaseUpdateInfo {
  const ReleaseUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.tagName,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.isUpdateAvailable,
    this.apkSizeBytes,
    this.publishedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final String tagName;
  final String releaseTitle;
  final String releaseNotes;
  final String apkDownloadUrl;
  final bool isUpdateAvailable;
  final int? apkSizeBytes;
  final DateTime? publishedAt;

  String get formattedSize {
    final int? bytes = apkSizeBytes;
    if (bytes == null || bytes <= 0) return 'APK';
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

typedef ReleaseJsonFetcher = Future<Map<String, dynamic>> Function(Uri uri);
typedef ApkFileDownloader = Future<File> Function({
  required Uri url,
  required File destinationFile,
  void Function(double progress)? onProgress,
});

/// Lightweight, zero-cloud-dependency OTA updater that checks GitHub Releases
/// (`https://api.github.com/repos/themasum-com/sampan/releases/latest`),
/// downloads `Sampan.apk` with progress reporting, verifies APK archive magic
/// bytes, and launches the Android system package installer.
class AppUpdateService {
  AppUpdateService({
    NativeBridge nativeBridge = const NativeBridge(),
    ReleaseJsonFetcher? jsonFetcher,
    ApkFileDownloader? apkDownloader,
  })  : _nativeBridge = nativeBridge,
        _jsonFetcher = jsonFetcher,
        _apkDownloader = apkDownloader;

  final NativeBridge _nativeBridge;
  final ReleaseJsonFetcher? _jsonFetcher;
  final ApkFileDownloader? _apkDownloader;

  /// Normalizes a version string such as `'v1.2.0+3'` into `'1.2.0'`.
  static String normalizeVersion(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }
    final int plusIdx = cleaned.indexOf('+');
    if (plusIdx != -1) {
      cleaned = cleaned.substring(0, plusIdx);
    }
    return cleaned.isEmpty ? '0.0.0' : cleaned;
  }

  /// Parses `[major, minor, patch]` numeric segments from a version string.
  static List<int> parseVersionNumbers(String raw) {
    final String normalized = normalizeVersion(raw);
    final int dashIdx = normalized.indexOf('-');
    final String core =
        dashIdx != -1 ? normalized.substring(0, dashIdx) : normalized;
    final List<String> parts = core.split('.');
    final List<int> nums = <int>[0, 0, 0];
    for (int i = 0; i < 3 && i < parts.length; i++) {
      nums[i] = int.tryParse(parts[i].trim()) ?? 0;
    }
    return nums;
  }

  /// Returns `true` if [latestVersion] is strictly newer than [currentVersion].
  static bool isNewerVersion({
    required String currentVersion,
    required String latestVersion,
  }) {
    final String normCurrent = normalizeVersion(currentVersion);
    final String normLatest = normalizeVersion(latestVersion);
    if (normLatest.isEmpty || normLatest == '0.0.0') {
      return false;
    }

    final List<int> cur = parseVersionNumbers(normCurrent);
    final List<int> lat = parseVersionNumbers(normLatest);

    for (int i = 0; i < 3; i++) {
      if (lat[i] > cur[i]) return true;
      if (lat[i] < cur[i]) return false;
    }

    // If numeric [major, minor, patch] are equal, a stable release is newer
    // than a pre-release (e.g. '1.0.0' > '1.0.0-beta.1'), but not vice versa.
    final bool curIsPre = normCurrent.contains('-');
    final bool latIsPre = normLatest.contains('-');
    if (curIsPre && !latIsPre) {
      return true;
    }
    return false;
  }

  /// Parses a GitHub Releases API JSON payload into a [ReleaseUpdateInfo].
  static ReleaseUpdateInfo parseGitHubReleaseJson(
    Map<String, dynamic> json, {
    required String currentVersion,
  }) {
    final bool isDraft = (json['draft'] as bool?) ?? false;
    final bool isPrerelease = (json['prerelease'] as bool?) ?? false;

    final String rawTag = (json['tag_name'] as String?)?.trim() ?? '';
    final String tagName =
        rawTag.isNotEmpty ? rawTag : 'v${SampanConstants.appVersion}';
    final String latestVersion = normalizeVersion(tagName);
    final String normCurrent = normalizeVersion(currentVersion);

    final String releaseTitle =
        (json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : 'Sampan $tagName';
    final String releaseNotes =
        (json['body'] as String?)?.trim().isNotEmpty == true
            ? (json['body'] as String).trim()
            : 'Release $tagName available on GitHub Releases.';

    String apkUrl =
        'https://github.com/${SampanConstants.githubOwner}/${SampanConstants.githubRepo}/releases/download/$tagName/Sampan.apk';
    int? apkSize;

    final Object? assetsRaw = json['assets'];
    if (assetsRaw is List<dynamic>) {
      Map<String, dynamic>? preferredAsset;
      Map<String, dynamic>? fallbackApkAsset;

      for (final dynamic item in assetsRaw) {
        if (item is Map<String, dynamic>) {
          final String assetName =
              ((item['name'] as String?) ?? '').toLowerCase();
          final String? downloadUrl = item['browser_download_url'] as String?;
          if (downloadUrl != null &&
              downloadUrl.isNotEmpty &&
              assetName.endsWith('.apk')) {
            if (assetName == 'sampan.apk') {
              preferredAsset = item;
              break;
            }
            fallbackApkAsset ??= item;
          }
        }
      }

      final Map<String, dynamic>? chosen = preferredAsset ?? fallbackApkAsset;
      if (chosen != null) {
        final String? chosenUrl = chosen['browser_download_url'] as String?;
        if (chosenUrl != null && chosenUrl.isNotEmpty) {
          apkUrl = chosenUrl;
        }
        final Object? sizeObj = chosen['size'];
        if (sizeObj is num && sizeObj > 0) {
          apkSize = sizeObj.toInt();
        }
      }
    }

    DateTime? publishedAt;
    final String? pubRaw = json['published_at'] as String?;
    if (pubRaw != null && pubRaw.isNotEmpty) {
      publishedAt = DateTime.tryParse(pubRaw);
    }

    final bool updateAvailable = !isDraft &&
        !isPrerelease &&
        isNewerVersion(
          currentVersion: normCurrent,
          latestVersion: latestVersion,
        );

    return ReleaseUpdateInfo(
      currentVersion: normCurrent,
      latestVersion: latestVersion,
      tagName: tagName,
      releaseTitle: releaseTitle,
      releaseNotes: releaseNotes,
      apkDownloadUrl: apkUrl,
      isUpdateAvailable: updateAvailable,
      apkSizeBytes: apkSize,
      publishedAt: publishedAt,
    );
  }

  /// Queries GitHub Releases for the latest version of Sampan.
  Future<ReleaseUpdateInfo> checkForUpdate({
    String? currentVersionOverride,
  }) async {
    final String currentVersion = currentVersionOverride ??
        await _nativeBridge.getInstalledAppVersion();
    final Uri uri = Uri.parse(SampanConstants.githubLatestReleaseApiUrl);

    final ReleaseJsonFetcher fetcher = _jsonFetcher ?? _defaultFetchReleaseJson;
    final Map<String, dynamic> payload = await fetcher(uri);
    return parseGitHubReleaseJson(
      payload,
      currentVersion: currentVersion,
    );
  }

  /// Downloads the release APK from GitHub Releases, validates its ZIP/APK
  /// signature (`0x50 0x4B 0x03 0x04`), and launches the native Android
  /// package installer.
  Future<String> downloadAndInstallUpdate({
    required ReleaseUpdateInfo releaseInfo,
    void Function(double progress)? onProgress,
  }) async {
    final String? appDir = await _nativeBridge.getAppDataDirectory();
    final Directory baseDir = (appDir != null && appDir.isNotEmpty)
        ? Directory('$appDir/updates')
        : Directory('${Directory.systemTemp.path}/sampan_updates');
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }

    final File destinationFile = File('${baseDir.path}/Sampan-update.apk');
    final Uri downloadUri = Uri.parse(releaseInfo.apkDownloadUrl);

    final ApkFileDownloader downloader =
        _apkDownloader ?? _defaultDownloadApkFile;
    final File downloaded = await downloader(
      url: downloadUri,
      destinationFile: destinationFile,
      onProgress: onProgress,
    );

    if (!downloaded.existsSync() || downloaded.lengthSync() < 4) {
      throw const FileSystemException('Downloaded APK file is empty');
    }

    final RandomAccessFile raf = downloaded.openSync(mode: FileMode.read);
    final Uint8List header;
    try {
      header = raf.readSync(4);
    } finally {
      raf.closeSync();
    }
    if (!hasValidApkZipHeader(header)) {
      throw const FormatException(
        'Downloaded file is not a valid Android APK package',
      );
    }

    return _nativeBridge.installDownloadedApk(downloaded.path);
  }

  /// Checks whether the first 4 bytes match the standard ZIP/APK magic header
  /// (`PK\x03\x04` = `[0x50, 0x4B, 0x03, 0x04]`).
  static bool hasValidApkZipHeader(List<int> headerBytes) {
    if (headerBytes.length < 4) return false;
    return headerBytes[0] == 0x50 &&
        headerBytes[1] == 0x4B &&
        headerBytes[2] == 0x03 &&
        headerBytes[3] == 0x04;
  }

  static Future<Map<String, dynamic>> _defaultFetchReleaseJson(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sampan-Android-Updater/${SampanConstants.appVersion}',
      );

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw HttpException(
          'GitHub Releases API returned HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Invalid GitHub Release JSON response');
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> _defaultDownloadApkFile({
    required Uri url,
    required File destinationFile,
    void Function(double progress)? onProgress,
  }) async {
    final File partFile = File('${destinationFile.path}.part');
    if (partFile.existsSync()) {
      await partFile.delete();
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request =
          await client.getUrl(url).timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sampan-Android-Updater/${SampanConstants.appVersion}',
      );

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException(
          'APK download failed with HTTP ${response.statusCode}',
          uri: url,
        );
      }

      final int totalBytes = response.contentLength;
      int receivedBytes = 0;
      onProgress?.call(0.0);

      final IOSink sink = partFile.openWrite();
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            final double ratio =
                (receivedBytes / totalBytes).clamp(0.0, 1.0);
            onProgress?.call(ratio);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (destinationFile.existsSync()) {
        await destinationFile.delete();
      }
      final File renamed = await partFile.rename(destinationFile.path);
      onProgress?.call(1.0);
      return renamed;
    } finally {
      client.close(force: true);
    }
  }
}
