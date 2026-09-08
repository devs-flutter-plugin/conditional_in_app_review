import 'package:shared_preferences/shared_preferences.dart';

import 'review_storage.dart';

/// `ReviewStorage` implementation backed by `SharedPreferencesAsync`.
final class SharedPreferencesReviewStorage implements ReviewStorage {
  /// Creates the default persistent review storage.
  SharedPreferencesReviewStorage({
    SharedPreferencesAsync? preferences,
    this.keyPrefix = 'conditional_in_app_review',
  }) : _preferences = preferences;

  SharedPreferencesAsync? _preferences;

  /// Prefix used for every key owned by this package.
  final String keyPrefix;

  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  String get _firstInitializedAtKey => '$keyPrefix.first_initialized_at';
  String get _launchCountKey => '$keyPrefix.launch_count';
  String get _significantEventCountKey => '$keyPrefix.significant_event_count';
  String get _lastRequestAtKey => '$keyPrefix.last_request_at';
  String get _lastRequestedVersionKey => '$keyPrefix.last_requested_version';

  @override
  Future<DateTime?> getFirstInitializedAt() async {
    final milliseconds = await _prefs.getInt(_firstInitializedAtKey);
    return _dateTimeFromMilliseconds(milliseconds);
  }

  @override
  Future<void> setFirstInitializedAt(DateTime value) {
    return _prefs.setInt(
      _firstInitializedAtKey,
      value.millisecondsSinceEpoch,
    );
  }

  @override
  Future<int> getLaunchCount() async {
    return await _prefs.getInt(_launchCountKey) ?? 0;
  }

  @override
  Future<void> setLaunchCount(int value) {
    return _prefs.setInt(_launchCountKey, value);
  }

  @override
  Future<int> getSignificantEventCount() async {
    return await _prefs.getInt(_significantEventCountKey) ?? 0;
  }

  @override
  Future<void> setSignificantEventCount(int value) {
    return _prefs.setInt(_significantEventCountKey, value);
  }

  @override
  Future<DateTime?> getLastRequestAt() async {
    final milliseconds = await _prefs.getInt(_lastRequestAtKey);
    return _dateTimeFromMilliseconds(milliseconds);
  }

  @override
  Future<void> setLastRequestAt(DateTime value) {
    return _prefs.setInt(_lastRequestAtKey, value.millisecondsSinceEpoch);
  }

  @override
  Future<String?> getLastRequestedVersion() {
    return _prefs.getString(_lastRequestedVersionKey);
  }

  @override
  Future<void> setLastRequestedVersion(String? value) {
    if (value == null) {
      return _prefs.remove(_lastRequestedVersionKey);
    }
    return _prefs.setString(_lastRequestedVersionKey, value);
  }

  @override
  Future<void> reset() async {
    await Future.wait<void>([
      _prefs.remove(_firstInitializedAtKey),
      _prefs.remove(_launchCountKey),
      _prefs.remove(_significantEventCountKey),
      _prefs.remove(_lastRequestAtKey),
      _prefs.remove(_lastRequestedVersionKey),
    ]);
  }

  DateTime? _dateTimeFromMilliseconds(int? milliseconds) {
    if (milliseconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
