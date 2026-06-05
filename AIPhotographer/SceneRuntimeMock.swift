import Foundation

enum SceneRuntimeContract {
    struct RuntimeStyleProfileInput: Codable, Equatable {
        let styleProfileId: String
        let styleProfile: StyleProfile
    }

    struct StyleProfile: Codable, Equatable {
        let styleProfileId: String
        let profileSource: String
        let runtimeVersion: String
        let scenePlanningWeights: ScenePlanningWeights
        let composition: CompositionProfile
        let light: LightProfile
        let captureBehavior: CaptureBehavior
        let preset: PresetProfile
    }

    struct ScenePlanningWeights: Codable, Equatable {
        let composition: Double
        let light: Double
        let depth: Double
    }

    struct CompositionProfile: Codable, Equatable {
        let subjectScale: String
        let anchorPreference: String
        let negativeSpace: String
        let framingDevices: [String]
    }

    struct LightProfile: Codable, Equatable {
        let preferredDirection: String
        let contrastTolerance: String
        let dramaticLightAllowed: Bool
    }

    struct CaptureBehavior: Codable, Equatable {
        let burstCount: Int
        let gestureStyle: String
    }

    struct PresetProfile: Codable, Equatable {
        let presetId: String
    }

    struct ProtectedSubjectSet: Codable, Equatable {
        let protectedSubjectSetId: String
        let protectedSubjectCount: Int
        let subjects: [ProtectedSubject]
        let rules: ProtectedSubjectRules
        let ignoredDetections: [IgnoredDetection]
    }

    struct ProtectedSubject: Codable, Equatable {
        let subjectId: String
        let role: String
        let displayLabel: String
        let includedInSubjectCount: Bool
        let facingCamera: Bool
    }

    struct ProtectedSubjectRules: Codable, Equatable {
        let mustKeepAllInFrame: Bool
        let closedEyesRejectFrame: Bool
        let focusAllSubjects: Bool
    }

    struct IgnoredDetection: Codable, Equatable {
        let reason: String
        let countsAsProtectedSubject: Bool
    }

    struct CreateSceneInputRequest: Codable, Equatable {
        let sessionId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputAttemptId: String
        let sceneInputMode: SceneInputMode
        let mediaRefs: [String]
        let uploadAnyway: Bool
    }

    struct CreateSceneInputResponse: Codable, Equatable {
        let sceneInputId: String
        let sceneInputAttemptId: String
        let sceneAnalysisId: String?
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
    }

    enum SceneInputMode: String, Codable {
        case scanVideo = "scan_video"
        case singlePhoto = "single_photo"
    }

    enum SceneInputStatus: String, Codable {
        case accepted
        case acceptedSuboptimal = "accepted_suboptimal"
        case rejectedRetryRequired = "rejected_retry_required"
        case uploadFailed = "upload_failed"
    }

    struct SceneInputQualityContext: Codable, Equatable {
        let sceneInputMode: SceneInputMode
        let sceneInputStatus: SceneInputStatus
        let allowsSuboptimalSceneInput: Bool
        let sceneInputFailureReason: SceneInputFailureReason?
        let qualitySignals: SceneInputQualitySignals?
    }

    struct SceneInputFailureReason: Codable, Equatable {
        let code: String
        let message: String
        let retryAction: String
        let uploadAnywayChosen: Bool
    }

    struct SceneInputQualitySignals: Codable, Equatable {
        let tooDark: Bool
        let overexposed: Bool
        let motionBlur: Bool
        let scanTooShort: Bool
        let noUsefulCompositionSpace: Bool
    }

    struct GenerateScenePlanRequest: Codable, Equatable {
        let sceneAnalysisId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
    }

    struct GenerateScenePlanResponse: Codable, Equatable {
        let scenePlanId: String
        let sceneAnalysisId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
        let sceneMatchType: SceneMatchType
        let standPoint: LabeledDescription
        let subjectPosition: SubjectPosition
        let operatorPosition: OperatorPosition
        let facingDirection: FacingDirection
        let roughFraming: RoughFraming
        let coachingCues: [CoachingCue]
        let initialCameraSettingsRecommendation: InitialCameraSettingsRecommendation
        let fallback: ScenePlanFallback?
    }

    enum SceneMatchType: String, Codable {
        case referenceMatch = "reference_match"
        case styleSynthesis = "style_synthesis"
        case bestEffortFallback = "best_effort_fallback"
    }

    struct LabeledDescription: Codable, Equatable {
        let label: String
        let description: String
    }

    struct SubjectPosition: Codable, Equatable {
        let zone: String
        let distanceCue: String
    }

    struct OperatorPosition: Codable, Equatable {
        let distanceCue: String
        let heightCue: String
        let framingCue: String
    }

    struct FacingDirection: Codable, Equatable {
        let subjectCue: String
        let operatorCue: String
    }

    struct RoughFraming: Codable, Equatable {
        let style: String
        let safetyMargin: String
        let orientation: String
    }

    struct CoachingCue: Codable, Equatable {
        let target: String
        let message: String
    }

    struct InitialCameraSettingsRecommendation: Codable, Equatable {
        let recommendationId: String
        let focus: FocusRecommendation
        let exposure: ExposureRecommendation
        let whiteBalance: WhiteBalanceRecommendation
        let depth: DepthRecommendation
        let framing: FramingRecommendation
        let colorAndTonePreview: ColorAndTonePreview
        let capture: CaptureRecommendation
    }

    struct FocusRecommendation: Codable, Equatable {
        let target: String
        let mode: String
        let priority: String
    }

    struct ExposureRecommendation: Codable, Equatable {
        let meteringTarget: String
        let bias: Double
        let protectHighlights: Bool
        let avoidFaceClipping: Bool
    }

    struct WhiteBalanceRecommendation: Codable, Equatable {
        let mode: String
        let lockWhenReady: Bool
    }

    struct DepthRecommendation: Codable, Equatable {
        let mode: String
        let portraitBlurStrength: Double
        let keepArchitecturalAnchorReadable: Bool
    }

    struct FramingRecommendation: Codable, Equatable {
        let shootWide: Bool
        let safetyMargin: String
        let orientation: String
        let compositionTarget: String
    }

    struct ColorAndTonePreview: Codable, Equatable {
        let contrast: String
        let saturation: String
        let highlightRecovery: String
    }

    struct CaptureRecommendation: Codable, Equatable {
        let burstCount: Int
        let highestPracticalResolution: Bool
    }

    struct ScenePlanFallback: Codable, Equatable {
        let type: String
        let message: String
        let nextAction: String
        let canContinueBestEffort: Bool
    }

    struct EvaluateLiveFrameReadinessRequest: Codable, Equatable {
        let scenePlanId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let initialCameraSettingsRecommendationId: String
        let liveFrameSummary: LiveFrameSummary
    }

    struct LiveFrameSummary: Codable, Equatable {
        let protectedSubjectsVisible: Bool
        let operatorTooClose: Bool
        let faceHighlightsNearClipping: Bool
        let lightChangedFromSceneAnalysis: Bool
        let nativeCapabilities: NativeCameraCapabilities
    }

    struct NativeCameraCapabilities: Codable, Equatable {
        let canLockFocus: Bool
        let canSetExposureBias: Bool
        let canLockWhiteBalance: Bool
        let canUseDepth: Bool
        let canCaptureBurst: Bool
        let canUseHighestPracticalResolution: Bool
    }

    struct EvaluateLiveFrameReadinessResponse: Codable, Equatable {
        let scenePlanId: String
        let readiness: ReadinessState
        let score: Double
        let blockingIssues: [String]
        let cues: [CoachingCue]
        let dynamicCameraSettingsAdjustment: DynamicCameraSettingsAdjustment
        let cameraSettingsUsed: CameraSettingsUsed?
        let canCaptureBestEffort: Bool
    }

    enum ReadinessState: String, Codable {
        case coaching
        case ready
        case bestEffort = "best_effort"
        case blocked
    }

    struct DynamicCameraSettingsAdjustment: Codable, Equatable {
        let focus: CameraAdjustment
        let exposure: CameraAdjustment
        let whiteBalance: CameraAdjustment
        let depth: CameraAdjustment
        let framing: CameraAdjustment
        let capture: CameraAdjustment
    }

    struct CameraAdjustment: Codable, Equatable {
        let status: CameraCapabilityStatus
        let value: String
        let reason: String?
        let capabilityGap: String?
    }

    enum CameraCapabilityStatus: String, Codable {
        case applied
        case adjusted
        case unavailable
        case needsOperatorAdjustment = "needs_operator_adjustment"
        case pending
    }

    struct CameraSettingsUsed: Codable, Equatable {
        let settingsId: String
        let appliedRecommendationId: String
        let focusModeUsed: String
        let exposureBiasUsed: Double
        let whiteBalanceModeUsed: String
        let depthModeUsed: String
        let burstCountRequested: Int
        let burstCountCaptured: Int
        let highestPracticalResolutionUsed: Bool
        let capabilityGaps: [String]
    }

    struct BeforeCaptureFinalMomentHandoff: Codable, Equatable {
        let scenePlanId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
        let initialCameraSettingsRecommendation: InitialCameraSettingsRecommendation
        let cameraSettingsUsed: CameraSettingsUsed
    }
}

struct MockSceneRuntimeService {
    typealias Contract = SceneRuntimeContract

    func runtimeStyleProfileInput() -> Contract.RuntimeStyleProfileInput {
        Contract.RuntimeStyleProfileInput(
            styleProfileId: "style_profile_campus_editorial_v1",
            styleProfile: Contract.StyleProfile(
                styleProfileId: "style_profile_campus_editorial_v1",
                profileSource: "curated_portfolio_library",
                runtimeVersion: "2026-06-03.runtime.v1",
                scenePlanningWeights: Contract.ScenePlanningWeights(composition: 0.5, light: 0.35, depth: 0.15),
                composition: Contract.CompositionProfile(
                    subjectScale: "environment_dominant",
                    anchorPreference: "high",
                    negativeSpace: "medium",
                    framingDevices: ["arches", "landmark", "leading_lines"]
                ),
                light: Contract.LightProfile(
                    preferredDirection: "mixed",
                    contrastTolerance: "medium_high",
                    dramaticLightAllowed: true
                ),
                captureBehavior: Contract.CaptureBehavior(burstCount: 10, gestureStyle: "natural_motion"),
                preset: Contract.PresetProfile(presetId: "warm_editorial")
            )
        )
    }

    func protectedSubjectSet() -> Contract.ProtectedSubjectSet {
        Contract.ProtectedSubjectSet(
            protectedSubjectSetId: "subject_set_001",
            protectedSubjectCount: 2,
            subjects: [
                Contract.ProtectedSubject(
                    subjectId: "subject_1",
                    role: "primary",
                    displayLabel: "Person 1",
                    includedInSubjectCount: true,
                    facingCamera: true
                ),
                Contract.ProtectedSubject(
                    subjectId: "subject_2",
                    role: "secondary",
                    displayLabel: "Person 2",
                    includedInSubjectCount: true,
                    facingCamera: true
                )
            ],
            rules: Contract.ProtectedSubjectRules(
                mustKeepAllInFrame: true,
                closedEyesRejectFrame: true,
                focusAllSubjects: true
            ),
            ignoredDetections: [
                Contract.IgnoredDetection(
                    reason: "background_person_not_facing_camera",
                    countsAsProtectedSubject: false
                )
            ]
        )
    }

    func createAcceptedSceneInput(mode: Contract.SceneInputMode = .scanVideo) -> Contract.CreateSceneInputResponse {
        Contract.CreateSceneInputResponse(
            sceneInputId: "scene_input_001",
            sceneInputAttemptId: mode == .scanVideo ? "scene_scan_attempt_001" : "scene_photo_attempt_001",
            sceneAnalysisId: "scene_analysis_001",
            styleProfileId: "style_profile_campus_editorial_v1",
            protectedSubjectSetId: "subject_set_001",
            sceneInputQualityContext: Contract.SceneInputQualityContext(
                sceneInputMode: mode,
                sceneInputStatus: .accepted,
                allowsSuboptimalSceneInput: false,
                sceneInputFailureReason: nil,
                qualitySignals: Contract.SceneInputQualitySignals(
                    tooDark: false,
                    overexposed: false,
                    motionBlur: false,
                    scanTooShort: false,
                    noUsefulCompositionSpace: false
                )
            )
        )
    }

    func createUploadAnywaySceneInput() -> Contract.CreateSceneInputResponse {
        Contract.CreateSceneInputResponse(
            sceneInputId: "scene_input_suboptimal_001",
            sceneInputAttemptId: "scene_photo_attempt_001",
            sceneAnalysisId: "scene_analysis_suboptimal_001",
            styleProfileId: "style_profile_campus_editorial_v1",
            protectedSubjectSetId: "subject_set_001",
            sceneInputQualityContext: Contract.SceneInputQualityContext(
                sceneInputMode: .singlePhoto,
                sceneInputStatus: .acceptedSuboptimal,
                allowsSuboptimalSceneInput: true,
                sceneInputFailureReason: Contract.SceneInputFailureReason(
                    code: "overexposed",
                    message: "The scene photo has bright highlights that may clip faces.",
                    retryAction: "Retake the photo in open shade.",
                    uploadAnywayChosen: true
                ),
                qualitySignals: Contract.SceneInputQualitySignals(
                    tooDark: false,
                    overexposed: true,
                    motionBlur: false,
                    scanTooShort: false,
                    noUsefulCompositionSpace: false
                )
            )
        )
    }

    func generateScenePlan(
        from sceneInput: Contract.CreateSceneInputResponse
    ) -> Contract.GenerateScenePlanResponse {
        let isSuboptimal = sceneInput.sceneInputQualityContext.allowsSuboptimalSceneInput
        let recommendation = initialCameraSettingsRecommendation(
            id: isSuboptimal ? "camera_rec_demo_suboptimal" : "camera_rec_demo_normal",
            exposureBias: isSuboptimal ? -0.7 : -0.3,
            portraitBlurStrength: isSuboptimal ? 0.1 : 0.2
        )

        return Contract.GenerateScenePlanResponse(
            scenePlanId: isSuboptimal ? "scene_plan_demo_suboptimal" : "scene_plan_demo_normal",
            sceneAnalysisId: sceneInput.sceneAnalysisId ?? "scene_analysis_missing",
            styleProfileId: sceneInput.styleProfileId,
            protectedSubjectSetId: sceneInput.protectedSubjectSetId,
            sceneInputQualityContext: sceneInput.sceneInputQualityContext,
            sceneMatchType: isSuboptimal ? .bestEffortFallback : .styleSynthesis,
            standPoint: Contract.LabeledDescription(
                label: isSuboptimal ? "nearest shade edge" : "shadow edge near the arch",
                description: isSuboptimal
                    ? "Use the least harsh available light; expect lower confidence."
                    : "Soft side light and clean depth fit the adopted portfolio."
            ),
            subjectPosition: Contract.SubjectPosition(
                zone: isSuboptimal ? "nearest_open_shade" : "lower_left_third",
                distanceCue: isSuboptimal ? "stand just inside shade" : "stand 6-8 feet from the arch"
            ),
            operatorPosition: Contract.OperatorPosition(
                distanceCue: "step back two steps",
                heightCue: "hold camera at chest height",
                framingCue: "keep the full arch and floor line in frame"
            ),
            facingDirection: Contract.FacingDirection(
                subjectCue: isSuboptimal ? "turn faces away from direct sun" : "turn faces slightly toward side light",
                operatorCue: "shoot toward the corridor depth"
            ),
            roughFraming: Contract.RoughFraming(
                style: "wide_environmental",
                safetyMargin: "high",
                orientation: "vertical"
            ),
            coachingCues: [
                Contract.CoachingCue(target: "operator", message: "Step back two steps to preserve the architecture."),
                Contract.CoachingCue(
                    target: "subject",
                    message: isSuboptimal
                        ? "Move into shade and keep faces away from direct sun."
                        : "Walk slowly toward each other and keep faces toward the soft light."
                )
            ],
            initialCameraSettingsRecommendation: recommendation,
            fallback: isSuboptimal
                ? Contract.ScenePlanFallback(
                    type: "bad_light",
                    message: "The current light is likely too harsh on faces.",
                    nextAction: "Move subjects into open shade or continue best-effort.",
                    canContinueBestEffort: true
                )
                : nil
        )
    }

    func evaluateLiveFrameReadiness(
        scenePlan: Contract.GenerateScenePlanResponse,
        capabilities: Contract.NativeCameraCapabilities = Contract.NativeCameraCapabilities(
            canLockFocus: true,
            canSetExposureBias: true,
            canLockWhiteBalance: true,
            canUseDepth: true,
            canCaptureBurst: true,
            canUseHighestPracticalResolution: true
        )
    ) -> Contract.EvaluateLiveFrameReadinessResponse {
        let hasCapabilityGap = !capabilities.canUseDepth || !capabilities.canCaptureBurst

        return Contract.EvaluateLiveFrameReadinessResponse(
            scenePlanId: scenePlan.scenePlanId,
            readiness: scenePlan.fallback == nil ? .coaching : .bestEffort,
            score: scenePlan.fallback == nil ? 0.72 : 0.58,
            blockingIssues: scenePlan.fallback == nil ? ["operator_too_close"] : ["harsh_face_light"],
            cues: [
                Contract.CoachingCue(
                    target: scenePlan.fallback == nil ? "operator" : "subject",
                    message: scenePlan.fallback == nil
                        ? "Step back until the full arch appears."
                        : "Move farther into shade before capture."
                )
            ],
            dynamicCameraSettingsAdjustment: Contract.DynamicCameraSettingsAdjustment(
                focus: Contract.CameraAdjustment(
                    status: capabilities.canLockFocus ? .applied : .unavailable,
                    value: capabilities.canLockFocus ? "locked_on_subject_1_subject_2" : "continuous_auto_focus",
                    reason: nil,
                    capabilityGap: capabilities.canLockFocus ? nil : "focus_lock_unavailable"
                ),
                exposure: Contract.CameraAdjustment(
                    status: capabilities.canSetExposureBias ? .adjusted : .unavailable,
                    value: scenePlan.fallback == nil ? "-0.4" : "-0.7",
                    reason: "face_highlights_near_clipping",
                    capabilityGap: capabilities.canSetExposureBias ? nil : "exposure_bias_unavailable"
                ),
                whiteBalance: Contract.CameraAdjustment(
                    status: capabilities.canLockWhiteBalance ? .applied : .unavailable,
                    value: "warm_daylight",
                    reason: nil,
                    capabilityGap: capabilities.canLockWhiteBalance ? nil : "white_balance_lock_unavailable"
                ),
                depth: Contract.CameraAdjustment(
                    status: capabilities.canUseDepth ? .applied : .unavailable,
                    value: capabilities.canUseDepth ? "environmental_depth" : "depth_off",
                    reason: "preserve_architecture_readability",
                    capabilityGap: capabilities.canUseDepth ? nil : "depth_mode_unavailable"
                ),
                framing: Contract.CameraAdjustment(
                    status: .needsOperatorAdjustment,
                    value: "step_back_until_arch_visible",
                    reason: "operator_too_close",
                    capabilityGap: nil
                ),
                capture: Contract.CameraAdjustment(
                    status: hasCapabilityGap ? .adjusted : .applied,
                    value: capabilities.canCaptureBurst ? "burst_10_high_res" : "single_high_res",
                    reason: hasCapabilityGap ? "closest_available_capture_behavior" : nil,
                    capabilityGap: capabilities.canCaptureBurst ? nil : "burst_unavailable"
                )
            ),
            cameraSettingsUsed: nil,
            canCaptureBestEffort: true
        )
    }

    func finalMomentHandoff(
        scenePlan: Contract.GenerateScenePlanResponse,
        settingsId: String = "camera_used_001"
    ) -> Contract.BeforeCaptureFinalMomentHandoff {
        Contract.BeforeCaptureFinalMomentHandoff(
            scenePlanId: scenePlan.scenePlanId,
            styleProfileId: scenePlan.styleProfileId,
            protectedSubjectSetId: scenePlan.protectedSubjectSetId,
            sceneInputQualityContext: scenePlan.sceneInputQualityContext,
            initialCameraSettingsRecommendation: scenePlan.initialCameraSettingsRecommendation,
            cameraSettingsUsed: Contract.CameraSettingsUsed(
                settingsId: settingsId,
                appliedRecommendationId: scenePlan.initialCameraSettingsRecommendation.recommendationId,
                focusModeUsed: "continuous_face_priority",
                exposureBiasUsed: scenePlan.fallback == nil ? -0.4 : -0.7,
                whiteBalanceModeUsed: "warm_daylight_locked",
                depthModeUsed: scenePlan.fallback == nil ? "environmental_depth" : "environmental_depth_reduced",
                burstCountRequested: scenePlan.initialCameraSettingsRecommendation.capture.burstCount,
                burstCountCaptured: scenePlan.initialCameraSettingsRecommendation.capture.burstCount,
                highestPracticalResolutionUsed: true,
                capabilityGaps: []
            )
        )
    }

    private func initialCameraSettingsRecommendation(
        id: String,
        exposureBias: Double,
        portraitBlurStrength: Double
    ) -> Contract.InitialCameraSettingsRecommendation {
        Contract.InitialCameraSettingsRecommendation(
            recommendationId: id,
            focus: Contract.FocusRecommendation(
                target: "all_protected_subjects",
                mode: "continuous_then_lock_when_ready",
                priority: "faces_and_bodies"
            ),
            exposure: Contract.ExposureRecommendation(
                meteringTarget: "protected_subject_faces",
                bias: exposureBias,
                protectHighlights: true,
                avoidFaceClipping: true
            ),
            whiteBalance: Contract.WhiteBalanceRecommendation(
                mode: "warm_daylight",
                lockWhenReady: true
            ),
            depth: Contract.DepthRecommendation(
                mode: "environmental_depth",
                portraitBlurStrength: portraitBlurStrength,
                keepArchitecturalAnchorReadable: true
            ),
            framing: Contract.FramingRecommendation(
                shootWide: true,
                safetyMargin: "high",
                orientation: "vertical",
                compositionTarget: "wide_environmental"
            ),
            colorAndTonePreview: Contract.ColorAndTonePreview(
                contrast: "medium",
                saturation: "slightly_warm",
                highlightRecovery: "moderate"
            ),
            capture: Contract.CaptureRecommendation(
                burstCount: 10,
                highestPracticalResolution: true
            )
        )
    }
}
