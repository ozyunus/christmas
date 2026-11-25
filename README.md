# Santa’s Gift Rush — Codex Handoff v1

Resume development from the [development handoff](docs/DEVELOPMENT_HANDOFF.md) for the current build, verification results, and next sprint.

## Run the first playable build

Use Flutter 3.38 / Dart 3.10 or newer and Xcode with an iOS simulator runtime. Run these commands from the project root.

```sh
flutter pub get
open -a Simulator
flutter devices
flutter run -d <simulator-id>
```

Choose an iPhone for portrait or an iPad for portrait and landscape. If Xcode reports Finder information or resource-fork metadata during code signing, run from a local checkout outside a File Provider-synced folder.

```sh
flutter analyze
flutter test
python3 tools/check_assets.py
```

The Python asset check needs Pillow. The Flutter suite also decodes all bundled PNGs and checks the six reference viewports.

The app plays offline. It saves the best score, latest result, and one unfinished shift on the device. Returning from the background keeps the shift paused until the player resumes. Firebase Analytics, Crashlytics, and Setgreet have adapter interfaces for the integration sprint. The simulator build uses `com.ozyunus.santasGiftRush` as its bundle identifier.

## Playable modes

- **Play Shifts** includes Packing Practice, Workshop Shift, and Christmas Eve Rush. Meeting a shift's goals unlocks the next shift on this device.
- **Arcade** runs the 60-second score attack. **Daily Shift** uses a separate record and repeats the day's gift sequence until midnight UTC.
- **Santa's Road Trip** includes three free 30-second previews. Fill a shipment in Texas Toy Roundup, find damaged drones and consoles in Silicon Valley Workshop, or sort through two timed ice surges in Great Lakes Ice Run.

Campaign and preview rules are defined in [the shift catalog](data/shifts.v1.json). Road Trip sprites and their generation prompts are listed in [the asset manifest](docs/asset_manifest.json).

The main rotation contains 12 gifts, including in Arcade, Daily Shift, Workshop Shift, and Christmas Eve Rush. Packing Practice uses a six-gift pool. A saved round resumes with the exact gift sequence it started with.

## Holiday soundtrack

Three original instrumentals rotate offline in the menu and during shifts. The **Music On** and **Music Off** control saves the player's preference. Replace a track with another MP3 using the same path, then rebuild the app.

- [Workshop Lights](assets/audio/workshop_lights.mp3)
- [Sleigh Route](assets/audio/sleigh_route.mp3)
- [Snowfall at the Pole](assets/audio/snowfall_at_the_pole.mp3)

The campaign's **Next Shift** action plays a two-second flight before starting the next round. Its optional audio cue is [Sleigh Bells](assets/audio/sleigh_bells.mp3).

**Tek proje klasörü / tek asset kökü.** Bu paket, daha önce ayrı teslim edilen 8 hediye, 4 elf, 11 fabrika sprite'ı ve 29 UI/efekt sprite'ını birleştirir. Ayrıca iki bağımsız, opak arka plan bulunur: iPhone dikey ve **yeni** iPad yatay. Toplam **54 PNG** (52 şeffaf sprite + 2 opak arka plan). Her oyun sprite'ı ayrı PNG dosyasıdır; toplu görsel kesimi yapılmadı.

## İlk açılacak dosyalar
- `docs/CODEX_START_HERE.md` — Codex görev tanımı ve uygulama sırası
- `docs/GAMEPLAY_SPEC.md` — 60 saniyelik oyunun kesin kuralları
- `docs/RESPONSIVE_LAYOUT.md` — iPhone ve iPad ekran yerleşimi
- `docs/ANALYTICS_EVENT_PLAN.md` — Firebase, Setgreet ve yerel saklama olayları
- `docs/ASSET_ART_REVIEW.md` — görsel stil açıkları / gerçek kalite durumu
- `docs/asset_manifest.json` — dosya yolları, piksel boyutları, alfa testleri ve SHA256
- `docs/qa/asset_checks.json` — otomatik kalite taraması

`assets/` klasörü Flutter projesine kopyalanır; `sources/` düzenlenebilir kaynaklar, `docs/previews/` yalnızca kalite ve ekran referanslarıdır. **Codex'ten yeni görsel üretmesini, kaynak kolaj kesmesini veya başka asset seçmesini istemiyoruz.**

**Dikkat:** Bu paket yüksek kaliteli ilk oynanabilir sürüm için yeterlidir; sanat dili henüz final değil. Elf kıyafetleri pozlar arasında kısmen tutarsız, SVG kökenli parçalar ise 3D görsellerden daha düz görünüyor. Ayrıca iPad portre için ayrı 3D background henüz üretilmedi; iPhone dikey background `BoxFit.cover` / odak noktası ile kullanılacak. Bunun için gerçek cihazda görsel test şart.

## Yapılandırma ve sprint
- `data/game_config.v1.json` — makine tarafından okunabilir hediyeler, combo ve süreler.
- `data/analytics_event_names.v1.json` — tek kaynak event adları.
- `docs/CODEX_SPRINT_TASKS.md` — Codex için küçük, test edilebilir görevler.
