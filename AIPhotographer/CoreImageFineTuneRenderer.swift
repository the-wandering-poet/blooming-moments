import CoreImage
import UIKit

enum CoreImageFineTuneInputSourceRole: String, Equatable {
    case finalCapture
    case subjectSelfie
    case sceneInput
}

struct CoreImageFineTuneRenderRequest {
    let originalImage: UIImage
    let inputSourceRole: CoreImageFineTuneInputSourceRole
    let cropBox: FinalMomentNormalizedRect?
    let subjectBoxes: [FinalMomentNormalizedRect]
    let editParameters: FinalMomentEditParameters

    init(
        originalImage: UIImage,
        inputSourceRole: CoreImageFineTuneInputSourceRole = .finalCapture,
        cropBox: FinalMomentNormalizedRect? = nil,
        subjectBoxes: [FinalMomentNormalizedRect] = [],
        editParameters: FinalMomentEditParameters = .phoneTestDefault
    ) {
        self.originalImage = originalImage
        self.inputSourceRole = inputSourceRole
        self.cropBox = cropBox
        self.subjectBoxes = subjectBoxes
        self.editParameters = editParameters
    }
}

struct CoreImageFineTuneRenderResult {
    let originalImage: UIImage
    let croppedImage: UIImage
    let fineTunedImage: UIImage
    let normalizedCropBoxUsed: FinalMomentNormalizedRect
    let pixelCropRectUsed: CGRect
    let editParametersUsed: FinalMomentEditParameters
    let inputSourceRoleUsed: CoreImageFineTuneInputSourceRole
    let isRegeneration: Bool
}

enum CoreImageFineTuneRendererError: Error, Equatable, LocalizedError {
    case invalidInputSourceRole(CoreImageFineTuneInputSourceRole)
    case invalidOriginalImage
    case invalidCropRect
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidInputSourceRole(let role):
            return "CoreImage fine tune renderer only accepts final captured photo A. Received \(role.rawValue)."
        case .invalidOriginalImage:
            return "Original image cannot be converted into a renderable CIImage."
        case .invalidCropRect:
            return "Crop rectangle is invalid for the original image."
        case .renderFailed:
            return "CoreImage renderer could not create a pixel output."
        }
    }
}

enum FinalCaptureRenderHandoffError: Error, Equatable, LocalizedError {
    case invalidSourceRole(CoreImageFineTuneInputSourceRole)
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .invalidSourceRole(let role):
            return "Final Moment renderer handoff only accepts final captured photo A. Received \(role.rawValue)."
        case .missingRequiredField(let field):
            return "Final Moment renderer handoff is missing \(field)."
        }
    }
}

struct FinalCaptureRenderHandoff {
    let sourceRole: CoreImageFineTuneInputSourceRole
    let finalCapturedImage: UIImage
    let finalCapturedAssetRef: FinalMomentAssetRef?
    let captureResultId: String
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let sceneInputQualityContext: FinalMomentSceneInputQualityContext
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed?
    let cropBox: FinalMomentNormalizedRect?
    let subjectBoxes: [FinalMomentNormalizedRect]
    let editParameters: FinalMomentEditParameters

    init(
        sourceRole: CoreImageFineTuneInputSourceRole = .finalCapture,
        finalCapturedImage: UIImage,
        finalCapturedAssetRef: FinalMomentAssetRef? = nil,
        captureResultId: String,
        scenePlanId: String,
        styleProfileId: String,
        protectedSubjectSetId: String,
        sceneInputQualityContext: FinalMomentSceneInputQualityContext,
        capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata,
        cameraSettingsUsed: FinalMomentCameraSettingsUsed? = nil,
        cropBox: FinalMomentNormalizedRect? = nil,
        subjectBoxes: [FinalMomentNormalizedRect] = [],
        editParameters: FinalMomentEditParameters = .graduationTrainingSetPreset
    ) {
        self.sourceRole = sourceRole
        self.finalCapturedImage = finalCapturedImage
        self.finalCapturedAssetRef = finalCapturedAssetRef
        self.captureResultId = captureResultId
        self.scenePlanId = scenePlanId
        self.styleProfileId = styleProfileId
        self.protectedSubjectSetId = protectedSubjectSetId
        self.sceneInputQualityContext = sceneInputQualityContext
        self.capturedAffordanceMetadata = capturedAffordanceMetadata
        self.cameraSettingsUsed = cameraSettingsUsed
        self.cropBox = cropBox
        self.subjectBoxes = subjectBoxes
        self.editParameters = editParameters
    }

    func makeRendererRequestBundle() throws -> FinalCaptureRendererRequestBundle {
        try validate()

        let request = CoreImageFineTuneRenderRequest(
            originalImage: finalCapturedImage,
            inputSourceRole: .finalCapture,
            cropBox: cropBox,
            subjectBoxes: subjectBoxes,
            editParameters: editParameters
        )
        let provenance = FinalCaptureRendererRequestProvenance(
            inputSourceRole: .finalCapture,
            captureResultId: captureResultId,
            finalCapturedAssetRef: finalCapturedAssetRef,
            scenePlanId: scenePlanId,
            styleProfileId: styleProfileId,
            protectedSubjectSetId: protectedSubjectSetId,
            sceneInputQualityContext: sceneInputQualityContext,
            capturedAffordanceMetadata: capturedAffordanceMetadata,
            cameraSettingsUsed: cameraSettingsUsed,
            isRegeneration: false
        )

        return FinalCaptureRendererRequestBundle(
            request: request,
            provenance: provenance
        )
    }

    private func validate() throws {
        guard sourceRole == .finalCapture else {
            throw FinalCaptureRenderHandoffError.invalidSourceRole(sourceRole)
        }
        try requireNonEmpty(captureResultId, field: "captureResultId")
        try requireNonEmpty(scenePlanId, field: "scenePlanId")
        try requireNonEmpty(styleProfileId, field: "styleProfileId")
        try requireNonEmpty(protectedSubjectSetId, field: "protectedSubjectSetId")
    }

    private func requireNonEmpty(
        _ value: String,
        field: String
    ) throws {
        guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw FinalCaptureRenderHandoffError.missingRequiredField(field)
        }
    }
}

struct FinalCaptureRendererRequestBundle {
    let request: CoreImageFineTuneRenderRequest
    let provenance: FinalCaptureRendererRequestProvenance
}

struct FinalCaptureRendererRequestProvenance {
    let inputSourceRole: CoreImageFineTuneInputSourceRole
    let captureResultId: String
    let finalCapturedAssetRef: FinalMomentAssetRef?
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let sceneInputQualityContext: FinalMomentSceneInputQualityContext
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed?
    let isRegeneration: Bool
}

final class CoreImageFineTuneRenderer {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    ])) {
        self.context = context
    }

    func render(
        _ request: CoreImageFineTuneRenderRequest
    ) throws -> CoreImageFineTuneRenderResult {
        guard request.inputSourceRole == .finalCapture else {
            throw CoreImageFineTuneRendererError.invalidInputSourceRole(request.inputSourceRole)
        }

        let orientedImage = try orientedCIImage(from: request.originalImage)
        let cropBox = Self.resolvedCropBox(
            requestedCropBox: request.cropBox,
            subjectBoxes: request.subjectBoxes
        )
        let pixelCropRect = try Self.pixelCropRect(
            from: cropBox,
            in: orientedImage.extent
        )

        let croppedCIImage = orientedImage
            .cropped(to: pixelCropRect)
            .transformed(by: CGAffineTransform(
                translationX: -pixelCropRect.origin.x,
                y: -pixelCropRect.origin.y
            ))
        let fineTunedCIImage = applyFineTune(
            to: croppedCIImage,
            parameters: request.editParameters
        )

        let croppedUIImage = try makeUIImage(
            from: croppedCIImage,
            scale: request.originalImage.scale
        )
        let fineTunedUIImage = try makeUIImage(
            from: fineTunedCIImage,
            scale: request.originalImage.scale
        )

        return CoreImageFineTuneRenderResult(
            originalImage: request.originalImage,
            croppedImage: croppedUIImage,
            fineTunedImage: fineTunedUIImage,
            normalizedCropBoxUsed: cropBox,
            pixelCropRectUsed: pixelCropRect,
            editParametersUsed: request.editParameters,
            inputSourceRoleUsed: request.inputSourceRole,
            isRegeneration: false
        )
    }

    static func resolvedCropBox(
        requestedCropBox: FinalMomentNormalizedRect?,
        subjectBoxes: [FinalMomentNormalizedRect] = []
    ) -> FinalMomentNormalizedRect {
        if let subjectCrop = cropBoxForSubjects(subjectBoxes) {
            return subjectCrop
        }

        if let requested = requestedCropBox,
           isValidCropBox(requested),
           isVisiblyDifferentFromIdentity(requested) {
            return bounded(requested)
        }

        return phoneTestPortraitFallbackCrop
    }

    private func orientedCIImage(from image: UIImage) throws -> CIImage {
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
                .oriented(forExifOrientation: image.imageOrientation.exifOrientation)
        }

        if let ciImage = image.ciImage {
            return ciImage.oriented(forExifOrientation: image.imageOrientation.exifOrientation)
        }

        throw CoreImageFineTuneRendererError.invalidOriginalImage
    }

    private func applyFineTune(
        to image: CIImage,
        parameters: FinalMomentEditParameters
    ) -> CIImage {
        var output = image

        output = filter(
            name: "CIExposureAdjust",
            input: output,
            values: ["inputEV": parameters.exposure]
        )
        output = filter(
            name: "CIColorControls",
            input: output,
            values: [
                "inputBrightness": min(max(parameters.shadowRecovery * 0.12, -0.15), 0.18),
                "inputContrast": 1.0 + min(max(parameters.contrast, -0.25), 0.35),
                "inputSaturation": 1.0 + min(max(parameters.warmth * 0.8, -0.20), 0.30)
            ]
        )
        output = filter(
            name: "CITemperatureAndTint",
            input: output,
            values: [
                "inputNeutral": CIVector(x: CGFloat(6500 + parameters.warmth * 1800), y: 0),
                "inputTargetNeutral": CIVector(x: 6200, y: 0)
            ]
        )
        output = filter(
            name: "CIHighlightShadowAdjust",
            input: output,
            values: [
                "inputHighlightAmount": max(0.0, 1.0 - min(parameters.highlightRecovery, 0.45)),
                "inputShadowAmount": min(max(0.25 + parameters.shadowRecovery, 0.0), 1.0)
            ]
        )

        if parameters.grainOrTexture > 0 || parameters.rimLightEmphasis > 0 {
            output = filter(
                name: "CIVignette",
                input: output,
                values: [
                    "inputIntensity": min(max(0.20 + parameters.grainOrTexture + parameters.rimLightEmphasis, 0.0), 0.75),
                    "inputRadius": max(min(Double(min(image.extent.width, image.extent.height)) * 0.75, 1600), 300)
                ]
            )
        }

        if parameters.localCrispness > 0 {
            output = filter(
                name: "CISharpenLuminance",
                input: output,
                values: ["inputSharpness": min(max(parameters.localCrispness * 3.0, 0.0), 0.7)]
            )
        }

        return output
    }

    private func filter(
        name: String,
        input: CIImage,
        values: [String: Any]
    ) -> CIImage {
        guard let filter = CIFilter(name: name) else {
            return input
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        for (key, value) in values {
            filter.setValue(value, forKey: key)
        }
        return filter.outputImage ?? input
    }

    private func makeUIImage(
        from image: CIImage,
        scale: CGFloat
    ) throws -> UIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw CoreImageFineTuneRendererError.renderFailed
        }
        guard let cgImage = context.createCGImage(image, from: extent) else {
            throw CoreImageFineTuneRendererError.renderFailed
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private static func pixelCropRect(
        from cropBox: FinalMomentNormalizedRect,
        in extent: CGRect
    ) throws -> CGRect {
        guard isValidCropBox(cropBox),
              extent.width > 0,
              extent.height > 0 else {
            throw CoreImageFineTuneRendererError.invalidCropRect
        }

        let normalized = bounded(cropBox)
        let x = extent.minX + CGFloat(normalized.x) * extent.width
        let y = extent.minY + CGFloat(1.0 - normalized.y - normalized.h) * extent.height
        let width = CGFloat(normalized.w) * extent.width
        let height = CGFloat(normalized.h) * extent.height
        let rect = CGRect(x: x, y: y, width: width, height: height).integral
            .intersection(extent.integral)

        guard rect.width > 1, rect.height > 1 else {
            throw CoreImageFineTuneRendererError.invalidCropRect
        }
        return rect
    }

    private static func cropBoxForSubjects(
        _ subjectBoxes: [FinalMomentNormalizedRect]
    ) -> FinalMomentNormalizedRect? {
        let validBoxes = subjectBoxes.filter(isValidCropBox)
        guard validBoxes.isEmpty == false else { return nil }

        let minX = validBoxes.map(\.x).min() ?? 0
        let minY = validBoxes.map(\.y).min() ?? 0
        let maxX = validBoxes.map { $0.x + $0.w }.max() ?? 1
        let maxY = validBoxes.map { $0.y + $0.h }.max() ?? 1
        let union = FinalMomentNormalizedRect(
            x: minX,
            y: minY,
            w: maxX - minX,
            h: maxY - minY
        )

        return bounded(FinalMomentNormalizedRect(
            x: union.x - 0.18,
            y: union.y - 0.22,
            w: union.w + 0.36,
            h: union.h + 0.34
        ))
    }

    private static var phoneTestPortraitFallbackCrop: FinalMomentNormalizedRect {
        FinalMomentNormalizedRect(
            x: 0.10,
            y: 0.06,
            w: 0.80,
            h: 0.84
        )
    }

    private static func isValidCropBox(_ rect: FinalMomentNormalizedRect) -> Bool {
        rect.x.isFinite
            && rect.y.isFinite
            && rect.w.isFinite
            && rect.h.isFinite
            && rect.w > 0.02
            && rect.h > 0.02
    }

    private static func isVisiblyDifferentFromIdentity(_ rect: FinalMomentNormalizedRect) -> Bool {
        rect.x > 0.02
            || rect.y > 0.02
            || rect.w < 0.96
            || rect.h < 0.96
    }

    private static func bounded(_ rect: FinalMomentNormalizedRect) -> FinalMomentNormalizedRect {
        let x = min(max(rect.x, 0.0), 0.98)
        let y = min(max(rect.y, 0.0), 0.98)
        let maxWidth = max(0.02, 1.0 - x)
        let maxHeight = max(0.02, 1.0 - y)
        return FinalMomentNormalizedRect(
            x: x,
            y: y,
            w: min(max(rect.w, 0.02), maxWidth),
            h: min(max(rect.h, 0.02), maxHeight)
        )
    }
}

extension FinalMomentEditParameters {
    static var graduationTrainingSetPreset: FinalMomentEditParameters {
        TrainingSetFineTunePreset.graduationLocalReviewPackage.editParameters
    }

    static var phoneTestDefault: FinalMomentEditParameters {
        FinalMomentEditParameters(
            exposure: 0.12,
            contrast: 0.18,
            warmth: 0.18,
            highlightRecovery: 0.28,
            shadowRecovery: 0.16,
            toneCurve: "phone_test_warm_visible_contrast",
            localCrispness: 0.12,
            localSoftness: 0.0,
            skinToneProtection: 0.80,
            shadowPatternEmphasis: 0.08,
            rimLightEmphasis: 0.08,
            backgroundReadability: 0.10,
            subjectSeparation: 0.0,
            grainOrTexture: 0.06
        )
    }
}

struct TrainingSetFineTunePreset: Equatable {
    let presetId: String
    let sourceStyleProfileId: String
    let sourcePortfolioId: String
    let evidenceSummary: String
    let editParameters: FinalMomentEditParameters

    static let graduationLocalReviewPackage = TrainingSetFineTunePreset(
        presetId: "preset_training_graduation_local_review_neutral_warm_editorial_v1",
        sourceStyleProfileId: "style_profile_training_graduation_local_same_photographer_v1",
        sourcePortfolioId: "training_graduation_local_same_photographer_v1",
        evidenceSummary: "Derived from the bundled graduation runtime style profile: neutral-warm white balance, -0.2 protected-face exposure bias, natural-light protection, crop composition, light-shadow contrast, local crispness, and background readability.",
        editParameters: FinalMomentEditParameters(
            exposure: 0.08,
            contrast: 0.22,
            warmth: 0.24,
            highlightRecovery: 0.34,
            shadowRecovery: 0.14,
            toneCurve: "training_graduation_neutral_warm_editorial_contrast",
            localCrispness: 0.16,
            localSoftness: 0.0,
            skinToneProtection: 0.84,
            shadowPatternEmphasis: 0.14,
            rimLightEmphasis: 0.10,
            backgroundReadability: 0.16,
            subjectSeparation: 0.04,
            grainOrTexture: 0.04
        )
    )
}

private extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
        case .up:
            return 1
        case .down:
            return 3
        case .left:
            return 8
        case .right:
            return 6
        case .upMirrored:
            return 2
        case .downMirrored:
            return 4
        case .leftMirrored:
            return 5
        case .rightMirrored:
            return 7
        @unknown default:
            return 1
        }
    }
}
