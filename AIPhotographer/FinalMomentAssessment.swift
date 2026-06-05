import Foundation

enum FinalMomentAssessmentFailure: String, Codable, Equatable, Hashable {
    case missedFocus = "missed_focus"
    case closedEyes = "closed_eyes"
    case faceBlur = "face_blur"
    case unusableFaceLight = "unusable_face_light"
    case underExposedFace = "under_exposed_face"
    case overExposedFace = "over_exposed_face"
    case deadExpression = "dead_expression"
    case absentInteraction = "absent_interaction"
    case tooTightCapture = "too_tight_capture"
    case protectedSubjectMissing = "protected_subject_missing"
    case missingAsset = "missing_asset"
    case corruptAsset = "corrupt_asset"
    case unreadableMetadata = "unreadable_metadata"
}

enum FinalMomentRecoverableEnhancement: String, Codable, Equatable, Hashable {
    case portfolioColorTone = "portfolio_color_tone"
    case lightShadowContrast = "light_shadow_contrast"
    case cropComposition = "crop_composition"
    case localCrispness = "local_crispness"
    case localSoftness = "local_softness"
    case backgroundReadability = "background_readability"
    case subjectSeparation = "subject_separation"
    case rimLightEmphasis = "rim_light_emphasis"
    case shadowPatternEmphasis = "shadow_pattern_emphasis"
}

struct FinalMomentProtectedSubjectObservation: Codable, Equatable {
    let subjectId: String
    let protectedSubjectInFrame: Bool
    let eyesOpen: Bool
    let faceSharpness: Double
    let faceExposure: Double
    let faceLightUsability: Double
    let expressionNaturalness: Double
    let interactionPresence: Double
    let cropHeadroom: Double
}

struct FinalMomentFrameAssessmentInput: Codable, Equatable {
    let frameId: String
    let assetRef: FinalMomentAssetRef
    let assetIsReadable: Bool
    let metadataIsReadable: Bool
    let protectedSubjectObservations: [FinalMomentProtectedSubjectObservation]
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let postCapturePrerequisites: FinalMomentPostCapturePrerequisites
}

struct FinalMomentCameraStatusEvidence: Codable, Equatable {
    let parameter: String
    let status: FinalMomentCapabilityStatus
    let confidenceAdjustment: Double
    let provenanceNote: String
}

struct FinalMomentProtectedSubjectAssessment: Codable, Equatable {
    let subjectId: String
    let protectedSubjectInFrame: Bool
    let eyesOpen: Bool
    let focusUsable: Bool
    let faceExposureUsable: Bool
    let faceLightUsable: Bool
    let expressionNatural: Bool
    let interactionPresent: Bool
    let cropHeadroomPreserved: Bool
    let failures: [FinalMomentAssessmentFailure]
    let confidence: Double
}

struct FinalMomentFrameAssessment: Codable, Equatable {
    let frameId: String
    let assetReadable: Bool
    let metadataReadable: Bool
    let protectedSubjectAssessments: [FinalMomentProtectedSubjectAssessment]
    let cameraStatusEvidence: [FinalMomentCameraStatusEvidence]
    let recoverableEnhancements: [FinalMomentRecoverableEnhancement]
    let nonRecoverableFailures: [FinalMomentAssessmentFailure]
    let confidence: Double
    let provenanceNotes: [String]

    var passesCapturePrerequisites: Bool {
        assetReadable && metadataReadable && nonRecoverableFailures.isEmpty
    }
}

protocol FinalMomentPostCaptureAssessmentAdapter {
    func assessFrame(_ input: FinalMomentFrameAssessmentInput) -> FinalMomentFrameAssessment
}

final class FinalMomentLocalTestAssessmentAdapter: FinalMomentPostCaptureAssessmentAdapter {
    struct Thresholds: Equatable {
        let focusSharpnessMinimum: Double
        let faceExposureMinimum: Double
        let faceExposureMaximum: Double
        let faceLightUsabilityMinimum: Double
        let expressionNaturalnessMinimum: Double
        let interactionPresenceMinimum: Double
        let cropHeadroomMinimum: Double

        static let `default` = Thresholds(
            focusSharpnessMinimum: 0.70,
            faceExposureMinimum: 0.35,
            faceExposureMaximum: 0.92,
            faceLightUsabilityMinimum: 0.55,
            expressionNaturalnessMinimum: 0.55,
            interactionPresenceMinimum: 0.45,
            cropHeadroomMinimum: 0.35
        )
    }

    private let thresholds: Thresholds

    init(thresholds: Thresholds = .default) {
        self.thresholds = thresholds
    }

    func assessFrame(_ input: FinalMomentFrameAssessmentInput) -> FinalMomentFrameAssessment {
        let cameraEvidence = assessCameraSettings(input.cameraSettingsUsed)
        var provenanceNotes = cameraEvidence.map(\.provenanceNote)
        var nonRecoverableFailures: [FinalMomentAssessmentFailure] = []

        if input.assetRef.assetId.isEmpty || input.assetRef.uri.isEmpty {
            nonRecoverableFailures.append(.missingAsset)
            provenanceNotes.append("asset reference missing or empty")
        }

        if input.assetIsReadable == false {
            nonRecoverableFailures.append(.corruptAsset)
            provenanceNotes.append("asset unreadable; assessment cannot treat the frame as recoverable")
        }

        if input.metadataIsReadable == false {
            nonRecoverableFailures.append(.unreadableMetadata)
            provenanceNotes.append("metadata unreadable; frame-level evidence is incomplete")
        }

        if input.protectedSubjectObservations.isEmpty {
            nonRecoverableFailures.append(.protectedSubjectMissing)
            provenanceNotes.append("no protected subject observations were available")
        }

        let subjectAssessments = input.protectedSubjectObservations.map { observation in
            assessProtectedSubject(observation, cameraEvidence: cameraEvidence)
        }

        for subject in subjectAssessments {
            nonRecoverableFailures.append(contentsOf: subject.failures)
        }

        let recoverableEnhancements = recoverableEnhancements(
            input: input,
            nonRecoverableFailures: nonRecoverableFailures
        )

        let subjectConfidence = subjectAssessments.isEmpty
            ? 0.0
            : subjectAssessments.map(\.confidence).reduce(0.0, +) / Double(subjectAssessments.count)
        let cameraAdjustment = cameraEvidence.map(\.confidenceAdjustment).reduce(0.0, +)
        let baseConfidence = min(max(subjectConfidence + cameraAdjustment, 0.0), 1.0)
        let confidence = (input.assetIsReadable && input.metadataIsReadable) ? baseConfidence : min(baseConfidence, 0.25)

        return FinalMomentFrameAssessment(
            frameId: input.frameId,
            assetReadable: input.assetIsReadable,
            metadataReadable: input.metadataIsReadable,
            protectedSubjectAssessments: subjectAssessments,
            cameraStatusEvidence: cameraEvidence,
            recoverableEnhancements: recoverableEnhancements,
            nonRecoverableFailures: uniqueFailures(nonRecoverableFailures),
            confidence: confidence,
            provenanceNotes: provenanceNotes
        )
    }

    private func assessProtectedSubject(
        _ observation: FinalMomentProtectedSubjectObservation,
        cameraEvidence: [FinalMomentCameraStatusEvidence]
    ) -> FinalMomentProtectedSubjectAssessment {
        var failures: [FinalMomentAssessmentFailure] = []

        if observation.protectedSubjectInFrame == false {
            failures.append(.protectedSubjectMissing)
        }

        if observation.eyesOpen == false {
            failures.append(.closedEyes)
        }

        let focusUsable = observation.faceSharpness >= thresholds.focusSharpnessMinimum
        if focusUsable == false {
            failures.append(observation.faceSharpness < 0.45 ? .missedFocus : .faceBlur)
        }

        let faceExposureUsable = observation.faceExposure >= thresholds.faceExposureMinimum && observation.faceExposure <= thresholds.faceExposureMaximum
        if faceExposureUsable == false {
            failures.append(observation.faceExposure < thresholds.faceExposureMinimum ? .underExposedFace : .overExposedFace)
        }

        let faceLightUsable = observation.faceLightUsability >= thresholds.faceLightUsabilityMinimum
        if faceLightUsable == false {
            failures.append(.unusableFaceLight)
        }

        let expressionNatural = observation.expressionNaturalness >= thresholds.expressionNaturalnessMinimum
        if expressionNatural == false {
            failures.append(.deadExpression)
        }

        let interactionPresent = observation.interactionPresence >= thresholds.interactionPresenceMinimum
        if interactionPresent == false {
            failures.append(.absentInteraction)
        }

        let cropHeadroomPreserved = observation.cropHeadroom >= thresholds.cropHeadroomMinimum
        if cropHeadroomPreserved == false {
            failures.append(.tooTightCapture)
        }

        let cameraAdjustment = cameraEvidence.map(\.confidenceAdjustment).reduce(0.0, +)
        let signalValues = [
            observation.protectedSubjectInFrame ? 1.0 : 0.0,
            observation.eyesOpen ? 1.0 : 0.0,
            observation.faceSharpness,
            exposureScore(observation.faceExposure),
            observation.faceLightUsability,
            observation.expressionNaturalness,
            observation.interactionPresence,
            observation.cropHeadroom
        ]
        let signalConfidence = signalValues.reduce(0.0, +) / Double(signalValues.count)
        let confidence = min(max(signalConfidence + cameraAdjustment, 0.0), 1.0)

        return FinalMomentProtectedSubjectAssessment(
            subjectId: observation.subjectId,
            protectedSubjectInFrame: observation.protectedSubjectInFrame,
            eyesOpen: observation.eyesOpen,
            focusUsable: focusUsable,
            faceExposureUsable: faceExposureUsable,
            faceLightUsable: faceLightUsable,
            expressionNatural: expressionNatural,
            interactionPresent: interactionPresent,
            cropHeadroomPreserved: cropHeadroomPreserved,
            failures: uniqueFailures(failures),
            confidence: confidence
        )
    }

    private func exposureScore(_ value: Double) -> Double {
        if value >= thresholds.faceExposureMinimum && value <= thresholds.faceExposureMaximum {
            return 1.0
        }
        if value < thresholds.faceExposureMinimum {
            return max(0.0, value / thresholds.faceExposureMinimum)
        }
        return max(0.0, 1.0 - (value - thresholds.faceExposureMaximum))
    }

    private func assessCameraSettings(_ settings: FinalMomentCameraSettingsUsed) -> [FinalMomentCameraStatusEvidence] {
        [
            evidence("focus", settings.focus.status),
            evidence("exposure", settings.exposure.status),
            evidence("whiteBalance", settings.whiteBalance.status),
            evidence("depthPortrait", settings.depthPortrait.status),
            evidence("zoomLens", settings.zoomLens.status),
            evidence("framing", settings.framing.status),
            evidence("captureQuality", settings.captureQuality.status),
            evidence("flashLowLightPolicy", settings.flashLowLightPolicy.status)
        ]
    }

    private func evidence(_ parameter: String, _ status: FinalMomentCapabilityStatus) -> FinalMomentCameraStatusEvidence {
        let adjustment: Double
        switch status {
        case .applied, .locked:
            adjustment = 0.04
        case .available:
            adjustment = 0.02
        case .adjusted:
            adjustment = -0.02
        case .unavailable:
            adjustment = -0.06
        case .needsOperatorAdjustment:
            adjustment = -0.08
        case .notRequested:
            adjustment = 0.0
        }

        return FinalMomentCameraStatusEvidence(
            parameter: parameter,
            status: status,
            confidenceAdjustment: adjustment,
            provenanceNote: "\(parameter).\(status.rawValue)"
        )
    }

    private func recoverableEnhancements(
        input: FinalMomentFrameAssessmentInput,
        nonRecoverableFailures: [FinalMomentAssessmentFailure]
    ) -> [FinalMomentRecoverableEnhancement] {
        let failureSet = Set(nonRecoverableFailures)
        if failureSet.contains(.missedFocus)
            || failureSet.contains(.closedEyes)
            || failureSet.contains(.unusableFaceLight)
            || failureSet.contains(.deadExpression)
            || failureSet.contains(.absentInteraction)
            || failureSet.contains(.tooTightCapture)
            || failureSet.contains(.protectedSubjectMissing)
            || failureSet.contains(.missingAsset)
            || failureSet.contains(.corruptAsset)
            || failureSet.contains(.unreadableMetadata) {
            return []
        }

        var enhancements: [FinalMomentRecoverableEnhancement] = []
        for eligibility in input.capturedAffordanceMetadata.postCaptureFineTuneEligible {
            switch eligibility {
            case "portfolio_color_tone":
                enhancements.append(.portfolioColorTone)
            case "crop_composition":
                enhancements.append(.cropComposition)
            case "light_shadow_contrast":
                enhancements.append(.lightShadowContrast)
            case "local_crispness":
                enhancements.append(.localCrispness)
            case "background_readability":
                enhancements.append(.backgroundReadability)
            case "subject_separation":
                enhancements.append(.subjectSeparation)
            default:
                continue
            }
        }

        if input.capturedAffordanceMetadata.rimHairEdgeLightPreserved {
            enhancements.append(.rimLightEmphasis)
        }

        if input.capturedAffordanceMetadata.projectedShadowPatternPreserved {
            enhancements.append(.shadowPatternEmphasis)
        }

        return uniqueEnhancements(enhancements)
    }

    private func uniqueFailures(_ values: [FinalMomentAssessmentFailure]) -> [FinalMomentAssessmentFailure] {
        var seen: Set<FinalMomentAssessmentFailure> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func uniqueEnhancements(_ values: [FinalMomentRecoverableEnhancement]) -> [FinalMomentRecoverableEnhancement] {
        var seen: Set<FinalMomentRecoverableEnhancement> = []
        return values.filter { seen.insert($0).inserted }
    }
}
