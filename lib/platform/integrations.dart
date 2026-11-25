enum OnboardingOutcome { completed, dismissed, unavailable }

abstract interface class OnboardingAdapter {
  Future<OnboardingOutcome> trackMainMenu({
    required bool Function() isMainMenuVisible,
    required bool Function() isOnboardingEligible,
    required void Function() onStarted,
  });
}

abstract interface class CrashReporter {
  Future<void> recordError(Object error, StackTrace stackTrace);
}

final class FirebaseCrashlyticsAdapter implements CrashReporter {
  const FirebaseCrashlyticsAdapter(this.report);

  final Future<void> Function(Object error, StackTrace stackTrace) report;

  @override
  Future<void> recordError(Object error, StackTrace stackTrace) =>
      report(error, stackTrace);
}
