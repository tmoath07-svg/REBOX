#!/usr/bin/env python3
"""Enable REBOX frame OCR on the existing Starfold Xbox Remote Play screen.

Changes only the checked-out build copy of the pinned MIT-licensed submodule.
The REBOX source is kept in our own application target.
"""
from pathlib import Path

stream_view = Path("StarfoldVendor/StarfoldiOS/Features/Stream/StreamView.swift")
renderer = Path("StarfoldVendor/Packages/StreamKit/Sources/StreamKit/Rendering/StreamRenderer.swift")

source = stream_view.read_text()
needle = """            StreamPicture(
                renderer: streamViewModel.renderer,
                isVisible: streamViewModel.hasFirstFrame
            )
"""
addition = needle + """
            // REBOX addition: OCR from the native Remote Play renderer, never the camera.
            REBOXStreamTranslator(renderer: streamViewModel.renderer)
"""
if "REBOXStreamTranslator(renderer:" not in source:
    if source.count(needle) != 1:
        raise SystemExit("Cannot locate unique StreamPicture anchor in pinned Starfold")
    stream_view.write_text(source.replace(needle, addition, 1))

# lastFrameImage() exists upstream; preserve enough pixels for small game captions.
source = renderer.read_text()
needle = "let lastFrameMaximumWidth: CGFloat = 640"
replacement = "let lastFrameMaximumWidth: CGFloat = 1280"
if replacement not in source:
    if source.count(needle) != 1:
        raise SystemExit("Pinned StreamRenderer lastFrameImage API changed")
    renderer.write_text(source.replace(needle, replacement, 1))

print("REBOX direct Xbox frame OCR enabled (no camera, local renderer, 1280px OCR frames)")
