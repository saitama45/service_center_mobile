import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoUtil {
  DeviceInfoUtil._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Returns a concise device identifier string for session tracking.
  static Future<String> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        return '${info.manufacturer} ${info.model} (Android ${info.version.release})';
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return '${info.name} (iOS ${info.systemVersion})';
      }
      return 'Unknown device';
    } catch (_) {
      return 'Unknown device';
    }
  }
}
