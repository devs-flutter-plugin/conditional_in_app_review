# conditional_in_app_review

A Flutter package for requesting in-app reviews only when configurable conditions are met, such as app launches, days since first use, significant events, cooldown periods, and app version.

The package delegates the native review flow to [`in_app_review`](https://pub.dev/packages/in_app_review) and keeps the eligibility policy in Dart. It does not contain its own Android or iOS implementation.

## Features

- Minimum days since first package use before the first review attempt.
- Minimum app launches.
- Minimum significant events.
- Cooldown between review attempts.
- Optional one-attempt-per-app-version policy.
- Optional delay before requesting the native review flow.
- Detailed decision result for analytics and debugging.
- Read-only persisted state snapshots.
- `SharedPreferencesAsync` storage by default.
- Injectable storage, requester, and clock for deterministic tests.
- No package-owned Android or iOS implementation.

## Installation

```yaml
dependencies:
  conditional_in_app_review: ^0.1.0
```

Until the package is published on pub.dev, it can be consumed directly from GitHub:

```yaml
dependencies:
  conditional_in_app_review:
    git:
      url: https://github.com/devs-flutter-plugin/conditional_in_app_review.git
```

## Basic usage

Create a single instance for the app lifecycle and initialize it once when the application starts:

```dart
final appReview = ConditionalInAppReview(
  conditions: const ReviewConditions(
    minDaysSinceFirstUse: 7,
    minLaunches: 5,
    minSignificantEvents: 2,
    cooldown: Duration(days: 90),
    requestOncePerVersion: true,
  ),
);

await appReview.initialize();
```

`initialize()` records the first-use timestamp and, by default, one launch. Repeated or concurrent initialization calls on the same instance are deduplicated and do not increment the launch counter more than once.

Register meaningful positive interactions from your product flow:

```dart
await appReview.registerSignificantEvent();
```

Then request a review at a natural point in the user journey:

```dart
final decision = await appReview.requestIfEligible(
  currentVersion: '1.4.0',
);

if (decision == ReviewDecision.requested) {
  // Log analytics if desired.
}
```

When `requestOncePerVersion` is enabled, `currentVersion` is required. The package intentionally does not depend on `package_info_plus`; the application may provide its version using whichever mechanism it already uses.

## Inspecting state

Use `getSnapshot()` when you need counters and persisted metadata for diagnostics or analytics:

```dart
final snapshot = await appReview.getSnapshot();

print(snapshot.launchCount);
print(snapshot.significantEventCount);
print(snapshot.lastRequestAt);
print(snapshot.lastRequestedVersion);
```

A snapshot is read-only and can be obtained even before `initialize()` is called on the current manager instance.

## Decisions

`requestIfEligible()` returns a `ReviewDecision`, including:

- `requested`
- `unavailable`
- `notInitialized`
- `notEnoughDays`
- `notEnoughLaunches`
- `notEnoughSignificantEvents`
- `cooldownActive`
- `versionRequired`
- `alreadyRequestedForVersion`
- `requestInProgress`

`requested` means the package invoked the platform review API. Android and iOS control whether the review dialog is actually displayed, so applications must not treat this result as confirmation that the user saw or submitted a review.

## First use vs install date

The package intentionally does not claim to know the operating system's original installation date. `minDaysSinceFirstUse` is measured from the first time `initialize()` records package state. When the package is added to an already-installed app, this counter begins with the first app version that includes and initializes the package.

## Significant events

A significant event should represent a successful or valuable product interaction, for example:

- a booking completed;
- an order completed;
- a task successfully finished;
- a user returning after meaningful usage.

The package intentionally keeps this as a generic counter. Your application decides what qualifies as significant, avoiding domain-specific event names and persistence migrations inside the package.

## Custom storage and testing

The constructor accepts custom `ReviewStorage`, `ReviewRequester`, and clock implementations. This makes review policies testable without invoking Android or iOS APIs and lets applications replace the default persistence layer if necessary.

Invalid conditions such as negative counters, cooldowns, or delays are rejected when `ConditionalInAppReview` is created. Default platform adapters are created lazily, so constructing the manager does not access platform storage or the native review API.

## Platform behavior

The stores decide whether a review prompt is actually displayed. Google Play does not tell the app whether the user saw or submitted the review, and Apple applies its own presentation policy. Do not repeatedly call the API or make app behavior depend on a dialog appearing.

- [Google Play in-app review documentation](https://developer.android.com/guide/playcore/in-app-review/kotlin-java)
- [Apple StoreKit review documentation](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews)

## License

MIT License. See [LICENSE](LICENSE).
