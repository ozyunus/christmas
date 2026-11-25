# Santa's Gift Rush Development Handoff

Checkpoint for November 25, 2026. The offline Flutter and Flame game is playable. The Setgreet workshop tour is published for the game's dedicated Setgreet app. Firebase integration and TestFlight preparation are next.

## Playable build

- **Sorting.** Swipe left or tap **SHIP** for a good gift. Swipe right or tap **REJECT** for a damaged or unsuitable gift. A wrong answer or missed gift resets the combo. The data and analytics retain the `nice` and `naughty` identifiers.
- **Campaign.** Packing Practice (30 seconds), Workshop Shift (45 seconds), and Christmas Eve Rush (60 seconds) unlock in order when the player meets each shift's goals. The campaign finale offers Arcade and Daily Shift.
- **Arcade and Daily Shift.** Both run for 60 seconds. Daily Shift repeats a seeded sequence for the UTC day within a rules version and has its own local record. The main pool now has 12 gifts, up from eight, and Packing Practice has six. Existing unfinished shifts use their original rules version and gift sequence.
- **Santa's Road Trip.** Texas Toy Roundup, Silicon Valley Workshop, and Great Lakes Ice Run each offer a free 30-second preview. Texas has a shipment order, Silicon Valley has damaged and working versions of two toys, and Great Lakes has two timed ice surges. Each preview has four regional gift sprites.
- **Holiday audio and animation.** Campaign transitions show Santa and his reindeer for two unskippable seconds before the next round timer starts. Three original MP3 tracks rotate offline. To replace a track, keep its filename in `assets/audio/` and rebuild. The player can toggle music in the main menu.
- **Device state.** Arcade best score, latest result, campaign unlocks, daily record, music preference, and one unfinished round are saved locally. Returning from the background leaves the round paused until the player resumes. The game UI is English and supports iPhone portrait and iPad portrait and landscape.
- **Workshop onboarding.** The published Setgreet tour uses the game's factory scenes and celebrating elf, a conveyor with SHIP and REJECT examples, and Santa's sleigh with Packing Practice goals. The text and buttons are native Setgreet components. Setgreet targets the first `main_menu` screen signal with `onboarding_eligible: true` and a once-per-user frequency. Completion and skipping are saved locally. Unconfigured or offline installations still have **How to Play** and **Packing Practice**. [Setgreet flow](https://app.setgreet.com/flows/6b06dccd87e178eef956a1f6)

## Files to start with

- Base rules and the current shift catalog are in [game_config.v1.json](../data/game_config.v1.json) and [shifts.v1.json](../data/shifts.v1.json). The catalog loads both current and legacy rule versions. [shift_catalog.dart](../lib/game/shift_catalog.dart)
- Round timing, decisions, scoring, and checkpoints live in the game controller. [shift_session.dart](../lib/game/shift_session.dart)
- The main menu, gameplay, results, and lifecycle are coordinated by the app widget. [gift_rush_app.dart](../lib/ui/gift_rush_app.dart)
- Setgreet 1.14.2 requires iOS and iPadOS 15 or later. The app presents the configured flow through the onboarding adapter. Firebase work can start with the existing typed event dispatcher. The app currently uses a no-op analytics service. [setgreet_onboarding.dart](../lib/platform/setgreet_onboarding.dart) · [analytics.dart](../lib/platform/analytics.dart) · [main.dart](../lib/main.dart)

## Verification

`flutter analyze --no-pub` reported no issues and all 46 Flutter tests passed. The asset validator previously verified 71 PNGs. On an iPhone simulator, the published screen trigger opened the three live screens and the final button opened **Play Shifts** with **Packing Practice** available. Relaunching after completion showed the main menu and sent `onboarding_eligible: false`. In the redesigned tour, the welcome and final screens were visually verified on iPhone. Visual review of the controls screen and the iPad layout is pending after the simulator stopped responding.

Follow the [README](../README.md) to install dependencies, run the app on a simulator, and repeat the checks.

## Next sprint

1. Connect Firebase Analytics and Crashlytics for the chosen iOS bundle identifier. Use the existing analytics event names and verify onboarding, first-round completion, replay, gift mistakes, difficulty phases, pause and resume, and inferred abandonment. Link BigQuery before the public pilot. [Analytics event plan](ANALYTICS_EVENT_PLAN.md)
2. Confirm the release bundle identifier, icon, and signing. Run smoke tests on physical iPhones and iPads, then prepare the TestFlight build with the three free previews and the published Setgreet tour. Supply `SETGREET_APP_KEY` when building the release. The simulator uses `com.ozyunus.santasGiftRush`.

Full paid regional packs and StoreKit purchases with restoration are later work. A snowfall effect for selected shifts remains a design option.
