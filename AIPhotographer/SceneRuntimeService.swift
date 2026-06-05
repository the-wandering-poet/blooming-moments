import Foundation

enum SceneRuntimeServiceSchema {
    static let currentVersion = "2026-06-04.scene-runtime.v1"

    static func validate(_ schemaVersion: String, operation: SceneRuntimeOperation) throws {
        guard schemaVersion == currentVersion else {
            throw SceneRuntimeServiceError(
                code: .unsupportedSchemaVersion,
                operation: operation,
                message: "Unsupported Scene Runtime schema version.",
                fieldPath: "schemaVersion",
                fallback: nil
            )
        }
    }
}

enum SceneRuntimeOperation: String, Codable, Equatable {
    case createSceneInput
    case generateScenePlan
    case evaluateLiveFrameReadiness
    case buildBeforeCaptureFinalMomentHandoff
}

enum SceneRuntimeImplementationKind: String, Codable, Equatable {
    case production
    case mockFixture
}

struct SceneRuntimeServiceError: Error, Codable, Equatable {
    enum Code: String, Codable {
        case unsupportedSchemaVersion
        case validationFailed
        case fallbackRequired
        case dependencyUnavailable
    }

    let code: Code
    let operation: SceneRuntimeOperation
    let message: String
    let fieldPath: String?
    let fallback: SceneRuntimeTypedFallback?
}

struct SceneRuntimeTypedFallback: Codable, Equatable {
    let type: String
    let message: String
    let nextAction: String
    let canContinueBestEffort: Bool
}

protocol SceneRuntimeServiceFacade {
    var implementationKind: SceneRuntimeImplementationKind { get }

    func createSceneInput(
        _ request: SceneRuntimeModels.CreateSceneInputRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.CreateSceneInputResponse

    func generateScenePlan(
        _ request: SceneRuntimeModels.GenerateScenePlanRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.GenerateScenePlanResponse

    func evaluateLiveFrameReadiness(
        _ request: SceneRuntimeModels.EvaluateLiveFrameReadinessRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.EvaluateLiveFrameReadinessResponse

    func buildBeforeCaptureFinalMomentHandoff(
        _ request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.BeforeCaptureFinalMomentHandoff
}

protocol ScenePlanGenerationProvider {
    func generateScenePlan(
        _ request: SceneRuntimeModels.GenerateScenePlanRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.GenerateScenePlanResponse
}

struct ProductionSceneRuntimeServiceFacade: SceneRuntimeServiceFacade {
    let implementationKind: SceneRuntimeImplementationKind = .production
    let sceneInputRepository: SceneRuntimeRepository
    let scenePlanProvider: (any ScenePlanGenerationProvider)?
    let liveCoachEvaluator: LiveCoachEvaluator
    let beforeCaptureHandoffBuilder: BeforeCaptureHandoffBuilder

    init(
        sceneInputRepository: SceneRuntimeRepository = InMemorySceneRuntimeRepository(),
        scenePlanProvider: (any ScenePlanGenerationProvider)? = nil,
        liveCoachEvaluator: LiveCoachEvaluator = LiveCoachEvaluator(),
        beforeCaptureHandoffBuilder: BeforeCaptureHandoffBuilder = BeforeCaptureHandoffBuilder()
    ) {
        self.sceneInputRepository = sceneInputRepository
        self.scenePlanProvider = scenePlanProvider
        self.liveCoachEvaluator = liveCoachEvaluator
        self.beforeCaptureHandoffBuilder = beforeCaptureHandoffBuilder
    }

    func createSceneInput(
        _ request: SceneRuntimeModels.CreateSceneInputRequest,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeModels.CreateSceneInputResponse {
        try SceneRuntimeServiceSchema.validate(schemaVersion, operation: .createSceneInput)
        try SceneRuntimeRequestValidator.validate(request)

        let qualitySignals = request.qualitySignals ?? request.ingestionMetadata?.qualitySignals ?? .empty
        let failureReason = SceneInputQualityGate.failureReason(
            qualitySignals: qualitySignals,
            uploadFailureReason: request.uploadFailureReason,
            uploadAnyway: request.uploadAnyway
        )
        let status = SceneInputQualityGate.status(
            qualitySignals: qualitySignals,
            uploadFailureReason: request.uploadFailureReason,
            uploadAnyway: request.uploadAnyway
        )
        let sceneInputId = SceneRuntimeIdFactory.sceneInputId(attemptId: request.sceneInputAttemptId)
        let sceneAnalysisId = SceneInputQualityGate.createsAnalysisJob(status)
            ? SceneRuntimeIdFactory.sceneAnalysisId(attemptId: request.sceneInputAttemptId)
            : nil
        let context = SceneRuntimeModels.SceneInputQualityContext(
            sceneInputMode: request.sceneInputMode,
            sceneInputStatus: status,
            allowsSuboptimalSceneInput: status == .acceptedSuboptimal,
            sceneInputFailureReason: failureReason,
            qualitySignals: qualitySignals
        )
        let response = SceneRuntimeModels.CreateSceneInputResponse(
            sceneInputId: sceneInputId,
            sceneInputAttemptId: request.sceneInputAttemptId,
            sceneAnalysisId: sceneAnalysisId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            sceneInputQualityContext: context,
            persistenceWriteIntent: SceneInputQualityGate.createsAnalysisJob(status)
                ? ["sceneInput", "analysisJob"]
                : ["sceneInput"]
        )
        let record = SceneInputIngestionRecord(
            schemaVersion: schemaVersion,
            sessionId: request.sessionId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            sceneInputAttemptId: request.sceneInputAttemptId,
            sceneInputId: sceneInputId,
            sceneAnalysisId: sceneAnalysisId,
            sceneInputMode: request.sceneInputMode,
            mediaRefs: request.mediaRefs,
            ingestionMetadata: request.ingestionMetadata,
            qualityContext: context,
            response: response,
            isActiveAttempt: SceneInputQualityGate.createsAnalysisJob(status)
        )

        let storedRecord = try await sceneInputRepository.upsertSceneInput(record)
        return storedRecord.response
    }

    func generateScenePlan(
        _ request: SceneRuntimeModels.GenerateScenePlanRequest,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeModels.GenerateScenePlanResponse {
        try SceneRuntimeServiceSchema.validate(schemaVersion, operation: .generateScenePlan)
        try SceneRuntimeRequestValidator.validate(request)

        if request.sceneInputQualityContext.sceneInputStatus == .rejectedRetryRequired {
            throw SceneRuntimeServiceError(
                code: .fallbackRequired,
                operation: .generateScenePlan,
                message: "Scene plan cannot be generated for a retry-required scene input.",
                fieldPath: "sceneInputQualityContext.sceneInputStatus",
                fallback: SceneRuntimeTypedFallback(
                    type: "retry_scene_input",
                    message: "Scene input failed quality validation.",
                    nextAction: "Retry scene scan/photo or choose upload anyway.",
                    canContinueBestEffort: false
                )
            )
        }

        guard let scenePlanProvider else {
            throw dependencyUnavailable(.generateScenePlan)
        }
        return try await scenePlanProvider.generateScenePlan(
            request,
            schemaVersion: schemaVersion
        )
    }

    func evaluateLiveFrameReadiness(
        _ request: SceneRuntimeModels.EvaluateLiveFrameReadinessRequest,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeModels.EvaluateLiveFrameReadinessResponse {
        try SceneRuntimeServiceSchema.validate(schemaVersion, operation: .evaluateLiveFrameReadiness)
        try SceneRuntimeRequestValidator.validate(request)

        let evaluation = try await liveCoachEvaluator.evaluate(
            LiveCoachEvaluatorInput(
                schemaVersion: schemaVersion,
                request: request,
                bestEffortAllowed: false
            )
        )
        return evaluation.response
    }

    func buildBeforeCaptureFinalMomentHandoff(
        _ request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> SceneRuntimeModels.BeforeCaptureFinalMomentHandoff {
        try SceneRuntimeServiceSchema.validate(schemaVersion, operation: .buildBeforeCaptureFinalMomentHandoff)
        try SceneRuntimeRequestValidator.validate(request)
        let result = try await beforeCaptureHandoffBuilder.buildFromLockedRequest(
            request,
            schemaVersion: schemaVersion
        )
        return result.handoff
    }

    private func dependencyUnavailable(_ operation: SceneRuntimeOperation) -> SceneRuntimeServiceError {
        SceneRuntimeServiceError(
            code: .dependencyUnavailable,
            operation: operation,
            message: "Step 2 locks the production service facade shape only; runtime dependencies are not wired yet.",
            fieldPath: nil,
            fallback: nil
        )
    }
}

protocol SceneRuntimeRepository: AnyObject {
    func upsertSceneInput(_ record: SceneInputIngestionRecord) async throws -> SceneInputIngestionRecord
    func sceneInputRecord(attemptId: String) async -> SceneInputIngestionRecord?
    func activeSceneInputRecord(
        sessionId: String,
        styleProfileId: String,
        protectedSubjectSetId: String
    ) async -> SceneInputIngestionRecord?
    func sceneInputRecords() async -> [SceneInputIngestionRecord]
}

final class InMemorySceneRuntimeRepository: SceneRuntimeRepository {
    private var recordsByAttemptId: [String: SceneInputIngestionRecord] = [:]
    private var activeAttemptByContextKey: [String: String] = [:]

    func upsertSceneInput(_ record: SceneInputIngestionRecord) async throws -> SceneInputIngestionRecord {
        if let existing = recordsByAttemptId[record.sceneInputAttemptId] {
            return existing
        }

        recordsByAttemptId[record.sceneInputAttemptId] = record
        if record.isActiveAttempt {
            activeAttemptByContextKey[Self.contextKey(record)] = record.sceneInputAttemptId
        }
        return record
    }

    func sceneInputRecord(attemptId: String) async -> SceneInputIngestionRecord? {
        recordsByAttemptId[attemptId]
    }

    func activeSceneInputRecord(
        sessionId: String,
        styleProfileId: String,
        protectedSubjectSetId: String
    ) async -> SceneInputIngestionRecord? {
        let key = Self.contextKey(
            sessionId: sessionId,
            styleProfileId: styleProfileId,
            protectedSubjectSetId: protectedSubjectSetId
        )
        guard let attemptId = activeAttemptByContextKey[key] else {
            return nil
        }
        return recordsByAttemptId[attemptId]
    }

    func sceneInputRecords() async -> [SceneInputIngestionRecord] {
        Array(recordsByAttemptId.values)
    }

    private static func contextKey(_ record: SceneInputIngestionRecord) -> String {
        contextKey(
            sessionId: record.sessionId,
            styleProfileId: record.styleProfileId,
            protectedSubjectSetId: record.protectedSubjectSetId
        )
    }

    private static func contextKey(
        sessionId: String,
        styleProfileId: String,
        protectedSubjectSetId: String
    ) -> String {
        "\(sessionId)|\(styleProfileId)|\(protectedSubjectSetId)"
    }
}

struct SceneInputIngestionRecord: Codable, Equatable {
    let schemaVersion: String
    let sessionId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let sceneInputAttemptId: String
    let sceneInputId: String
    let sceneAnalysisId: String?
    let sceneInputMode: SceneRuntimeModels.SceneInputMode
    let mediaRefs: [String]
    let ingestionMetadata: SceneRuntimeModels.SceneInputIngestionMetadata?
    let qualityContext: SceneRuntimeModels.SceneInputQualityContext
    let response: SceneRuntimeModels.CreateSceneInputResponse
    let isActiveAttempt: Bool
}

enum SceneRuntimeIdFactory {
    static func sceneInputId(attemptId: String) -> String {
        "scene_input_\(sanitize(attemptId))"
    }

    static func sceneAnalysisId(attemptId: String) -> String {
        "scene_analysis_\(sanitize(attemptId))"
    }

    private static func sanitize(_ value: String) -> String {
        value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : "_"
            }
            .reduce(into: "") { partialResult, character in
                if character == "_" && partialResult.last == "_" {
                    return
                }
                partialResult.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

enum SceneInputQualityGate {
    static func status(
        qualitySignals: SceneRuntimeModels.SceneInputQualitySignals,
        uploadFailureReason: SceneRuntimeModels.SceneInputFailureReason?,
        uploadAnyway: Bool
    ) -> SceneRuntimeModels.SceneInputStatus {
        if uploadFailureReason != nil || qualitySignals.uploadFailed == true {
            return .uploadFailed
        }
        if hasQualityFailure(qualitySignals) {
            return uploadAnyway ? .acceptedSuboptimal : .rejectedRetryRequired
        }
        return .accepted
    }

    static func failureReason(
        qualitySignals: SceneRuntimeModels.SceneInputQualitySignals,
        uploadFailureReason: SceneRuntimeModels.SceneInputFailureReason?,
        uploadAnyway: Bool
    ) -> SceneRuntimeModels.SceneInputFailureReason? {
        if var uploadFailureReason {
            uploadFailureReason = SceneRuntimeModels.SceneInputFailureReason(
                code: uploadFailureReason.code,
                message: uploadFailureReason.message,
                retryAction: uploadFailureReason.retryAction,
                uploadAnywayChosen: uploadAnyway
            )
            return uploadFailureReason
        }

        guard let failure = firstQualityFailure(qualitySignals) else {
            return nil
        }

        return SceneRuntimeModels.SceneInputFailureReason(
            code: failure.code,
            message: failure.message,
            retryAction: failure.retryAction,
            uploadAnywayChosen: uploadAnyway
        )
    }

    static func createsAnalysisJob(_ status: SceneRuntimeModels.SceneInputStatus) -> Bool {
        status == .accepted || status == .acceptedSuboptimal
    }

    private static func hasQualityFailure(_ signals: SceneRuntimeModels.SceneInputQualitySignals) -> Bool {
        firstQualityFailure(signals) != nil
    }

    private static func firstQualityFailure(
        _ signals: SceneRuntimeModels.SceneInputQualitySignals
    ) -> (code: String, message: String, retryAction: String)? {
        if signals.scanTooShort {
            return (
                "scene_input_too_short",
                "The scan was too short to evaluate light and scene anchors.",
                "Scan slowly for at least five seconds."
            )
        }
        if signals.motionBlur {
            return (
                "scene_input_motion_blur",
                "The scene input is too blurry to evaluate reliably.",
                "Retake the scan or photo while moving more slowly."
            )
        }
        if signals.tooDark {
            return (
                "scene_input_too_dark",
                "The scene is too dark to evaluate protected-subject face light.",
                "Move toward brighter natural light or rescan another direction."
            )
        }
        if signals.overexposed {
            return (
                "scene_input_overexposed",
                "The scene has bright highlights that may clip protected-subject faces.",
                "Retake the photo in open shade."
            )
        }
        if signals.noUsefulCompositionSpace {
            return (
                "no_useful_scene_candidate",
                "The scene does not show enough usable space or anchor context.",
                "Step back or scan a wider area."
            )
        }
        return nil
    }
}

enum SceneRuntimeRequestValidator {
    static func validate(_ request: SceneRuntimeModels.CreateSceneInputRequest) throws {
        try requireNonEmpty(request.sessionId, "sessionId", .createSceneInput)
        try requireNonEmpty(request.styleProfileId, "styleProfileId", .createSceneInput)
        try requireNonEmpty(request.protectedSubjectSetId, "protectedSubjectSetId", .createSceneInput)
        try requireNonEmpty(request.sceneInputAttemptId, "sceneInputAttemptId", .createSceneInput)
        if request.mediaRefs.isEmpty {
            throw validationError(.createSceneInput, fieldPath: "mediaRefs", message: "Scene input requires at least one media ref.")
        }
        if request.ingestionMetadata?.mediaKind == .liveFrameSummary && request.ingestionMetadata?.liveFrameSummary == nil {
            throw validationError(
                .createSceneInput,
                fieldPath: "ingestionMetadata.liveFrameSummary",
                message: "Live-frame summary ingestion requires live frame summary metadata."
            )
        }
    }

    static func validate(_ request: SceneRuntimeModels.GenerateScenePlanRequest) throws {
        try requireNonEmpty(request.sceneAnalysisId, "sceneAnalysisId", .generateScenePlan)
        try requireNonEmpty(request.styleProfileId, "styleProfileId", .generateScenePlan)
        try requireNonEmpty(request.protectedSubjectSetId, "protectedSubjectSetId", .generateScenePlan)
    }

    static func validate(_ request: SceneRuntimeModels.EvaluateLiveFrameReadinessRequest) throws {
        try requireNonEmpty(request.scenePlanId, "scenePlanId", .evaluateLiveFrameReadiness)
        try requireNonEmpty(request.styleProfileId, "styleProfileId", .evaluateLiveFrameReadiness)
        try requireNonEmpty(request.protectedSubjectSetId, "protectedSubjectSetId", .evaluateLiveFrameReadiness)
        if request.runtimeAffordanceSignals.isEmpty {
            throw validationError(
                .evaluateLiveFrameReadiness,
                fieldPath: "runtimeAffordanceSignals",
                message: "Live readiness requires runtime affordance signals."
            )
        }
        if request.postCapturePrerequisites.mustCaptureCorrectly.isEmpty {
            throw validationError(
                .evaluateLiveFrameReadiness,
                fieldPath: "postCapturePrerequisites.mustCaptureCorrectly",
                message: "Live readiness requires post-capture prerequisites."
            )
        }
    }

    static func validate(_ request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest) throws {
        try requireNonEmpty(request.scenePlanId, "scenePlanId", .buildBeforeCaptureFinalMomentHandoff)
        try requireNonEmpty(request.styleProfileId, "styleProfileId", .buildBeforeCaptureFinalMomentHandoff)
        try requireNonEmpty(request.protectedSubjectSetId, "protectedSubjectSetId", .buildBeforeCaptureFinalMomentHandoff)
        if request.runtimeAffordanceSignals.isEmpty {
            throw validationError(
                .buildBeforeCaptureFinalMomentHandoff,
                fieldPath: "runtimeAffordanceSignals",
                message: "Final Moment handoff requires runtime affordance signals."
            )
        }
        if request.cameraSettingsUsed == nil {
            throw validationError(
                .buildBeforeCaptureFinalMomentHandoff,
                fieldPath: "cameraSettingsUsed",
                message: "Final Moment handoff requires final camera settings used."
            )
        }
    }

    private static func requireNonEmpty(
        _ value: String,
        _ fieldPath: String,
        _ operation: SceneRuntimeOperation
    ) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw validationError(operation, fieldPath: fieldPath, message: "\(fieldPath) must not be empty.")
        }
    }

    private static func validationError(
        _ operation: SceneRuntimeOperation,
        fieldPath: String,
        message: String
    ) -> SceneRuntimeServiceError {
        SceneRuntimeServiceError(
            code: .validationFailed,
            operation: operation,
            message: message,
            fieldPath: fieldPath,
            fallback: nil
        )
    }
}

enum SceneRuntimeModels {
    enum SceneInputMode: String, Codable, Equatable {
        case scanVideo = "scan_video"
        case singlePhoto = "single_photo"
    }

    enum SceneInputStatus: String, Codable, Equatable {
        case accepted
        case acceptedSuboptimal = "accepted_suboptimal"
        case rejectedRetryRequired = "rejected_retry_required"
        case uploadFailed = "upload_failed"
    }

    enum SceneMatchType: String, Codable, Equatable {
        case referenceMatch = "reference_match"
        case styleSynthesis = "style_synthesis"
        case bestEffortFallback = "best_effort_fallback"
    }

    enum Readiness: String, Codable, Equatable {
        case scanning
        case coaching
        case almostReady = "almost_ready"
        case ready
        case bestEffort = "best_effort"
        case blocked
    }

    enum CameraCapabilityStatus: String, Codable, Equatable {
        case applied
        case adjusted
        case unavailable
        case needsOperatorAdjustment = "needs_operator_adjustment"
        case pending
    }

    enum RuntimeAffordanceSignalType: String, Codable, Equatable {
        case softFrontLight = "soft_front_light"
        case softSideLight = "soft_side_light"
        case rimHairEdgeLight = "rim_hair_edge_light"
        case projectedShadowPattern = "projected_shadow_pattern"
        case dramaticSideLightUsable = "dramatic_side_light_usable"
        case classicLocationAnchor = "classic_location_anchor"
        case openSpaceAnchor = "open_space_anchor"
        case architecturalAnchor = "architectural_anchor"
        case cropHeadroomAvailable = "crop_headroom_available"
        case naturalMotionOpportunity = "natural_motion_opportunity"
        case relationshipInteractionOpportunity = "relationship_interaction_opportunity"
        case focusDepthOpportunity = "focus_depth_opportunity"
    }

    enum PostCapturePrerequisite: String, Codable, Equatable {
        case protectedSubjectFocus = "protected_subject_focus"
        case usableFaceLight = "usable_face_light"
        case naturalExpressionOrInteraction = "natural_expression_or_interaction"
        case cropHeadroom = "crop_headroom"
        case protectedSubjectsVisible = "protected_subjects_visible"
    }

    enum PostCaptureFineTuneSignal: String, Codable, Equatable {
        case lightShadowContrast = "light_shadow_contrast"
        case portfolioColorTone = "portfolio_color_tone"
        case cropComposition = "crop_composition"
        case localCrispnessOrSoftness = "local_crispness_or_softness"
        case backgroundReadabilityOrSubjectSeparation = "background_readability_or_subject_separation"
    }

    struct RuntimeStyleProfileInput: Codable, Equatable {
        let styleProfileId: String
        let styleProfile: StyleProfile
    }

    struct StyleProfile: Codable, Equatable {
        let styleProfileId: String
        let portfolioId: String?
        let profileVersion: String
        let profileSource: String
        let profileStatus: String
        let professionalHappyMomentBaseline: ProfessionalHappyMomentBaseline
        let runtimeAffordanceSignals: StyleRuntimeAffordanceSignals
        let postCaptureFineTuneSignals: [PostCaptureFineTuneSignal]
        let nativeCameraParameterIntent: NativeCameraParameterIntent
        let confidence: [String: Double]?
    }

    struct ProfessionalHappyMomentBaseline: Codable, Equatable {
        let protectSubjectFaceLight: Bool
        let preferNaturalRelaxedExpression: Bool
        let preferRelationshipInteraction: Bool
        let focusProtectedSubjects: Bool
        let preserveCropHeadroomWhenPossible: Bool
    }

    struct StyleRuntimeAffordanceSignals: Codable, Equatable {
        let sceneAnalysisShouldDetect: [RuntimeAffordanceSignalType]
        let liveCoachShouldProtect: [String]
    }

    struct NativeCameraParameterIntent: Codable, Equatable {
        let focus: FocusIntent
        let exposure: ExposureIntent
        let whiteBalance: WhiteBalanceIntent
        let zoomLensFraming: ZoomLensFramingIntent
        let depthPortrait: DepthPortraitIntent
        let captureQuality: CaptureQualityIntent
        let flashLowLightPolicy: FlashLowLightPolicy
        let capabilityPolicy: CapabilityPolicy
    }

    struct FocusIntent: Codable, Equatable {
        let target: String
        let modePreference: String
        let focusPointStrategy: String
        let lensPositionStrategy: String?
    }

    struct ExposureIntent: Codable, Equatable {
        let meteringTarget: String
        let biasPreference: Double?
        let protectHighlights: Bool?
        let avoidFaceShadowCrush: Bool?
        let customExposureAllowed: Bool?
    }

    struct WhiteBalanceIntent: Codable, Equatable {
        let modePreference: String
        let colorTemperatureBias: String?
        let lockWhenFaceLightReady: Bool?
    }

    struct ZoomLensFramingIntent: Codable, Equatable {
        let preferredLens: String
        let allowUltraWideForTightSpaces: Bool?
        let avoidDigitalZoomBeyond: Double?
        let preserveCropHeadroom: Bool?
    }

    struct DepthPortraitIntent: Codable, Equatable {
        let depthDataPreferred: Bool?
        let portraitEffectsMattePreferred: Bool?
        let blurStrengthIntent: String?
        let keepEnvironmentReadable: Bool?
    }

    struct CaptureQualityIntent: Codable, Equatable {
        let photoQualityPrioritization: String
        let highResolutionPreferred: Bool?
        let burstPreferred: Bool?
        let captureResponsiveness: String?
    }

    struct FlashLowLightPolicy: Codable, Equatable {
        let preferNaturalLight: Bool
        let flashAllowedOnlyForRecovery: Bool?
        let torchAllowedOnlyForRecovery: Bool?
    }

    struct CapabilityPolicy: Codable, Equatable {
        let mustReportGaps: Bool
        let allowClosestAvailableFallback: Bool
    }

    struct ProtectedSubjectSet: Codable, Equatable {
        let protectedSubjectSetId: String
        let protectedSubjectCount: Int
        let subjects: [ProtectedSubject]
        let rules: ProtectedSubjectRules
        let ignoredDetections: [IgnoredDetection]?
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
        let closedEyesRejectFrame: Bool?
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
        let ingestionMetadata: SceneInputIngestionMetadata?
        let qualitySignals: SceneInputQualitySignals?
        let uploadFailureReason: SceneInputFailureReason?
    }

    struct SceneInputIngestionMetadata: Codable, Equatable {
        let mediaKind: SceneInputMediaKind
        let frameCount: Int?
        let sampledFrameCount: Int?
        let durationMilliseconds: Int?
        let capturedAt: String?
        let liveFrameSummary: LiveFrameSummary?
        let qualitySignals: SceneInputQualitySignals?
    }

    enum SceneInputMediaKind: String, Codable, Equatable {
        case scanVideo = "scan_video"
        case sampledFrames = "sampled_frames"
        case singleScenePhoto = "single_scene_photo"
        case liveFrameSummary = "live_frame_summary"
    }

    struct CreateSceneInputResponse: Codable, Equatable {
        let sceneInputId: String
        let sceneInputAttemptId: String
        let sceneAnalysisId: String?
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
        let persistenceWriteIntent: [String]?
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
        let professionalHappyMomentAssessment: ProfessionalHappyMomentAssessment
        let runtimeAffordanceSignals: [RuntimeAffordanceSignal]
        let postCapturePrerequisites: PostCapturePrerequisites
        let postCaptureFineTuneSignals: [PostCaptureFineTuneSignal]
        let standPoint: LabeledDescription
        let subjectPosition: SubjectPosition
        let operatorPosition: OperatorPosition
        let facingDirection: FacingDirection
        let roughFraming: RoughFraming
        let coachingCues: [CoachingCue]
        let initialCameraSettingsRecommendation: InitialCameraSettingsRecommendation
        let fallback: ScenePlanFallback?
        let persistenceWriteIntent: [String]?
    }

    struct EvaluateLiveFrameReadinessRequest: Codable, Equatable {
        let scenePlanId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let initialCameraSettingsRecommendation: InitialCameraSettingsRecommendation
        let runtimeAffordanceSignals: [RuntimeAffordanceSignal]
        let postCapturePrerequisites: PostCapturePrerequisites
        let liveFrameSummary: LiveFrameSummary
    }

    struct EvaluateLiveFrameReadinessResponse: Codable, Equatable {
        let scenePlanId: String
        let readiness: Readiness
        let score: Double
        let blockingIssues: [String]
        let cues: [CoachingCue]
        let dynamicCameraSettingsAdjustment: DynamicCameraSettingsAdjustment
        let capturedAffordanceMetadata: CapturedAffordanceMetadata
        let postCapturePrerequisiteStatus: [String: String]
        let cameraSettingsUsed: CameraSettingsUsed?
        let canCaptureBestEffort: Bool
        let persistenceWriteIntent: [String]?
    }

    struct BuildBeforeCaptureFinalMomentHandoffRequest: Codable, Equatable {
        let scenePlanId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
        let initialCameraSettingsRecommendation: InitialCameraSettingsRecommendation
        let runtimeAffordanceSignals: [RuntimeAffordanceSignal]
        let postCapturePrerequisites: PostCapturePrerequisites
        let capturedAffordanceMetadata: CapturedAffordanceMetadata
        let cameraSettingsUsed: CameraSettingsUsed?
    }

    struct BeforeCaptureFinalMomentHandoff: Codable, Equatable {
        let scenePlanId: String
        let styleProfileId: String
        let protectedSubjectSetId: String
        let sceneInputQualityContext: SceneInputQualityContext
        let initialCameraSettingsRecommendation: InitialCameraSettingsRecommendation
        let runtimeAffordanceSignals: [RuntimeAffordanceSignal]
        let postCapturePrerequisites: PostCapturePrerequisites
        let capturedAffordanceMetadata: CapturedAffordanceMetadata
        let cameraSettingsUsed: CameraSettingsUsed
        let persistenceWriteIntent: [String]?
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
        static let empty = SceneInputQualitySignals(
            tooDark: false,
            overexposed: false,
            motionBlur: false,
            scanTooShort: false,
            noUsefulCompositionSpace: false,
            uploadFailed: false
        )

        let tooDark: Bool
        let overexposed: Bool
        let motionBlur: Bool
        let scanTooShort: Bool
        let noUsefulCompositionSpace: Bool
        let uploadFailed: Bool?
    }

    struct ProfessionalHappyMomentAssessment: Codable, Equatable {
        let faceLightUsable: Bool
        let naturalExpressionOpportunity: Bool
        let relationshipInteractionOpportunity: Bool
        let protectedSubjectFocusFeasible: Bool
        let cropHeadroomFeasible: Bool
        let unrecoverableRisks: [String]?
    }

    struct RuntimeAffordanceSignal: Codable, Equatable {
        let type: RuntimeAffordanceSignalType
        let confidence: Double
        let recommendedUse: String?
        let evidence: String?
    }

    struct PostCapturePrerequisites: Codable, Equatable {
        let mustCaptureCorrectly: [PostCapturePrerequisite]
        let canFineTuneLater: [PostCaptureFineTuneSignal]?
        let statusAtCapture: [String: String]?
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

    struct ScenePlanFallback: Codable, Equatable {
        let type: String
        let message: String
        let nextAction: String
        let canContinueBestEffort: Bool
    }

    struct InitialCameraSettingsRecommendation: Codable, Equatable {
        let recommendationId: String
        let sourceNativeCameraParameterIntentId: String?
        let focus: FocusRecommendation
        let exposure: ExposureRecommendation
        let whiteBalance: WhiteBalanceRecommendation
        let zoomLens: ZoomLensRecommendation?
        let depth: DepthRecommendation?
        let framing: FramingRecommendation?
        let colorAndTonePreview: ColorAndTonePreview?
        let capture: CaptureRecommendation?
        let flashLowLight: FlashLowLightRecommendation?
        let capabilityRequirements: CapabilityRequirements?
    }

    struct FocusRecommendation: Codable, Equatable {
        let target: String
        let mode: String
        let priority: String?
        let focusPointStrategy: String?
    }

    struct ExposureRecommendation: Codable, Equatable {
        let meteringTarget: String
        let bias: Double?
        let protectHighlights: Bool?
        let avoidFaceClipping: Bool?
        let avoidFaceShadowCrush: Bool?
    }

    struct WhiteBalanceRecommendation: Codable, Equatable {
        let mode: String
        let lockWhenReady: Bool?
        let temperatureBias: String?
        let tintBias: String?
    }

    struct ZoomLensRecommendation: Codable, Equatable {
        let preferredLens: String
        let targetZoomFactor: Double?
        let maxDigitalZoomFactor: Double?
        let allowUltraWideIfOperatorTooClose: Bool?
        let avoidLensSwitchDuringCapture: Bool?
    }

    struct DepthRecommendation: Codable, Equatable {
        let mode: String
        let portraitBlurStrength: Double?
        let keepArchitecturalAnchorReadable: Bool?
        let depthDataDeliveryPreferred: Bool?
        let portraitEffectsMattePreferred: Bool?
    }

    struct FramingRecommendation: Codable, Equatable {
        let shootWide: Bool?
        let safetyMargin: String?
        let orientation: String?
        let compositionTarget: String?
    }

    struct ColorAndTonePreview: Codable, Equatable {
        let contrast: String?
        let saturation: String?
        let highlightRecovery: String?
    }

    struct CaptureRecommendation: Codable, Equatable {
        let burstCount: Int?
        let highestPracticalResolution: Bool?
        let photoQualityPrioritization: String?
        let captureResponsiveness: String?
        let stabilizationPreferred: Bool?
    }

    struct FlashLowLightRecommendation: Codable, Equatable {
        let preferNaturalLight: Bool?
        let flashMode: String?
        let torchAllowed: Bool?
        let lowLightRecoveryPolicy: String?
    }

    struct CapabilityRequirements: Codable, Equatable {
        let reportUnavailableSettings: Bool?
        let allowedFallbackBehavior: String?
        let statusValues: [CameraCapabilityStatus]?
    }

    struct LiveFrameSummary: Codable, Equatable {
        let protectedSubjectsVisible: Bool
        let protectedSubjectFocusState: String
        let faceExposureState: String
        let expressionInteractionState: String?
        let cropHeadroomState: String
        let detectedAffordances: [RuntimeAffordanceSignalType]?
        let lightChangedFromSceneAnalysis: Bool?
        let nativeCapabilities: NativeCameraCapabilities
    }

    struct NativeCameraCapabilities: Codable, Equatable {
        let canLockFocus: Bool
        let canSetFocusPoint: Bool?
        let canSetExposurePoint: Bool?
        let canSetExposureBias: Bool?
        let canLockWhiteBalance: Bool?
        let canSetWhiteBalanceGains: Bool?
        let canUseDepth: Bool?
        let canDeliverDepthData: Bool?
        let canDeliverPortraitEffectsMatte: Bool?
        let availableLenses: [String]?
        let minZoomFactor: Double?
        let maxOpticalZoomFactor: Double?
        let maxAcceptableDigitalZoomFactor: Double?
        let canSetPhotoQualityPrioritization: Bool?
        let canCaptureBurst: Bool?
        let canUseHighestPracticalResolution: Bool?
        let canControlFlash: Bool?
        let canUseTorch: Bool?
    }

    struct DynamicCameraSettingsAdjustment: Codable, Equatable {
        let focus: CameraAdjustment
        let exposure: CameraAdjustment
        let whiteBalance: CameraAdjustment
        let zoomLens: CameraAdjustment
        let depth: CameraAdjustment
        let framing: CameraAdjustment
        let capture: CameraAdjustment
        let flashLowLight: CameraAdjustment
        let capabilityStatus: [String: CameraCapabilityStatus]
    }

    struct CameraAdjustment: Codable, Equatable {
        let status: CameraCapabilityStatus
        let value: String?
        let reason: String?
        let capabilityGap: String?
        let lockedOn: [String]?
        let adjustment: String?
        let meteringTarget: String?
        let bias: Double?
        let mode: String?
        let temperatureBias: String?
        let portraitBlurStrength: Double?
        let depthDataDelivery: Bool?
        let portraitEffectsMatteDelivery: Bool?
        let lensUsed: String?
        let zoomFactor: Double?
        let cue: String?
        let shootWide: Bool?
        let burstCount: Int?
        let highestPracticalResolution: Bool?
        let photoQualityPrioritization: String?
        let captureResponsiveness: String?
        let flashMode: String?
        let torchMode: String?
    }

    struct CapturedAffordanceMetadata: Codable, Equatable {
        let protectedSubjectFocusReady: Bool
        let faceExposureUsable: Bool
        let rimHairEdgeLightPreserved: Bool?
        let naturalExpressionOrInteractionObserved: Bool
        let cropHeadroomPreserved: Bool
        let postCaptureFineTuneEligible: [PostCaptureFineTuneSignal]
        let weakPrerequisites: [PostCapturePrerequisite]?
    }

    struct CameraSettingsUsed: Codable, Equatable {
        let settingsId: String
        let appliedRecommendationId: String
        let focusModeUsed: String?
        let focusPointStrategyUsed: String?
        let focusStatus: CameraCapabilityStatus
        let exposureMeteringTargetUsed: String?
        let exposureBiasUsed: Double?
        let exposureStatus: CameraCapabilityStatus
        let whiteBalanceModeUsed: String?
        let whiteBalanceStatus: CameraCapabilityStatus
        let lensUsed: String?
        let zoomFactorUsed: Double?
        let zoomLensStatus: CameraCapabilityStatus
        let depthModeUsed: String?
        let depthDataDeliveryUsed: Bool?
        let portraitEffectsMatteUsed: Bool?
        let depthStatus: CameraCapabilityStatus
        let photoQualityPrioritizationUsed: String?
        let burstCountRequested: Int?
        let burstCountCaptured: Int?
        let highestPracticalResolutionUsed: Bool?
        let flashModeUsed: String?
        let lowLightPolicyUsed: String?
        let capabilityGaps: [String]
        let substitutions: [CameraSettingSubstitution]?
    }

    struct CameraSettingSubstitution: Codable, Equatable {
        let parameter: String
        let requested: Bool?
        let used: Bool?
        let status: CameraCapabilityStatus
        let reason: String
    }
}
