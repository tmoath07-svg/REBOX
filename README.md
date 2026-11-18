# REBOX

Native iPadOS Xbox Remote Play companion with an original neon-tropical visual identity.

## Direction
- Native SwiftUI iPad app; Xbox Series S is the first console target.
- DualShock 4 support through Apple's GameController framework.
- Original sunset pink/coral, cyan, violet, dark navy, tropical line-art, and restrained Xbox-green accents.
- No GTA artwork, Rockstar logos, game screenshots, or proprietary fonts are included.
- Streaming is a separate integration milestone. This starter does not claim to connect to or stream from Xbox yet.

## Build
Install XcodeGen, generate the Xcode project, then build for the simulator:
- brew install xcodegen
- xcodegen generate
- xcodebuild -project REBOX.xcodeproj -scheme REBOX -destination 'generic/platform=iOS Simulator' build

GitHub Actions runs this build on a macOS runner and uploads the simulator app.

## Signing
The default workflow creates an unsigned simulator build. A device-installable IPA needs a valid Apple signing identity and provisioning profile. Signing secrets can be configured later using your own Apple Developer credentials.

## Streaming engine research
Starfold is the leading candidate for evaluation because it is a native SwiftUI Apple-platform client and is MIT-licensed. Its current source, deployment target, dependencies, notices, and license obligations must be reviewed before integration.

## Disclaimer
REBOX is independent and is not affiliated with, endorsed by, or sponsored by Microsoft or Xbox. Xbox names and marks belong to their respective owners.
