import Foundation

struct FinalMomentPublishedPreset: Codable, Equatable {
    let presetId: String
    let lutAssetId: String
    let isAvailable: Bool
    let supportedEditSignals: [String]
}

struct FinalMomentFineTuneServiceRequest: Codable, Equatable {
    let fineTuneResultId: String
    let request: FinalMomentFineTuneRequest
    let keeperSelection: FinalMomentKeeperSelection
    let cropGenerationResult: FinalMomentCropGenerationResult
    let originalFrames: [FinalMomentFrame]
    let cropDecisions: [FinalMomentCropDecisionRefRecord]
    let preset: FinalMomentPublishedPreset
    let requestedEnhancements: [String]
    let nonRecoverableFailuresByFrame: [String: [FinalMomentAssessmentFailure]]
}

enum FinalMomentFineTuneServiceError: Error, Equatable, LocalizedError {
    case staleKeeperSelectionId(expected: String, actual: String)
    case staleCropGenerationId(expected: String, actual: String)
    case presetUnavailable(presetId: String)
    case unsupportedEditParameter(String)
    case missingOriginalFrame(frameId: String)
    case missingCropDecision(frameId: String)
    case originalAssetMissing(assetId: String)
    case croppedAssetMissing(assetId: String)
    case editedAssetWriteFailed(assetId: String)
    case regenerationNotAllowed(frameId: String)

    var errorDescription: String? {
        switch self {
        case .staleKeeperSelectionId(let expected, let actual):
            return "Stale keeper selection ID. Expected \(expected), got \(actual)."
        case .staleCropGenerationId(let expected, let actual):
            return "Stale crop generation ID. Expected \(expected), got \(actual)."
        case .presetUnavailable(let presetId):
            return "Published preset or LUT is unavailable: \(presetId)."
        case .unsupportedEditParameter(let parameter):
            return "Unsupported fine tune edit parameter: \(parameter)."
        case .missingOriginalFrame(let frameId):
            return "Missing original captured frame for fine tune: \(frameId)."
        case .missingCropDecision(let frameId):
            return "Missing recommended crop decision for fine tune: \(frameId)."
        case .originalAssetMissing(let assetId):
            return "Original captured asset is unavailable: \(assetId)."
        case .croppedAssetMissing(let assetId):
            return "Cropped captured asset is unavailable: \(assetId)."
        case .editedAssetWriteFailed(let assetId):
            return "Edited asset write failed: \(assetId)."
        case .regenerationNotAllowed(let frameId):
            return "Fine tune must preserve isRegeneration=false for frame: \(frameId)."
        }
    }
}

final class FinalMomentFineTuneService {
    private let repository: (any FinalMomentRepository)?
    private let assetRepository: (any FinalMomentAssetRepository)?

    init(
        repository: (any FinalMomentRepository)? = nil,
        assetRepository: (any FinalMomentAssetRepository)? = nil
    ) {
        self.repository = repository
        self.assetRepository = assetRepository
    }

    func prepareFineTuneReview(
        _ serviceRequest: FinalMomentFineTuneServiceRequest
    ) throws -> FinalMomentFineTuneResult {
        guard serviceRequest.request.keeperSelectionId == serviceRequest.keeperSelection.keeperSelectionId else {
            throw FinalMomentFineTuneServiceError.staleKeeperSelectionId(
                expected: serviceRequest.keeperSelection.keeperSelectionId,
                actual: serviceRequest.request.keeperSelectionId
            )
        }
        guard serviceRequest.request.cropGenerationResultId == serviceRequest.cropGenerationResult.cropGenerationResultId else {
            throw FinalMomentFineTuneServiceError.staleCropGenerationId(
                expected: serviceRequest.cropGenerationResult.cropGenerationResultId,
                actual: serviceRequest.request.cropGenerationResultId
            )
        }
        guard serviceRequest.preset.isAvailable else {
            throw FinalMomentFineTuneServiceError.presetUnavailable(presetId: serviceRequest.preset.presetId)
        }

        try validateRequestedEnhancements(serviceRequest.requestedEnhancements, preset: serviceRequest.preset)

        let framesById = Dictionary(uniqueKeysWithValues: serviceRequest.originalFrames.map { ($0.frameId, $0) })
        let cropDecisionsByFrameId = Dictionary(uniqueKeysWithValues: serviceRequest.cropDecisions.map { ($0.frameId, $0) })
        let cropCandidatesById = Dictionary(uniqueKeysWithValues: serviceRequest.cropGenerationResult.cropCandidates.map { ($0.cropId, $0) })

        var items: [FinalMomentFineTuneItem] = []
        for frameId in serviceRequest.keeperSelection.selectedFrameIds {
            guard let originalFrame = framesById[frameId] else {
                throw FinalMomentFineTuneServiceError.missingOriginalFrame(frameId: frameId)
            }
            guard let cropDecision = cropDecisionsByFrameId[frameId],
                  cropDecision.cropGenerationResultId == serviceRequest.cropGenerationResult.cropGenerationResultId else {
                throw FinalMomentFineTuneServiceError.missingCropDecision(frameId: frameId)
            }

            let cropCandidate = cropCandidatesById[cropDecision.recommendedCropId]
            try validateAssetAvailable(originalFrame.assetRef, missing: .original)
            try validateAssetAvailable(cropDecision.cropAssetRef, missing: .cropped)

            let warnings = cannotRecoverWarnings(
                frameId: frameId,
                serviceRequest: serviceRequest,
                cropCandidate: cropCandidate
            )
            let enhancedAffordances = enhancedAffordances(
                serviceRequest: serviceRequest,
                cropCandidate: cropCandidate,
                warnings: warnings
            )
            let editParameters = editParameters(
                serviceRequest: serviceRequest,
                enhancedAffordances: enhancedAffordances,
                warnings: warnings
            )
            let consumedSignals = consumedSignals(
                serviceRequest: serviceRequest,
                cropCandidate: cropCandidate,
                enhancedAffordances: enhancedAffordances,
                warnings: warnings
            )
            let editedAsset = editedAssetRef(
                fineTuneResultId: serviceRequest.fineTuneResultId,
                frameId: frameId
            )

            let item = FinalMomentFineTuneItem(
                frameId: frameId,
                originalAssetRef: originalFrame.assetRef,
                croppedAssetRef: cropDecision.cropAssetRef,
                editedAssetRef: editedAsset,
                recommendedCropId: cropDecision.recommendedCropId,
                editParameters: editParameters,
                consumedSignals: consumedSignals,
                enhancedAffordances: enhancedAffordances,
                cannotRecoverWarnings: warnings,
                isRegeneration: false
            )

            guard item.isRegeneration == false else {
                throw FinalMomentFineTuneServiceError.regenerationNotAllowed(frameId: frameId)
            }

            try writeEditedAsset(item, serviceRequest: serviceRequest)
            try persist(item, serviceRequest: serviceRequest)
            items.append(item)
        }

        return FinalMomentFineTuneResult(
            fineTuneResultId: serviceRequest.fineTuneResultId,
            keeperSelectionId: serviceRequest.keeperSelection.keeperSelectionId,
            cropGenerationResultId: serviceRequest.cropGenerationResult.cropGenerationResultId,
            presetApplied: serviceRequest.preset.presetId,
            items: items
        )
    }

    private enum MissingAssetKind {
        case original
        case cropped
    }

    private func validateAssetAvailable(
        _ assetRef: FinalMomentAssetRef,
        missing: MissingAssetKind
    ) throws {
        guard let assetRepository else { return }
        do {
            _ = try assetRepository.loadAsset(assetId: assetRef.assetId)
        } catch _ as FinalMomentStoreError {
            switch missing {
            case .original:
                throw FinalMomentFineTuneServiceError.originalAssetMissing(assetId: assetRef.assetId)
            case .cropped:
                throw FinalMomentFineTuneServiceError.croppedAssetMissing(assetId: assetRef.assetId)
            }
        }
    }

    private func validateRequestedEnhancements(
        _ requested: [String],
        preset: FinalMomentPublishedPreset
    ) throws {
        let supported = Set(preset.supportedEditSignals)
        for signal in requested {
            guard supported.contains(signal) else {
                throw FinalMomentFineTuneServiceError.unsupportedEditParameter(signal)
            }
        }
    }

    private func editParameters(
        serviceRequest: FinalMomentFineTuneServiceRequest,
        enhancedAffordances: [String],
        warnings: [String]
    ) -> FinalMomentEditParameters {
        let settings = serviceRequest.request.cameraSettingsUsed
        let exposureScale = scaleFor(settings.exposure.status)
        let whiteBalanceScale = scaleFor(settings.whiteBalance.status)
        let captureQualityScale = scaleFor(settings.captureQuality.status)
        let depthAvailable = settings.depthPortrait.status != .unavailable
            && settings.depthPortrait.status != .needsOperatorAdjustment
        let blockedByNonRecovery = warnings.contains { $0.hasPrefix("cannot_recover_") }

        return FinalMomentEditParameters(
            exposure: blockedByNonRecovery ? 0.0 : 0.10 * exposureScale,
            contrast: blockedByNonRecovery ? 0.0 : 0.08 * captureQualityScale,
            warmth: blockedByNonRecovery ? 0.0 : 0.12 * whiteBalanceScale,
            highlightRecovery: blockedByNonRecovery ? 0.0 : 0.20 * exposureScale,
            shadowRecovery: blockedByNonRecovery ? 0.0 : 0.06 * exposureScale,
            toneCurve: blockedByNonRecovery ? "captured_original_no_recovery_claim" : "warm_editorial_medium_contrast",
            localCrispness: enhancedAffordances.contains("local_crispness") ? 0.10 * captureQualityScale : 0.0,
            localSoftness: enhancedAffordances.contains("local_softness") ? 0.04 * captureQualityScale : 0.0,
            skinToneProtection: 0.90,
            shadowPatternEmphasis: enhancedAffordances.contains("light_shadow_contrast") ? 0.08 * captureQualityScale : 0.0,
            rimLightEmphasis: enhancedAffordances.contains("rim_light_emphasis") ? 0.06 * captureQualityScale : 0.0,
            backgroundReadability: enhancedAffordances.contains("background_readability") ? 0.12 * captureQualityScale : 0.0,
            subjectSeparation: enhancedAffordances.contains("subject_separation") && depthAvailable ? 0.08 * captureQualityScale : 0.0,
            grainOrTexture: blockedByNonRecovery ? 0.0 : 0.03 * captureQualityScale
        )
    }

    private func scaleFor(_ status: FinalMomentCapabilityStatus) -> Double {
        switch status {
        case .applied, .locked, .available:
            return 1.0
        case .adjusted:
            return 0.6
        case .unavailable, .needsOperatorAdjustment:
            return 0.0
        case .notRequested:
            return 0.4
        }
    }

    private func enhancedAffordances(
        serviceRequest: FinalMomentFineTuneServiceRequest,
        cropCandidate: FinalMomentCropCandidate?,
        warnings: [String]
    ) -> [String] {
        guard warnings.contains(where: { $0.hasPrefix("cannot_recover_") }) == false else {
            return []
        }

        var enhancements: [String] = []
        let eligible = serviceRequest.request.capturedAffordanceMetadata.postCaptureFineTuneEligible
        let requested = serviceRequest.requestedEnhancements.isEmpty
            ? eligible
            : serviceRequest.requestedEnhancements
        let supported = Set(serviceRequest.preset.supportedEditSignals)

        for signal in requested where supported.contains(signal) {
            switch signal {
            case "portfolio_color_tone":
                enhancements.append("portfolio_color_tone")
            case "light_shadow_contrast":
                enhancements.append("light_shadow_contrast")
            case "crop_composition":
                enhancements.append("crop_composition")
            case "local_crispness":
                enhancements.append("local_crispness")
            case "local_softness":
                enhancements.append("local_softness")
            case "background_readability":
                enhancements.append("background_readability")
            case "subject_separation":
                if serviceRequest.request.cameraSettingsUsed.depthPortrait.status != .unavailable
                    && serviceRequest.request.cameraSettingsUsed.depthPortrait.status != .needsOperatorAdjustment {
                    enhancements.append("subject_separation")
                }
            default:
                continue
            }
        }

        if cropCandidate?.preservedAffordanceSignals.contains(.rimHairEdgeLight) == true {
            enhancements.append("rim_light_emphasis")
        }
        if cropCandidate?.preservedAffordanceSignals.contains(.projectedShadowPattern) == true {
            enhancements.append("light_shadow_contrast")
        }

        return unique(enhancements)
    }

    private func cannotRecoverWarnings(
        frameId: String,
        serviceRequest: FinalMomentFineTuneServiceRequest,
        cropCandidate: FinalMomentCropCandidate?
    ) -> [String] {
        var warnings: [String] = []

        for failure in serviceRequest.nonRecoverableFailuresByFrame[frameId] ?? [] {
            switch failure {
            case .missedFocus, .faceBlur:
                warnings.append("cannot_recover_protected_subject_focus")
            case .unusableFaceLight, .underExposedFace, .overExposedFace:
                warnings.append("cannot_recover_unusable_face_light")
            case .deadExpression, .closedEyes:
                warnings.append("cannot_recover_dead_expression")
            case .absentInteraction:
                warnings.append("cannot_recover_absent_interaction")
            case .tooTightCapture:
                warnings.append("cannot_recover_too_tight_capture")
            case .protectedSubjectMissing:
                warnings.append("cannot_recover_missing_protected_subject")
            case .missingAsset, .corruptAsset, .unreadableMetadata:
                warnings.append("cannot_recover_unreadable_capture_asset")
            }
        }

        let settings = serviceRequest.request.cameraSettingsUsed
        appendStatusWarning("focus", settings.focus.status, to: &warnings)
        appendStatusWarning("exposure", settings.exposure.status, to: &warnings)
        appendStatusWarning("white_balance", settings.whiteBalance.status, to: &warnings)
        appendStatusWarning("capture_quality", settings.captureQuality.status, to: &warnings)

        if settings.depthPortrait.status == .unavailable || settings.depthPortrait.status == .needsOperatorAdjustment {
            warnings.append("depth_portrait_unavailable_no_depth_separation")
        }
        if cropCandidate?.isDefaultFallback == true {
            warnings.append("crop_default_fallback_conservative_edit")
        }

        return unique(warnings)
    }

    private func appendStatusWarning(
        _ parameter: String,
        _ status: FinalMomentCapabilityStatus,
        to warnings: inout [String]
    ) {
        switch status {
        case .applied, .locked, .available, .notRequested:
            return
        case .adjusted:
            warnings.append("camera_\(parameter)_adjusted_conservative_edit")
        case .unavailable:
            warnings.append("camera_\(parameter)_unavailable_no_recovery_claim")
        case .needsOperatorAdjustment:
            warnings.append("camera_\(parameter)_needs_operator_adjustment_capture_limitation")
        }
    }

    private func consumedSignals(
        serviceRequest: FinalMomentFineTuneServiceRequest,
        cropCandidate: FinalMomentCropCandidate?,
        enhancedAffordances: [String],
        warnings: [String]
    ) -> FinalMomentConsumedSignals {
        FinalMomentConsumedSignals(
            styleProfileSignals: [
                "preset:\(serviceRequest.preset.presetId)",
                "lut:\(serviceRequest.preset.lutAssetId)"
            ],
            runtimeAffordanceSignals: cropCandidate?.preservedAffordanceSignals ?? serviceRequest.request.runtimeAffordanceSignals,
            capturedAffordanceMetadata: enhancedAffordances + warnings,
            cameraSettingsUsed: cameraStatusNotes(serviceRequest.request.cameraSettingsUsed)
        )
    }

    private func cameraStatusNotes(
        _ settings: FinalMomentCameraSettingsUsed
    ) -> [String] {
        [
            "focus.\(settings.focus.status.rawValue)",
            "exposure.\(settings.exposure.status.rawValue)",
            "whiteBalance.\(settings.whiteBalance.status.rawValue)",
            "depthPortrait.\(settings.depthPortrait.status.rawValue)",
            "zoomLens.\(settings.zoomLens.status.rawValue)",
            "framing.\(settings.framing.status.rawValue)",
            "captureQuality.\(settings.captureQuality.status.rawValue)"
        ]
    }

    private func editedAssetRef(
        fineTuneResultId: String,
        frameId: String
    ) -> FinalMomentAssetRef {
        FinalMomentAssetRef(
            assetId: "asset_edited_\(fineTuneResultId)_\(frameId)",
            uri: "asset://edited_\(fineTuneResultId)_\(frameId)",
            role: .edited,
            width: 2400,
            height: 3000,
            mimeType: "image/jpeg"
        )
    }

    private func writeEditedAsset(
        _ item: FinalMomentFineTuneItem,
        serviceRequest: FinalMomentFineTuneServiceRequest
    ) throws {
        guard let assetRepository else { return }
        do {
            _ = try assetRepository.upsertAsset(FinalMomentAssetRecord(
                assetRef: item.editedAssetRef,
                sourceStage: "fine_tune_output",
                captureResultId: serviceRequest.keeperSelection.captureResultId,
                frameId: item.frameId,
                isReadable: true,
                contentFingerprint: "\(serviceRequest.preset.presetId)_\(item.recommendedCropId)"
            ))
        } catch {
            throw FinalMomentFineTuneServiceError.editedAssetWriteFailed(assetId: item.editedAssetRef.assetId)
        }
    }

    private func persist(
        _ item: FinalMomentFineTuneItem,
        serviceRequest: FinalMomentFineTuneServiceRequest
    ) throws {
        guard let repository else { return }
        _ = try repository.upsertFineTuneParameterRef(FinalMomentFineTuneParameterRefRecord(
            recordId: "\(item.frameId)_\(serviceRequest.fineTuneResultId)",
            fineTuneResultId: serviceRequest.fineTuneResultId,
            cropGenerationResultId: serviceRequest.cropGenerationResult.cropGenerationResultId,
            frameId: item.frameId,
            presetApplied: serviceRequest.preset.presetId,
            editParameters: item.editParameters,
            consumedSignals: item.consumedSignals,
            enhancedAffordances: item.enhancedAffordances,
            cannotRecoverWarnings: item.cannotRecoverWarnings,
            originalAssetRef: item.originalAssetRef,
            croppedAssetRef: item.croppedAssetRef,
            editedAssetRef: item.editedAssetRef,
            isRegeneration: item.isRegeneration
        ))
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
