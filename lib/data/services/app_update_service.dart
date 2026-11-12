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

/// Lightweight updater: checks GitHub Releases
/// (`https://api.github.com/repos/8Masum/sampan/releases/latest`) inside the
/// app, then hands the APK link to the browser, which downloads it fast and
/// shows Android's own "Install / Update" prompt.
class AppUpdateService {
  AppUpdateService({
    NativeBridge nativeBridge = const NativeBridge(),
    ReleaseJsonFetcher? jsonFetcher,
  })  : _nativeBridge = nativeBridge,
        _jsonFetcher = jsonFetcher;

  final NativeBridge _nativeBridge;
  final ReleaseJsonFetcher? _jsonFetcher;

  /// Normalizes a version string such as `'v1.2.0+3'` or `'release-v1.2.0'`
  /// into `'1.2.0'`.
  static String normalizeVersion(String raw) {
    String cleaned = raw.trim();
    final int plusIdx = cleaned.indexOf('+');
    if (plusIdx != -1) {
      cleaned = cleaned.substring(0, plusIdx).trim();
    }
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }
    final RegExp semverPattern = RegExp(
      r'(\d+\.\d+(?:\.\d+)*(?:-[0-9A-Za-z.-]+)?)',
    );
    final RegExpMatch? match = semverPattern.firstMatch(cleaned);
    if (match != null) {
      final String? extracted = match.group(1);
      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }
    }
    return cleaned.isEmpty ? '0.0.0' : cleaned;
  }

  /// Parses `[major, minor, patch, ...]` numeric segments from a version string.
  static List<int> parseVersionNumbers(String raw) {
    final String normalized = normalizeVersion(raw);
    final int dashIdx = normalized.indexOf('-');
    final String core =
        dashIdx != -1 ? normalized.substring(0, dashIdx) : normalized;
    final List<String> parts = core.split('.');
    final int count = parts.length > 3 ? parts.length : 3;
    final List<int> nums = List<int>.filled(count, 0);
    for (int i = 0; i < parts.length; i++) {
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
    final int maxLen = cur.length > lat.length ? cur.length : lat.length;

    for (int i = 0; i < maxLen; i++) {
      final int curVal = i < cur.length ? cur[i] : 0;
      final int latVal = i < lat.length ? lat[i] : 0;
      if (latVal > curVal) return true;
      if (latVal < curVal) return false;
    }

    // If numeric segments are equal, a stable release is newer than a
    // pre-release (e.g. '1.0.0' > '1.0.0-beta.1'), and '1.0.0-beta.2' > '1.0.0-beta.1'.
    final int curDash = normCurrent.indexOf('-');
    final int latDash = normLatest.indexOf('-');
    final bool curIsPre = curDash != -1;
    final bool latIsPre = latDash != -1;
    if (curIsPre && !latIsPre) {
      return true;
    }
    if (!curIsPre && latIsPre) {
      return false;
    }
    if (curIsPre && latIsPre) {
      final String curPre = normCurrent.substring(curDash + 1);
      final String latPre = normLatest.substring(latDash + 1);
      return _comparePrereleaseIdentifiers(curPre, latPre) < 0;
    }
    return false;
  }

  static int _comparePrereleaseIdentifiers(String a, String b) {
    if (a == b) return 0;
    final List<String> aParts = a.split('.');
    final List<String> bParts = b.split('.');
    final int len = aParts.length < bParts.length ? aParts.length : bParts.length;
    for (int i = 0; i < len; i++) {
      final int? aNum = int.tryParse(aParts[i]);
      final int? bNum = int.tryParse(bParts[i]);
      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else {
        final int cmp = aParts[i].compareTo(bParts[i]);
        if (cmp != 0) return cmp;
      }
    }
    return aParts.length.compareTo(bParts.length);
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
    bool hasExplicitAssetsList = false;
    bool foundApkAsset = false;
    if (assetsRaw is List<dynamic>) {
      hasExplicitAssetsList = true;
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
        foundApkAsset = true;
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

    final bool hasReadyApk = !hasExplicitAssetsList || foundApkAsset;
    final bool updateAvailable = !isDraft &&
        !isPrerelease &&
        hasReadyApk &&
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

  /// Opens the release APK link in the browser. Returns `false` if no
  /// browser could handle it.
  Future<bool> openReleaseInBrowser(ReleaseUpdateInfo releaseInfo) {
    return _nativeBridge.openUrlInBrowser(releaseInfo.apkDownloadUrl);
  }

  /// Removes APK files left by the old in-app downloader (v2.x–v3.0), which
  /// could take ~50 MB of the phone's storage.
  Future<void> deleteLegacyDownloads() async {
    final String? appDir = await _nativeBridge.getAppDataDirectory();
    if (appDir == null || appDir.isEmpty) return;
    final Directory legacyDir = Directory('$appDir/updates');
    try {
      if (legacyDir.existsSync()) {
        await legacyDir.delete(recursive: true);
      }
    } on FileSystemException {
      // Best effort: a leftover file must never block the app.
    }
  }

  /// Extracts the release tag from a GitHub `/releases/tag/<tag>` redirect URL.
  static String? extractTagFromRedirectUrl(String url) {
    final RegExp tagRegex = RegExp(r'/releases/tag/([^/?#]+)');
    final RegExpMatch? match = tagRegex.firstMatch(url);
    if (match == null) return null;
    final String? raw = match.group(1);
    if (raw == null || raw.trim().isEmpty) return null;
    return Uri.decodeComponent(raw.trim());
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
      if (response.statusCode == 403 || response.statusCode == 429) {
        await response.drain<void>();
        return await _fetchReleaseViaHtmlRedirect(client);
      }
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

  /// Fallback when `api.github.com` is rate-limited (HTTP 403/429 on shared
  /// caravan Wi-Fi or carrier CGNAT): resolves `/releases/latest` via HTTP 302
  /// redirect to `/releases/tag/<tag>`.
  static Future<Map<String, dynamic>> _fetchReleaseViaHtmlRedirect(
    HttpClient client,
  ) async {
    final Uri latestWebUri = Uri.parse(
      'https://github.com/${SampanConstants.githubOwner}/${SampanConstants.githubRepo}/releases/latest',
    );
    final HttpClientRequest request =
        await client.getUrl(latestWebUri).timeout(const Duration(seconds: 10));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Sampan-Android-Updater/${SampanConstants.appVersion}',
    );
    final HttpClientResponse response =
        await request.close().timeout(const Duration(seconds: 10));
    await response.drain<void>();

    String? resolvedTag;
    for (final RedirectInfo redirect in response.redirects) {
      resolvedTag = extractTagFromRedirectUrl(redirect.location.toString()) ??
          resolvedTag;
    }
    if (resolvedTag == null || resolvedTag.isEmpty) {
      throw HttpException(
        'Could not resolve latest release tag from GitHub redirect',
        uri: latestWebUri,
      );
    }

    return <String, dynamic>{
      'tag_name': resolvedTag,
      'name': 'Sampan (সাম্পান) $resolvedTag',
      'body': 'Release $resolvedTag available on GitHub Releases.',
      'draft': false,
      'prerelease': false,
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Sampan.apk',
          'browser_download_url':
              'https://github.com/${SampanConstants.githubOwner}/${SampanConstants.githubRepo}/releases/download/$resolvedTag/Sampan.apk',
        },
      ],
    };
  }
}
