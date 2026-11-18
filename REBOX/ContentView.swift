import SwiftUI

private enum REBOXTab: String, CaseIterable {
    case home = "الرئيسية"
    case controller = "اليد"
    case network = "الشبكة"
    case settings = "الإعدادات"

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .controller: return "gamecontroller.fill"
        case .network: return "wifi"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var controller: ControllerManager
    @State private var selectedTab: REBOXTab = .home
    @State private var showConnectInfo = false

    var body: some View {
        ZStack {
            TropicalBackdrop()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        switch selectedTab {
                        case .home: homeContent
                        case .controller: controllerContent
                        case .network: networkContent
                        case .settings: settingsContent
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 920)
                    .frame(maxWidth: .infinity)
                }
                bottomNavigation
            }
        }
        .alert("الاتصال بالبث غير جاهز", isPresented: $showConnectInfo) {
            Button("تمام", role: .cancel) { }
        } message: {
            Text("واجهة REBOX ودعم يد التحكم قيد التجهيز. محرك Xbox Remote Play لم يُدمج أو يُختبر بعد.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(REBOXTheme.xbox)
                    Text("REBOX")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white)
                }
                Text("REMOTE PLAY • SERIES S")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(REBOXTheme.muted)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(controller.isConnected ? REBOXTheme.xbox : REBOXTheme.coral)
                    .frame(width: 7, height: 7)
                Text(controller.isConnected ? "CONTROLLER ON" : "STANDBY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(REBOXTheme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.06), in: Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: 968)
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR GAME.\nYOUR SPACE.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .tracking(-1.8)
                    .lineSpacing(-5)
                    .foregroundStyle(.white)
                Text("اللعب يبدأ من هنا.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(REBOXTheme.cyan)
            }
            .padding(.top, 8)

            consoleCard

            HStack(spacing: 12) {
                metricCard(title: "VIDEO", value: "1080P", note: "TARGET", symbol: "display")
                metricCard(title: "FRAME RATE", value: "60 FPS", note: "TARGET", symbol: "speedometer")
                metricCard(title: "INPUT", value: controller.isConnected ? "READY" : "WAIT", note: "DUALSHOCK", symbol: "gamecontroller")
            }

            VStack(alignment: .leading, spacing: 13) {
                sectionTitle("QUICK ACCESS", subtitle: "تحكم سريع")
                HStack(spacing: 12) {
                    quickTile(title: "Controller", subtitle: "إعدادات اليد", symbol: "gamecontroller.fill", tint: REBOXTheme.cyan) {
                        selectedTab = .controller
                    }
                    quickTile(title: "Network", subtitle: "حالة الشبكة", symbol: "wifi", tint: REBOXTheme.pink) {
                        selectedTab = .network
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill").foregroundStyle(REBOXTheme.cyan)
                Text("REBOX حاليًا في مرحلة تأسيس الواجهة ودعم اليد. الاتصال الفعلي بجهاز Xbox سيُضاف بعد دمج محرك البث واختباره.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(REBOXTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var consoleCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("XBOX SERIES S", systemImage: "xbox.logo")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(REBOXTheme.xbox)
                Spacer()
                Text("LOCAL CONSOLE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(REBOXTheme.muted)
            }

            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(colors: [Color(hex: 0x252B37), Color(hex: 0x11151E)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 116, height: 142)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.09), lineWidth: 1))
                    VStack(spacing: 9) {
                        Circle()
                            .fill(Color(hex: 0x252B37))
                            .frame(width: 74, height: 74)
                            .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
                            .overlay(Image(systemName: "xbox.logo").font(.system(size: 38, weight: .light)).foregroundStyle(REBOXTheme.xbox))
                        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.15)).frame(width: 52, height: 3)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("SERIES S")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Xbox home console")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(REBOXTheme.muted)
                    HStack(spacing: 6) {
                        Circle().fill(REBOXTheme.coral).frame(width: 7, height: 7)
                        Text("NOT CONNECTED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(REBOXTheme.coral)
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }

            Button { showConnectInfo = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                    Text("CONNECT TO XBOX").tracking(1.5)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: 0x071006))
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(REBOXTheme.xbox, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(hex: 0x1B2630), REBOXTheme.panel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(REBOXTheme.xbox.opacity(0.24), lineWidth: 1))
    }

    private var controllerContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("CONTROLLER", subtitle: "إدارة يد التحكم")
            HStack(spacing: 14) {
                Image(systemName: "gamecontroller.fill").font(.system(size: 32)).foregroundStyle(REBOXTheme.cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Text(controller.controllerName ?? "DUALSHOCK 4")
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(controller.isConnected ? "متصلة بالآيباد" : "اربط يد التحكم من إعدادات Bluetooth")
                        .font(.system(size: 12)).foregroundStyle(REBOXTheme.muted)
                }
                Spacer()
                Circle().fill(controller.isConnected ? REBOXTheme.xbox : REBOXTheme.coral).frame(width: 10, height: 10)
            }
            .padding(18)
            .background(REBOXTheme.panel, in: RoundedRectangle(cornerRadius: 20))

            HStack(spacing: 12) {
                stickCard(title: "LEFT STICK", x: controller.leftX, y: controller.leftY)
                stickCard(title: "RIGHT STICK", x: controller.rightX, y: controller.rightY)
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("TRIGGERS", subtitle: "المحفزات")
                triggerMeter(title: "L2", value: controller.leftTrigger, tint: REBOXTheme.cyan)
                triggerMeter(title: "R2", value: controller.rightTrigger, tint: REBOXTheme.pink)
            }

            Text(controller.lastInput)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(REBOXTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var networkContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("NETWORK", subtitle: "الشبكة والأداء")
            infoRow("Connection", value: "Not tested", symbol: "wifi")
            infoRow("Latency", value: "— ms", symbol: "timer")
            infoRow("Stream bitrate", value: "— Mbps", symbol: "chart.line.uptrend.xyaxis")
            infoRow("Resolution", value: "1080p target", symbol: "display")
            infoRow("Frame rate", value: "60 FPS target", symbol: "film")
            Text("قياسات الشبكة الفعلية ستظهر بعد تنفيذ الاتصال بمحرك البث.")
                .font(.system(size: 12)).foregroundStyle(REBOXTheme.muted)
                .padding(15).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("SETTINGS", subtitle: "إعدادات REBOX")
            infoRow("App version", value: "0.1.0", symbol: "app")
            infoRow("Platform", value: "Native iPadOS", symbol: "ipad")
            infoRow("Controller API", value: "GameController", symbol: "gamecontroller")
            infoRow("Streaming engine", value: "Not integrated", symbol: "waveform.path")
            Text("هوية REBOX أصلية: ألوان استوائية نيون مع لمسات Xbox الخضراء. لا تستخدم واجهة التطبيق صورًا أو شعارات GTA.")
                .font(.system(size: 12)).foregroundStyle(REBOXTheme.muted)
                .padding(15).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            ForEach(REBOXTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol).font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? REBOXTheme.cyan : REBOXTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .black, design: .rounded)).tracking(2).foregroundStyle(REBOXTheme.cyan)
            Text(subtitle).font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func metricCard(title: String, value: String, note: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(REBOXTheme.pink)
            Text(value).font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(note).font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(REBOXTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(REBOXTheme.panel, in: RoundedRectangle(cornerRadius: 17))
    }

    private func quickTile(title: String, subtitle: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 42, height: 42).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(REBOXTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(REBOXTheme.muted)
            }
            .padding(13).background(REBOXTheme.panel, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }

    private func stickCard(title: String, x: Double, y: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 10, weight: .black, design: .rounded)).tracking(1).foregroundStyle(REBOXTheme.muted)
            GeometryReader { proxy in
                ZStack {
                    Circle().stroke(.white.opacity(0.15), lineWidth: 1)
                    Path { path in
                        path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                        path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
                        path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                    }.stroke(.white.opacity(0.12), lineWidth: 1)
                    Circle().fill(REBOXTheme.cyan).frame(width: 15, height: 15)
                        .offset(x: CGFloat(x) * proxy.size.width * 0.38, y: CGFloat(-y) * proxy.size.height * 0.38)
                }
            }
            .frame(height: 100)
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(REBOXTheme.panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func triggerMeter(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.white)
                Spacer()
                Text("\(Int(value * 100))%").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(REBOXTheme.muted)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(tint).frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 7)
        }
    }

    private func infoRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(REBOXTheme.cyan)
                .frame(width: 38, height: 38).background(REBOXTheme.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(REBOXTheme.muted)
        }
        .padding(13).background(REBOXTheme.panel, in: RoundedRectangle(cornerRadius: 15))
    }
}
