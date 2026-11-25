import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/log.dart';

/// Small key/value store that prefers the OS keyring.
///
/// Some platforms have no usable secure backend, so availability is probed once
/// and plain shared preferences are used afterwards. The fallback is deliberate
/// and visible, not a silent failure.
class LocalStore {
  LocalStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _probeKey = 'storage_probe';

  final FlutterSecureStorage _storage;
  Future<bool>? _availability;

  Future<bool> _canUseSecureStorage() {
    return _availability ??= _probeSecureStorage();
  }

  Future<bool> _probeSecureStorage() async {
    try {
      await _storage.write(key: _probeKey, value: _probeKey);
      await _storage.delete(key: _probeKey);
      return true;
    } catch (error) {
      logError('secure storage unavailable, falling back to shared preferences',
          error);
      return false;
    }
  }

  Future<String?> read(String key) async {
    if (await _canUseSecureStorage()) {
      return _storage.read(key: key);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write(String key, String value) async {
    if (await _canUseSecureStorage()) {
      await _storage.write(key: key, value: value);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
