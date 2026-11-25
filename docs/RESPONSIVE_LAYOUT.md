# Responsive Layout — iPhone & iPad

## Temel prensip
- Gameplay sabit normalize edilmiş orta alan; arka plan ekranı örter, tüm interaktif elemanlar `SafeArea` altında. Görselleri stretch etme; `BoxFit.cover` arka planda, `BoxFit.contain` sprite ve panellerde.
- Referanslar ve tasarım ölçüleri başlangıç noktasıdır; pixel-perfect durum gerçek cihazda test edilir.
- iPhone portrait: 390×844 mantıksal px referansı. Üst safe area altında HUD (sol score, orta timer, sağ combo); gift odak konumu ~genişliğin %50'si ve safe height %51–59; conveyor ~%63–73; `SHIP` solda, `REJECT` sağda alt safe alan üzerinde büyük hit zone.
- iPad landscape: arena maks 780–860 logical px genişlikte ortada; HUD arena tepesinde; iki buton alt merkezde, aralarında yeterli mesafe. Yeni `factory_ipad_landscape.png` bağımsız opak sahnedir (konveyör gömülü değildir), sahnenin yan tarafı dekoratif nefes alanı.
- iPad portrait: ayrı foto-gerçekçi arka plan henüz yok. Şimdilik `factory_iphone_portrait.png` focal-center `cover` ile. Gerektiğinde yan parallax dekor veya letterbox; zorunlu tek bir görseli stretch ederek bozmamalı.
- Dikey uzun cihazda HUD ve butonlar safe-edge mesafelerinin dışına düşmemeli; iPad arka planı 4:3, iPhone portrait 852×1846.

## Layer order
1. Opaque background.
2. Background decorations (wreath, boiler etc; optional).
3. Conveyor scroll tile **clipped** into conveyor area.
4. Conveyor frame fixed (tile'ın üzerinde).
5. Active gift sprite (conveyor üstünde).
6. Elf and good/bad response FX.
7. Flutter overlay HUD and two tactile buttons.
8. Pause/menu/results overlays. Don't put dynamic text inside PNG assets.

## UI assets
Overlay the English labels `SHIP` and `REJECT` and the check/cross icons on `assets/ui/buttons/btn_nice_3d_blank.png` and `btn_naughty_3d_blank.png`. `assets/ui/hud/*_blank.png` dynamic score, time, combo. `assets/ui/panels/panel_results_blank.png` results copy, accuracy, buttons. `docs/previews` are NEVER sprites.

## Hitbox
Minimum accessibility target 44 pt, recommend 120+ logical px decision zones. Swipe on gift or arena must not start scroll navigation. A tap into a positive or negative zone dispatches a typed game action; do not duplicate the sorting logic.
