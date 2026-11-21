# REBOX TV Translator — Free LG + iOS game captions

Developed in the existing REBOX repository, on a feature branch. The original Xbox Remote Play project on main remains untouched. No paid translation API, premium feature gate, advertisements, or subscriptions in this implementation.

## Implemented

- Live camera OCR: Apple Vision reads on-screen subtitles from the lower section of the TV, throttled to about 0.9 seconds with two matching frames required before translating.
- Apple Translation framework translates the recognized English to Arabic on the device; first-time model installation and availability are controlled by iOS.
- 120-entry in-memory translation cache; stable deduped text is sent to the LAN TV receiver.
- Manual typing, pasted text, screenshot OCR and test caption are also available.
- TV receiver uses port 8080 when free and automatically finds a new free port when occupied (NWError 48). iOS shows the actual local receiver URL.
- LG webOS browser page at /tv has an experimental HDMI 1–4 video source selector, caption positioning, colors and sizing. If embedded HDMI is not available, it falls back to a captions-only browser page.
- Separate LG webOS IPK and Android TV APK targets already exist but are not required for the browser experiment.
- GitHub Actions builds unsigned IPA that can be signed using user's existing iOS sideloading setup.

## Public research and source inspiration

The following open-source projects and documentation informed design decisions. Implementations here are independently written; no source code was copied from these projects.

- VI Translator LG webOS: https://github.com/vi-translator/vi-translator-webos-tv — compositing HDMI input with subtitles in a webOS application, MIT.
- webOS Homebrew documentation: https://github.com/webosbrew/pages — web app service/webos-external and ext://hdmi:1–4; partially works in stock TV browser.
- Universal Game Translator: https://github.com/lrq3000/pyugt — OCR + translation pipeline inspiration.
- Subtitle Translator: https://github.com/vshapovalov/subtitle-translator — stable OCR and translation caching design.
- LG PIP overlay experiment: https://github.com/ISDaddy/ha-lg-webos-pip — hardware-specific transparent app overlay, MIT.
- LG reticle overlay experiment: https://github.com/XerxeS2K1/webos-reticle — hardware-specific root/overlay limitations, MIT.

## Limitations

- This does NOT capture Xbox/PS HDMI pixels directly. Automatic mode currently requires pointing the iPhone/iPad rear camera at the television.
- No live game audio transcription. The live camera reads visible text only.
- Opening the browser while an HDMI input is selected normally replaces it. Embedding HDMI within the browser may be unsupported or partial on a given LG model. A successful build does not guarantee actual HDMI + subtitle composition on the TV.
- iOS camera and local HTTP receiver require the app in the foreground. Both devices need the same reachable Wi-Fi.
- Apple on-device translation languages differ by iOS/version; Arabic model support must be verified on the real device.

## Try from an iPhone without a computer

1. From GitHub Actions, download the latest REBOX-TV-unsigned-IPA artifact and sign it with your own ESign certificate.
2. Launch REBOX TV, grant Camera and Local Network permissions and wait for the live local URL.
3. Open the displayed /tv URL using the LG webOS system browser.
4. Select the Xbox HDMI port 1–4 experimentally, or choose caption-only if no picture appears.
5. Enable live camera mode in the iOS app and point the bottom camera view at the game's subtitles. Keep the app open.
6. If HDMI is black, note the exact LG model and webOS version and use caption-only browser mode to test the translation pipeline.

## Privacy and cost

Vision OCR and recognized frame analysis stay on the iOS device, and captions go over the local network only. No paid hosted backend. The local URL has no authentication and is intended for trusted home Wi-Fi only.