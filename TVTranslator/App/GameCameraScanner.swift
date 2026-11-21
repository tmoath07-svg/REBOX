import AVFoundation
import SwiftUI
import Vision
import UIKit
import Combine

/// Free on-device Vision OCR for captions visible on a television.
/// Uses the rear camera and never uploads video frames.
final class GameCameraScanner: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()

    @Published private(set) var isRunning = false
    @Published var info = "وجّه الكاميرا على نص اللعبة أسفل شاشة التلفزيون"

    var onStableText: ((String) -> Void)?

    private let captureQueue = DispatchQueue(label: "rebox.tv.camera.session")
    private let visionQueue = DispatchQueue(label: "rebox.tv.camera.vision")
    private var configured = false
    private var nextFrameAt: CFTimeInterval = 0
    private var recentText = ""
    private var stableHits = 0
    private var sentText = ""

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                if allowed {
                    self?.configureAndStart()
                } else {
                    DispatchQueue.main.async { self?.info = "اسمح للكاميرا من الإعدادات عشان تبدأ الترجمة التلقائية" }
                }
            }
        default:
            DispatchQueue.main.async { self.info = "الكاميرا غير مسموح بها. فعّل الصلاحية من إعدادات الجهاز." }
        }
    }

    private func configureAndStart() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.info = "ما حصلت كاميرا خلفية متوافقة" }
                    return
                }
                self.session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.visionQueue)
                guard self.session.canAddOutput(output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.info = "تعذر تهيئة بث الكاميرا" }
                    return
                }
                self.session.addOutput(output)
                if let connection = output.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                if self.session.isRunning {
                    self.info = "شغالة: قراءة النصوص تلقائيًا محليًا بدون رفع الصور"
                }
            }
        }
    }

    func stop() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now >= nextFrameAt, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        nextFrameAt = now + 0.90

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        // Focus on the lower part of the camera image, where games normally render subtitles.
        request.regionOfInterest = CGRect(x: 0.04, y: 0.02, width: 0.92, height: 0.52)

        do {
            try VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .right, options: [:]).perform([request])
            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let candidate = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidate.count >= 4, candidate.count <= 320 else {
                recentText = ""
                stableHits = 0
                return
            }
            if candidate == recentText {
                stableHits += 1
            } else {
                recentText = candidate
                stableHits = 1
            }
            // Require two matching scans to prevent flicker and expensive duplicate translation.
            guard stableHits >= 2, candidate != sentText else { return }
            sentText = candidate
            DispatchQueue.main.async { [weak self] in
                self?.onStableText?(candidate)
            }
        } catch {
            // An occasional camera frame can be unreadable; keep scanning the next frame.
        }
    }

    deinit {
        session.stopRunning()
    }
}

struct GameCameraPreview: UIViewRepresentable {
    let scanner: GameCameraScanner

    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface()
        view.cameraLayer.session = scanner.session
        view.cameraLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewSurface, context: Context) {}

    final class PreviewSurface: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var cameraLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
