abstract interface class OnboardingAdapter {
  Future<void> showOnboarding();
}

final class SetgreetOnboardingAdapter implements OnboardingAdapter {
  const SetgreetOnboardingAdapter(this.presentFlow);

  final Future<void> Function() presentFlow;

  @override
  Future<void> showOnboarding() => presentFlow();
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
