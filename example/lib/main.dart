import 'package:conditional_in_app_review/conditional_in_app_review.dart';
import 'package:flutter/material.dart';

final ConditionalInAppReview _appReview = ConditionalInAppReview(
  conditions: const ReviewConditions(
    minDaysAfterInstall: 0,
    minLaunches: 1,
    minSignificantEvents: 1,
    cooldown: Duration(days: 90),
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _appReview.initialize();
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conditional In-App Review',
      home: Scaffold(
        appBar: AppBar(title: const Text('Conditional In-App Review')),
        body: const Center(child: _ReviewExample()),
      ),
    );
  }
}

class _ReviewExample extends StatefulWidget {
  const _ReviewExample();

  @override
  State<_ReviewExample> createState() => _ReviewExampleState();
}

class _ReviewExampleState extends State<_ReviewExample> {
  ReviewDecision? _lastDecision;

  Future<void> _completeSignificantEvent() async {
    await _appReview.registerSignificantEvent();
    final decision = await _appReview.requestIfEligible();

    if (!mounted) {
      return;
    }

    setState(() {
      _lastDecision = decision;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _completeSignificantEvent,
            child: const Text('Complete significant event'),
          ),
          const SizedBox(height: 16),
          Text('Last decision: ${_lastDecision?.name ?? 'none'}'),
        ],
      ),
    );
  }
}
