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
    @State private var input = ""
    @State private var requested = ""
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var selectedImage: PhotosPickerItem?
    @State private var page = 0

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
                            Text("صفحة المتصفح وحدها لا تظهر فوق HDMI إلا لو التلفزيون يدعم العرض المتراكب.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    card("الترجمة") {
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
                    Text("هذا إصدار أولي مجاني: يدعم إدخال النص واستخراجه من الصور وترجمته وإرساله لشاشة استقبال. لا يحتوي حاليًا على التقاط مباشر لصوت أو صورة ألعاب الكونسول.")
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
                    bridge.subtitle = answer.targetText
                    bridge.message = "تمت الترجمة والإرسال"
                }
            } catch {
                await MainActor.run { bridge.message = "تعذرت الترجمة: \(error.localizedDescription)" }
            }
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
