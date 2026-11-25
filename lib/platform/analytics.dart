import 'dart:async';

import '../game/shift_session.dart';

enum AnalyticsEventName {
  onboardingStarted('onboarding_started'),
  onboardingStepViewed('onboarding_step_viewed'),
  onboardingCompleted('onboarding_completed'),
  tutorialStarted('tutorial_started'),
  tutorialError('tutorial_error'),
  tutorialCompleted('tutorial_completed'),
  gameStarted('game_started'),
  difficultyPhaseEntered('difficulty_phase_entered'),
  giftSorted('gift_sorted'),
  giftMissed('gift_missed'),
  gameInterrupted('game_interrupted'),
  gameResumed('game_resumed'),
  gameCompleted('game_completed'),
  gameReplayed('game_replayed'),
  gameAbandonedInferred('game_abandoned_inferred'),
  appErrorContext('app_error_context');

  const AnalyticsEventName(this.wireName);
  final String wireName;
}

final class AnalyticsEvent {
  AnalyticsEvent(this.name, Map<String, Object> parameters)
    : parameters = Map.unmodifiable(parameters);

  final AnalyticsEventName name;
  final Map<String, Object> parameters;
}

abstract interface class AnalyticsService {
  Future<void> track(AnalyticsEvent event);
}

final class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> track(AnalyticsEvent event) async {}
}

/// The SDK integration supplies its logEvent function.
final class FirebaseAnalyticsAdapter implements AnalyticsService {
  const FirebaseAnalyticsAdapter(this.logEvent);

  final Future<void> Function(String name, Map<String, Object> parameters)
  logEvent;

  @override
  Future<void> track(AnalyticsEvent event) =>
      logEvent(event.name.wireName, event.parameters);
}

final class ShiftTelemetry {
  const ShiftTelemetry(this.service);

  final AnalyticsService service;

  void dispatch(AnalyticsEvent event) {
    unawaited(
      Future<void>.microtask(
        () => service.track(event),
      ).catchError((Object _, StackTrace _) {}),
    );
  }

  void record(ShiftSessionController shift, ShiftEvent event) {
    final roundId = shift.roundId;
    final elapsedBucket = shift.elapsedMs ~/ 10000 * 10;
    switch (event) {
      case ShiftStarted(:final previousRoundId):
        if (previousRoundId != null) {
          dispatch(
            AnalyticsEvent(AnalyticsEventName.gameReplayed, {
              'previous_round_id': previousRoundId,
              'session_index': shift.sessionIndex,
            }),
          );
        }
        dispatch(
          AnalyticsEvent(AnalyticsEventName.gameStarted, {
            'round_id': roundId,
            'mode': shift.config.mode,
            'seed': shift.seed,
            'session_index': shift.sessionIndex,
          }),
        );
      case PhaseEntered(:final index, :final elapsedMs):
        dispatch(
          AnalyticsEvent(AnalyticsEventName.difficultyPhaseEntered, {
            'round_id': roundId,
            'phase_index': index,
            'elapsed_bucket': elapsedMs ~/ 10000 * 10,
          }),
        );
      case GiftResolved(
        :final activeGift,
        :final outcome,
        :final elapsedMs,
        :final choice,
        :final inputMethod,
      ):
        final common = <String, Object>{
          'round_id': roundId,
          'gift_id': activeGift.gift.id,
          'phase_index': activeGift.phaseIndex,
        };
        if (outcome == GiftOutcome.missed) {
          dispatch(
            AnalyticsEvent(AnalyticsEventName.giftMissed, {
              ...common,
              'deadline_ms': activeGift.deadlineMs,
            }),
          );
        } else {
          dispatch(
            AnalyticsEvent(AnalyticsEventName.giftSorted, {
              ...common,
              'classification': choice!.name,
              'correct': outcome == GiftOutcome.correct ? 1 : 0,
              'response_ms': elapsedMs - activeGift.spawnedAtMs,
              'input_method': inputMethod!.name,
            }),
          );
        }
      case ShiftInterrupted(:final reason):
        dispatch(
          AnalyticsEvent(AnalyticsEventName.gameInterrupted, {
            'round_id': roundId,
            'phase_index': shift.phaseIndex,
            'elapsed_bucket': elapsedBucket,
            'reason': reason.name,
          }),
        );
      case ShiftResumed():
        dispatch(
          AnalyticsEvent(AnalyticsEventName.gameResumed, {
            'round_id': roundId,
            'elapsed_bucket': elapsedBucket,
          }),
        );
      case ShiftCompleted(:final result):
        final stats = result.stats;
        dispatch(
          AnalyticsEvent(AnalyticsEventName.gameCompleted, {
            'round_id': roundId,
            'score': stats.score,
            'accuracy_pct': stats.accuracyPercent.round(),
            'best_combo': stats.bestCombo,
            'correct_count': stats.correct,
            'wrong_count': stats.wrong,
            'missed_count': stats.missed,
            'duration_ms': shift.config.durationMs,
          }),
        );
    }
  }
}
