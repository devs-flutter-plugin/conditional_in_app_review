/// Immutable snapshot of the state used to evaluate review eligibility.
final class ReviewSnapshot {
  /// Creates a persisted review state snapshot.
  const ReviewSnapshot({
    required this.firstInitializedAt,
    required this.launchCount,
    required this.significantEventCount,
    required this.lastRequestAt,
    required this.lastRequestedVersion,
  });

  /// When this package was first initialized for the current app data.
  final DateTime? firstInitializedAt;

  /// Number of application launches registered by the package.
  final int launchCount;

  /// Number of significant events registered by the application.
  final int significantEventCount;

  /// When the native review request API was most recently invoked.
  final DateTime? lastRequestAt;

  /// App version associated with the most recent review request.
  final String? lastRequestedVersion;
}
