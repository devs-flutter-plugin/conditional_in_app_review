/// Persistence contract used by `ConditionalInAppReview`.
abstract interface class ReviewStorage {
  /// Returns when this package was first initialized for the current app data.
  Future<DateTime?> getFirstInitializedAt();

  /// Persists the first initialization timestamp.
  Future<void> setFirstInitializedAt(DateTime value);

  /// Returns the number of registered application launches.
  Future<int> getLaunchCount();

  /// Persists the application launch count.
  Future<void> setLaunchCount(int value);

  /// Returns the number of registered significant events.
  Future<int> getSignificantEventCount();

  /// Persists the significant-event count.
  Future<void> setSignificantEventCount(int value);

  /// Returns when the native review API was most recently requested.
  Future<DateTime?> getLastRequestAt();

  /// Persists when the native review API was requested.
  Future<void> setLastRequestAt(DateTime value);

  /// Returns the app version used for the most recent review request.
  Future<String?> getLastRequestedVersion();

  /// Persists the app version associated with the most recent review request.
  Future<void> setLastRequestedVersion(String? value);

  /// Removes all state owned by this package's storage implementation.
  Future<void> reset();
}
