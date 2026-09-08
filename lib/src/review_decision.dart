/// Describes the result of evaluating or requesting an in-app review.
enum ReviewDecision {
  /// All configured conditions are currently satisfied.
  eligible,

  /// The platform review API was invoked.
  ///
  /// This does not guarantee that Android or iOS displayed a review dialog.
  requested,

  /// The platform reported that in-app review is unavailable.
  unavailable,

  /// `ConditionalInAppReview.initialize` has not completed for this instance.
  notInitialized,

  /// Not enough time has elapsed since the package was first initialized.
  notEnoughDays,

  /// The minimum launch count has not been reached.
  notEnoughLaunches,

  /// The minimum significant-event count has not been reached.
  notEnoughSignificantEvents,

  /// The configured cooldown period is still active.
  cooldownActive,

  /// Version-based limiting is enabled but no current version was provided.
  versionRequired,

  /// A request has already been made for the supplied app version.
  alreadyRequestedForVersion,

  /// Another review request is already being processed by this instance.
  requestInProgress,
}
