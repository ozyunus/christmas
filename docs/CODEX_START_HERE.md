# CODEX — BAŞLANGIÇ VE UYGULAMA SÖZLEŞMESİ

## Amaç
Flutter + Flame ile Santa's Gift Rush'ın gerçek çalışan iOS uygulamasını hazırla. **Kodlamayı sen yap; görselleri yeniden üretme.** `assets/` içindeki gerçek kaynakları kullan. `docs/previews` altındaki JPG'leri veya herhangi bir montajı sprite yapma. Proje/repo dosyaları varsa önce kontrol et; yoksa Flutter projesi oluştur.

## P0 — Gameplay
- iPhone ve iPad (iOS/iPadOS), dikey iPhone; iPad hem dikey hem yatay uyumlu, responsive/centered arena.
- 60 saniyelik arcade shift. Tek anda tek hediye. Sekiz sabit hediye görseli NICE/NAUGHTY.
- NICE: teddy_bear, toy_train, candy_cane, toy_robot. NAUGHTY: coal, dirty_sock, prank_spider, broken_ornament.
- Sola swipe NICE / sağa swipe NAUGHTY. Aynı iki büyük butonla da karar verilebilir. Her ikisinde aynı kontrol katmanı.
- Doğru cevap +100 x combo tier, yanlış/kaçırılan puan 0 ve combo 0. Oyun 60 sn bitince sonuç ekranına geçer.
- Hediye zaman aşımı; 0–10 sn 2.0 s, 10–20 1.65, 20–30 1.4, 30–40 1.2, 40–50 1.1, 50–60 1.0. Varsayım/test edilecek, Remote Config'e hazır yapı.
- Her turda 60 sn nominal oyun zamanı; cihaz arka plana geçince pause/resume kararları tek bir controller'da.
- Yalnızca basit hareketler: conveyor belt scroll, doğru/yanlış gift exit, 4 elf pose geçişi. İlk sürümde Santa Says Opposite yok, levelli mod yok.

## P0 — Kod yapısı
`GiftCatalog`, `GiftSequence(seed)`, `DifficultyController`, `ScoreCalculator`, `ShiftSessionController`, `GameEventBus`, `LocalSaveRepository`, `AnalyticsService` (no-op ve Firebase adapter), `OnboardingAdapter` (Setgreet adapter), `ResponsiveGameLayout` ve Flutter overlay menü/sonuç ekranları. Pure Dart puanlama ve zamanlama testleri.

## P0 — Analytics / onboarding / data
- Setgreet SDK, ilk açılış onboarding'i; onboarding yalnızca bir kez veya sürüm/koşula göre. SDK özelliklerini resmî güncel dokümanda doğrula; entegrasyon başarısız olsa bile oyun açılsın.
- Firebase Analytics/Crashlytics; ilk ilk çalışır sürümde event şemasına göre bağlanacak. Veri analizi amacı: hangi aşamada yanlışlar, bırakma, ikinci tur dönüşü.
- Login ve Firebase Auth yok. En yüksek skor, ayar, tutorial/onboarding ilerlemesi, yarım tur durumu **cihazda**. BigQuery export yapılandırma adımı docs içinde.
- Oyun kişisel veri toplamaz. SDK'ların gizlilik açıklamalarını ve gerekli izinleri App Store için incele; reklama geçilirse ayrı onay gereklilikleri değerlendirilir.
- Oyunu Firebase/Setgreet ağ isteğine bloklama. Event dispatch best-effort, kritik yarım tur state'i local persist.

## P1 (çekirdek eğlence ölçüldükten sonra)
- Seed ile asenkron arkadaş challenge ve doğrulanmış skor paylaşımı. Kullanıcı hesap açmadan linkle challenge hedefi olabilir; backend/id kararını bu aşamada tasarla.
- AdMob ve IAP henüz P0'a ekleme.

## Kabul
1. Kullanılmayan sprite yok sayılmaz; mevcut dosya yollarıyla proje derlenir ve animasyonlu gift sorting çalışır.
2. iPhone (390x844, 430x932), iPad (768x1024, 1024x1366, 1024x768, 1366x1024) test edilir. Özellikle safe area, NICE/NAUGHTY hit-box, hand reach, arkaplan crop.
3. Skor, süre, doğruluk, combo, kaybetme/yeniden başlama ve event payload testleri.
4. `assets` için placeholder/kolaj asset kullanılmaz. Eksik teknik bağımlılığı raporla, dokümana göre karar ver.
5. Derleme, test komutları ve başarısız kalanlar raporlanır.

## İlk Codex isteği
“Bu paketteki README ve `docs/` sözleşmelerini oku. Mevcut repoyu incele, yoksa Flutter + Flame projesi oluştur. İlk sprintte 60 saniyelik sorting core ve responsive gameplay ekranını, verilen gerçek assetlerle geliştir; puanlama ve zamanlama unit testlerini yaz. Setgreet/Firebase adapter interface'lerini oluştur ama SDK bağlantısını ayrı test edilebilir görevde yap. Görsel üretme, sprite sheet kesme, konsept JPG yükleme.”
