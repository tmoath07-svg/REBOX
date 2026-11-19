#!/usr/bin/env python3
"""Apply the REBOX-specific WebRTC startup fix to the pinned Starfold submodule."""
from pathlib import Path

root = Path("StarfoldVendor/Packages/StreamKit/Sources/StreamKit")
peer = root / "Connection/PeerConnection.swift"
event = root / "Connection/PeerEvent.swift"
controller = root / "Session/StreamController.swift"

def replace_once(path: Path, old: str, new: str) -> None:
    source = path.read_text()
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one patch location in {path}, found {count}")
    path.write_text(source.replace(old, new, 1))

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

        // Xbox hosts may deliver the audio receiver later than video. Request the
        // first keyframe as soon as video is attached instead of waiting for audio.
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

print("Applied video-first keyframe startup patch.")
