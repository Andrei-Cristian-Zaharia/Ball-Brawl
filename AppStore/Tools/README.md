# App Store art

The product page header, search result image and framed screenshots are rendered by the app itself
(debug builds only), so the balls and UI always match the game.

1. **Simulators**: an iPhone 17 Pro Max and an iPad Pro 13" (M5). Pin the status bar:
   `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`.
   Answer the tracking prompt once (or it covers every capture).
2. **Install** a Debug build on both.
3. **Capture** the 6 demo screens per language (`-storeDemo <scene>` opens them on a showcase profile that is never saved):
   `./capture.sh <udid> ja ja_JP raw/ja/phone` (and `raw/<lang>/pad` on the iPad).
   The search result image needs `raw/<lang>/pad/abilities.png` for every language.
4. **Render**: `./make_jobs.py raw out jobs`, then for each language
   `xcrun simctl launch --console-pty <udid> com.andreizaharia.ballbrawl -storeArt jobs/job_<lang>.json`.
5. **Shrink** to 8-bit PNGs: `swiftc -O to8.swift -o to8 && find out -name '*.png' -print0 | xargs -0 ./to8`.

Headline texts are in `marketing/<lang>.json`; languages without `shots` only get the header and search images.
