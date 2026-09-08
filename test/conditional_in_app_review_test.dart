import 'package:conditional_in_app_review/conditional_in_app_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConditionalInAppReview', () {
    test('requests review when all conditions are satisfied', () async {
      final storage = _MemoryReviewStorage();
      final requester = _FakeReviewRequester();
      final clock = _MutableClock(DateTime.utc(2026, 1, 1));
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 2,
          minLaunches: 2,
          minSignificantEvents: 1,
          cooldown: Duration(days: 30),
        ),
        storage: storage,
        requester: requester,
        clock: clock.call,
      );

      await review.initialize();
      await review.registerLaunch();
      await review.registerSignificantEvent();
      clock.value = DateTime.utc(2026, 1, 3);

      final decision = await review.requestIfEligible();

      expect(decision, ReviewDecision.requested);
      expect(requester.requestCount, 1);
      expect(storage.lastRequestAt, DateTime.utc(2026, 1, 3));
    });

    test('does not double count initialize on the same instance', () async {
      final storage = _MemoryReviewStorage();
      final review = ConditionalInAppReview(
        storage: storage,
        requester: _FakeReviewRequester(),
      );

      await review.initialize();
      await review.initialize();

      expect(storage.launchCount, 1);
      expect(storage.launchWriteCount, 1);
    });

    test('deduplicates concurrent initialize calls', () async {
      final storage = _MemoryReviewStorage(
        firstInitializationReadDelay: const Duration(milliseconds: 20),
      );
      final review = ConditionalInAppReview(
        storage: storage,
        requester: _FakeReviewRequester(),
      );

      await Future.wait<void>([
        review.initialize(),
        review.initialize(),
        review.initialize(),
      ]);

      expect(storage.firstInitializedWriteCount, 1);
      expect(storage.launchWriteCount, 1);
      expect(storage.launchCount, 1);
    });

    test('enforces cooldown after a request', () async {
      final storage = _MemoryReviewStorage();
      final requester = _FakeReviewRequester();
      final clock = _MutableClock(DateTime.utc(2026, 1, 1));
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 0,
          minLaunches: 1,
          cooldown: Duration(days: 10),
        ),
        storage: storage,
        requester: requester,
        clock: clock.call,
      );

      await review.initialize();
      expect(await review.requestIfEligible(), ReviewDecision.requested);

      clock.value = DateTime.utc(2026, 1, 5);
      expect(
        await review.requestIfEligible(),
        ReviewDecision.cooldownActive,
      );

      clock.value = DateTime.utc(2026, 1, 11);
      expect(await review.requestIfEligible(), ReviewDecision.requested);
      expect(requester.requestCount, 2);
    });

    test('requires currentVersion when once-per-version is enabled', () async {
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 0,
          minLaunches: 1,
          cooldown: Duration.zero,
          requestOncePerVersion: true,
        ),
        storage: _MemoryReviewStorage(),
        requester: _FakeReviewRequester(),
      );

      await review.initialize();

      expect(
        await review.evaluateEligibility(),
        ReviewDecision.versionRequired,
      );
      expect(
        await review.requestIfEligible(currentVersion: '1.0.0'),
        ReviewDecision.requested,
      );
      expect(
        await review.requestIfEligible(currentVersion: '1.0.0'),
        ReviewDecision.alreadyRequestedForVersion,
      );
    });

    test('does not record an unavailable request', () async {
      final storage = _MemoryReviewStorage();
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 0,
          minLaunches: 1,
          cooldown: Duration.zero,
        ),
        storage: storage,
        requester: _FakeReviewRequester(available: false),
      );

      await review.initialize();

      expect(await review.requestIfEligible(), ReviewDecision.unavailable);
      expect(storage.lastRequestAt, isNull);
    });

    test('returns a persisted state snapshot', () async {
      final storage = _MemoryReviewStorage();
      final clock = _MutableClock(DateTime.utc(2026, 2, 1));
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 0,
          minLaunches: 1,
          minSignificantEvents: 1,
          cooldown: Duration.zero,
          requestOncePerVersion: true,
        ),
        storage: storage,
        requester: _FakeReviewRequester(),
        clock: clock.call,
      );

      await review.initialize();
      await review.registerSignificantEvent(count: 2);
      await review.requestIfEligible(currentVersion: '2.4.0');

      final snapshot = await review.getSnapshot();

      expect(snapshot.firstInitializedAt, DateTime.utc(2026, 2, 1));
      expect(snapshot.launchCount, 1);
      expect(snapshot.significantEventCount, 2);
      expect(snapshot.lastRequestAt, DateTime.utc(2026, 2, 1));
      expect(snapshot.lastRequestedVersion, '2.4.0');
    });

    test('rejects invalid conditions consistently', () {
      expect(
        () => ConditionalInAppReview(
          conditions: const ReviewConditions(minLaunches: -1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ConditionalInAppReview(
          conditions: const ReviewConditions(
            cooldown: Duration(seconds: -1),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => ConditionalInAppReview(
          conditions: const ReviewConditions(
            delayBeforeRequest: Duration(milliseconds: -1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects overlapping review requests', () async {
      final requester = _FakeReviewRequester(
        requestDelay: const Duration(milliseconds: 30),
      );
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 0,
          minLaunches: 1,
          cooldown: Duration.zero,
        ),
        storage: _MemoryReviewStorage(),
        requester: requester,
      );

      await review.initialize();

      final first = review.requestIfEligible();
      await Future<void>.delayed(Duration.zero);
      final second = await review.requestIfEligible();

      expect(second, ReviewDecision.requestInProgress);
      expect(await first, ReviewDecision.requested);
      expect(requester.requestCount, 1);
    });
  });
}

final class _MutableClock {
  _MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}

final class _FakeReviewRequester implements ReviewRequester {
  _FakeReviewRequester({
    this.available = true,
    this.requestDelay = Duration.zero,
  });

  final bool available;
  final Duration requestDelay;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    if (requestDelay > Duration.zero) {
      await Future<void>.delayed(requestDelay);
    }
    requestCount += 1;
  }
}

final class _MemoryReviewStorage implements ReviewStorage {
  _MemoryReviewStorage({
    this.firstInitializationReadDelay = Duration.zero,
  });

  final Duration firstInitializationReadDelay;

  DateTime? firstInitializedAt;
  int launchCount = 0;
  int significantEventCount = 0;
  DateTime? lastRequestAt;
  String? lastRequestedVersion;
  int firstInitializedWriteCount = 0;
  int launchWriteCount = 0;

  @override
  Future<DateTime?> getFirstInitializedAt() async {
    if (firstInitializationReadDelay > Duration.zero) {
      await Future<void>.delayed(firstInitializationReadDelay);
    }
    return firstInitializedAt;
  }

  @override
  Future<void> setFirstInitializedAt(DateTime value) async {
    firstInitializedWriteCount += 1;
    firstInitializedAt = value;
  }

  @override
  Future<int> getLaunchCount() async => launchCount;

  @override
  Future<void> setLaunchCount(int value) async {
    launchWriteCount += 1;
    launchCount = value;
  }

  @override
  Future<int> getSignificantEventCount() async => significantEventCount;

  @override
  Future<void> setSignificantEventCount(int value) async {
    significantEventCount = value;
  }

  @override
  Future<DateTime?> getLastRequestAt() async => lastRequestAt;

  @override
  Future<void> setLastRequestAt(DateTime value) async {
    lastRequestAt = value;
  }

  @override
  Future<String?> getLastRequestedVersion() async => lastRequestedVersion;

  @override
  Future<void> setLastRequestedVersion(String? value) async {
    lastRequestedVersion = value;
  }

  @override
  Future<void> reset() async {
    firstInitializedAt = null;
    launchCount = 0;
    significantEventCount = 0;
    lastRequestAt = null;
    lastRequestedVersion = null;
    firstInitializedWriteCount = 0;
    launchWriteCount = 0;
  }
}
