import 'package:conditional_in_app_review/conditional_in_app_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConditionalInAppReview', () {
    test('requests review when all conditions are satisfied', () async {
      final storage = MemoryReviewStorage();
      final requester = FakeReviewRequester();
      final clock = MutableClock(DateTime.utc(2026, 1, 1));
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
      final storage = MemoryReviewStorage();
      final review = ConditionalInAppReview(
        storage: storage,
        requester: FakeReviewRequester(),
      );

      await review.initialize();
      await review.initialize();

      expect(storage.launchCount, 1);
    });

    test('enforces cooldown after a request', () async {
      final storage = MemoryReviewStorage();
      final requester = FakeReviewRequester();
      final clock = MutableClock(DateTime.utc(2026, 1, 1));
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
        storage: MemoryReviewStorage(),
        requester: FakeReviewRequester(),
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
      final storage = MemoryReviewStorage();
      final review = ConditionalInAppReview(
        conditions: const ReviewConditions(
          minDaysAfterInstall: 0,
          minLaunches: 1,
          cooldown: Duration.zero,
        ),
        storage: storage,
        requester: FakeReviewRequester(available: false),
      );

      await review.initialize();

      expect(await review.requestIfEligible(), ReviewDecision.unavailable);
      expect(storage.lastRequestAt, isNull);
    });
  });
}

final class MutableClock {
  MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}

final class FakeReviewRequester implements ReviewRequester {
  FakeReviewRequester({this.available = true});

  final bool available;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requestCount += 1;
  }
}

final class MemoryReviewStorage implements ReviewStorage {
  DateTime? firstInitializedAt;
  int launchCount = 0;
  int significantEventCount = 0;
  DateTime? lastRequestAt;
  String? lastRequestedVersion;

  @override
  Future<DateTime?> getFirstInitializedAt() async => firstInitializedAt;

  @override
  Future<void> setFirstInitializedAt(DateTime value) async {
    firstInitializedAt = value;
  }

  @override
  Future<int> getLaunchCount() async => launchCount;

  @override
  Future<void> setLaunchCount(int value) async {
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
  }
}
