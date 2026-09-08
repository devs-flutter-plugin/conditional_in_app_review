import 'package:shared_preferences/shared_preferences.dart';

import 'review_storage.dart';

/// `ReviewStorage` implementation backed by `SharedPreferencesAsync`.
final class SharedPreferencesReviewStorage implements ReviewStorage {
  /// Creates the default persistent review storage.
  SharedPreferencesReviewStorage({
    SharedPreferencesAsync? preferences,
    this.keyPrefix = 'conditional_in_app_review',
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  /// Prefix used for every key owned by this package.
  final String keyPrefix;

  String get _firstInitializedAtKey => '$keyPrefix.first_initialized_at';
  String get _launchCountKey => '$keyPrefix.launch_count';
  String get _significantEventCountKey => '$keyPrefix.significant_event_count';
  String get _lastRequestAtKey => '$keyPrefix.last_request_at';
  String get _lastRequestedVersionKey => '$keyPrefix.last_requested_version';

  @override
  Future<DateTime?> getFirstInitializedAt() async {
    final milliseconds = await _preferences.getInt(_firstInitializedAtKey);
    return _dateTimeFromMilliseconds(milliseconds);
  }

  @override
  Future<void> setFirstInitializedAt(DateTime value) {
    return _preferences.setInt(
      _firstInitializedAtKey,
      value.millisecondsSinceEpoch,
    );
  }

  @override
  Future<int> getLaunchCount() async {
    return await _preferences.getInt(_launchCountKey) ?? 0;
  }

  @override
  Future<void> setLaunchCount(int value) {
    return _preferences.setInt(_launchCountKey, value);
  }

  @override
  Future<int> getSignificantEventCount() async {
    return await _preferences.getInt(_significantEventCountKey) ?? 0;
  }

  @override
  Future<void> setSignificantEventCount(int value) {
    return _preferences.setInt(_significantEventCountKey, value);
  }

  @override
  Future<DateTime?> getLastRequestAt() async {
    final milliseconds = await _preferences.getInt(_lastRequestAtKey);
    return _dateTimeFromMilliseconds(milliseconds);
  }

  @override
  Future<void> setLastRequestAt(DateTime value) {
    return _preferences.setInt(_lastRequestAtKey, value.millisecondsSinceEpoch);
  }

  @override
  Future<String?> getLastRequestedVersion() {
    return _preferences.getString(_lastRequestedVersionKey);
  }

  @override
  Future<void> setLastRequestedVersion(String? value) {
    if (value == null) {
      return _preferences.remove(_lastRequestedVersionKey);
    }
    return _preferences.setString(_lastRequestedVersionKey, value);
  }

  @override
  Future<void> reset() async {
    await Future.wait<void>([
      _preferences.remove(_firstInitializedAtKey),
      _preferences.remove(_launchCountKey),
      _preferences.remove(_significantEventCountKey),
      _preferences.remove(_lastRequestAtKey),
      _preferences.remove(_lastRequestedVersionKey),
    ]);
  }

  DateTime? _dateTimeFromMilliseconds(int? milliseconds) {
    if (milliseconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
