import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/version.dart';
import '../utils/log.dart';

/// The newest published release, as GitHub reports it.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.downloadUrl});

  final AppVersion version;
  final String downloadUrl;
}

/// Compares the running build with the latest GitHub release.
class UpdateChecker {
  UpdateChecker({
    http.Client? client,
    String repoOwner = defaultRepoOwner,
    String repoName = defaultRepoName,
  })  : _client = client ?? http.Client(),
        _repoOwner = repoOwner,
        _repoName = repoName;

  static const String defaultRepoOwner = 'OvermindGroup';
  static const String defaultRepoName = 'Overmind';

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _repoOwner;
  final String _repoName;

  /// Shows the download prompt only when the release is genuinely newer.
  ///
  /// Anything unreadable (offline, unexpected payload) is logged and skipped:
  /// an update check must never block or break startup.
  Future<void> checkForUpdates(BuildContext context) async {
    final current =
        AppVersion.parse((await PackageInfo.fromPlatform()).version);
    final latest = await _latestRelease();

    if (current == null || latest == null) return;
    if (!latest.version.isNewerThan(current)) {
      log('App is up to date ($current)');
      return;
    }

    if (!context.mounted) return;
    _showUpdateNotification(context, latest.downloadUrl);
  }

  Future<ReleaseInfo?> _latestRelease() async {
    final apiUrl =
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

    try {
      final response = await _client.get(Uri.parse(apiUrl)).timeout(_timeout);
      if (response.statusCode != 200) {
        logError('loading update information', 'HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;

      final version = AppVersion.parse(json['tag_name']?.toString() ?? '');
      final downloadUrl = json['html_url']?.toString();
      if (version == null || downloadUrl == null) return null;

      return ReleaseInfo(version: version, downloadUrl: downloadUrl);
    } catch (error) {
      logError('checking for updates', error);
      return null;
    }
  }

  void _showUpdateNotification(BuildContext context, String downloadUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Version Available!'),
          content: const Text(
            'A new version of Overmind is available. Click on the "Update" '
            'button below to go to the download page.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openDownloadPage(downloadUrl);
              },
              child: const Text('Update'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      logError('opening the download page', 'Could not launch $uri');
    }
  }
}
