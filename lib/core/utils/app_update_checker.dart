import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Asks the store this install came from whether a newer build is out, and
/// answers with the store page to send the member to (null when up to date).
///
/// **Android** asks Play, whose answer is per install: a closed tester is told
/// about the closed track, a production member about production, and a member
/// outside a staged rollout is told nothing. Debug runs and sideloaded APKs
/// make Play throw.
///
/// **iOS** has no such API, so it compares the installed version with Apple's
/// public lookup. Only a store version strictly newer than the installed one
/// counts, so TestFlight and a build in App Review (always ahead of the store)
/// are never blocked, and an app not yet on the store returns no results.
class AppUpdateChecker {
  AppUpdateChecker._();

  /// The app's store listing. Play has one listing per package, so this same
  /// link serves closed testing today and production after launch.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.coffeebean.cbtl';

  static const String _bundleId = 'com.coffeebean.cbtl';

  /// Apple's lookup only finds an app in a storefront that sells it.
  static const String _appStoreCountry = 'ph';

  static Future<String?> findUpdate() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return _findOnPlay();
    if (Platform.isIOS) return _findOnAppStore();
    return null;
  }

  static Future<String?> _findOnPlay() async {
    final info = await InAppUpdate.checkForUpdate();
    final waiting = info.updateAvailability ==
            UpdateAvailability.updateAvailable ||
        info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress;
    return waiting ? playStoreUrl : null;
  }

  static Future<String?> _findOnAppStore() async {
    final response = await http
        .get(Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': _bundleId,
          'country': _appStoreCountry,
        }))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    return appStoreUpdateUrl(
      response.body,
      installedVersion: (await PackageInfo.fromPlatform()).version,
      osVersion: (await DeviceInfoPlugin().iosInfo).systemVersion,
    );
  }

  /// A release that needs a newer iOS than this phone runs is not offered to
  /// it by the App Store, so blocking that member would lock them out for good.
  @visibleForTesting
  static String? appStoreUpdateUrl(
    String lookupBody, {
    required String installedVersion,
    required String osVersion,
  }) {
    final results = (jsonDecode(lookupBody) as Map)['results'] as List;
    if (results.isEmpty) return null;

    final app = results.first as Map;
    final storeVersion = app['version'] as String?;
    final url = app['trackViewUrl'] as String?;
    final minimumOs = app['minimumOsVersion'] as String?;
    if (storeVersion == null || url == null) return null;

    if (_compareVersions(storeVersion, installedVersion) <= 0) return null;
    if (minimumOs != null && _compareVersions(osVersion, minimumOs) < 0) {
      return null;
    }
    return url;
  }

  static int _compareVersions(String a, String b) {
    final left = a.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final right = b.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}
