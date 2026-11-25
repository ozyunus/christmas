# Art Review / Asset Provenance — Status

**Gerçek durum:** Bu paket **Codex prototipi için** tasarlanmış tekil varlık koleksiyonudur. Final estetik kalite garantisi değildir.

### Art direction
- Kullanıcının orijinal referansı: sıcak amber ışıklar, teal/yeşil oyuncak-fabrikası makineleri, kırmızı ve altın vurgu, dışarıda mavi karlı gece, cozy 3D/2.5D storybook.
- Hediyeler: 8 sprite ayrı ayrı hazırlanmış (bazıları procedural/3D raster); her sprite bağımsız PNG. Örümcek daha sevimli, broken ornament görseli diğerlerine göre stil farkı gösterebilir.
- Elf: 4 farklı görsel bağımsız üretilmiş, aynı karakter hissi mevcut ama yaka, çizgili çorap, ayakkabı renkleri ve kostüm detayları birebir eşleşmiyor. **Kare animasyon sprite sheet'i değildir.**
- Fabrika: iPhone opak 3D-style arka plan; iPad landscape yeni ayrı sahne; her ikisi de oynanışı engellemeyecek açık orta alanlı. Bu ikisi birebir aynı binanın kamera genişlemesi değildir.
- Modüler makineler: SVG authored 2.5D, henüz 3D arkaplanıyla eşleşmiyor.
- UI: ana NICE 3D button green; red color variant; diğer panel/ikonlar vektör tabanlı. Dinamik oyun text'i raster görsele gömülmedi.

### Bilinçli olarak dışarıda bırakılanlar
- Önceki AI kolajları / toplu görsel sprite sheet'leri.
- İçine bant ve yazı gömülmüş iPad referansları.
- Preview screenshots as gameplay sprite sources.
- Level Select & Level Complete (oyun arcade, levelli değil).

### Release blocker (P0 vs final)
P0 prototipte sanat uyumu eksikliği kabul; App Store final kalite kontrolünde aynı kostüm modeli, edge alpha fringing, küçük boyutta okunabilirlik, cihaz crop ve 60 FPS üzerinde FX maliyeti tekrar gözden geçirilmeli.
