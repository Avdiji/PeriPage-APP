import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value store for the saved printer and device defaults.
final class PreferencesService {
  static const _savedDeviceKey = 'saved_device';
  static const _deviceSettingsKey = 'device_settings';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<Map<String, dynamic>?> savedDevice() => _readJson(_savedDeviceKey);
  Future<void> saveDevice(Map<String, dynamic> json) => _prefs.setString(_savedDeviceKey, jsonEncode(json));
  Future<void> clearDevice() => _prefs.remove(_savedDeviceKey);

  Future<Map<String, dynamic>?> deviceSettings() => _readJson(_deviceSettingsKey);
  Future<void> saveDeviceSettings(Map<String, dynamic> json) =>
      _prefs.setString(_deviceSettingsKey, jsonEncode(json));

  /// Measured print speed in dot-lines per second, per printer name.
  Future<double?> printSpeed(String deviceName) => _prefs.getDouble('print_speed_$deviceName');
  Future<void> savePrintSpeed(String deviceName, double linesPerSecond) =>
      _prefs.setDouble('print_speed_$deviceName', linesPerSecond);

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final raw = await _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }
}

final preferencesServiceProvider = Provider<PreferencesService>((Ref ref) => PreferencesService());
