import SwiftUI

enum REBOXTheme {
    static let ink = Color(hex: 0x090B13)
    static let panel = Color(hex: 0x151827)
    static let pink = Color(hex: 0xFF4F9A)
    static let coral = Color(hex: 0xFF8A72)
    static let cyan = Color(hex: 0x51E5E5)
    static let violet = Color(hex: 0x9B78FF)
    static let xbox = Color(hex: 0x75C943)
    static let muted = Color(hex: 0xA5ABC0)

    static let sunset = LinearGradient(
        colors: [pink, coral, Color(hex: 0xFFC078)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct TropicalBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                REBOXTheme.ink
                Circle()
                    .fill(REBOXTheme.sunset)
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 1)
                    .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.38)
                    .opacity(0.20)
                Circle()
                    .stroke(REBOXTheme.cyan.opacity(0.15), lineWidth: 1)
                    .frame(width: proxy.size.width * 0.9)
                    .offset(x: proxy.size.width * 0.44, y: -proxy.size.height * 0.28)
                PalmFrond()
                    .stroke(REBOXTheme.cyan.opacity(0.10), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 170, height: 210)
                    .rotationEffect(.degrees(-12))
                    .offset(x: proxy.size.width * 0.40, y: proxy.size.height * 0.30)
            }
            .ignoresSafeArea()
        }
    }
}

nonisolated struct PalmFrond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stem = CGPoint(x: rect.width * 0.45, y: rect.height * 0.92)
        let crown = CGPoint(x: rect.width * 0.56, y: rect.height * 0.24)
        path.move(to: stem)
        path.addQuadCurve(to: crown, control: CGPoint(x: rect.width * 0.25, y: rect.height * 0.55))
        let tips: [(CGFloat, CGFloat)] = [(0.05, 0.10), (0.18, 0.02), (0.35, 0.00), (0.72, 0.02), (0.92, 0.12), (1.00, 0.28)]
        for (x, y) in tips {
            path.move(to: crown)
            path.addQuadCurve(
                to: CGPoint(x: rect.width * x, y: rect.height * y),
                control: CGPoint(x: rect.width * (0.48 + x) / 2, y: rect.height * (0.05 + y) / 2)
            )
        }
        return path
    }
}
