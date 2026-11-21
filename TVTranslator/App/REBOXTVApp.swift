import SwiftUI
import Translation
import PhotosUI
import Vision
import UIKit

@main
struct REBOXTVApp: App {
    var body: some Scene {
        WindowGroup {
            TVTranslatorView().preferredColorScheme(.dark)
        }
    }
}

struct TVTranslatorView: View {
    @StateObject private var bridge = SubtitleBridge()
    @StateObject private var camera = GameCameraScanner()
    @State private var liveCameraEnabled = false
    @State private var translationCache: [String: String] = [:]
    @State private var input = ""
    @State private var requested = ""
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var selectedImage: PhotosPickerItem?
    @State private var page = 0
    @State private var selectedConsole = "Xbox"
    @State private var ocrRegion = CGRect(x: 0.14, y: 0.73, width: 0.72, height: 0.18)
    @State private var cameraZoom = 1.0
    @State private var cropIsEditable = true

    private let accent = Color(red: 0.38, green: 0.82, blue: 1)
    private let surface = Color(red: 0.10, green: 0.12, blue: 0.18)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("REBOX TV Translator", systemImage: "tv")
                        .font(.title2.bold()).foregroundStyle(accent)
                    Text("ترجمة مجانية على التلفزيون والجوال")
                        .foregroundStyle(.secondary)

                    consoleSelector

                    HStack(spacing: 8) {
                        Label("English", systemImage: "character.book.closed")
                        Image(systemName: "arrow.left").font(.caption)
                        Label("العربية", systemImage: "character.bubble")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(surface, in: RoundedRectangle(cornerRadius: 13))

                    Picker("مكان الترجمة", selection: $page) {
                        Text("التلفزيون").tag(0)
                        Text("الجوال").tag(1)
                    }.pickerStyle(.segmented)

                    if page == 0 {
                        card("اتصال التلفزيون") {
                            Label(bridge.serverStatus, systemImage: "wifi").foregroundStyle(accent)
                            Text("افتح هذا الرابط بمتصفح التلفزيون على نفس الواي فاي")
                                .font(.subheadline)
                            Text(bridge.tvURL)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Button("نسخ رابط التلفزيون") {
                                guard bridge.canShareURL else { return }
                                UIPasteboard.general.string = bridge.tvURL
                            }
                            .disabled(!bridge.canShareURL)
                            Text("إذا تغير رقم المنفذ، افتح الرابط الجديد في متصفح LG. خل التطبيق مفتوح وعلى نفس الشبكة.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("التحكم بمدخل HDMI من الجوال")
                                .font(.subheadline.bold())
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(0..<5, id: \.self) { port in
                                        Button(port == 0 ? "ترجمة فقط" : "HDMI \(port)") {
                                            bridge.hdmiInput = port
                                        }
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 11).padding(.vertical, 10)
                                        .background(bridge.hdmiInput == port ? accent : Color.white.opacity(0.12),
                                                    in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(bridge.hdmiInput == port ? Color.black : Color.white)
                                    }
                                }
                            }
                            Toggle("إظهار قائمة HDMI على شاشة LG", isOn: $bridge.showTVControls)
                                .tint(accent)
                            Toggle("عرض الترجمة على LG", isOn: $bridge.subtitleVisible)
                                .tint(accent)
                            Text("إخفاء قائمة الصفحة لا يخفي شريط عنوان متصفح LG. زر ملء الشاشة التجريبي موجود في صفحة التلفزيون.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("صفحة المتصفح وحدها لا تظهر فوق HDMI إلا لو التلفزيون يدعم العرض المتراكب.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    card("ترجمة مباشرة بدون نسخ ولصق") {
                        Toggle("قراءة نص اللعبة بالكاميرا تلقائيًا", isOn: $liveCameraEnabled)
                            .tint(accent)
                        if liveCameraEnabled {
                            ZStack {
                                GameCameraPreview(scanner: camera)
                                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                    .background(Color.black)
                                if cropIsEditable {
                                    OCRCropEditor(region: $ocrRegion)
                                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                }
                            }
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            HStack {
                                Button(cropIsEditable ? "إنهاء تحديد OCR" : "تعديل مربع OCR") {
                                    cropIsEditable.toggle()
                                }
                                Spacer()
                                Button("ضبط على النص أسفل الشاشة") {
                                    ocrRegion = CGRect(x: 0.14, y: 0.73, width: 0.72, height: 0.18)
                                }
                            }
                            .font(.caption).foregroundStyle(accent)
                            slider("تكبير الكاميرا", $cameraZoom, 1...4, "×")
                            slider("عرض المربع", Binding(
                                get: { Double(ocrRegion.width) },
                                set: { newWidth in
                                    let width = CGFloat(newWidth)
                                    ocrRegion.size.width = width
                                    ocrRegion.origin.x = min(ocrRegion.origin.x, 1 - width)
                                }), 0.14...1.0, "")
                            slider("ارتفاع المربع", Binding(
                                get: { Double(ocrRegion.height) },
                                set: { newHeight in
                                    let height = CGFloat(newHeight)
                                    ocrRegion.size.height = height
                                    ocrRegion.origin.y = min(ocrRegion.origin.y, 1 - height)
                                }), 0.07...0.75, "")
                            Text("اسحب المربع الأزرق أو زواياه الأربع لتحديد النص المطلوب، مثل الصورة اللي أرسلتها.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(camera.info).font(.caption).foregroundStyle(.secondary)
                            Button("إيقاف القراءة وإخفاء آخر ترجمة") {
                                liveCameraEnabled = false
                                bridge.subtitle = ""
                            }.font(.caption).foregroundStyle(accent)
                        }
                        Text("تستخدم كاميرا الجهاز وApple Vision للقراءة وApple Translation للترجمة. لا يحتاج اشتراكًا أو مفتاح API. خلك فاتح التطبيق؛ ما يقدر يقرأ HDMI من دون كاميرا أو بث.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    card("الترجمة اليدوية والصور") {
                        TextEditor(text: $input)
                            .scrollContentBackground(.hidden)
                            .frame(height: 110)
                            .padding(8)
                            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
                        HStack {
                            Button("لصق") { input = UIPasteboard.general.string ?? "" }
                            Spacer()
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                Label("استخراج من صورة", systemImage: "photo")
                            }
                        }.foregroundStyle(accent)
                        Button {
                            translateInput()
                        } label: {
                            Label("ترجمة وإرسال", systemImage: "character.bubble")
                                .frame(maxWidth: .infinity).padding(8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent).foregroundStyle(.black)
                        HStack {
                            Button("إرسال النص بدون ترجمة") { bridge.subtitle = input }
                            Spacer()
                            Button("مسح") { bridge.subtitle = "" }
                        }.font(.caption)
                    }

                    card("معاينة") {
                        Text(bridge.subtitle.isEmpty ? "الترجمة تظهر هنا" : bridge.subtitle)
                            .font(.system(size: CGFloat(bridge.fontSize), weight: .bold))
                            .foregroundStyle(Color(rgb: bridge.textColor))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(Color(rgb: bridge.boxColor).opacity(bridge.boxOpacity), in: RoundedRectangle(cornerRadius: 12))
                        Text(bridge.message).font(.caption).foregroundStyle(.secondary)
                    }

                    if page == 0 {
                        card("خيارات شاشة التلفزيون") {
                            slider("الموضع العمودي", $bridge.position, 0...90, "%")
                            slider("حجم الخط", $bridge.fontSize, 16...52, " pt")
                            slider("عتامة الخلفية", $bridge.boxOpacity, 0...1, "")
                            Text("لون الترجمة")
                            swatches($bridge.textColor, ["#FFFFFF", "#55D6FF", "#FFE600", "#00F17C", "#FF981B"])
                            Text("لون الخلفية")
                            swatches($bridge.boxColor, ["#101C2A", "#000000", "#281639", "#0D3726", "#34475A"])
                            Button("إرسال ترجمة تجريبية") {
                                bridge.subtitle = "هذه ترجمة تجريبية من REBOX TV"
                            }.foregroundStyle(accent)
                        }
                    }
                    Text("إصدار مجاني تجريبي: استخراج آلي من كاميرا الجوال، ترجمة محلية، وإرسال ترجمات لمتصفح LG. عرض HDMI داخل المتصفح يعتمد على موديل التلفزيون ولا يضمن النجاح.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.bottom, 18)
                }.padding(16)
            }
            .background(Color(red: 0.035, green: 0.045, blue: 0.07))
            .navigationTitle("REBOX TV")
            .navigationBarTitleDisplayMode(.inline)
        }
        .translationTask(translationConfiguration) { session in
            let text = requested
            guard !text.isEmpty else { return }
            do {
                let answer = try await session.translate(text)
                await MainActor.run {
                    guard requested == text else { return }
                    bridge.subtitle = answer.targetText
                    translationCache[text] = answer.targetText
                    if translationCache.count > 120 {
                        translationCache.removeAll()
                        translationCache[text] = answer.targetText
                    }
                    bridge.message = "تمت الترجمة والإرسال"
                }
            } catch {
                await MainActor.run { bridge.message = "تعذرت الترجمة: \(error.localizedDescription)" }
            }
        }
        .onAppear {
            camera.setRegion(ocrRegion)
            camera.setZoom(cameraZoom)
            camera.onStableText = { text in
                guard liveCameraEnabled else { return }
                input = text
                translateInput()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: ocrRegion) { _, next in
            camera.setRegion(next)
        }
        .onChange(of: cameraZoom) { _, next in
            camera.setZoom(next)
        }
        .onChange(of: liveCameraEnabled) { _, enabled in
            if enabled { camera.start() }
            else { camera.stop() }
        }
        .onChange(of: selectedImage) { _, photo in
            guard let photo else { return }
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self) {
                    scanImage(data)
                }
            }
        }
    }

    private var consoleSelector: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("وضع الكونسول", systemImage: "gamecontroller.fill")
                .font(.title3.bold())
            HStack(spacing: 10) {
                ForEach(["Xbox", "PlayStation"], id: \.self) { system in
                    Button {
                        selectedConsole = system
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: system == "Xbox" ? "gamecontroller.fill" : "gamecontroller")
                                .font(.title)
                            Text(system).font(.headline)
                            Text(system == "Xbox" ? "Series X / S" : "PS4 / PS5")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .background(selectedConsole == system
                                    ? (system == "Xbox" ? Color.green.opacity(0.24) : Color.blue.opacity(0.24))
                                    : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(selectedConsole == system ? accent : .clear, lineWidth: 2)
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("الاختيار يضبط واجهة الترجمة فقط؛ اتصال البث المباشر بالكونسول مو مفعّل في هذه النسخة. الترجمة التلقائية حاليًا من كاميرا الجوال.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ suffix: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(suffix.isEmpty ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue))\(suffix)")
                    .foregroundStyle(accent)
            }.font(.subheadline)
            Slider(value: value, in: range).tint(accent)
        }
    }

    private func swatches(_ selected: Binding<String>, _ choices: [String]) -> some View {
        HStack {
            ForEach(choices, id: \.self) { hex in
                Button {
                    selected.wrappedValue = hex
                } label: {
                    Circle().fill(Color(rgb: hex)).frame(width: 35, height: 35)
                        .padding(4)
                        .overlay(Circle().stroke(selected.wrappedValue == hex ? accent : .clear, lineWidth: 3))
                }.buttonStyle(.plain)
            }
        }
    }

    private func translateInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { bridge.message = "اكتب النص أولًا"; return }
        requested = text
        if let cached = translationCache[text] {
            bridge.subtitle = cached
            bridge.message = "تم استخدام ترجمة محفوظة محليًا"
            return
        }
        bridge.message = "جاري استخدام ترجمة Apple"
        if translationConfiguration == nil {
            translationConfiguration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "ar")
            )
        } else {
            translationConfiguration?.invalidate()
        }
    }

    private func scanImage(_ data: Data) {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            bridge.message = "تعذر قراءة الصورة"; return
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            input = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            bridge.message = input.isEmpty ? "ما فيه نص واضح بالصورة" : "تم استخراج النص"
        } catch {
            bridge.message = "تعذر استخراج النص: \(error.localizedDescription)"
        }
    }
}

extension Color {
    init(rgb hex: String) {
        let value = Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255,
                  opacity: 1)
    }
}
