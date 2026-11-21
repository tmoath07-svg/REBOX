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
    @State private var translationCache: [String: String] = [:]
    @State private var input = ""
    @State private var requested = ""
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var selectedImage: PhotosPickerItem?
    @State private var page = 0
    @State private var selectedConsole = "Xbox"
    @State private var sourceLanguage = "en"
    @State private var targetLanguage = "ar"
    @State private var prepareOnly = false
    @State private var languageMessage = "اضغط تجهيز اللغات؛ تنزيل الحزم مجاني ويتم بموافقتك."

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
                            HStack(spacing: 7) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(bridge.tvRecentlyConnected ? Color.green : Color.orange)
                                Text(bridge.tvRecentlyConnected ? "متصل بمتصفح التلفزيون ويستقبل الترجمة" : "لم يصل طلب من متصفح التلفزيون بعد")
                                    .font(.subheadline)
                                    .foregroundStyle(bridge.tvRecentlyConnected ? Color.green : Color.orange)
                            }
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

                    card("ترجمة بث الكونسول — بدون كاميرا") {
                        Label("القراءة المباشرة تكون من إطارات Xbox Remote Play داخل REBOX", systemImage: "gamecontroller.fill")
                            .foregroundStyle(accent)
                        Text("بنبني الالتقاط داخل مشغل Xbox الموجود بمشروع REBOX. هذا التطبيق يستقبل الترجمة ويرسلها للتلفزيون؛ ما يحتاج صلاحية كاميرا.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("PlayStation يتطلب ربط بث منفصل، وما بنعرضه على أنه شغال قبل الاختبار.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    card("لغات الترجمة — مجانية") {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading) {
                                Text("من").font(.caption)
                                Picker("اللغة المصدر", selection: $sourceLanguage) {
                                    Text("English").tag("en")
                                    Text("Deutsch").tag("de")
                                    Text("Français").tag("fr")
                                    Text("Español").tag("es")
                                    Text("العربية").tag("ar")
                                }.pickerStyle(.menu)
                            }
                            Spacer()
                            Image(systemName: "arrow.left.right").foregroundStyle(accent)
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("إلى").font(.caption)
                                Picker("اللغة المستهدفة", selection: $targetLanguage) {
                                    Text("العربية").tag("ar")
                                    Text("English").tag("en")
                                    Text("Deutsch").tag("de")
                                    Text("Français").tag("fr")
                                    Text("Español").tag("es")
                                }.pickerStyle(.menu)
                            }
                        }
                        Button {
                            prepareLanguages()
                        } label: {
                            Label("تجهيز / تنزيل لغات الترجمة مجانًا", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity).padding(9)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .foregroundStyle(.black)
                        Text(languageMessage).font(.caption).foregroundStyle(.secondary)
                        Text("إذا كانت اللغات غير مثبتة، بيظهر طلب Apple للموافقة على تنزيلها. ما يحتاج اشتراك.")
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
                    Text("إصدار مجاني بلا كاميرا. الترجمة الآلية من بث Xbox تحتاج تشغيل ميزة قراءة الإطارات داخل مشغل REBOX. عرض HDMI داخل متصفح LG يعتمد على موديل التلفزيون.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.bottom, 18)
                }.padding(16)
            }
            .background(REBOXGalaxyBackground())
            .navigationTitle("REBOX TV")
            .navigationBarTitleDisplayMode(.inline)
        }
        .translationTask(translationConfiguration) { session in
            do {
                // Apple requests permission and downloads missing languages in-app.
                // Explicit source/target are required for prepareTranslation().
                if prepareOnly {
                    try await session.prepareTranslation()
                    await MainActor.run {
                        languageMessage = "اللغات جاهزة للاستخدام، أو بدأ تنزيلها بموافقتك."
                        prepareOnly = false
                    }
                    return
                }

                let text = requested
                guard !text.isEmpty else { return }
                let response = try await session.translate(text)
                await MainActor.run {
                    guard requested == text else { return }
                    bridge.subtitle = response.targetText
                    translationCache[translationKey(text)] = response.targetText
                    if translationCache.count > 120 { translationCache.removeAll() }
                    bridge.message = "تمت الترجمة والإرسال"
                }
            } catch {
                await MainActor.run {
                    prepareOnly = false
                    languageMessage = "تعذر تجهيز اللغات: \(error.localizedDescription)"
                    bridge.message = "الترجمة غير متاحة حاليًا: تأكد من دعم اللغات أو جهزها من الزر أعلاه."
                }
            }
        }
        .onChange(of: sourceLanguage) { _, _ in resetLanguageSession() }
        .onChange(of: targetLanguage) { _, _ in resetLanguageSession() }
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
        if let cached = translationCache[translationKey(text)] {
            bridge.subtitle = cached
            bridge.message = "تم استخدام ترجمة محفوظة محليًا"
            return
        }
        bridge.message = "جاري استخدام ترجمة Apple"
        runLanguageTask()

    }

    private func translationKey(_ text: String) -> String {
        "\(sourceLanguage):\(targetLanguage):\(text)"
    }

    private func resetLanguageSession() {
        translationConfiguration = nil
        prepareOnly = false
        languageMessage = "اضغط تجهيز اللغات لاستخدام هذا الزوج."
    }

    private func prepareLanguages() {
        guard sourceLanguage != targetLanguage else {
            languageMessage = "اختر لغتين مختلفتين."
            return
        }
        prepareOnly = true
        languageMessage = "جارٍ فحص زوج اللغات وطلب التنزيل عند الحاجة..."
        runLanguageTask()
    }

    private func runLanguageTask() {
        guard sourceLanguage != targetLanguage else {
            bridge.message = "اختر لغتين مختلفتين."
            return
        }
        if let config = translationConfiguration,
           config.source?.languageCode?.identifier == sourceLanguage,
           config.target?.languageCode?.identifier == targetLanguage {
            translationConfiguration?.invalidate()
        } else {
            translationConfiguration = TranslationSession.Configuration(
                source: Locale.Language(identifier: sourceLanguage),
                target: Locale.Language(identifier: targetLanguage)
            )
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

private struct REBOXGalaxyBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.020, green: 0.035, blue: 0.069),
                        Color(red: 0.032, green: 0.044, blue: 0.098),
                        Color(red: 0.012, green: 0.023, blue: 0.050)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.blue.opacity(0.24), .clear],
                    center: UnitPoint(x: 0.78, y: 0.32),
                    startRadius: 4, endRadius: 330
                )
                ForEach(0..<75, id: \.self) { index in
                    let dotSize: CGFloat = index.isMultiple(of: 9) ? 2.6 : 1.1
                    Circle()
                        .fill(Color.white.opacity(0.12 + Double(index % 5) * 0.08))
                        .frame(width: dotSize, height: dotSize)
                        .position(
                            x: geo.size.width * CGFloat((index * 43 + 11) % 97) / 97,
                            y: geo.size.height * CGFloat((index * 31 + 19) % 101) / 101
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
