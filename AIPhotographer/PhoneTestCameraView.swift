import AVFoundation
import SwiftUI
import UIKit

struct PhoneTestCameraGuidePlacement: Equatable {
    let frame: CGRect
    let labelPosition: CGPoint
    let arrowPosition: CGPoint

    var focusPoint: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    static let environmentalStanding = PhoneTestCameraGuidePlacement(
        frame: CGRect(x: 0.31, y: 0.35, width: 0.62, height: 0.47),
        labelPosition: CGPoint(x: 0.72, y: 0.26),
        arrowPosition: CGPoint(x: 0.68, y: 0.46)
    )

    static let graduationSingleSubject = PhoneTestCameraGuidePlacement(
        frame: CGRect(x: 0.47, y: 0.36, width: 0.34, height: 0.42),
        labelPosition: CGPoint(x: 0.64, y: 0.27),
        arrowPosition: CGPoint(x: 0.57, y: 0.49)
    )

    static let seatedSubject = PhoneTestCameraGuidePlacement(
        frame: CGRect(x: 0.42, y: 0.46, width: 0.42, height: 0.30),
        labelPosition: CGPoint(x: 0.63, y: 0.36),
        arrowPosition: CGPoint(x: 0.55, y: 0.55)
    )
}

struct PhoneTestCameraGuidanceOverlay {
    let readiness: SceneRuntimeModels.Readiness
    let displayCues: [SceneRuntimeModels.CoachingCue]
    let settingBadges: [SceneRuntimeLiveSettingBadge]
    let standPointTitle: String
    let guidePlacement: PhoneTestCameraGuidePlacement
    let subjectCue: String?
    let operatorCue: String?
    let cameraRecommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation?
    let checkAction: () -> Void
    let retakeAction: () -> Void
}

struct PhoneTestCameraView: View {
    let title: String
    let permissionPrompt: String
    let runningPrompt: String
    let spokenPrompts: [String]
    let guidanceOverlay: PhoneTestCameraGuidanceOverlay?
    let captureAccessibilityLabel: String
    let demoFallbackImage: UIImage?
    let captureAction: (UIImage) -> Void
    let cancelAction: () -> Void

    @StateObject private var controller: PhoneTestCameraController
    @StateObject private var speechCoach = LiveCoachingSpeechCoach()
    @State private var appliedRecommendationId: String?
    @State private var pendingCaptureToken: UUID?

    init(
        title: String = "Subject Selfie",
        permissionPrompt: String = "Camera access is needed to capture a subject selfie.",
        runningPrompt: String = "Hold steady",
        spokenPrompts: [String] = [],
        guidanceOverlay: PhoneTestCameraGuidanceOverlay? = nil,
        captureAccessibilityLabel: String = "Capture subject selfie",
        preferredPosition: AVCaptureDevice.Position = .front,
        demoFallbackImage: UIImage? = nil,
        captureAction: @escaping (UIImage) -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.title = title
        self.permissionPrompt = permissionPrompt
        self.runningPrompt = runningPrompt
        self.spokenPrompts = spokenPrompts
        self.guidanceOverlay = guidanceOverlay
        self.captureAccessibilityLabel = captureAccessibilityLabel
        self.demoFallbackImage = demoFallbackImage
        self.captureAction = captureAction
        self.cancelAction = cancelAction
        _controller = StateObject(wrappedValue: PhoneTestCameraController(preferredPosition: preferredPosition))
    }

    var body: some View {
        ZStack {
            PhoneTestCameraPreview(session: controller.session)
                .ignoresSafeArea()
                .overlay(.black.opacity(overlayOpacity))

            if let guidanceOverlay {
                PhoneTestGuidedCameraHUD(
                    guidance: guidanceOverlay,
                    cameraState: controller.state,
                    runningPrompt: runningPrompt,
                    permissionPrompt: permissionPrompt,
                    isCapturing: controller.isCapturing,
                    captureAccessibilityLabel: captureAccessibilityLabel,
                    captureAction: captureIfReady,
                    cancelAction: cancelAction
                )
            } else {
                defaultCameraChrome
            }
        }
        .task {
            controller.start()
            updateSpeech(for: controller.state)
            applyGuidanceCameraSettingsIfNeeded()
        }
        .onChange(of: controller.state) { _, state in
            updateSpeech(for: state)
            applyGuidanceCameraSettingsIfNeeded()
        }
        .onChange(of: guidanceRecommendationId) { _, _ in
            appliedRecommendationId = nil
            applyGuidanceCameraSettingsIfNeeded()
        }
        .onDisappear {
            speechCoach.stop()
            controller.stop()
        }
    }

    private var overlayOpacity: Double {
        switch controller.state {
        case .running:
            return guidanceOverlay == nil ? 0 : 0.06
        default:
            return 0.35
        }
    }

    private var defaultCameraChrome: some View {
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

            Button(action: captureIfReady) {
                defaultCaptureButton
            }
            .buttonStyle(.plain)
            .disabled(controller.state != .running || controller.isCapturing)
            .accessibilityLabel(captureAccessibilityLabel)
            .padding(.bottom, 48)
        }
    }

    private var defaultCaptureButton: some View {
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

    private var guidanceRecommendationId: String? {
        guidanceOverlay?.cameraRecommendation?.recommendationId
    }

    private func captureIfReady() {
        guard controller.state == .running, !controller.isCapturing else { return }
        let token = UUID()
        pendingCaptureToken = token
        controller.capturePhoto { image in
            guard pendingCaptureToken == token else { return }
            pendingCaptureToken = nil
            captureAction(image)
        }
        guard let demoFallbackImage else { return }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard pendingCaptureToken == token else { return }
            pendingCaptureToken = nil
            captureAction(demoFallbackImage)
        }
    }

    private func applyGuidanceCameraSettingsIfNeeded() {
        guard controller.state == .running,
              let guidanceOverlay,
              let recommendation = guidanceOverlay.cameraRecommendation,
              appliedRecommendationId != recommendation.recommendationId else {
            return
        }
        appliedRecommendationId = recommendation.recommendationId
        controller.applyCameraRecommendation(
            recommendation,
            focusPoint: guidanceOverlay.guidePlacement.focusPoint
        )
    }

    private func updateSpeech(for state: PhoneTestCameraController.State) {
        guard state == .running else {
            speechCoach.stop()
            return
        }
        speechCoach.start(prompts: spokenPrompts)
    }
}

private struct PhoneTestGuidedCameraHUD: View {
    let guidance: PhoneTestCameraGuidanceOverlay
    let cameraState: PhoneTestCameraController.State
    let runningPrompt: String
    let permissionPrompt: String
    let isCapturing: Bool
    let captureAccessibilityLabel: String
    let captureAction: () -> Void
    let cancelAction: () -> Void

    private var isRunning: Bool {
        cameraState == .running
    }

    private var canCapture: Bool {
        isRunning && !isCapturing
    }

    private var statusText: String {
        switch cameraState {
        case .idle, .requestingPermission:
            return "Preparing camera..."
        case .running:
            return guidance.operatorCue ?? runningPrompt
        case .denied:
            return permissionPrompt
        case .unavailable(let message):
            return message
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [.black.opacity(0.18), .clear, .black.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                LiveCameraGrid()
                    .ignoresSafeArea()

                PhoneTestGuidedSubjectOverlay(
                    title: guidance.standPointTitle,
                    placement: guidance.guidePlacement
                )
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if isRunning {
                    PhoneTestGuidedFocusPointReticle()
                        .position(
                            x: proxy.size.width * guidance.guidePlacement.focusPoint.x,
                            y: proxy.size.height * guidance.guidePlacement.focusPoint.y
                        )
                }

                topChrome
                    .padding(.horizontal, 18)
                    .padding(.top, 70)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if isRunning {
                    cueStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 12)
                        .padding(.bottom, 246)

                    settingStrip
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 132)
                } else {
                    PhoneTestGuidedStatusPill(text: statusText)
                        .padding(.horizontal, 22)
                }

                PhoneTestGuidedCameraControlTray(
                    isCaptureEnabled: canCapture,
                    isCapturing: isCapturing,
                    checkAction: guidance.checkAction,
                    captureAction: captureAction,
                    retakeAction: guidance.retakeAction,
                    captureAccessibilityLabel: captureAccessibilityLabel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private var topChrome: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: cancelAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(.black.opacity(0.46), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close camera")

                Spacer()

                LiveCoachingBadge(readiness: guidance.readiness)
            }

            if isRunning {
                PhoneTestGuidedStatusPill(text: statusText)
                    .frame(maxWidth: 280, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var cueStack: some View {
        LiveCueStack(cues: resolvedDisplayCues, isReady: guidance.readiness == .ready || guidance.readiness == .bestEffort)
            .frame(width: 176)
    }

    private var resolvedDisplayCues: [SceneRuntimeModels.CoachingCue] {
        if !guidance.displayCues.isEmpty {
            return guidance.displayCues
        }
        guard let subjectCue = guidance.subjectCue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !subjectCue.isEmpty else {
            return []
        }
        return [SceneRuntimeModels.CoachingCue(target: "subject", message: subjectCue)]
    }

    private var settingStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(guidance.settingBadges.prefix(4).enumerated()), id: \.offset) { _, badge in
                    LiveSettingBadge(icon: badge.icon, title: badge.title, status: badge.status)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct PhoneTestGuidedSubjectOverlay: View {
    let title: String
    var placement: PhoneTestCameraGuidePlacement = .environmentalStanding
    private let guideColor = Color(red: 0.980, green: 0.835, blue: 0.260)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(guideColor.opacity(0.92), lineWidth: 2.4)
                    .frame(width: width * placement.frame.width, height: height * placement.frame.height)
                    .position(x: width * placement.frame.midX, y: height * placement.frame.midY)

                Text(title)
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .foregroundStyle(AppPalette.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(guideColor.opacity(0.86), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppPalette.paper.opacity(0.48), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    .position(x: width * placement.labelPosition.x, y: height * placement.labelPosition.y)

                HStack(spacing: 7) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 34, weight: .bold))
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(guideColor.opacity(0.94))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                .position(x: width * placement.arrowPosition.x, y: height * placement.arrowPosition.y)
            }
        }
    }

}

private struct PhoneTestGuidedFocusPointReticle: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppPalette.gold.opacity(0.90), lineWidth: 1.6)
                .frame(width: 34, height: 34)
            Path { path in
                path.move(to: CGPoint(x: 17, y: 0))
                path.addLine(to: CGPoint(x: 17, y: 9))
                path.move(to: CGPoint(x: 17, y: 25))
                path.addLine(to: CGPoint(x: 17, y: 34))
                path.move(to: CGPoint(x: 0, y: 17))
                path.addLine(to: CGPoint(x: 9, y: 17))
                path.move(to: CGPoint(x: 25, y: 17))
                path.addLine(to: CGPoint(x: 34, y: 17))
            }
            .stroke(AppPalette.gold.opacity(0.88), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .shadow(color: .black.opacity(0.26), radius: 4, y: 2)
    }
}

private struct PhoneTestGuidedStatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("AvenirNext-DemiBold", size: 12.6))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(2)
            .minimumScaleFactor(0.76)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(.black.opacity(0.48), in: Capsule())
            .overlay {
                Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct PhoneTestGuidedCameraControlTray: View {
    let isCaptureEnabled: Bool
    let isCapturing: Bool
    let checkAction: () -> Void
    let captureAction: () -> Void
    let retakeAction: () -> Void
    let captureAccessibilityLabel: String

    var body: some View {
        HStack(alignment: .center) {
            Button(action: checkAction) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 31, weight: .medium))
                        .frame(width: 62, height: 62)
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay { Circle().stroke(AppPalette.paper.opacity(0.20), lineWidth: 1) }
                    Text("Check")
                        .font(.custom("AvenirNext-Regular", size: 17))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Run readiness check")

            Spacer()

            Button(action: captureAction) {
                ZStack {
                    Circle()
                        .stroke(AppPalette.paper, lineWidth: 6)
                        .frame(width: 86, height: 86)
                    Circle()
                        .stroke(.black.opacity(0.74), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(AppPalette.gold.opacity(isCaptureEnabled ? 1 : 0.38))
                        .frame(width: 62, height: 62)
                    if isCapturing {
                        ProgressView()
                            .tint(AppPalette.paper)
                    }
                }
            }
            .disabled(!isCaptureEnabled)
            .buttonStyle(.plain)
            .accessibilityLabel(captureAccessibilityLabel)

            Spacer()

            Button(action: retakeAction) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 27, weight: .regular))
                        .frame(width: 62, height: 62)
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay { Circle().stroke(AppPalette.paper.opacity(0.20), lineWidth: 1) }
                    Text("Retake")
                        .font(.custom("AvenirNext-Regular", size: 17))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to live coaching")
        }
        .foregroundStyle(AppPalette.paper)
        .padding(.horizontal, 36)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
