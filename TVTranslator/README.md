# REBOX FREE — Console Stream Translator (no camera)

Project stays inside the existing REBOX GitHub repository. The user's no-camera preference is enforced: no camera permission in REBOX TV, and camera OCR files were deleted from the app.

## No-camera architecture

- REBOX's **existing native Xbox Remote Play** uses the MIT-licensed Starfold streaming engine.
- On a game stream, `REBOXStreamTranslator` reads a throttled frame from Starfold's `StreamRenderer.lastFrameImage()` (with a 1280-pixel OCR frame cap set by the local build patch). It runs Apple Vision OCR on the console video decoded inside the app, with a crop selector and 2-frame stabilization.
- The same view uses Apple's on-device Translation framework (default English to Arabic) and forwards results over the built-in local TV HTTP subtitle server to the `/tv` browser page on LG webOS.
- Supports selecting German→English and several other source/target language pairs.
- No Xbox stream = no live automatic OCR. Xbox Remote Play pairing, connection and frame delivery are necessary. **PlayStation Remote Play direct video has not been integrated**.
- This work is still experimental until the Xbox build and an actual console/LG test pass.

## Missing translation languages

- In both REBOX TV sender and the new Xbox stream overlay, tap **تجهيز / تنزيل لغات الترجمة مجانًا** to use `TranslationSession.prepareTranslation()`; iOS will ask for permission to download the selected models (free).
- You can instead manage downloaded languages at Settings > Apps > Translate > Languages or Downloaded Languages (wording depends on iOS).
- A language pair may be unsupported on some OS models; the app should show the error rather than claim success. First download may require Internet connectivity and local storage.
- Selecting English→Arabic by default prevents a stale German→English label when English→Arabic was actually requested.

## LG browser

From the REBOX stream overlay, copy the displayed local `http://PHONE_IP:PORT/tv` link and open it on LG's system web browser. Use same Wi-Fi and keep REBOX foregrounded. The local server detects a port already in use and attempts a free port automatically.

HDMI embedded in a stock LG browser is experimental and not guaranteed: the browser may show a black HDMI video region or hide the TV input. There is a captions-only fallback mode. The LG IPK is an optional alternative for supported LG models, not a browser-only solution.

## Cost/privacy

All source code is in the same repository. No subscriptions, paid API keys or in-app purchases were added. Xbox frames are processed with Vision locally and are not uploaded. Translated text stays on your home LAN to the LG receiver.

## GitHub builds

- `REBOX iPadOS Build`: builds the original REBOX Xbox Remote Play app with the no-camera direct-frame translator after the Starfold build patch.
- `Build REBOX TV Translator`: optional separate existing REBOX TV sender app, now without camera and with in-app translation model preparation.
- Both workflows create unsigned IPA artifacts for signing with ESign.

References: https://developer.apple.com/documentation/translation/translationsession/preparetranslation() and https://github.com/JarvanSun/Starfold

### Status
See GitHub Actions. Compiling an IPA does not prove Xbox connection, Live OCR on screen, or HDMI overlay on real LG hardware.