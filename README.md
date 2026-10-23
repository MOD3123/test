# WebCenter pre iPadOS 15 (TrollStore)

Port Android appky na natívny UIKit projekt (iPad only, iOS/iPadOS 15.0+, bez podpisu).

## Ako získať .ipa

Potrebuješ macOS (Xcode 14.1+) – lokálne, alebo zadarmo cez GitHub Actions.

**A) GitHub Actions (bez Macu):**
1. Nahraj obsah tohto priečinka do nového GitHub repa (vetva `main`).
2. Záložka *Actions* → *Build IPA* → *Run workflow*.
3. Po dobehnutí stiahni artefakt `WebCenter-ipa` → `WebCenter.ipa`.

**B) Na Macu:** `brew install xcodegen && ./build_ipa.sh` → vznikne `WebCenter.ipa`.

## Inštalácia
Pošli `WebCenter.ipa` na iPad (AirDrop / Súbory), otvor cez TrollStore → *Install*.
Podpis netreba, TrollStore si ho rieši sám.

## Čo je preportované
- WebView shell: bočné menu (31 položiek), spodná lišta (5 položiek), späť/dopredu/obnoviť, zvýrazňovanie položky podľa URL
- Offline režim (overlay "Ste offline", offline menu, lokálne HTML v `Resources/assets`)
- QR / čiarový skener (AVFoundation) – kopírovať, otvoriť, Google, zdieľať
- Tesco skener cien – výber obchodu, token, cena, záloha, akcie/Clubcard
- Solitaire na celú obrazovku, svetlý/tmavý režim podľa systému
- Externé weby (mimo google.com / github.io / bing.com) sa otvárajú v Safari okne

## Rozdiely oproti Androidu
- Solitaire: bez CSS škálovania 0.67 a bez zamknutia na šírku (na tablete netreba)
- Mimo whitelistu sa v appke otvárajú aj odkazy v rámci rovnakej domény (napr. shmu.sk), nie len v Safari okne
- Tlačidlo "Zavrieť aplikáciu" používa `exit(0)`
- Ikony sú SF Symbols namiesto Android vektorov
