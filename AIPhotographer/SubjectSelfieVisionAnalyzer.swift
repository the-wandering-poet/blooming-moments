import UIKit
import Vision

enum SubjectSelfieVisionAnalyzer {
    static func calibrationResult(
        for image: UIImage,
        sessionId: String
    ) -> PhoneTestSubjectCalibrationResult {
        let hasRenderableImage = image.size.width > 0 && image.size.height > 0
        let selfieAssetRef = "phone-test-subject-selfie://\(UUID().uuidString.lowercased())"
        guard hasRenderableImage, let cgImage = image.cgImage else {
            return fallbackResult(
                selfieAssetRef: selfieAssetRef,
                sessionId: sessionId,
                hasRenderableImage: hasRenderableImage
            )
        }

        do {
            let observations = try faceObservations(in: cgImage, orientation: image.cgImageOrientation)
            let visibleFaces = observations.filter { observation in
                observation.confidence >= 0.30
                    && observation.boundingBox.width >= 0.04
                    && observation.boundingBox.height >= 0.04
            }
            let visibleCount = visibleFaces.count
            let observedCount = observations.count
            let facesVisibleEnough = visibleCount > 0
            let confidence = min(0.95, max(0.35, Double(visibleCount) * 0.22 + Double(observedCount) * 0.08))
            let phoneTestProfile = PhoneTestSubjectSceneAnalysisAdapter.subjectProfile(
                from: PhoneTestSubjectSelfieSignals(
                    source: .iosSubjectHeuristic,
                    selfieAssetRef: selfieAssetRef,
                    observedFaceCount: observedCount,
                    visibleFacingSubjectCount: facesVisibleEnough ? visibleCount : nil,
                    ignoredBackgroundPersonCount: max(0, observedCount - visibleCount),
                    facesVisibleEnough: facesVisibleEnough,
                    confidence: facesVisibleEnough ? confidence : 0.20,
                    readinessNotes: facesVisibleEnough
                        ? [
                            "selfie uploaded",
                            visibleCount == 1 ? "1 face clearly seen" : "\(visibleCount) faces clearly seen",
                            "ready for processing"
                        ]
                        : [
                            "selfie uploaded",
                            "no clear face found",
                            "retake recommended before pose matching"
                        ]
                ),
                sessionId: sessionId,
                fallbackProtectedSubjectCount: 0
            )
            return PhoneTestSubjectCalibrationResult(
                profile: SubjectProfile(phoneTestProfile: phoneTestProfile),
                source: phoneTestProfile.source.rawValue,
                confidenceLabel: facesVisibleEnough ? "On-device Vision" : "Retake recommended"
            )
        } catch {
            return fallbackResult(
                selfieAssetRef: selfieAssetRef,
                sessionId: sessionId,
                hasRenderableImage: hasRenderableImage
            )
        }
    }

    private static func faceObservations(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        return request.results ?? []
    }

    private static func fallbackResult(
        selfieAssetRef: String,
        sessionId: String,
        hasRenderableImage: Bool
    ) -> PhoneTestSubjectCalibrationResult {
        let phoneTestProfile = PhoneTestSubjectSceneAnalysisAdapter.subjectProfile(
            from: PhoneTestSubjectSelfieSignals(
                source: .deterministicSubjectFallback,
                selfieAssetRef: selfieAssetRef,
                observedFaceCount: nil,
                visibleFacingSubjectCount: nil,
                ignoredBackgroundPersonCount: nil,
                facesVisibleEnough: hasRenderableImage ? nil : false,
                confidence: hasRenderableImage ? 0.25 : 0.05,
                readinessNotes: hasRenderableImage
                    ? ["selfie uploaded", "face analysis unavailable", "ready for processing"]
                    : ["selfie unavailable", "subject count needs retry"]
            ),
            sessionId: sessionId,
            fallbackProtectedSubjectCount: hasRenderableImage ? 1 : 0
        )
        return PhoneTestSubjectCalibrationResult(
            profile: SubjectProfile(phoneTestProfile: phoneTestProfile),
            source: phoneTestProfile.source.rawValue,
            confidenceLabel: hasRenderableImage ? "Local fallback" : "Needs retry"
        )
    }
}

private extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}

