import 'package:in_app_review/in_app_review.dart';

/// Abstraction over the platform in-app review implementation.
abstract interface class ReviewRequester {
  /// Returns whether the native in-app review API is available.
  Future<bool> isAvailable();

  /// Requests the native in-app review flow.
  Future<void> requestReview();
}

/// Default requester backed by the `in_app_review` package.
final class InAppReviewRequester implements ReviewRequester {
  /// Creates a requester.
  InAppReviewRequester({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  @override
  Future<bool> isAvailable() => _inAppReview.isAvailable();

  @override
  Future<void> requestReview() => _inAppReview.requestReview();
}
