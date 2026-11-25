# Analytics Event Plan — First Playable & Pilot

**Amaç:** Nerede öğrenemiyor, nerede hata yapıyor, hangi fazda ayrılıyor, ne tekrar oynatıyor? **Her event ölçüm hipotezine bağlıdır.** Kullanıcı login yapmaz. Skor/kullanıcı ayarları local; davranış agregasyonu Firebase Analytics. Setgreet flow/anket/koşullu onboarding için.

## Ölçüm olayları
| Event | When | Primary params |
|---|---|---|
| `onboarding_started` | Setgreet flow starts | `flow_id`, `app_version` |
| `onboarding_step_viewed` | screen shown | `flow_id`, `step_id` |
| `onboarding_completed` | flow finished | `flow_id`, `duration_ms` |
| `tutorial_started` | in-game lesson start | `tutorial_version` |
| `tutorial_error` | wrong tutorial action | `step_id`, `input_method` |
| `tutorial_completed` | lesson finished | `duration_ms` |
| `game_started` | start round | `round_id`, `mode`, `seed`, `session_index` |
| `difficulty_phase_entered` | enter 10s phase | `round_id`, `phase_index`, `elapsed_bucket` |
| `gift_sorted` | every valid input | `round_id`, `gift_id`, `classification`, `correct`, `phase_index`, `response_ms`, `input_method` |
| `gift_missed` | gift deadline | `round_id`, `gift_id`, `phase_index`, `deadline_ms` |
| `game_interrupted` | app backgrounds / pause | `round_id`, `phase_index`, `elapsed_bucket`, `reason` |
| `game_resumed` | user resumes | `round_id`, `elapsed_bucket` |
| `game_completed` | 60s round ends | `round_id`, `score`, `accuracy_pct`, `best_combo`, `correct_count`, `wrong_count`, `missed_count`, `duration_ms` |
| `game_replayed` | replay tapped | `previous_round_id`, `session_index` |
| `game_abandoned_inferred` | next open detects never-resumed interrupted round | `round_id`, `last_phase`, `last_elapsed_bucket` |
| `app_error_context` | non-fatal context, avoid PII | `scene_id`, `error_category` |

Do not log precise wallclock of every input, names, emails, or device ID in custom params. Prefer bounded enums and integer buckets for event analysis. Very high-rate `gift_sorted` may cost event volume; pilot track all, later sample, aggregate on completion or adjust with documented policy. Verify Firebase parameter naming and current SDK limits before implementation.

## Accurate abandonment
Force-quit cannot reliably send an event at exit. Persist `round_id`, last phase and status locally when backgrounding. On next app launch, if unresolved and not resumed within the defined policy window, generate **inferred** abandonment *once*. Keep this separate from deliberate pause. This is an analytic inference, not a known reason.

## Installation / link
Connect Firebase Analytics to BigQuery **before public pilot**; configure export and billing controls, data retention, regional privacy disclosures. Setgreet's UI events are not a substitute for in-game telemetry. If business/legal policy needs opt-in, respect user privacy choices; game still works when tracking disabled.

## QA
Test event sequence for a complete round, an interrupted/resumed round, a tutorial error and restart, and offline play. Check duplicate emission, event naming parity, valid score/time and 0/1 classification. Do not let analytics calls block 60s gameplay.
