#!/usr/bin/env python3
"""Apply REBOX-specific streaming lifecycle fixes to the pinned Starfold submodule."""
from pathlib import Path

root = Path("StarfoldVendor/Packages/StreamKit/Sources/StreamKit")
peer = root / "Connection/PeerConnection.swift"
event = root / "Connection/PeerEvent.swift"
controller = root / "Session/StreamController.swift"
audio = root / "Audio/StereoAudioDevice.swift"
view_model = Path(
    "StarfoldVendor/Packages/StarfoldShared/Sources/StarfoldShared/Features/Stream/StreamViewModel.swift"
)


def replace_once(path: Path, old: str, new: str) -> None:
    source = path.read_text()
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one patch location in {path}, found {count}")
    path.write_text(source.replace(old, new, 1))


# Request the first video keyframe as soon as the video receiver is attached.
replace_once(
    event,
    "    case channelClosed(DataChannelLabel)\n    case mediaTracksReady\n",
    "    case channelClosed(DataChannelLabel)\n    case videoTrackReady\n    case mediaTracksReady\n",
)

replace_once(
    peer,
    """    fileprivate func handleReceiver(_ receiver: LKRTCRtpReceiver) {
        let hasBothTracks = lock.withLock {
            switch receiver.track {
            case let track as LKRTCVideoTrack:
                videoTrack = track
                track.add(frameReceiver)
                hasVideo = true
            case is LKRTCAudioTrack:
                hasAudio = true
            default:
                break
            }

            return hasAudio && hasVideo
        }

        if hasBothTracks {
            events(.mediaTracksReady)
        }
    }
""",
    """    fileprivate func handleReceiver(_ receiver: LKRTCRtpReceiver) {
        let (videoTrackAdded, hasBothTracks) = lock.withLock {
            var videoTrackAdded = false
            switch receiver.track {
            case let track as LKRTCVideoTrack:
                videoTrack = track
                track.add(frameReceiver)
                hasVideo = true
                videoTrackAdded = true
            case is LKRTCAudioTrack:
                hasAudio = true
            default:
                break
            }

            return (videoTrackAdded, hasAudio && hasVideo)
        }

        // Xbox hosts may deliver audio after video. Do not wait for audio to request
        // the first keyframe.
        if videoTrackAdded {
            events(.videoTrackReady)
        }
        if hasBothTracks {
            events(.mediaTracksReady)
        }
    }
""",
)

replace_once(
    controller,
    """        case .mediaTracksReady:
            mark("media tracks ready")
            requestKeyframe()
""",
    """        case .videoTrackReady:
            mark("video track ready")
            requestKeyframe()
        case .mediaTracksReady:
            mark("audio and video tracks ready")
""",
)

# Starfold deliberately mutes its audio mixer while backgrounded. REBOX opts into
# iOS background audio and must keep the remote-play audio audible after screen lock.
replace_once(
    audio,
    """    private func volume(isInBackground: Bool) -> Float {
        isInBackground ? 0 : 1
    }
""",
    """    private func volume(isInBackground: Bool) -> Float {
        // Background audio is an explicit REBOX streaming mode.
        1
    }
""",
)
replace_once(
    audio,
    """        log.info(
            "Audio \\(isInBackground ? "muted in the background" : "unmuted", privacy: .public)"
        )
""",
    """        log.info(
            "Audio background state changed; background playback remains enabled"
        )
""",
)

# Keep the gamepad input route open while the app is backgrounded. iOS may still
# restrict delivery of physical controller events while locked.
replace_once(
    view_model,
    """    public var isRoutingInputToGame: Bool {
        isPlayable && !isMenuOpen && isInForeground
    }
""",
    """    public var isRoutingInputToGame: Bool {
        isPlayable && !isMenuOpen
    }
""",
)

# Keep the iPhone/iPad awake for the duration of a stream. This is the supported
# way to keep GameController input live while the user watches on the console;
# manually locking the device still allows iOS to suspend the app.
stream_view = Path("StarfoldVendor/StarfoldiOS/Features/Stream/StreamView.swift")
replace_once(
    stream_view,
    "import SwiftUI\n",
    "import SwiftUI\nimport UIKit\n",
)
replace_once(
    stream_view,
    "        .onAppear { appear() }\n",
    """        .onAppear { appear() }
        .onChange(of: streamViewModel.isStreaming, initial: true) { _, isStreaming in
            UIApplication.shared.isIdleTimerDisabled = isStreaming
        }
""",
)
replace_once(
    stream_view,
    "        .onDisappear { controllerHub.routeInput(toGame: false) }\n",
    """        .onDisappear {
            controllerHub.routeInput(toGame: false)
            UIApplication.shared.isIdleTimerDisabled = false
        }
""",
)

# Bound every Xbox GSSV HTTP request so a stalled request cannot leave the UI
# indefinitely showing "Connecting". Polling loops retain their own overall deadlines.
gssv_client = Path("StarfoldVendor/Packages/XboxKit/Sources/XboxKit/Streaming/GSSVClient.swift")
replace_once(
    gssv_client,
    """            let response = try await httpClient.send(
                .init(url: url, method: method, headers: headers, body: body)
            )
""",
    """            let response = try await httpClient.send(
                .init(
                    url: url,
                    method: method,
                    headers: headers,
                    body: body,
                    timeout: .seconds(20)
                )
            )
""",
)

print("Applied REBOX video-startup, background audio, input-routing, and keep-awake patches.")

