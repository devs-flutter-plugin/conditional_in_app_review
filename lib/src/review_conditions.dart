/// Defines the built-in conditions that must be met before requesting a review.
final class ReviewConditions {
  /// Creates a set of review conditions.
  const ReviewConditions({
    this.minDaysAfterInstall = 7,
    this.minLaunches = 5,
    this.minSignificantEvents = 0,
    this.cooldown = const Duration(days: 90),
    this.requestOncePerVersion = false,
    this.delayBeforeRequest = Duration.zero,
  }) : assert(minDaysAfterInstall >= 0),
       assert(minLaunches >= 0),
       assert(minSignificantEvents >= 0),
       assert(cooldown.inMicroseconds >= 0),
       assert(delayBeforeRequest.inMicroseconds >= 0);

  /// Minimum whole days since the package first initialized in this app install.
  final int minDaysAfterInstall;

  /// Minimum number of application launches registered by this package.
  final int minLaunches;

  /// Minimum number of significant events registered by the application.
  final int minSignificantEvents;

  /// Minimum time between successful calls to the native review request API.
  final Duration cooldown;

  /// Whether a review request may happen at most once for each app version.
  ///
  /// When enabled, callers must provide `currentVersion` to eligibility and
  /// request methods.
  final bool requestOncePerVersion;

  /// Delay applied after all conditions pass and before invoking the native API.
  final Duration delayBeforeRequest;
}
