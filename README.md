# conditional_in_app_review

A Flutter package for requesting in-app reviews only when configurable conditions are met, such as app launches, days since first initialization, significant events, cooldown periods, and app version.

The package delegates the native review flow to [`in_app_review`](https://pub.dev/packages/in_app_review) and keeps the eligibility policy in Dart. It does not contain its own Android or iOS implementation.

## Features

- Minimum days before the first review attempt.
- Minimum app launches.
- Minimum significant events.
- Cooldown between review attempts.
- Optional one-attempt-per-app-version policy.
- Optional delay before requesting the native review flow.
- Detailed decision result for analytics and debugging.
- `SharedPreferencesAsync` storage by default.
- Injectable storage, requester, and clock for deterministic tests.

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

## Usage

Create a single instance for the app lifecycle and initialize it once when the application starts:

```dart
final appReview = ConditionalInAppReview(
  conditions: const ReviewConditions(
    minDaysAfterInstall: 7,
    minLaunches: 5,
    minSignificantEvents: 2,
    cooldown: Duration(days: 90),
    requestOncePerVersion: true,
  ),
);

await appReview.initialize();
```

`initialize()` records the first initialization timestamp and, by default, one launch. Calling it again on the same instance does not increment the launch counter again.

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

## First initialization vs install date

The package cannot reliably read the operating system's original install date on every supported platform. Therefore `minDaysAfterInstall` is measured from the first time `initialize()` records state. For a newly installed app this closely matches installation time; when adding this package to an already-installed app, the counter begins with the first app version containing the package.

## Significant events

A significant event should represent a successful or valuable product interaction, for example:

- a booking completed;
- an order completed;
- a task successfully finished;
- a user returning after meaningful usage.

The package stays domain-agnostic: your application decides what qualifies as significant.

## Testing

The constructor accepts custom `ReviewStorage`, `ReviewRequester`, and clock implementations. This makes review policies testable without invoking Android or iOS APIs.

## Platform behavior

The underlying stores enforce their own quotas and eligibility rules. Do not repeatedly call the review API or assume that a request always shows a dialog.

## License

MIT License. See [LICENSE](LICENSE).
