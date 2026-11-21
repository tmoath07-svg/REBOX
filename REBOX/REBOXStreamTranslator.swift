import Combine
import CoreGraphics
import StreamKit
import SwiftUI
import Translation
import UIKit
import Vision

/// Captures frames from the already-running native Xbox Remote Play renderer.
/// No camera, screen-recording permission, or paid translation service required.
struct REBOXStreamTranslator: View {
    let renderer: StreamRenderer?

    @StateObject private var sender = SubtitleBridge()
    @State private var enabled = false
    @State private var showSettings = false
    @State private var editingCrop = false
    @State private var region = CGRect(x: 0.14, y: 0.77, width: 0.72, height: 0.17)
    @State private var sourceCode = "en"
    @State private var targetCode = "ar"
    @State private var prepareOnly = false
    @State private var requestText = ""
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var recognized = ""
    @State private var priorRead = ""
    @State private var matchingFrames = 0
    @State private var translations: [String: String] = [:]
    @State private var lastResult = "ابدأ بث Xbox ثم فعّل ترجمة REBOX."
    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if editingCrop && enabled {
                cropOverlay
                    .allowsHitTesting(true)
            }

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    showSettings.toggle()
                } label: {
                    Label("ترجمة REBOX", systemImage: "character.bubble")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .background(.black.opacity(0.80), in: Capsule())
                        .overlay(Capsule().stroke(cyan.opacity(0.9), lineWidth: 1))
                }
                .foregroundStyle(cyan)

                if showSettings {
                    settings
                        .frame(maxWidth: 320)
                        .padding(12)
                        .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.top, 45)
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: enabled) {
            guard enabled else { return }
            while !Task.isCancelled {
                if let renderer, let image = renderer.lastFrameImage() {
                    scan(image)
                }
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
        .translationTask(translationConfiguration) { session in
            // Single-operation ownership of TranslationSession avoids use by
            // unrelated concurrent translation jobs.
            let owned = REBOXTranslationHandle(session: session)
            do {
                if prepareOnly {
                    try await owned.prepare()
                    prepareOnly = false
                    lastResult = "اللغات جاهزة أو تم قبول تنزيلها من Apple."
                    return
                }
                let content = requestText
                guard !content.isEmpty else { return }
                let translated = try await owned.translate(content)
                guard content == requestText else { return }
                sender.subtitle = translated
                translations[cacheKey(content)] = translated
                if translations.count > 120 {
                    translations.removeAll()
                    translations[cacheKey(content)] = result.targetText
                }
                lastResult = "تمت ترجمة النص وإرساله إلى LG."
            } catch {
                prepareOnly = false
                lastResult = "الترجمة غير متاحة: \(error.localizedDescription). اضغط تنزيل اللغات."
            }
        }
        .onChange(of: sourceCode) { _, _ in
            translationConfiguration = nil
            translations.removeAll()
        }
        .onChange(of: targetCode) { _, _ in
            translationConfiguration = nil
            translations.removeAll()
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("ترجمة الكونسول بدون كاميرا")
                .font(.headline).foregroundStyle(cyan)
            Toggle("ترجمة إطارات Xbox تلقائيًا", isOn: $enabled)
                .tint(.green)
            Text("تقرأ إطارات Remote Play داخل REBOX مباشرة. لا تصور التلفزيون ولا تسجل الفيديو.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Picker("من", selection: $sourceCode) {
                    Text("English").tag("en")
                    Text("German").tag("de")
                    Text("French").tag("fr")
                    Text("Arabic").tag("ar")
                }
                .pickerStyle(.menu)
                Spacer()
                Image(systemName: "arrow.left").font(.caption)
                Picker("إلى", selection: $targetCode) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                    Text("Français").tag("fr")
                }
                .pickerStyle(.menu)
            }
            Button {
                prepareOnly = true
                startTranslationTask()
            } label: {
                Label("تجهيز لغات Apple مجانًا", systemImage: "arrow.down.circle")
            }
            .font(.subheadline).foregroundStyle(cyan)

            HStack {
                Text(sender.tvRecentlyConnected ? "LG متصل" : "متصفح LG غير متصل")
                    .foregroundStyle(sender.tvRecentlyConnected ? .green : .orange)
                Spacer()
                Button("نسخ الرابط") {
                    guard sender.canShareURL else { return }
                    UIPasteboard.general.string = sender.tvURL
                    lastResult = "انسخ الرابط إلى متصفح LG."
                }
                .disabled(!sender.canShareURL)
            }
            .font(.caption)

            Text(sender.tvURL)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
            Toggle("تحريك مربع OCR", isOn: $editingCrop)
                .tint(cyan)
            if editingCrop {
                Slider(value: Binding(get: { Double(region.width) }, set: {
                    region.size.width = CGFloat($0)
                    region.origin.x = min(region.origin.x, 1 - region.width)
                }), in: 0.2...1)
                Text("عرض المنطقة").font(.caption)
                Slider(value: Binding(get: { Double(region.height) }, set: {
                    region.size.height = CGFloat($0)
                    region.origin.y = min(region.origin.y, 1 - region.height)
                }), in: 0.06...0.6)
                Text("ارتفاع المنطقة").font(.caption)
            }
            Text(lastResult)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !recognized.isEmpty {
                Text("OCR: " + recognized)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(cyan)
            }
        }
        .foregroundStyle(.white)
    }

    private var cropOverlay: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 8)
                .stroke(cyan, lineWidth: 3)
                .background(cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    Text("OCR")
                        .font(.caption.bold())
                        .padding(5)
                        .background(cyan, in: Capsule())
                        .foregroundStyle(.black)
                }
                .frame(width: geometry.size.width * region.width,
                       height: geometry.size.height * region.height)
                .position(x: geometry.size.width * region.midX,
                          y: geometry.size.height * region.midY)
                .gesture(DragGesture()
                    .onChanged { value in
                        let x = value.location.x / max(1, geometry.size.width)
                        let y = value.location.y / max(1, geometry.size.height)
                        region.origin.x = min(max(0, x - region.width / 2), 1 - region.width)
                        region.origin.y = min(max(0, y - region.height / 2), 1 - region.height)
                    })
        }
    }

    private func scan(_ image: CGImage) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [sourceCode == "de" ? "de-DE" :
                                        sourceCode == "fr" ? "fr-FR" :
                                        sourceCode == "ar" ? "ar-SA" : "en-US"]
        let area = CGRect(x: region.minX,
                          y: max(0, 1 - region.maxY),
                          width: region.width, height: region.height)
        request.regionOfInterest = area
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 4, text.count < 250 else {
                matchingFrames = 0
                priorRead = ""
                return
            }
            if text == priorRead { matchingFrames += 1 }
            else { priorRead = text; matchingFrames = 1 }
            guard matchingFrames >= 2, recognized != text else { return }
            recognized = text
            let key = cacheKey(text)
            if let saved = translations[key] {
                sender.subtitle = saved
                lastResult = "تم استخدام ترجمة محفوظة."
            } else {
                requestText = text
                prepareOnly = false
                startTranslationTask()
            }
        } catch {
            lastResult = "تعذر التعرف على النص في إطار اللعبة."
        }
    }

    private func cacheKey(_ text: String) -> String {
        "\(sourceCode)→\(targetCode):\(text)"
    }

    private func startTranslationTask() {
        guard sourceCode != targetCode else {
            lastResult = "اختر لغتين مختلفتين."
            return
        }
        let source = Locale.Language(identifier: sourceCode)
        let target = Locale.Language(identifier: targetCode)
        if let existing = translationConfiguration,
           existing.source == source && existing.target == target {
            translationConfiguration?.invalidate()
        } else {
            translationConfiguration = TranslationSession.Configuration(source: source, target: target)
        }
    }
}

/// TranslationSession is scoped to a single SwiftUI translationTask invocation.
/// This Sendable adapter is not shared between tasks; Apple owns the session lifecycle.
private struct REBOXTranslationHandle: @unchecked Sendable {
    let session: TranslationSession

    nonisolated func prepare() async throws {
        try await session.prepareTranslation()
    }

    nonisolated func translate(_ text: String) async throws -> String {
        let response = try await session.translate(text)
        return response.targetText
    }
}
