import SwiftUI

/// Draggable/resizable crop selector. Coordinates are normalized to the camera preview.
struct OCRCropEditor: View {
    @Binding var region: CGRect
    @State private var dragOrigin: CGRect?

    private let minimumWidth: CGFloat = 0.12
    private let minimumHeight: CGFloat = 0.07
    private let cyan = Color(red: 0.36, green: 0.87, blue: 1.0)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                Color.clear

                RoundedRectangle(cornerRadius: 9)
                    .fill(cyan.opacity(0.13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(cyan, lineWidth: 2.5)
                    }
                    .overlay(alignment: .top) {
                        Text("OCR")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(cyan, in: Capsule())
                            .offset(y: -13)
                    }
                    .frame(width: size.width * region.width,
                           height: size.height * region.height)
                    .position(x: size.width * region.midX, y: size.height * region.midY)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragOrigin == nil { dragOrigin = region }
                            guard let start = dragOrigin else { return }
                            region.origin.x = clamp(start.origin.x + value.translation.width / max(1, size.width),
                                                    0, 1 - region.width)
                            region.origin.y = clamp(start.origin.y + value.translation.height / max(1, size.height),
                                                    0, 1 - region.height)
                        }
                        .onEnded { _ in dragOrigin = nil })

                ForEach(0..<4, id: \.self) { corner in
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(cyan, lineWidth: 2))
                        .position(position(for: corner, in: size))
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragOrigin == nil { dragOrigin = region }
                                guard let start = dragOrigin else { return }
                                let dx = value.translation.width / max(1, size.width)
                                let dy = value.translation.height / max(1, size.height)
                                region = resized(start, corner: corner, dx: dx, dy: dy)
                            }
                            .onEnded { _ in dragOrigin = nil })
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("مربع تحديد المنطقة المترجمة")
        }
    }

    private func position(for corner: Int, in size: CGSize) -> CGPoint {
        let x = corner == 0 || corner == 2 ? region.minX : region.maxX
        let y = corner == 0 || corner == 1 ? region.minY : region.maxY
        return CGPoint(x: x * size.width, y: y * size.height)
    }

    private func resized(_ start: CGRect, corner: Int, dx: CGFloat, dy: CGFloat) -> CGRect {
        var minX = start.minX
        var minY = start.minY
        var maxX = start.maxX
        var maxY = start.maxY
        if corner == 0 || corner == 2 {
            minX = clamp(start.minX + dx, 0, maxX - minimumWidth)
        } else {
            maxX = clamp(start.maxX + dx, minX + minimumWidth, 1)
        }
        if corner == 0 || corner == 1 {
            minY = clamp(start.minY + dy, 0, maxY - minimumHeight)
        } else {
            maxY = clamp(start.maxY + dy, minY + minimumHeight, 1)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func clamp(_ n: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(n, lower), upper)
    }
}
