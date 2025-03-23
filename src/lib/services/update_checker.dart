import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening URLs
import 'package:flutter/material.dart'; // Import Flutter Material for UI elements.

class UpdateChecker {
  final String repoOwner = 'OvermindGroup';
  final String repoName = 'Overmind';

  Future<void> checkForUpdates(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    try {
      final apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final latestVersion = jsonData['tag_name'].toString().replaceAll('v', '');
        final releaseUrl = jsonData['html_url'];

        if (_isNewVersionAvailable(currentVersion, latestVersion)) {
          _showUpdateNotification(context, releaseUrl);
        } else {
          print('App is up to date.');
        }
      } else {
        print('Failed to load update information from GitHub API. Status code: ${response.statusCode}');
      }

    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  bool _isNewVersionAvailable(String currentVersion, String latestVersion) {
    return latestVersion.compareTo(currentVersion) > 0;
  }

  Future<void> _showUpdateNotification(BuildContext context, String releaseUrl) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Version Available!'),
          content: const Text('A new version of Overmind is available. Click on the "Update" button below to go to the download page.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                _launchURL(releaseUrl);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri _url = Uri.parse(url);
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }
}
