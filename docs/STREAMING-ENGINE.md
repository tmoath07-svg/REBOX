# Streaming engine decision

## First candidate
Starfold is the first candidate to evaluate for the Xbox Remote Play engine. Its public project description identifies it as a native SwiftUI Apple-platform client and its repository is MIT-licensed.

Repository: https://github.com/JarvanSun/Starfold

## Required checks before integration
1. Inspect the actual source tree and current license text.
2. Confirm iPadOS deployment target and Xcode requirements.
3. Review sign-in, token storage, console discovery, session negotiation, WebRTC, audio, video, and controller-input modules.
4. Review all third-party notices and package licenses.
5. Confirm modules can be integrated without copying app-specific branding or unrelated UI.
6. Build and run a test session against an Xbox Series S before enabling Connect.

## Why it is not wired in yet
A project description is not proof that its source can be embedded as a library. REBOX keeps a small StreamingEngine boundary so the UI does not pretend to connect before a real engine is integrated and tested.

## Branding
REBOX uses an original neon-tropical visual language: sunset pink/coral, cyan, violet, dark navy, tropical palm-line artwork, and restrained Xbox-green accents. Do not copy Grand Theft Auto VI artwork, Rockstar logos, game screenshots, or proprietary fonts. Xbox marks belong to Microsoft; REBOX is independent and must not imply endorsement.
