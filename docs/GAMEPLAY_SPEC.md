# Oynanış GDD — v1.0 (P0)

## Fantezi ve core loop
Oyuncu Noel arifesinde fabrikadaki son elf. Bir hediye gelir, oyuncu onu sevkiyata uygun (NICE) veya uygun değil (NAUGHTY) diye ayırır. Doğru karar fiziksel çıkış animasyonu, elf geri bildirimi, puan, combo ve yeni hediyeyi tetikler.

## Tur kuralları
- İlk tur: 60s, tek eşzamanlı hediye, can yok, hata oyunu bitirmez, 60s sonunda Results.
- Swipe left or tap `SHIP` for NICE. Swipe right or tap `REJECT` for NAUGHTY.
- NICE: `teddy_bear`, `toy_train`, `candy_cane`, `toy_robot`.
- NAUGHTY: `coal`, `dirty_sock`, `prank_spider`, `broken_ornament`.
- Oyuncu doğru yanıt verirse combo **önce bir artırılır**, ilgili tier çarpanıyla 100 puan verilir.
- Combo 1–4 ×1; 5–9 ×1.2; 10–14 ×1.5; 15–19 ×1.8; 20+ ×2. Yanlış veya deadline sonu: combo=0, +0 puan.
- 0–10s deadline 2.0s; 10–20 1.65s; 20–30 1.4s; 30–40 1.2s; 40–50 1.1s; 50–60 1.0s. Bunlar deneysel başlangıç değerleri.
- Karar hemen gelirse bir sonraki hediye kısa çıkış transition sonrasında başlatılır (ör. 150–220ms). Süre kritikse transition kısaltılabilir.
- 60s her zaman nominal tur saati; uygulama `paused` konumundayken geçmez; foreground resume bilinçli devam.

## Seed / adalet
- Sabit seed, *hediye dizisi* için deterministik; kod düzeyinde platformlar arası aynı PRNG.
- **Aynı seed aynı hediye sayısını garanti etmez.** Oyuncu tepkisine göre işlenen hediye adedi değişebilir; skor karşılaştırması sabit 60s + aynı hediye dizisi/rules + doğrulanmış kurallarla yapılır.
- Arkadaş challenge sisteminin server validation'ı P1. İlk P0 local skor güvenilir multiplayer sonucu değildir.

## P0 sonuçlar
`final_score`, `accuracy = correct / total_attempts_and_misses`, `best_combo`, `correct`, `incorrect`, `missed`, `completed_at`.

## Key game feel
- Oyun sırasında UI'yi kapatan Setgreet flow açma.
- Hediye sahnede yüksek kontrastlı, tek bakışta okunur boyut ve kontrollü arka plan karartması.
- Happy/sad elf geçişleri çok sık olursa kısalt veya score efektleriyle sınırlı tut.
- iPad'de oyun dünyası yatayca genişlemez; merkezi karar alanı aynı oyun mekaniğini korur.
