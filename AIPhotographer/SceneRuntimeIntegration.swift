import Foundation

enum SceneRuntimeFrontendNativeIntegrationError: Error, Equatable {
    case productionServiceRequired
    case sceneAnalysisDidNotCreateJob
    case missingLiveReadinessResponse
}

struct SceneRuntimeFrontendCaptureContext: Codable, Equatable {
    let sessionId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let sceneInputAttemptId: String
    let sceneInputMode: SceneRuntimeModels.SceneInputMode
    let mediaRefs: [String]
    let uploadAnyway: Bool
    let qualitySignals: SceneRuntimeModels.SceneInputQualitySignals
    let uploadFailureReason: SceneRuntimeModels.SceneInputFailureReason?
}

struct SceneRuntimeSceneAnalysisDisplayState: Codable, Equatable {
    let scenePlanId: String?
    let title: String
    let subtitle: String
    let metrics: [SceneRuntimeDisplayMetric]
    let planCues: [SceneRuntimeModels.CoachingCue]

    init(scenePlan: SceneRuntimeModels.GenerateScenePlanResponse) {
        scenePlanId = scenePlan.scenePlanId
        title = scenePlan.standPoint.label
        subtitle = scenePlan.standPoint.description
        metrics = [
            SceneRuntimeDisplayMetric(
                icon: "sun.max",
                label: "Light",
                value: scenePlan.professionalHappyMomentAssessment.faceLightUsable ? "Usable" : "Caution"
            ),
            SceneRuntimeDisplayMetric(
                icon: "target",
                label: "Focus",
                value: scenePlan.professionalHappyMomentAssessment.protectedSubjectFocusFeasible ? "Feasible" : "Weak"
            ),
            SceneRuntimeDisplayMetric(
                icon: "square.3.layers.3d.down.right",
                label: "Headroom",
                value: scenePlan.professionalHappyMomentAssessment.cropHeadroomFeasible ? "Preserved" : "Tight"
            ),
            SceneRuntimeDisplayMetric(
                icon: "building.columns",
                label: "Affordances",
                value: "\(scenePlan.runtimeAffordanceSignals.count)"
            )
        ]
        planCues = scenePlan.coachingCues
    }

    static func pending(portfolioTitle: String) -> SceneRuntimeSceneAnalysisDisplayState {
        SceneRuntimeSceneAnalysisDisplayState(
            scenePlanId: nil,
            title: "Reading \(portfolioTitle)",
            subtitle: "Checking light, protected-subject focus, crop headroom, and scene affordances.",
            metrics: [
                SceneRuntimeDisplayMetric(icon: "sun.max", label: "Light", value: "Checking"),
                SceneRuntimeDisplayMetric(icon: "target", label: "Focus", value: "Checking"),
                SceneRuntimeDisplayMetric(icon: "square.3.layers.3d.down.right", label: "Headroom", value: "Checking"),
                SceneRuntimeDisplayMetric(icon: "building.columns", label: "Affordances", value: "Checking")
            ],
            planCues: []
        )
    }

    private init(
        scenePlanId: String?,
        title: String,
        subtitle: String,
        metrics: [SceneRuntimeDisplayMetric],
        planCues: [SceneRuntimeModels.CoachingCue]
    ) {
        self.scenePlanId = scenePlanId
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.planCues = planCues
    }
}

struct SceneRuntimeDisplayMetric: Codable, Equatable {
    let icon: String
    let label: String
    let value: String
}

struct SceneRuntimeLiveSettingBadge: Codable, Equatable {
    let icon: String
    let title: String
    let status: SceneRuntimeModels.CameraCapabilityStatus
}

struct SceneRuntimeLiveCoachUIState: Codable, Equatable {
    let scenePlanId: String?
    let readiness: SceneRuntimeModels.Readiness
    let score: Double
    let blockingIssues: [String]
    let operatorCues: [SceneRuntimeModels.CoachingCue]
    let subjectCues: [SceneRuntimeModels.CoachingCue]
    let settingBadges: [SceneRuntimeLiveSettingBadge]
    let response: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse?

    var isReadyToCapture: Bool {
        readiness == .ready || readiness == .bestEffort
    }

    var displayCues: [SceneRuntimeModels.CoachingCue] {
        let cues = operatorCues + subjectCues
        if cues.isEmpty, readiness == .ready {
            return [SceneRuntimeModels.CoachingCue(target: "operator", message: "Hold steady and capture now.")]
        }
        return cues
    }

    init(scenePlan: SceneRuntimeModels.GenerateScenePlanResponse) {
        scenePlanId = scenePlan.scenePlanId
        readiness = .coaching
        score = 0
        blockingIssues = []
        operatorCues = scenePlan.coachingCues.filter { $0.target.lowercased() == "operator" }
        subjectCues = scenePlan.coachingCues.filter { $0.target.lowercased() != "operator" }
        settingBadges = [
            SceneRuntimeLiveSettingBadge(icon: "scope", title: "Focus pending", status: .pending),
            SceneRuntimeLiveSettingBadge(icon: "sun.max", title: "Light pending", status: .pending),
            SceneRuntimeLiveSettingBadge(icon: "camera.aperture", title: "Camera pending", status: .pending)
        ]
        response = nil
    }

    init(response: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse) {
        scenePlanId = response.scenePlanId
        readiness = response.readiness
        score = response.score
        blockingIssues = response.blockingIssues
        operatorCues = response.cues.filter { $0.target.lowercased() == "operator" }
        subjectCues = response.cues.filter { $0.target.lowercased() != "operator" }
        settingBadges = Self.settingBadges(from: response.dynamicCameraSettingsAdjustment)
        self.response = response
    }

    static let waiting = SceneRuntimeLiveCoachUIState(
        scenePlanId: nil,
        readiness: .coaching,
        score: 0,
        blockingIssues: [],
        operatorCues: [SceneRuntimeModels.CoachingCue(target: "operator", message: "Run a live readiness check.")],
        subjectCues: [],
        settingBadges: [
            SceneRuntimeLiveSettingBadge(icon: "scope", title: "Focus pending", status: .pending),
            SceneRuntimeLiveSettingBadge(icon: "sun.max", title: "Light pending", status: .pending),
            SceneRuntimeLiveSettingBadge(icon: "camera.aperture", title: "Camera pending", status: .pending)
        ],
        response: nil
    )

    private init(
        scenePlanId: String?,
        readiness: SceneRuntimeModels.Readiness,
        score: Double,
        blockingIssues: [String],
        operatorCues: [SceneRuntimeModels.CoachingCue],
        subjectCues: [SceneRuntimeModels.CoachingCue],
        settingBadges: [SceneRuntimeLiveSettingBadge],
        response: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse?
    ) {
        self.scenePlanId = scenePlanId
        self.readiness = readiness
        self.score = score
        self.blockingIssues = blockingIssues
        self.operatorCues = operatorCues
        self.subjectCues = subjectCues
        self.settingBadges = settingBadges
        self.response = response
    }

    private static func settingBadges(
        from adjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    ) -> [SceneRuntimeLiveSettingBadge] {
        [
            SceneRuntimeLiveSettingBadge(icon: "scope", title: badgeTitle("Focus", adjustment.focus.status), status: adjustment.focus.status),
            SceneRuntimeLiveSettingBadge(icon: "sun.max", title: badgeTitle("Light", adjustment.exposure.status), status: adjustment.exposure.status),
            SceneRuntimeLiveSettingBadge(icon: "thermometer.sun", title: badgeTitle("Tone", adjustment.whiteBalance.status), status: adjustment.whiteBalance.status),
            SceneRuntimeLiveSettingBadge(icon: "camera.aperture", title: badgeTitle("Lens", adjustment.zoomLens.status), status: adjustment.zoomLens.status),
            SceneRuntimeLiveSettingBadge(icon: "circle.dotted", title: badgeTitle("Depth", adjustment.depth.status), status: adjustment.depth.status),
            SceneRuntimeLiveSettingBadge(icon: "bolt.slash", title: badgeTitle("Low light", adjustment.flashLowLight.status), status: adjustment.flashLowLight.status)
        ]
    }

    private static func badgeTitle(
        _ label: String,
        _ status: SceneRuntimeModels.CameraCapabilityStatus
    ) -> String {
        switch status {
        case .applied:
            return "\(label) handled"
        case .adjusted:
            return "\(label) adjusted"
        case .unavailable:
            return "\(label) limited"
        case .needsOperatorAdjustment:
            return "\(label) needs position"
        case .pending:
            return "\(label) pending"
        }
    }
}

protocol NativeCameraRuntimeCommandSink: AnyObject {
    func apply(
        _ adjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment,
        scenePlanId: String,
        recommendationId: String
    ) async throws
}

struct NativeCameraRuntimeApplication: Codable, Equatable {
    let scenePlanId: String
    let recommendationId: String
    let adjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
}

final class InMemoryNativeCameraRuntimeCommandSink: NativeCameraRuntimeCommandSink {
    private var appliedApplications: [NativeCameraRuntimeApplication] = []

    func apply(
        _ adjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment,
        scenePlanId: String,
        recommendationId: String
    ) async throws {
        appliedApplications.append(
            NativeCameraRuntimeApplication(
                scenePlanId: scenePlanId,
                recommendationId: recommendationId,
                adjustment: adjustment
            )
        )
    }

    func applications() async -> [NativeCameraRuntimeApplication] {
        appliedApplications
    }
}

struct SceneRuntimeFrontendNativeCoordinator {
    let service: any SceneRuntimeServiceFacade
    let nativeCommandSink: any NativeCameraRuntimeCommandSink

    init(
        service: any SceneRuntimeServiceFacade,
        nativeCommandSink: any NativeCameraRuntimeCommandSink,
        requireProductionService: Bool = true
    ) throws {
        if requireProductionService && service.implementationKind != .production {
            throw SceneRuntimeFrontendNativeIntegrationError.productionServiceRequired
        }
        self.service = service
        self.nativeCommandSink = nativeCommandSink
    }

    static func localTest() -> SceneRuntimeFrontendNativeCoordinator {
        let service = ProductionSceneRuntimeServiceFacade(
            scenePlanProvider: LocalTestScenePlanProvider()
        )
        return try! SceneRuntimeFrontendNativeCoordinator(
            service: service,
            nativeCommandSink: InMemoryNativeCameraRuntimeCommandSink()
        )
    }

    static func phoneTestCloudFirst() -> SceneRuntimeFrontendNativeCoordinator {
        let repository = InMemorySceneRuntimeRepository()
        let provider: any ScenePlanGenerationProvider = DevDirectCloudScenePlanProvider.isConfigured()
            ? DevDirectCloudScenePlanProvider(repository: repository)
            : LocalTestScenePlanProvider()
        let service = ProductionSceneRuntimeServiceFacade(
            sceneInputRepository: repository,
            scenePlanProvider: provider
        )
        return try! SceneRuntimeFrontendNativeCoordinator(
            service: service,
            nativeCommandSink: InMemoryNativeCameraRuntimeCommandSink()
        )
    }

    func ingestAndGenerateScenePlan(
        context: SceneRuntimeFrontendCaptureContext,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeModels.GenerateScenePlanResponse {
        let createResponse = try await service.createSceneInput(
            SceneRuntimeModels.CreateSceneInputRequest(
                sessionId: context.sessionId,
                styleProfileId: context.styleProfileId,
                protectedSubjectSetId: context.protectedSubjectSetId,
                sceneInputAttemptId: context.sceneInputAttemptId,
                sceneInputMode: context.sceneInputMode,
                mediaRefs: context.mediaRefs,
                uploadAnyway: context.uploadAnyway,
                ingestionMetadata: SceneRuntimeModels.SceneInputIngestionMetadata(
                    mediaKind: context.sceneInputMode == .scanVideo ? .scanVideo : .singleScenePhoto,
                    frameCount: context.sceneInputMode == .scanVideo ? 120 : nil,
                    sampledFrameCount: context.sceneInputMode == .scanVideo ? 12 : nil,
                    durationMilliseconds: context.sceneInputMode == .scanVideo ? 5_800 : nil,
                    capturedAt: "2026-06-04T12:00:00Z",
                    liveFrameSummary: nil,
                    qualitySignals: context.qualitySignals
                ),
                qualitySignals: context.qualitySignals,
                uploadFailureReason: context.uploadFailureReason
            ),
            schemaVersion: schemaVersion
        )
        guard let sceneAnalysisId = createResponse.sceneAnalysisId else {
            throw SceneRuntimeFrontendNativeIntegrationError.sceneAnalysisDidNotCreateJob
        }
        return try await service.generateScenePlan(
            SceneRuntimeModels.GenerateScenePlanRequest(
                sceneAnalysisId: sceneAnalysisId,
                styleProfileId: createResponse.styleProfileId,
                protectedSubjectSetId: createResponse.protectedSubjectSetId,
                sceneInputQualityContext: createResponse.sceneInputQualityContext
            ),
            schemaVersion: schemaVersion
        )
    }

    func evaluateLiveFrame(
        scenePlan: SceneRuntimeModels.GenerateScenePlanResponse,
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeLiveCoachUIState {
        let response = try await service.evaluateLiveFrameReadiness(
            SceneRuntimeModels.EvaluateLiveFrameReadinessRequest(
                scenePlanId: scenePlan.scenePlanId,
                styleProfileId: scenePlan.styleProfileId,
                protectedSubjectSetId: scenePlan.protectedSubjectSetId,
                initialCameraSettingsRecommendation: scenePlan.initialCameraSettingsRecommendation,
                runtimeAffordanceSignals: scenePlan.runtimeAffordanceSignals,
                postCapturePrerequisites: scenePlan.postCapturePrerequisites,
                liveFrameSummary: liveFrameSummary
            ),
            schemaVersion: schemaVersion
        )
        try await nativeCommandSink.apply(
            response.dynamicCameraSettingsAdjustment,
            scenePlanId: scenePlan.scenePlanId,
            recommendationId: scenePlan.initialCameraSettingsRecommendation.recommendationId
        )
        return SceneRuntimeLiveCoachUIState(response: response)
    }

    func buildCaptureHandoff(
        scenePlan: SceneRuntimeModels.GenerateScenePlanResponse,
        liveCoachState: SceneRuntimeLiveCoachUIState,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeModels.BeforeCaptureFinalMomentHandoff {
        guard let response = liveCoachState.response else {
            throw SceneRuntimeFrontendNativeIntegrationError.missingLiveReadinessResponse
        }
        let cameraSettingsUsed = SceneRuntimeCaptureSettingsFinalizer.cameraSettingsUsed(
            scenePlan: scenePlan,
            liveResponse: response
        )
        return try await service.buildBeforeCaptureFinalMomentHandoff(
            SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest(
                scenePlanId: scenePlan.scenePlanId,
                styleProfileId: scenePlan.styleProfileId,
                protectedSubjectSetId: scenePlan.protectedSubjectSetId,
                sceneInputQualityContext: scenePlan.sceneInputQualityContext,
                initialCameraSettingsRecommendation: scenePlan.initialCameraSettingsRecommendation,
                runtimeAffordanceSignals: scenePlan.runtimeAffordanceSignals,
                postCapturePrerequisites: SceneRuntimeModels.PostCapturePrerequisites(
                    mustCaptureCorrectly: scenePlan.postCapturePrerequisites.mustCaptureCorrectly,
                    canFineTuneLater: scenePlan.postCapturePrerequisites.canFineTuneLater,
                    statusAtCapture: response.postCapturePrerequisiteStatus
                ),
                capturedAffordanceMetadata: response.capturedAffordanceMetadata,
                cameraSettingsUsed: cameraSettingsUsed
            ),
            schemaVersion: schemaVersion
        )
    }
}

enum SceneRuntimeCaptureSettingsFinalizer {
    static func cameraSettingsUsed(
        scenePlan: SceneRuntimeModels.GenerateScenePlanResponse,
        liveResponse: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse
    ) -> SceneRuntimeModels.CameraSettingsUsed {
        let adjustment = liveResponse.dynamicCameraSettingsAdjustment
        let recommendation = scenePlan.initialCameraSettingsRecommendation
        let substitutions = substitutions(from: adjustment)
        return SceneRuntimeModels.CameraSettingsUsed(
            settingsId: "camera_settings_used_\(scenePlan.scenePlanId)",
            appliedRecommendationId: recommendation.recommendationId,
            focusModeUsed: adjustment.focus.mode ?? recommendation.focus.mode,
            focusPointStrategyUsed: recommendation.focus.focusPointStrategy,
            focusStatus: adjustment.focus.status,
            exposureMeteringTargetUsed: adjustment.exposure.meteringTarget ?? recommendation.exposure.meteringTarget,
            exposureBiasUsed: adjustment.exposure.bias,
            exposureStatus: adjustment.exposure.status,
            whiteBalanceModeUsed: adjustment.whiteBalance.mode ?? recommendation.whiteBalance.mode,
            whiteBalanceStatus: adjustment.whiteBalance.status,
            lensUsed: adjustment.zoomLens.lensUsed ?? recommendation.zoomLens?.preferredLens,
            zoomFactorUsed: adjustment.zoomLens.zoomFactor ?? recommendation.zoomLens?.targetZoomFactor,
            zoomLensStatus: adjustment.zoomLens.status,
            depthModeUsed: adjustment.depth.mode ?? recommendation.depth?.mode,
            depthDataDeliveryUsed: adjustment.depth.depthDataDelivery,
            portraitEffectsMatteUsed: adjustment.depth.portraitEffectsMatteDelivery,
            depthStatus: adjustment.depth.status,
            photoQualityPrioritizationUsed: adjustment.capture.photoQualityPrioritization,
            burstCountRequested: recommendation.capture?.burstCount,
            burstCountCaptured: adjustment.capture.burstCount,
            highestPracticalResolutionUsed: adjustment.capture.highestPracticalResolution,
            flashModeUsed: adjustment.flashLowLight.flashMode ?? recommendation.flashLowLight?.flashMode,
            lowLightPolicyUsed: recommendation.flashLowLight?.lowLightRecoveryPolicy ?? adjustment.flashLowLight.torchMode,
            capabilityGaps: capabilityGaps(from: adjustment),
            substitutions: substitutions.isEmpty ? nil : substitutions
        )
    }

    private static func capabilityGaps(
        from adjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    ) -> [String] {
        let gaps = [
            adjustment.focus.capabilityGap,
            adjustment.exposure.capabilityGap,
            adjustment.whiteBalance.capabilityGap,
            adjustment.zoomLens.capabilityGap,
            adjustment.depth.capabilityGap,
            adjustment.framing.capabilityGap,
            adjustment.capture.capabilityGap,
            adjustment.flashLowLight.capabilityGap
        ].compactMap { $0 }
        return Array(Set(gaps)).sorted()
    }

    private static func substitutions(
        from adjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    ) -> [SceneRuntimeModels.CameraSettingSubstitution] {
        adjustment.capabilityStatus
            .filter { _, status in
                status == .adjusted || status == .unavailable || status == .needsOperatorAdjustment
            }
            .map { parameter, status in
                SceneRuntimeModels.CameraSettingSubstitution(
                    parameter: parameter,
                    requested: true,
                    used: status != .unavailable,
                    status: status,
                    reason: "Final live camera adjustment recorded \(status.rawValue) for \(parameter)."
                )
            }
            .sorted { $0.parameter < $1.parameter }
    }
}

struct LocalTestScenePlanProvider: ScenePlanGenerationProvider {
    func generateScenePlan(
        _ request: SceneRuntimeModels.GenerateScenePlanRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.GenerateScenePlanResponse {
        try SceneRuntimeServiceSchema.validate(schemaVersion, operation: .generateScenePlan)
        let isGraduation = request.styleProfileId.lowercased().contains("graduation")
        return SceneRuntimeModels.GenerateScenePlanResponse(
            scenePlanId: "scene_plan_\(request.sceneAnalysisId.replacingOccurrences(of: "scene_analysis_", with: ""))",
            sceneAnalysisId: request.sceneAnalysisId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            sceneInputQualityContext: request.sceneInputQualityContext,
            sceneMatchType: request.sceneInputQualityContext.allowsSuboptimalSceneInput ? .bestEffortFallback : .styleSynthesis,
            professionalHappyMomentAssessment: SceneRuntimeModels.ProfessionalHappyMomentAssessment(
                faceLightUsable: true,
                naturalExpressionOpportunity: true,
                relationshipInteractionOpportunity: true,
                protectedSubjectFocusFeasible: true,
                cropHeadroomFeasible: true,
                unrecoverableRisks: request.sceneInputQualityContext.allowsSuboptimalSceneInput
                    ? ["scene_input_suboptimal_preserved_for_lower_confidence"]
                    : nil
            ),
            runtimeAffordanceSignals: Self.runtimeAffordanceSignals(),
            postCapturePrerequisites: Self.postCapturePrerequisites(),
            postCaptureFineTuneSignals: [.portfolioColorTone, .cropComposition, .lightShadowContrast, .backgroundReadabilityOrSubjectSeparation],
            standPoint: Self.standPoint(isGraduation: isGraduation),
            subjectPosition: Self.subjectPosition(isGraduation: isGraduation),
            operatorPosition: Self.operatorPosition(isGraduation: isGraduation),
            facingDirection: Self.facingDirection(isGraduation: isGraduation),
            roughFraming: SceneRuntimeModels.RoughFraming(
                style: "wide_environmental",
                safetyMargin: "high",
                orientation: "vertical"
            ),
            coachingCues: Self.coachingCues(isGraduation: isGraduation),
            initialCameraSettingsRecommendation: Self.initialCameraSettingsRecommendation(
                scenePlanId: request.sceneAnalysisId,
                isGraduation: isGraduation
            ),
            fallback: request.sceneInputQualityContext.allowsSuboptimalSceneInput
                ? SceneRuntimeModels.ScenePlanFallback(
                    type: "accepted_suboptimal_scene_input",
                    message: "Scene input was accepted with preserved quality warnings.",
                    nextAction: "Coach conservatively and record weak prerequisites if needed.",
                    canContinueBestEffort: true
                )
                : nil,
            persistenceWriteIntent: ["sceneAnalysis", "scenePlan", "initialCameraSettingsRecommendation"]
        )
    }

    static func liveFrameSummaryReady() -> SceneRuntimeModels.LiveFrameSummary {
        SceneRuntimeModels.LiveFrameSummary(
            protectedSubjectsVisible: true,
            protectedSubjectFocusState: "locked",
            faceExposureState: "usable",
            expressionInteractionState: "natural_observed",
            cropHeadroomState: "available",
            detectedAffordances: runtimeAffordanceSignals().map(\.type),
            lightChangedFromSceneAnalysis: false,
            nativeCapabilities: nativeCapabilities()
        )
    }

    static func nativeCapabilities() -> SceneRuntimeModels.NativeCameraCapabilities {
        SceneRuntimeModels.NativeCameraCapabilities(
            canLockFocus: true,
            canSetFocusPoint: true,
            canSetExposurePoint: true,
            canSetExposureBias: true,
            canLockWhiteBalance: true,
            canSetWhiteBalanceGains: true,
            canUseDepth: true,
            canDeliverDepthData: true,
            canDeliverPortraitEffectsMatte: true,
            availableLenses: ["ultra_wide", "wide", "tele"],
            minZoomFactor: 0.5,
            maxOpticalZoomFactor: 3.0,
            maxAcceptableDigitalZoomFactor: 3.0,
            canSetPhotoQualityPrioritization: true,
            canCaptureBurst: true,
            canUseHighestPracticalResolution: true,
            canControlFlash: true,
            canUseTorch: true
        )
    }

    private static func runtimeAffordanceSignals() -> [SceneRuntimeModels.RuntimeAffordanceSignal] {
        [
            signal(.softSideLight),
            signal(.rimHairEdgeLight),
            signal(.cropHeadroomAvailable),
            signal(.naturalMotionOpportunity),
            signal(.relationshipInteractionOpportunity),
            signal(.focusDepthOpportunity),
            signal(.architecturalAnchor)
        ]
    }

    private static func signal(
        _ type: SceneRuntimeModels.RuntimeAffordanceSignalType
    ) -> SceneRuntimeModels.RuntimeAffordanceSignal {
        SceneRuntimeModels.RuntimeAffordanceSignal(
            type: type,
            confidence: 0.86,
            recommendedUse: "preserve_during_live_capture",
            evidence: "local_test_scene_runtime_provider"
        )
    }

    private static func postCapturePrerequisites() -> SceneRuntimeModels.PostCapturePrerequisites {
        SceneRuntimeModels.PostCapturePrerequisites(
            mustCaptureCorrectly: [
                .protectedSubjectsVisible,
                .protectedSubjectFocus,
                .usableFaceLight,
                .naturalExpressionOrInteraction,
                .cropHeadroom
            ],
            canFineTuneLater: [.portfolioColorTone, .cropComposition, .lightShadowContrast, .backgroundReadabilityOrSubjectSeparation],
            statusAtCapture: nil
        )
    }

    private static func standPoint(isGraduation: Bool) -> SceneRuntimeModels.LabeledDescription {
        if isGraduation {
            return SceneRuntimeModels.LabeledDescription(
                label: "Stand here",
                description: "Place the subject where the face catches the softest available indoor light with a simple readable background."
            )
        }
        return SceneRuntimeModels.LabeledDescription(
            label: "Soft side light near the anchor",
            description: "Keep protected-subject faces in soft light while preserving the place cue."
        )
    }

    private static func subjectPosition(isGraduation: Bool) -> SceneRuntimeModels.SubjectPosition {
        if isGraduation {
            return SceneRuntimeModels.SubjectPosition(
                zone: "graduation_single_subject_soft_indoor_light",
                distanceCue: "stand inside the guide with the face bright and shoulders relaxed"
            )
        }
        return SceneRuntimeModels.SubjectPosition(
            zone: "open_light_edge",
            distanceCue: "stand where faces stay bright and the background remains readable"
        )
    }

    private static func operatorPosition(isGraduation: Bool) -> SceneRuntimeModels.OperatorPosition {
        if isGraduation {
            return SceneRuntimeModels.OperatorPosition(
                distanceCue: "step back until the head and upper body fit comfortably",
                heightCue: "hold the phone just below eye level",
                framingCue: "keep the face inside the guide and leave a little space above the head"
            )
        }
        return SceneRuntimeModels.OperatorPosition(
            distanceCue: "step back until heads and the scene anchor have room",
            heightCue: "hold the phone around chest height",
            framingCue: "keep protected subjects and the anchor inside the guide"
        )
    }

    private static func facingDirection(isGraduation: Bool) -> SceneRuntimeModels.FacingDirection {
        if isGraduation {
            return SceneRuntimeModels.FacingDirection(
                subjectCue: "turn shoulders toward the softest available light",
                operatorCue: "meter on the face and keep the background calm"
            )
        }
        return SceneRuntimeModels.FacingDirection(
            subjectCue: "turn gently toward the softer side light",
            operatorCue: "face the phone toward the subjects and anchor"
        )
    }

    private static func coachingCues(isGraduation: Bool) -> [SceneRuntimeModels.CoachingCue] {
        if isGraduation {
            return GraduationSingleSubjectDemoGuidance.cues
        }
        return [
            SceneRuntimeModels.CoachingCue(target: "operator", message: "Step back until protected subjects and the scene anchor fit."),
            SceneRuntimeModels.CoachingCue(target: "subjects", message: "Turn gently toward the softer side light."),
            SceneRuntimeModels.CoachingCue(target: "subjects", message: "Walk together slowly and keep talking to each other.")
        ]
    }

    private static func initialCameraSettingsRecommendation(
        scenePlanId: String,
        isGraduation: Bool = false
    ) -> SceneRuntimeModels.InitialCameraSettingsRecommendation {
        SceneRuntimeModels.InitialCameraSettingsRecommendation(
            recommendationId: "camera_rec_\(scenePlanId.replacingOccurrences(of: "scene_analysis_", with: ""))",
            sourceNativeCameraParameterIntentId: "style_profile_runtime.local_test.native_camera_intent",
            focus: SceneRuntimeModels.FocusRecommendation(
                target: isGraduation ? "single_graduate_face" : "all_protected_subjects",
                mode: "continuous_then_lock_when_ready",
                priority: isGraduation ? "single_face_and_upper_body" : "faces_and_bodies",
                focusPointStrategy: isGraduation ? "guide_center_face_priority" : "protected_subject_face_group"
            ),
            exposure: SceneRuntimeModels.ExposureRecommendation(
                meteringTarget: "protected_subject_faces",
                bias: isGraduation ? -0.15 : -0.2,
                protectHighlights: true,
                avoidFaceClipping: true,
                avoidFaceShadowCrush: true
            ),
            whiteBalance: SceneRuntimeModels.WhiteBalanceRecommendation(
                mode: "auto_then_lock_when_ready",
                lockWhenReady: true,
                temperatureBias: "warm",
                tintBias: "neutral"
            ),
            zoomLens: SceneRuntimeModels.ZoomLensRecommendation(
                preferredLens: "wide",
                targetZoomFactor: isGraduation ? 1.15 : 1.0,
                maxDigitalZoomFactor: 2.0,
                allowUltraWideIfOperatorTooClose: true,
                avoidLensSwitchDuringCapture: true
            ),
            depth: SceneRuntimeModels.DepthRecommendation(
                mode: "environmental_depth",
                portraitBlurStrength: 0.2,
                keepArchitecturalAnchorReadable: true,
                depthDataDeliveryPreferred: true,
                portraitEffectsMattePreferred: true
            ),
            framing: SceneRuntimeModels.FramingRecommendation(
                shootWide: true,
                safetyMargin: "high",
                orientation: "vertical",
                compositionTarget: "wide_environmental"
            ),
            colorAndTonePreview: SceneRuntimeModels.ColorAndTonePreview(
                contrast: "medium",
                saturation: "slightly_warm",
                highlightRecovery: "moderate"
            ),
            capture: SceneRuntimeModels.CaptureRecommendation(
                burstCount: 10,
                highestPracticalResolution: true,
                photoQualityPrioritization: "quality",
                captureResponsiveness: "balanced",
                stabilizationPreferred: true
            ),
            flashLowLight: SceneRuntimeModels.FlashLowLightRecommendation(
                preferNaturalLight: true,
                flashMode: "off_unless_recovery_needed",
                torchAllowed: false,
                lowLightRecoveryPolicy: "move_subjects_or_best_effort_before_flash"
            ),
            capabilityRequirements: SceneRuntimeModels.CapabilityRequirements(
                reportUnavailableSettings: true,
                allowedFallbackBehavior: "closest_available_with_explicit_gap_reporting",
                statusValues: [.applied, .adjusted, .unavailable, .needsOperatorAdjustment]
            )
        )
    }
}
