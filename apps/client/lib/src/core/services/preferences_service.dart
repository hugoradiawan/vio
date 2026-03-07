import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for storing user preferences
class PreferencesService {
  PreferencesService._();

  static PreferencesService? _instance;
  static PreferencesService get instance =>
      _instance ??= PreferencesService._();

  SharedPreferences? _prefs;

  /// Initialize the preferences service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError(
        'PreferencesService not initialized. Call initialize() first.',
      );
    }
    return _prefs!;
  }

  // ============================================================================
  // Branch Preferences
  // ============================================================================

  static const _lastBranchIdKey = 'last_branch_id';
  static const _lastProjectIdKey = 'last_project_id';

  /// Get the last selected branch ID for a project
  String? getLastBranchId(String projectId) {
    final storedProjectId = _preferences.getString(_lastProjectIdKey);
    if (storedProjectId != projectId) {
      // Different project, don't use stored branch
      return null;
    }
    return _preferences.getString(_lastBranchIdKey);
  }

  /// Save the last selected branch ID
  Future<void> setLastBranchId(String projectId, String branchId) async {
    await _preferences.setString(_lastProjectIdKey, projectId);
    await _preferences.setString(_lastBranchIdKey, branchId);
  }

  /// Clear the last selected branch
  Future<void> clearLastBranch() async {
    await _preferences.remove(_lastBranchIdKey);
    await _preferences.remove(_lastProjectIdKey);
  }

  // ============================================================================
  // Theme Preferences
  // ============================================================================

  static const _themeSeedColorKey = 'theme_seed_color';
  static const _themeModeKey = 'theme_mode';

  /// Default seed color — Vio primary blue (#4C9AFF).
  static const _defaultSeedArgb = 0xFF4C9AFF;

  /// Return the persisted seed color, or [VioColors.primary] if none was saved.
  Color getThemeSeedColor() {
    final argb = _preferences.getInt(_themeSeedColorKey);
    if (argb == null) return const Color(_defaultSeedArgb);
    return Color(argb);
  }

  /// Persist the user's chosen seed [color].
  Future<void> setThemeSeedColor(Color color) async {
    await _preferences.setInt(_themeSeedColorKey, color.toARGB32());
  }

  /// Return the persisted theme mode, or [ThemeMode.dark] if none was saved.
  ThemeMode getThemeMode() {
    final raw = _preferences.getString(_themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  /// Persist the user's chosen [mode].
  Future<void> setThemeMode(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    };
    await _preferences.setString(_themeModeKey, raw);
  }
}
