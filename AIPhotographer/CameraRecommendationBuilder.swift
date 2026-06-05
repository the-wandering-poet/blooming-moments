import Foundation

enum CameraRecommendationBuilderSchema {
    static let currentVersion = "2026-06-04.camera-recommendation-builder.v1"
    static let maximumSafeDigitalZoomFactor = 3.0
}

enum CameraRecommendationBuilderError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case validationFailed(fieldPath: String, message: String)
    case missingNativeCameraParameterIntent(styleProfileId: String)
}

enum CameraRecommendationWarning: String, Codable, Equatable, Hashable {
    case unsupportedDepthPortraitBehavior = "unsupported_depth_portrait_behavior"
    case unsafeFlashPolicy = "unsafe_flash_policy"
    case excessiveDigitalZoomIntent = "excessive_digital_zoom_intent"
    case conflictingBurstHighResolutionPreference = "conflicting_burst_high_resolution_preference"
}

struct RuntimeCameraStyleProfileInput: Codable, Equatable {
    let styleProfileId: String
    let profileStatus: String
    let profileVersion: String
    let nativeCameraParameterIntent: SceneRuntimeModels.NativeCameraParameterIntent?
    let postCaptureFineTuneSignals: [SceneRuntimeModels.PostCaptureFineTuneSignal]
    let confidence: [String: Double]?

    init(
        styleProfile: SceneRuntimeModels.StyleProfile
    ) {
        styleProfileId = styleProfile.styleProfileId
        profileStatus = styleProfile.profileStatus
        profileVersion = styleProfile.profileVersion
        nativeCameraParameterIntent = styleProfile.nativeCameraParameterIntent
        postCaptureFineTuneSignals = styleProfile.postCaptureFineTuneSignals
        confidence = styleProfile.confidence
    }

    init(
        styleProfileId: String,
        profileStatus: String,
        profileVersion: String,
        nativeCameraParameterIntent: SceneRuntimeModels.NativeCameraParameterIntent?,
        postCaptureFineTuneSignals: [SceneRuntimeModels.PostCaptureFineTuneSignal],
        confidence: [String: Double]? = nil
    ) {
        self.styleProfileId = styleProfileId
        self.profileStatus = profileStatus
        self.profileVersion = profileVersion
        self.nativeCameraParameterIntent = nativeCameraParameterIntent
        self.postCaptureFineTuneSignals = postCaptureFineTuneSignals
        self.confidence = confidence
    }
}

struct CameraRecommendationBuilderInput: Codable, Equatable {
    let schemaVersion: String
    let sceneAnalysis: SceneAnalysisRecord
    let scenePlan: ScenePlanDraft
    let styleProfile: RuntimeCameraStyleProfileInput
    let protectedSubjectSetId: String

    init(
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion,
        sceneAnalysis: SceneAnalysisRecord,
        scenePlan: ScenePlanDraft,
        styleProfile: RuntimeCameraStyleProfileInput,
        protectedSubjectSetId: String
    ) {
        self.schemaVersion = schemaVersion
        self.sceneAnalysis = sceneAnalysis
        self.scenePlan = scenePlan
        self.styleProfile = styleProfile
        self.protectedSubjectSetId = protectedSubjectSetId
    }
}

struct InitialCameraSettingsRecommendationBuildResult: Codable, Equatable {
    let recommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation
    let warnings: [CameraRecommendationWarning]
    let fallbackNotes: [String]
    let requestedOnly: Bool
}

struct CameraRecommendationBuilder {
    func build(
        _ input: CameraRecommendationBuilderInput
    ) throws -> InitialCameraSettingsRecommendationBuildResult {
        try validate(input)
        guard let intent = input.styleProfile.nativeCameraParameterIntent else {
            throw CameraRecommendationBuilderError.missingNativeCameraParameterIntent(
                styleProfileId: input.styleProfile.styleProfileId
            )
        }

        let warningResult = warnings(for: intent)
        let faceLightUsable = input.sceneAnalysis.professionalHappyMomentAssessment.faceLightUsable
        let cropHeadroomFeasible = input.sceneAnalysis.professionalHappyMomentAssessment.cropHeadroomFeasible
        let hasArchitecturalAnchor = input.scenePlan.selectedAffordances.contains { $0.type == .architecturalAnchor }
        let hasRimOrShadow = input.scenePlan.selectedAffordances.contains {
            $0.type == .rimHairEdgeLight || $0.type == .projectedShadowPattern || $0.type == .dramaticSideLightUsable
        }
        let recommendation = SceneRuntimeModels.InitialCameraSettingsRecommendation(
            recommendationId: recommendationId(scenePlanId: input.scenePlan.scenePlanId),
            sourceNativeCameraParameterIntentId: "\(input.styleProfile.styleProfileId).native_camera_intent",
            focus: focusRecommendation(intent.focus),
            exposure: exposureRecommendation(intent.exposure, faceLightUsable: faceLightUsable),
            whiteBalance: whiteBalanceRecommendation(intent.whiteBalance),
            zoomLens: zoomLensRecommendation(
                intent.zoomLensFraming,
                cropHeadroomFeasible: cropHeadroomFeasible
            ),
            depth: depthRecommendation(
                intent.depthPortrait,
                hasArchitecturalAnchor: hasArchitecturalAnchor
            ),
            framing: framingRecommendation(
                intent.zoomLensFraming,
                scenePlan: input.scenePlan,
                cropHeadroomFeasible: cropHeadroomFeasible
            ),
            colorAndTonePreview: colorAndTonePreview(
                fineTuneSignals: input.styleProfile.postCaptureFineTuneSignals,
                hasRimOrShadow: hasRimOrShadow,
                faceLightUsable: faceLightUsable
            ),
            capture: captureRecommendation(intent.captureQuality),
            flashLowLight: flashLowLightRecommendation(
                intent.flashLowLightPolicy,
                faceLightUsable: faceLightUsable
            ),
            capabilityRequirements: capabilityRequirements(intent.capabilityPolicy)
        )

        return InitialCameraSettingsRecommendationBuildResult(
            recommendation: recommendation,
            warnings: warningResult.warnings,
            fallbackNotes: warningResult.fallbackNotes,
            requestedOnly: true
        )
    }

    private func validate(_ input: CameraRecommendationBuilderInput) throws {
        guard input.schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw CameraRecommendationBuilderError.unsupportedSchemaVersion(input.schemaVersion)
        }
        try requireNonEmpty(input.sceneAnalysis.sceneAnalysisId, fieldPath: "sceneAnalysis.sceneAnalysisId")
        try requireNonEmpty(input.scenePlan.scenePlanId, fieldPath: "scenePlan.scenePlanId")
        try requireNonEmpty(input.styleProfile.styleProfileId, fieldPath: "styleProfile.styleProfileId")
        try requireNonEmpty(input.protectedSubjectSetId, fieldPath: "protectedSubjectSetId")
        if input.scenePlan.styleProfileId != input.styleProfile.styleProfileId {
            throw CameraRecommendationBuilderError.validationFailed(
                fieldPath: "scenePlan.styleProfileId",
                message: "Scene plan and style profile IDs must match."
            )
        }
        if input.scenePlan.protectedSubjectSetId != input.protectedSubjectSetId {
            throw CameraRecommendationBuilderError.validationFailed(
                fieldPath: "scenePlan.protectedSubjectSetId",
                message: "Scene plan and protected subject set IDs must match."
            )
        }
    }

    private func requireNonEmpty(_ value: String, fieldPath: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CameraRecommendationBuilderError.validationFailed(
                fieldPath: fieldPath,
                message: "\(fieldPath) must not be empty."
            )
        }
    }

    private func focusRecommendation(
        _ intent: SceneRuntimeModels.FocusIntent
    ) -> SceneRuntimeModels.FocusRecommendation {
        SceneRuntimeModels.FocusRecommendation(
            target: intent.target == "protected_subject_group" ? "all_protected_subjects" : intent.target,
            mode: intent.modePreference,
            priority: "faces_and_bodies",
            focusPointStrategy: intent.focusPointStrategy
        )
    }

    private func exposureRecommendation(
        _ intent: SceneRuntimeModels.ExposureIntent,
        faceLightUsable: Bool
    ) -> SceneRuntimeModels.ExposureRecommendation {
        let baseBias = intent.biasPreference ?? 0
        let sceneBias = faceLightUsable ? -0.1 : -0.5
        return SceneRuntimeModels.ExposureRecommendation(
            meteringTarget: intent.meteringTarget,
            bias: rounded(max(-1.0, min(1.0, baseBias + sceneBias))),
            protectHighlights: intent.protectHighlights,
            avoidFaceClipping: intent.protectHighlights,
            avoidFaceShadowCrush: intent.avoidFaceShadowCrush
        )
    }

    private func whiteBalanceRecommendation(
        _ intent: SceneRuntimeModels.WhiteBalanceIntent
    ) -> SceneRuntimeModels.WhiteBalanceRecommendation {
        SceneRuntimeModels.WhiteBalanceRecommendation(
            mode: intent.modePreference,
            lockWhenReady: intent.lockWhenFaceLightReady,
            temperatureBias: intent.colorTemperatureBias,
            tintBias: "neutral"
        )
    }

    private func zoomLensRecommendation(
        _ intent: SceneRuntimeModels.ZoomLensFramingIntent,
        cropHeadroomFeasible: Bool
    ) -> SceneRuntimeModels.ZoomLensRecommendation {
        let requestedMaxZoom = intent.avoidDigitalZoomBeyond
        let maxDigitalZoom = min(
            requestedMaxZoom ?? CameraRecommendationBuilderSchema.maximumSafeDigitalZoomFactor,
            CameraRecommendationBuilderSchema.maximumSafeDigitalZoomFactor
        )
        return SceneRuntimeModels.ZoomLensRecommendation(
            preferredLens: intent.preferredLens,
            targetZoomFactor: intent.preferredLens == "ultra_wide" ? 0.5 : 1.0,
            maxDigitalZoomFactor: maxDigitalZoom,
            allowUltraWideIfOperatorTooClose: intent.allowUltraWideForTightSpaces,
            avoidLensSwitchDuringCapture: cropHeadroomFeasible
        )
    }

    private func depthRecommendation(
        _ intent: SceneRuntimeModels.DepthPortraitIntent,
        hasArchitecturalAnchor: Bool
    ) -> SceneRuntimeModels.DepthRecommendation {
        let mode: String
        if intent.keepEnvironmentReadable == true {
            mode = "environmental_depth"
        } else if intent.depthDataPreferred == true || intent.portraitEffectsMattePreferred == true {
            mode = "portrait_depth_requested"
        } else {
            mode = "standard_photo_depth_optional"
        }

        return SceneRuntimeModels.DepthRecommendation(
            mode: mode,
            portraitBlurStrength: blurStrength(intent.blurStrengthIntent),
            keepArchitecturalAnchorReadable: hasArchitecturalAnchor || intent.keepEnvironmentReadable == true,
            depthDataDeliveryPreferred: intent.depthDataPreferred,
            portraitEffectsMattePreferred: intent.portraitEffectsMattePreferred
        )
    }

    private func framingRecommendation(
        _ intent: SceneRuntimeModels.ZoomLensFramingIntent,
        scenePlan: ScenePlanDraft,
        cropHeadroomFeasible: Bool
    ) -> SceneRuntimeModels.FramingRecommendation {
        let orientation = scenePlan.guidance?.roughFraming.orientation ?? "vertical"
        let shootWide = intent.preserveCropHeadroom == true || cropHeadroomFeasible
        return SceneRuntimeModels.FramingRecommendation(
            shootWide: shootWide,
            safetyMargin: shootWide ? "high" : "medium",
            orientation: orientation == "portrait" ? "vertical" : orientation,
            compositionTarget: shootWide ? "wide_environmental" : "subject_safe"
        )
    }

    private func colorAndTonePreview(
        fineTuneSignals: [SceneRuntimeModels.PostCaptureFineTuneSignal],
        hasRimOrShadow: Bool,
        faceLightUsable: Bool
    ) -> SceneRuntimeModels.ColorAndTonePreview {
        let wantsColorTone = fineTuneSignals.contains(.portfolioColorTone)
        return SceneRuntimeModels.ColorAndTonePreview(
            contrast: faceLightUsable ? (hasRimOrShadow ? "medium_high" : "medium") : "low",
            saturation: wantsColorTone ? "slightly_warm" : "natural",
            highlightRecovery: faceLightUsable ? "moderate" : "strong"
        )
    }

    private func captureRecommendation(
        _ intent: SceneRuntimeModels.CaptureQualityIntent
    ) -> SceneRuntimeModels.CaptureRecommendation {
        SceneRuntimeModels.CaptureRecommendation(
            burstCount: intent.burstPreferred == true ? 10 : nil,
            highestPracticalResolution: intent.highResolutionPreferred,
            photoQualityPrioritization: intent.photoQualityPrioritization,
            captureResponsiveness: intent.captureResponsiveness ?? "balanced",
            stabilizationPreferred: true
        )
    }

    private func flashLowLightRecommendation(
        _ intent: SceneRuntimeModels.FlashLowLightPolicy,
        faceLightUsable: Bool
    ) -> SceneRuntimeModels.FlashLowLightRecommendation {
        let flashMode: String
        if intent.preferNaturalLight {
            flashMode = intent.flashAllowedOnlyForRecovery == true
                ? "off_unless_recovery_needed"
                : "off"
        } else {
            flashMode = "recovery_only"
        }
        return SceneRuntimeModels.FlashLowLightRecommendation(
            preferNaturalLight: intent.preferNaturalLight,
            flashMode: flashMode,
            torchAllowed: intent.torchAllowedOnlyForRecovery == true,
            lowLightRecoveryPolicy: faceLightUsable
                ? "protect_natural_light_before_flash"
                : "move_subjects_or_best_effort_before_flash"
        )
    }

    private func capabilityRequirements(
        _ policy: SceneRuntimeModels.CapabilityPolicy
    ) -> SceneRuntimeModels.CapabilityRequirements {
        SceneRuntimeModels.CapabilityRequirements(
            reportUnavailableSettings: policy.mustReportGaps,
            allowedFallbackBehavior: policy.allowClosestAvailableFallback
                ? "closest_available_with_explicit_gap_reporting"
                : "strict_report_without_substitution",
            statusValues: [.pending, .adjusted, .unavailable, .needsOperatorAdjustment]
        )
    }

    private func warnings(
        for intent: SceneRuntimeModels.NativeCameraParameterIntent
    ) -> (warnings: [CameraRecommendationWarning], fallbackNotes: [String]) {
        var warnings: [CameraRecommendationWarning] = []
        var notes: [String] = []

        if intent.depthPortrait.portraitEffectsMattePreferred == true,
           intent.depthPortrait.keepEnvironmentReadable == false {
            warnings.append(.unsupportedDepthPortraitBehavior)
            notes.append("Portrait matte request is kept as intent, but environment readability must be protected until capability gating.")
        }

        if intent.flashLowLightPolicy.preferNaturalLight == false,
           intent.flashLowLightPolicy.flashAllowedOnlyForRecovery != true {
            warnings.append(.unsafeFlashPolicy)
            notes.append("Flash is constrained to recovery-only policy; users are not asked to toggle flash manually.")
        }

        if let zoom = intent.zoomLensFraming.avoidDigitalZoomBeyond,
           zoom > CameraRecommendationBuilderSchema.maximumSafeDigitalZoomFactor {
            warnings.append(.excessiveDigitalZoomIntent)
            notes.append("Digital zoom intent is capped for quality; lens/framing fallback remains adapter-owned.")
        }

        if intent.captureQuality.burstPreferred == true,
           intent.captureQuality.highResolutionPreferred == true,
           intent.captureQuality.captureResponsiveness == "fast" {
            warnings.append(.conflictingBurstHighResolutionPreference)
            notes.append("Burst, high resolution, and fast responsiveness are requested together; adapter must capability-gate without silent drops.")
        }

        return (Array(Set(warnings)).sorted { $0.rawValue < $1.rawValue }, notes)
    }

    private func recommendationId(scenePlanId: String) -> String {
        "camera_rec_\(scenePlanId.replacingOccurrences(of: "scene_plan_", with: ""))"
    }

    private func blurStrength(_ value: String?) -> Double? {
        switch value {
        case "none":
            return 0
        case "subtle":
            return 0.2
        case "moderate":
            return 0.45
        case "strong":
            return 0.65
        default:
            return value == nil ? nil : 0.2
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
