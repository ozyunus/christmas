# Santa's Gift Rush Development Handoff

Checkpoint for November 25, 2026. The offline Flutter and Flame game is playable. The next sprint connects Setgreet and Firebase and prepares the build for a TestFlight pilot.

## Playable build

- **Sorting.** Swipe left or tap **SHIP** for a good gift. Swipe right or tap **REJECT** for a damaged or unsuitable gift. A wrong answer or missed gift resets the combo. The data and analytics retain the `nice` and `naughty` identifiers.
- **Campaign.** Packing Practice (30 seconds), Workshop Shift (45 seconds), and Christmas Eve Rush (60 seconds) unlock in order when the player meets each shift's goals. The campaign finale offers Arcade and Daily Shift.
- **Arcade and Daily Shift.** Both run for 60 seconds. Daily Shift repeats a seeded sequence for the UTC day within a rules version and has its own local record. The main pool now has 12 gifts, up from eight, and Packing Practice has six. Existing unfinished shifts use their original rules version and gift sequence.
- **Santa's Road Trip.** Texas Toy Roundup, Silicon Valley Workshop, and Great Lakes Ice Run each offer a free 30-second preview. Texas has a shipment order, Silicon Valley has damaged and working versions of two toys, and Great Lakes has two timed ice surges. Each preview has four regional gift sprites.
- **Holiday audio and animation.** Campaign transitions show Santa and his reindeer for two unskippable seconds before the next round timer starts. Three original MP3 tracks rotate offline. To replace a track, keep its filename in `assets/audio/` and rebuild. The player can toggle music in the main menu.
- **Device state.** Arcade best score, latest result, campaign unlocks, daily record, music preference, and one unfinished round are saved locally. Returning from the background leaves the round paused until the player resumes. The game UI is English and supports iPhone portrait and iPad portrait and landscape.

## Files to start with

- Base rules and the current shift catalog are in [game_config.v1.json](../data/game_config.v1.json) and [shifts.v1.json](../data/shifts.v1.json). The catalog loads both current and legacy rule versions. [shift_catalog.dart](../lib/game/shift_catalog.dart)
- Round timing, decisions, scoring, and checkpoints live in the game controller. [shift_session.dart](../lib/game/shift_session.dart)
- The main menu, gameplay, results, and lifecycle are coordinated by the app widget. [gift_rush_app.dart](../lib/ui/gift_rush_app.dart)
- Start SDK work with the existing typed event dispatcher and adapter interfaces. The app currently uses a no-op analytics service. [analytics.dart](../lib/platform/analytics.dart) · [integrations.dart](../lib/platform/integrations.dart) · [main.dart](../lib/main.dart)

## Verification

`flutter analyze --no-pub` reported no issues, all 43 Flutter tests passed, and the asset validator verified 71 PNGs. The latest build compiled for the iOS Simulator. Physical iPhone and iPad testing is pending.

Follow the [README](../README.md) to install dependencies, run the app on a simulator, and repeat the checks.

## Next sprint

1. Connect the English Setgreet first-launch flow when its project configuration and flow are available. Keep the game playable when offline or when onboarding fails. The game already has a Help screen and Packing Practice. Interactive tutorial work is still open.
2. Connect Firebase Analytics and Crashlytics for the chosen iOS bundle identifier. Use the existing analytics event names and verify first-round completion, replay, gift mistakes, difficulty phases, pause and resume, and inferred abandonment. Link BigQuery before the public pilot. [Analytics event plan](ANALYTICS_EVENT_PLAN.md)
3. Confirm the release bundle identifier, icon, and signing. Run smoke tests on physical iPhones and iPads, then prepare the TestFlight build with the three free previews. The simulator uses `com.ozyunus.santasGiftRush`.

Full paid regional packs and StoreKit purchases with restoration are later work. A snowfall effect for selected shifts remains a design option.
