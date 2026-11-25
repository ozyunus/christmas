# Codex Sprint Tickets — kapsam ve kabul kriterleri

## Sprint 0: Read + Bootstrap
- Mevcut repoyu kontrol et, Flutter+Flame dependency ve hedef iOS/iPadOS kurulumu.
- `assets/` manifestine göre `pubspec.yaml` kaydı; tüm PNG yüklenebilirlik testi.
- `data/game_config.v1.json` parse, gift katalog birim testi. Eksik dosya kalmasın.

## Sprint 1: Pure Game Logic
- `ShiftSessionController`, sabit-seed `GiftSequence`, `ScoreCalculator`, `DifficultyController`.
- Doğru/yanlış/timeout, pause-resume, time limit, combo boundary testleri. `elapsed_secs` 10/20/30/40/50 eşiklerinde test.
- Bir turda tek aktif hediye ve çift input ile iki kez puan kazanılamaması.

## Sprint 2: Responsive Gameplay
- Gerçek ayrı PNG'leri Flame sahnesinde kullan, dinamik metin için Flutter overlay.
- Bant tile scroll ve sabit frame; iPad yatayda `factory_ipad_landscape.png`.
- iPhone dikey ve iPad dikey + yatay ölçülerde safe-area golden/widget testleri; tek elle oynanış.

## Sprint 3: State + Setgreet + Firebase
- Yerel skor, ayarlar, tutorial, yarım tur; hesap girişini ekleme.
- Setgreet onboarding SDK akışını güncel dokümanla doğrula, başarısız olursa fallback. Flame tutorial ayrı.
- Firebase Analytics event adapter, Crashlytics. BigQuery bağlantı adımını belgele. Oyun offline devam eder.
- Event sequence test: onboarding → tutorial → game_start → gift_sorted → game_complete → replay; pause/resume and inferred abandonment.

## Sprint 4: Playtest
- Gerçek cihaz smoke tests: iPhone küçük/büyük, iPad portrait/landscape.
- İlk test grubunda tutorial anlaşılırlığı, 60 sn tamamlanma, ikinci tur oynama oranı ve yanlış hediye farklarını ölç.
- Sonra güçlendirme: özel kurallar, sharing challenge, reklam ve premium P1/P2.

> Oyunun ilk testinde 60sn ve faz hızları hipotezdir, metrikleri değiştirilebilir tut.
