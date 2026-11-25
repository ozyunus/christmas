import 'dart:async';

import 'package:setgreet/setgreet.dart';

import 'integrations.dart';

final class SetgreetOnboardingAdapter implements OnboardingAdapter {
  const SetgreetOnboardingAdapter({required this.appKey});

  final String appKey;

  static SetgreetOnboardingAdapter? fromEnvironment() {
    const appKey = String.fromEnvironment('SETGREET_APP_KEY');
    if (appKey.trim().isEmpty) return null;
    return SetgreetOnboardingAdapter(appKey: appKey);
  }

  @override
  Future<OnboardingOutcome> trackMainMenu({
    required bool Function() isMainMenuVisible,
    required bool Function() isOnboardingEligible,
    required void Function() onStarted,
  }) async {
    const setupTimeout = Duration(seconds: 4);
    final outcome = Completer<OnboardingOutcome>();
    StreamSubscription<SetgreetFlowEvent>? subscription;
    Timer? presentationTimeout;
    String? displayedFlowId;

    void finish(OnboardingOutcome value) {
      if (!outcome.isCompleted) outcome.complete(value);
    }

    try {
      await Setgreet.setLocale('en-US').timeout(setupTimeout);
      if (!Setgreet.isInitialized) {
        await Setgreet.initialize(appKey).timeout(setupTimeout);
      }
      if (!isMainMenuVisible()) return OnboardingOutcome.unavailable;

      final eligible = isOnboardingEligible();
      if (eligible) {
        subscription = Setgreet.flowEvents.listen((event) {
          if (outcome.isCompleted) return;
          switch (event) {
            case FlowStartedEvent() when displayedFlowId == null:
              displayedFlowId = event.flowId;
              presentationTimeout?.cancel();
              onStarted();
            case FlowCompletedEvent() when event.flowId == displayedFlowId:
              finish(OnboardingOutcome.completed);
            case FlowDismissedEvent() when event.flowId == displayedFlowId:
              finish(OnboardingOutcome.dismissed);
            case FlowErrorEvent()
                when displayedFlowId == null || event.flowId == displayedFlowId:
              finish(OnboardingOutcome.unavailable);
            default:
              break;
          }
        });
        presentationTimeout = Timer(
          const Duration(minutes: 1),
          () => finish(OnboardingOutcome.unavailable),
        );
      }
      // Setgreet evaluates the published trigger and reports any flow it opens.
      await Setgreet.trackScreen(
        'main_menu',
        properties: {'onboarding_eligible': eligible},
      ).timeout(setupTimeout);
      return eligible ? await outcome.future : OnboardingOutcome.unavailable;
    } catch (_) {
      return OnboardingOutcome.unavailable;
    } finally {
      presentationTimeout?.cancel();
      await subscription?.cancel();
    }
  }
}
