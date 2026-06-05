import AVFoundation
import UIKit

struct PhoneTestCameraCapabilities: Equatable {
    let position: AVCaptureDevice.Position
    let supportsFocusPoint: Bool
    let supportsExposurePoint: Bool
    let supportsWhiteBalanceLock: Bool
    let supportsFlash: Bool
    let supportsDepthDelivery: Bool
    let minZoomFactor: CGFloat
    let maxZoomFactor: CGFloat
}

final class PhoneTestCameraController: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case running
        case denied
        case unavailable(String)
    }

    let session = AVCaptureSession()

    @Published private(set) var state: State = .idle
    @Published private(set) var isCapturing = false
    @Published private(set) var capabilities: PhoneTestCameraCapabilities?

    private let sessionQueue = DispatchQueue(label: "com.blooming.phone-test-camera.session")
    private let preferredPosition: AVCaptureDevice.Position
    private var photoOutput: AVCapturePhotoOutput?
    private var captureCompletion: ((UIImage) -> Void)?
    private var isConfigured = false

    init(preferredPosition: AVCaptureDevice.Position = .front) {
        self.preferredPosition = preferredPosition
        super.init()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            setState(.requestingPermission)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if isGranted {
                        self.configureAndStart()
                    } else {
                        self.setState(.denied)
                    }
                }
            }
        case .denied, .restricted:
            setState(.denied)
        @unknown default:
            setState(.unavailable("Camera permission is unavailable."))
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let photoOutput else {
                self.setState(.unavailable("Camera capture output is unavailable."))
                return
            }
            guard self.captureCompletion == nil else { return }

            self.captureCompletion = completion
            self.setIsCapturing(true)

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            if photoOutput.supportedFlashModes.contains(.off) {
                settings.flashMode = .off
            }

            if let connection = photoOutput.connection(with: .video) {
                Self.applyPortraitRotation(to: connection)
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = self.preferredPosition == .front
                }
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.isConfigured {
                    try self.configureSession()
                    self.isConfigured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                self.setState(.running)
            } catch {
                self.setState(.unavailable(error.localizedDescription))
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        let device = Self.makeCameraDevice(preferredPosition: preferredPosition)
        guard let device else {
            throw PhoneTestCameraError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw PhoneTestCameraError.inputUnavailable
        }
        session.addInput(input)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            throw PhoneTestCameraError.outputUnavailable
        }
        output.maxPhotoQualityPrioritization = .quality
        session.addOutput(output)
        photoOutput = output

        publishCapabilities(for: device, output: output)
    }

    private static func makeCameraDevice(preferredPosition: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition) {
            return device
        }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    static func applyPortraitRotation(to connection: AVCaptureConnection) {
        let portraitRotationAngle: CGFloat = 90
        if connection.isVideoRotationAngleSupported(portraitRotationAngle) {
            connection.videoRotationAngle = portraitRotationAngle
        }
    }

    private func publishCapabilities(for device: AVCaptureDevice, output: AVCapturePhotoOutput) {
        let snapshot = PhoneTestCameraCapabilities(
            position: device.position,
            supportsFocusPoint: device.isFocusPointOfInterestSupported,
            supportsExposurePoint: device.isExposurePointOfInterestSupported,
            supportsWhiteBalanceLock: device.isWhiteBalanceModeSupported(.locked),
            supportsFlash: output.supportedFlashModes.contains(.on),
            supportsDepthDelivery: output.isDepthDataDeliverySupported,
            minZoomFactor: device.minAvailableVideoZoomFactor,
            maxZoomFactor: device.maxAvailableVideoZoomFactor
        )
        DispatchQueue.main.async { [weak self] in
            self?.capabilities = snapshot
        }
    }

    private func setState(_ state: State) {
        DispatchQueue.main.async { [weak self] in
            self?.state = state
        }
    }

    private func setIsCapturing(_ isCapturing: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = isCapturing
        }
    }
}

extension PhoneTestCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            captureCompletion = nil
            setIsCapturing(false)
        }

        if let error {
            setState(.unavailable(error.localizedDescription))
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            setState(.unavailable("The captured photo could not be decoded."))
            return
        }

        DispatchQueue.main.async { [completion = captureCompletion] in
            completion?(image)
        }
    }
}

private enum PhoneTestCameraError: LocalizedError {
    case cameraUnavailable
    case inputUnavailable
    case outputUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "No camera is available on this device."
        case .inputUnavailable:
            return "Blooming could not attach the camera input."
        case .outputUnavailable:
            return "Blooming could not attach photo capture output."
        }
    }
}
