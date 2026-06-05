import Foundation

enum PhoneTestFrameSignalSource: String, Codable, Equatable {
    case iosMinimalFrameSignals = "ios_minimal_frame_signals"
    case deterministicLocalFallback = "deterministic_local_fallback"
}

enum PhoneTestRoughSubjectPosition: String, Codable, Equatable {
    case centered
    case leftEdge = "left_edge"
    case rightEdge = "right_edge"
    case tooLow = "too_low"
    case tooHigh = "too_high"
    case unknown
}

struct PhoneTestFrameSignals: Codable, Equatable {
    let source: PhoneTestFrameSignalSource
    let frameId: String?
    let observedAt: String?
    let protectedSubjectsVisible: Bool?
    let faceVisibilityConfidence: Double?
    let brightnessScore: Double?
    let isTooDark: Bool?
    let isOverexposed: Bool?
    let sharpnessScore: Double?
    let isBlurry: Bool?
    let hasCropHeadroom: Bool?
    let cropHeadroomScore: Double?
    let roughSubjectPosition: PhoneTestRoughSubjectPosition?
    let expressionOrInteractionObserved: Bool?
    let lightChangedFromSceneAnalysis: Bool?
    let detectedAffordances: [SceneRuntimeModels.RuntimeAffordanceSignalType]?
    let nativeCapabilities: SceneRuntimeModels.NativeCameraCapabilities?

    init(
        source: PhoneTestFrameSignalSource,
        frameId: String? = nil,
        observedAt: String? = nil,
        protectedSubjectsVisible: Bool? = nil,
        faceVisibilityConfidence: Double? = nil,
        brightnessScore: Double? = nil,
        isTooDark: Bool? = nil,
        isOverexposed: Bool? = nil,
        sharpnessScore: Double? = nil,
        isBlurry: Bool? = nil,
        hasCropHeadroom: Bool? = nil,
        cropHeadroomScore: Double? = nil,
        roughSubjectPosition: PhoneTestRoughSubjectPosition? = nil,
        expressionOrInteractionObserved: Bool? = nil,
        lightChangedFromSceneAnalysis: Bool? = nil,
        detectedAffordances: [SceneRuntimeModels.RuntimeAffordanceSignalType]? = nil,
        nativeCapabilities: SceneRuntimeModels.NativeCameraCapabilities? = nil
    ) {
        self.source = source
        self.frameId = frameId
        self.observedAt = observedAt
        self.protectedSubjectsVisible = protectedSubjectsVisible
        self.faceVisibilityConfidence = faceVisibilityConfidence
        self.brightnessScore = brightnessScore
        self.isTooDark = isTooDark
        self.isOverexposed = isOverexposed
        self.sharpnessScore = sharpnessScore
        self.isBlurry = isBlurry
        self.hasCropHeadroom = hasCropHeadroom
        self.cropHeadroomScore = cropHeadroomScore
        self.roughSubjectPosition = roughSubjectPosition
        self.expressionOrInteractionObserved = expressionOrInteractionObserved
        self.lightChangedFromSceneAnalysis = lightChangedFromSceneAnalysis
        self.detectedAffordances = detectedAffordances
        self.nativeCapabilities = nativeCapabilities
    }
}

struct PhoneTestLiveReadinessOutput: Codable, Equatable {
    let frameSource: PhoneTestFrameSignalSource
    let sourceLabel: String
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let liveReadinessAttemptId: String
    let liveFrameSummary: SceneRuntimeModels.LiveFrameSummary
    let captureReadiness: SceneRuntimeModels.Readiness
    let readinessScore: Double
    let blockingIssues: [String]
    let liveCoachingCues: [SceneRuntimeModels.CoachingCue]
    let subjectVisibilityState: String
    let protectedSubjectFocusState: String
    let faceLightState: String
    let cropHeadroomState: String
    let expressionInteractionState: String?
    let dynamicCameraSettingsAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    let cameraCapabilityStatus: [String: SceneRuntimeModels.CameraCapabilityStatus]
    let cameraCapabilityGaps: [String]
    let capturedAffordanceMetadataCandidate: SceneRuntimeModels.CapturedAffordanceMetadata
    let postCapturePrerequisiteStatus: [String: String]
    let cameraSettingsUsed: SceneRuntimeModels.CameraSettingsUsed?
    let canCaptureBestEffort: Bool
    let cameraSettingsApplicationStage: String
    let response: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse
}

enum PhoneTestFrameSignalAdapter {
    static func liveFrameSummary(
        from signals: PhoneTestFrameSignals,
        fallbackCapabilities: SceneRuntimeModels.NativeCameraCapabilities = conservativeFallbackCapabilities()
    ) -> SceneRuntimeModels.LiveFrameSummary {
        let subjectsVisible = protectedSubjectsVisible(signals)
        let focusState = protectedSubjectFocusState(signals, subjectsVisible: subjectsVisible)
        let exposureState = faceExposureState(signals, subjectsVisible: subjectsVisible)
        let expressionState = expressionInteractionState(signals)
        let headroomState = cropHeadroomState(signals)

        return SceneRuntimeModels.LiveFrameSummary(
            protectedSubjectsVisible: subjectsVisible,
            protectedSubjectFocusState: focusState,
            faceExposureState: exposureState,
            expressionInteractionState: expressionState,
            cropHeadroomState: headroomState,
            detectedAffordances: detectedAffordances(
                from: signals,
                focusState: focusState,
                expressionState: expressionState,
                cropHeadroomState: headroomState
            ),
            lightChangedFromSceneAnalysis: signals.lightChangedFromSceneAnalysis,
            nativeCapabilities: signals.nativeCapabilities ?? fallbackCapabilities
        )
    }

    static func noVisionDataFallback(
        nativeCapabilities: SceneRuntimeModels.NativeCameraCapabilities? = nil
    ) -> SceneRuntimeModels.LiveFrameSummary {
        liveFrameSummary(
            from: PhoneTestFrameSignals(
                source: .deterministicLocalFallback,
                nativeCapabilities: nativeCapabilities
            )
        )
    }

    static func liveReadiness(
        from signals: PhoneTestFrameSignals,
        scenePlanOutput: PhoneTestScenePlanOutput,
        evaluator: LiveCoachEvaluator = LiveCoachEvaluator(),
        bestEffortAllowed: Bool = true
    ) async throws -> PhoneTestLiveReadinessOutput {
        let summary = liveFrameSummary(from: signals)
        return try await liveReadiness(
            from: summary,
            frameSource: signals.source,
            scenePlanOutput: scenePlanOutput,
            evaluator: evaluator,
            bestEffortAllowed: bestEffortAllowed
        )
    }

    static func noVisionLiveReadiness(
        scenePlanOutput: PhoneTestScenePlanOutput,
        nativeCapabilities: SceneRuntimeModels.NativeCameraCapabilities? = nil,
        evaluator: LiveCoachEvaluator = LiveCoachEvaluator(),
        bestEffortAllowed: Bool = true
    ) async throws -> PhoneTestLiveReadinessOutput {
        let signals = PhoneTestFrameSignals(
            source: .deterministicLocalFallback,
            nativeCapabilities: nativeCapabilities
        )
        return try await liveReadiness(
            from: signals,
            scenePlanOutput: scenePlanOutput,
            evaluator: evaluator,
            bestEffortAllowed: bestEffortAllowed
        )
    }

    private static func liveReadiness(
        from summary: SceneRuntimeModels.LiveFrameSummary,
        frameSource: PhoneTestFrameSignalSource,
        scenePlanOutput: PhoneTestScenePlanOutput,
        evaluator: LiveCoachEvaluator,
        bestEffortAllowed: Bool
    ) async throws -> PhoneTestLiveReadinessOutput {
        let request = SceneRuntimeModels.EvaluateLiveFrameReadinessRequest(
            scenePlanId: scenePlanOutput.scenePlanId,
            styleProfileId: scenePlanOutput.scenePlan.styleProfileId,
            protectedSubjectSetId: scenePlanOutput.scenePlan.protectedSubjectSetId,
            initialCameraSettingsRecommendation: scenePlanOutput.initialCameraSettingsRecommendation,
            runtimeAffordanceSignals: scenePlanOutput.runtimeAffordanceSignals,
            postCapturePrerequisites: scenePlanOutput.postCapturePrerequisites,
            liveFrameSummary: summary
        )
        let evaluation = try await evaluator.evaluate(
            LiveCoachEvaluatorInput(
                request: request,
                bestEffortAllowed: bestEffortAllowed
            )
        )
        let response = evaluation.response

        return PhoneTestLiveReadinessOutput(
            frameSource: frameSource,
            sourceLabel: "source = \(frameSource.rawValue)",
            scenePlanId: scenePlanOutput.scenePlanId,
            styleProfileId: scenePlanOutput.scenePlan.styleProfileId,
            protectedSubjectSetId: scenePlanOutput.scenePlan.protectedSubjectSetId,
            liveReadinessAttemptId: evaluation.record.liveReadinessAttemptId,
            liveFrameSummary: summary,
            captureReadiness: response.readiness,
            readinessScore: response.score,
            blockingIssues: response.blockingIssues,
            liveCoachingCues: response.cues,
            subjectVisibilityState: summary.protectedSubjectsVisible ? "visible" : "missing",
            protectedSubjectFocusState: summary.protectedSubjectFocusState,
            faceLightState: summary.faceExposureState,
            cropHeadroomState: summary.cropHeadroomState,
            expressionInteractionState: summary.expressionInteractionState,
            dynamicCameraSettingsAdjustment: response.dynamicCameraSettingsAdjustment,
            cameraCapabilityStatus: response.dynamicCameraSettingsAdjustment.capabilityStatus,
            cameraCapabilityGaps: evaluation.record.capabilityGaps,
            capturedAffordanceMetadataCandidate: response.capturedAffordanceMetadata,
            postCapturePrerequisiteStatus: response.postCapturePrerequisiteStatus,
            cameraSettingsUsed: response.cameraSettingsUsed,
            canCaptureBestEffort: response.canCaptureBestEffort,
            cameraSettingsApplicationStage: "live_coach_native_adapter_evaluated_camera_settings_used_waits_for_final_capture",
            response: response
        )
    }

    static func conservativeFallbackCapabilities() -> SceneRuntimeModels.NativeCameraCapabilities {
        SceneRuntimeModels.NativeCameraCapabilities(
            canLockFocus: false,
            canSetFocusPoint: false,
            canSetExposurePoint: false,
            canSetExposureBias: false,
            canLockWhiteBalance: false,
            canSetWhiteBalanceGains: false,
            canUseDepth: false,
            canDeliverDepthData: false,
            canDeliverPortraitEffectsMatte: false,
            availableLenses: ["wide"],
            minZoomFactor: 1.0,
            maxOpticalZoomFactor: 1.0,
            maxAcceptableDigitalZoomFactor: 1.0,
            canSetPhotoQualityPrioritization: false,
            canCaptureBurst: false,
            canUseHighestPracticalResolution: false,
            canControlFlash: false,
            canUseTorch: false
        )
    }

    private static func protectedSubjectsVisible(_ signals: PhoneTestFrameSignals) -> Bool {
        if signals.source == .deterministicLocalFallback {
            return false
        }
        if let protectedSubjectsVisible = signals.protectedSubjectsVisible {
            return protectedSubjectsVisible
        }
        if let confidence = signals.faceVisibilityConfidence {
            return confidence >= 0.45
        }
        return false
    }

    private static func protectedSubjectFocusState(
        _ signals: PhoneTestFrameSignals,
        subjectsVisible: Bool
    ) -> String {
        guard subjectsVisible else {
            return "missing_protected_subject"
        }
        if signals.isBlurry == true {
            return "soft"
        }
        guard let sharpnessScore = signals.sharpnessScore else {
            return "weak_unknown_no_focus_signal"
        }
        if sharpnessScore >= 0.70 {
            return "locked"
        }
        if sharpnessScore < 0.35 {
            return "soft"
        }
        return "weak_searching"
    }

    private static func faceExposureState(
        _ signals: PhoneTestFrameSignals,
        subjectsVisible: Bool
    ) -> String {
        guard subjectsVisible else {
            return "missing_protected_subject"
        }
        if signals.isTooDark == true {
            return "too_dark"
        }
        if signals.isOverexposed == true {
            return "overexposed"
        }
        guard let brightnessScore = signals.brightnessScore else {
            return "weak_unknown_no_brightness_signal"
        }
        if brightnessScore < 0.18 {
            return "too_dark"
        }
        if brightnessScore > 0.92 {
            return "overexposed"
        }
        if brightnessScore >= 0.35 && brightnessScore <= 0.85 {
            return "usable"
        }
        return "recoverable_weak_light"
    }

    private static func expressionInteractionState(_ signals: PhoneTestFrameSignals) -> String {
        if signals.expressionOrInteractionObserved == true {
            return "natural_observed"
        }
        if signals.source == .deterministicLocalFallback {
            return "not_observed_no_vision_data"
        }
        return "neutral_forming"
    }

    private static func cropHeadroomState(_ signals: PhoneTestFrameSignals) -> String {
        if signals.hasCropHeadroom == false {
            return "too_tight"
        }
        if signals.hasCropHeadroom == true {
            return "available"
        }
        if let score = signals.cropHeadroomScore {
            if score >= 0.65 {
                return "available"
            }
            if score < 0.30 {
                return "too_tight"
            }
            return "tight"
        }
        switch signals.roughSubjectPosition {
        case .leftEdge, .rightEdge, .tooHigh, .tooLow:
            return "tight"
        case .centered:
            return "available"
        case .unknown, nil:
            return "unknown"
        }
    }

    private static func detectedAffordances(
        from signals: PhoneTestFrameSignals,
        focusState: String,
        expressionState: String,
        cropHeadroomState: String
    ) -> [SceneRuntimeModels.RuntimeAffordanceSignalType]? {
        if signals.source == .deterministicLocalFallback {
            return nil
        }
        if let detectedAffordances = signals.detectedAffordances {
            return detectedAffordances
        }

        var derived: [SceneRuntimeModels.RuntimeAffordanceSignalType] = []
        if cropHeadroomState == "available" {
            derived.append(.cropHeadroomAvailable)
        }
        if focusState == "locked" {
            derived.append(.focusDepthOpportunity)
        }
        if expressionState == "natural_observed" {
            derived.append(.naturalMotionOpportunity)
        }
        return derived.isEmpty ? nil : derived
    }
}
