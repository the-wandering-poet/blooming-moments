import AVFoundation
import SwiftUI
import UIKit

struct PhoneTestCameraView: View {
    let title: String
    let permissionPrompt: String
    let runningPrompt: String
    let spokenPrompts: [String]
    let captureAccessibilityLabel: String
    let captureAction: (UIImage) -> Void
    let cancelAction: () -> Void

    @StateObject private var controller: PhoneTestCameraController
    @StateObject private var speechCoach = LiveCoachingSpeechCoach()

    init(
        title: String = "Subject Selfie",
        permissionPrompt: String = "Camera access is needed to capture a subject selfie.",
        runningPrompt: String = "Hold steady",
        spokenPrompts: [String] = [],
        captureAccessibilityLabel: String = "Capture subject selfie",
        preferredPosition: AVCaptureDevice.Position = .front,
        captureAction: @escaping (UIImage) -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.title = title
        self.permissionPrompt = permissionPrompt
        self.runningPrompt = runningPrompt
        self.spokenPrompts = spokenPrompts
        self.captureAccessibilityLabel = captureAccessibilityLabel
        self.captureAction = captureAction
        self.cancelAction = cancelAction
        _controller = StateObject(wrappedValue: PhoneTestCameraController(preferredPosition: preferredPosition))
    }

    var body: some View {
        ZStack {
            PhoneTestCameraPreview(session: controller.session)
                .ignoresSafeArea()
                .overlay(.black.opacity(overlayOpacity))

            VStack(spacing: 0) {
                HStack {
                    Button(action: cancelAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.62), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close camera")

                    Spacer()

                    Text(title)
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.82))

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 22)
                .padding(.top, 70)

                Spacer()

                cameraStatus
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                Button {
                    controller.capturePhoto { image in
                        captureAction(image)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.92), lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(controller.isCapturing ? .white.opacity(0.48) : .white)
                            .frame(width: 60, height: 60)
                        if controller.isCapturing {
                            ProgressView()
                                .tint(.black.opacity(0.72))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(controller.state != .running || controller.isCapturing)
                .accessibilityLabel(captureAccessibilityLabel)
                .padding(.bottom, 48)
            }
        }
        .task {
            controller.start()
            updateSpeech(for: controller.state)
        }
        .onChange(of: controller.state) { state in
            updateSpeech(for: state)
        }
        .onDisappear {
            speechCoach.stop()
            controller.stop()
        }
    }

    private var overlayOpacity: Double {
        switch controller.state {
        case .running:
            return 0
        default:
            return 0.35
        }
    }

    @ViewBuilder
    private var cameraStatus: some View {
        switch controller.state {
        case .idle, .requestingPermission:
            statusPill("Preparing camera...")
        case .running:
            statusPill(runningPrompt)
        case .denied:
            statusPill(permissionPrompt)
        case .unavailable(let message):
            statusPill(message)
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("AvenirNext-Regular", size: 13))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.42), in: Capsule())
    }

    private func updateSpeech(for state: PhoneTestCameraController.State) {
        guard state == .running else {
            speechCoach.stop()
            return
        }
        speechCoach.start(prompts: spokenPrompts)
    }
}

private struct PhoneTestCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection {
            PhoneTestCameraController.applyPortraitRotation(to: connection)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        if let connection = uiView.videoPreviewLayer.connection {
            PhoneTestCameraController.applyPortraitRotation(to: connection)
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
