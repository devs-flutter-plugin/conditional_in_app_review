import 'review_conditions.dart';
import 'review_decision.dart';
import 'review_requester.dart';
import 'review_storage.dart';
import 'shared_preferences_review_storage.dart';

/// Coordinates review eligibility rules, persistence, and the native request.
final class ConditionalInAppReview {
  /// Creates a conditional in-app review manager.
  ConditionalInAppReview({
    this.conditions = const ReviewConditions(),
    ReviewStorage? storage,
    ReviewRequester? requester,
    DateTime Function()? clock,
  }) : _storage = storage ?? SharedPreferencesReviewStorage(),
       _requester = requester ?? InAppReviewRequester(),
       _clock = clock ?? DateTime.now;

  /// Conditions evaluated before requesting a review.
  final ReviewConditions conditions;

  final ReviewStorage _storage;
  final ReviewRequester _requester;
  final DateTime Function() _clock;

  bool _initialized = false;
  bool _requestInProgress = false;

  /// Whether this manager instance has completed initialization.
  bool get isInitialized => _initialized;

  /// Initializes package state and optionally registers one application launch.
  ///
  /// Calling this method multiple times on the same instance is idempotent and
  /// does not register additional launches.
  Future<void> initialize({bool registerLaunch = true}) async {
    if (_initialized) {
      return;
    }

    final now = _clock();
    final firstInitializedAt = await _storage.getFirstInitializedAt();
    if (firstInitializedAt == null) {
      await _storage.setFirstInitializedAt(now);
    }

    if (registerLaunch) {
      final launches = await _storage.getLaunchCount();
      await _storage.setLaunchCount(launches + 1);
    }

    _initialized = true;
  }

  /// Registers one or more application launches explicitly.
  ///
  /// Prefer `initialize()` for the normal startup path. This method is useful
  /// when launch registration is managed separately by the application.
  Future<void> registerLaunch({int count = 1}) async {
    _requireInitialized();
    _validatePositiveCount(count);

    final launches = await _storage.getLaunchCount();
    await _storage.setLaunchCount(launches + count);
  }

  /// Registers one or more meaningful product interactions.
  Future<void> registerSignificantEvent({int count = 1}) async {
    _requireInitialized();
    _validatePositiveCount(count);

    final events = await _storage.getSignificantEventCount();
    await _storage.setSignificantEventCount(events + count);
  }

  /// Evaluates the configured conditions without invoking the native review API.
  Future<ReviewDecision> evaluateEligibility({String? currentVersion}) async {
    if (!_initialized) {
      return ReviewDecision.notInitialized;
    }

    final normalizedVersion = _normalizeVersion(currentVersion);
    if (conditions.requestOncePerVersion && normalizedVersion == null) {
      return ReviewDecision.versionRequired;
    }

    final now = _clock();
    final firstInitializedAt = await _storage.getFirstInitializedAt();
    if (firstInitializedAt == null) {
      return ReviewDecision.notInitialized;
    }

    final minimumAge = Duration(days: conditions.minDaysAfterInstall);
    if (now.difference(firstInitializedAt) < minimumAge) {
      return ReviewDecision.notEnoughDays;
    }

    final launches = await _storage.getLaunchCount();
    if (launches < conditions.minLaunches) {
      return ReviewDecision.notEnoughLaunches;
    }

    final significantEvents = await _storage.getSignificantEventCount();
    if (significantEvents < conditions.minSignificantEvents) {
      return ReviewDecision.notEnoughSignificantEvents;
    }

    final lastRequestAt = await _storage.getLastRequestAt();
    if (lastRequestAt != null &&
        now.difference(lastRequestAt) < conditions.cooldown) {
      return ReviewDecision.cooldownActive;
    }

    if (conditions.requestOncePerVersion) {
      final lastVersion = await _storage.getLastRequestedVersion();
      if (lastVersion == normalizedVersion) {
        return ReviewDecision.alreadyRequestedForVersion;
      }
    }

    return ReviewDecision.eligible;
  }

  /// Requests the native review flow when all configured conditions are met.
  ///
  /// A `ReviewDecision.requested` result only confirms that the platform API
  /// was invoked. The operating system may still decide not to show a dialog.
  Future<ReviewDecision> requestIfEligible({String? currentVersion}) async {
    if (_requestInProgress) {
      return ReviewDecision.requestInProgress;
    }

    _requestInProgress = true;
    try {
      final decision = await evaluateEligibility(currentVersion: currentVersion);
      if (decision != ReviewDecision.eligible) {
        return decision;
      }

      if (!await _requester.isAvailable()) {
        return ReviewDecision.unavailable;
      }

      if (conditions.delayBeforeRequest > Duration.zero) {
        await Future<void>.delayed(conditions.delayBeforeRequest);
      }

      await _requester.requestReview();

      final now = _clock();
      await _storage.setLastRequestAt(now);

      final normalizedVersion = _normalizeVersion(currentVersion);
      if (normalizedVersion != null) {
        await _storage.setLastRequestedVersion(normalizedVersion);
      }

      return ReviewDecision.requested;
    } finally {
      _requestInProgress = false;
    }
  }

  /// Clears all persisted review state owned by the configured storage.
  Future<void> reset() async {
    await _storage.reset();
    _initialized = false;
    _requestInProgress = false;
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError(
        'ConditionalInAppReview.initialize() must be called first.',
      );
    }
  }

  void _validatePositiveCount(int count) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'Must be greater than zero.');
    }
  }

  String? _normalizeVersion(String? version) {
    final normalized = version?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
