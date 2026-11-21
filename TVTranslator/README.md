# REBOX TV Translator (free MVP)

A standalone new iOS app inside the REBOX repository. The original Xbox Remote Play files and workflow are untouched.

## Implemented
- Native SwiftUI interface for iPhone and iPad.
- English-to-Arabic text translation through Apple Translation framework, subject to device language support and initial language model download.
- Manual input, explicit clipboard paste, and OCR from a selected game screenshot using Vision.
- Local HTTP receiver hosted on port 8080. A TV on the same Wi-Fi opens the device's /tv URL to see the subtitle text.
- Styling options: vertical position, subtitle size, text color, box color and opacity.
- A demo subtitle button, no in-app purchases, subscriptions, or time limits.
- Workflow produces unsigned REBOX-TV-unsigned.ipa as an artifact.

## Limitations
The TV browser page does not itself provide an overlay over live HDMI. On most TVs opening the browser switches away from the HDMI picture. True HDMI overlay depends on a TV-specific overlay-capable receiver or platform features. This MVP does not control TV HDMI input, automatically read console game frames, or connect to console streams. Do not confuse it with a complete clone of Side Screen or its proprietary GuleryuzTV app.

## Test without a computer
- Trigger the Build REBOX TV Translator workflow or use the automatic PR build.
- Download the IPA from Actions artifacts and sign it using your own ESign/Sideloading setup.
- Keep the iPhone/iPad app open and on the same Wi-Fi as the TV.
- Open the displayed http://DEVICE_IP:8080/tv URL on the TV browser, press the demo subtitle button.
- Paste English text or select a screenshot, translate, and send to the TV receiver.

Project generated using XcodeGen from TVTranslator/project.yml. Bundle ID: com.tmoath07.reboxtv.
