import 'review_conditions.dart';
import 'review_decision.dart';
import 'review_requester.dart';
import 'review_snapshot.dart';
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
  })  : _storageOverride = storage,
        _requesterOverride = requester,
        _clock = clock ?? DateTime.now {
    _validateConditions(conditions);
  }

  /// Conditions evaluated before requesting a review.
  final ReviewConditions conditions;

  final ReviewStorage? _storageOverride;
  final ReviewRequester? _requesterOverride;
  final DateTime Function() _clock;

  ReviewStorage? _defaultStorage;
  ReviewRequester? _defaultRequester;

  ReviewStorage get _storage =>
      _storageOverride ?? (_defaultStorage ??= SharedPreferencesReviewStorage());

  ReviewRequester get _requester =>
      _requesterOverride ?? (_defaultRequester ??= InAppReviewRequester());

  bool _initialized = false;
  bool _requestInProgress = false;
  Future<void>? _initializationFuture;

  /// Whether this manager instance has completed initialization.
  bool get isInitialized => _initialized;

  /// Initializes package state and optionally registers one application launch.
  ///
  /// Calling this method multiple times on the same instance is idempotent and
  /// does not register additional launches. Concurrent calls share the same
  /// initialization operation; the first call determines `registerLaunch`.
  Future<void> initialize({bool registerLaunch = true}) {
    if (_initialized) {
      return Future<void>.value();
    }

    final currentInitialization = _initializationFuture;
    if (currentInitialization != null) {
      return currentInitialization;
    }

    final initialization = _initialize(registerLaunch: registerLaunch);
    _initializationFuture = initialization;
    return initialization;
  }

  Future<void> _initialize({required bool registerLaunch}) async {
    try {
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
    } finally {
      _initializationFuture = null;
    }
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

  /// Returns the currently persisted counters and review request metadata.
  ///
  /// This method can be used for diagnostics and analytics and does not require
  /// the manager instance to be initialized first.
  Future<ReviewSnapshot> getSnapshot() async {
    return ReviewSnapshot(
      firstInitializedAt: await _storage.getFirstInitializedAt(),
      launchCount: await _storage.getLaunchCount(),
      significantEventCount: await _storage.getSignificantEventCount(),
      lastRequestAt: await _storage.getLastRequestAt(),
      lastRequestedVersion: await _storage.getLastRequestedVersion(),
    );
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
      final decision =
          await evaluateEligibility(currentVersion: currentVersion);
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
    if (_requestInProgress) {
      throw StateError('Cannot reset while a review request is in progress.');
    }

    final initialization = _initializationFuture;
    if (initialization != null) {
      await initialization;
    }

    await _storage.reset();
    _initialized = false;
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError(
        'ConditionalInAppReview.initialize() must be called first.',
      );
    }
  }

  static void _validateConditions(ReviewConditions conditions) {
    if (conditions.minDaysAfterInstall < 0) {
      throw ArgumentError.value(
        conditions.minDaysAfterInstall,
        'minDaysAfterInstall',
        'Must not be negative.',
      );
    }
    if (conditions.minLaunches < 0) {
      throw ArgumentError.value(
        conditions.minLaunches,
        'minLaunches',
        'Must not be negative.',
      );
    }
    if (conditions.minSignificantEvents < 0) {
      throw ArgumentError.value(
        conditions.minSignificantEvents,
        'minSignificantEvents',
        'Must not be negative.',
      );
    }
    if (conditions.cooldown.isNegative) {
      throw ArgumentError.value(
        conditions.cooldown,
        'cooldown',
        'Must not be negative.',
      );
    }
    if (conditions.delayBeforeRequest.isNegative) {
      throw ArgumentError.value(
        conditions.delayBeforeRequest,
        'delayBeforeRequest',
        'Must not be negative.',
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
