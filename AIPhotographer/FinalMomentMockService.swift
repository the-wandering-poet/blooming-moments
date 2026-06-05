import Foundation

enum FinalMomentAssetRole: String, Codable {
    case original
    case cropPreview
    case cropped
    case edited
    case thumbnail
}

enum FinalMomentCapabilityStatus: String, Codable, Equatable {
    case applied
    case adjusted
    case unavailable
    case needsOperatorAdjustment = "needs_operator_adjustment"
    case available
    case locked
    case notRequested = "not_requested"
}

enum FinalMomentRejectionReason: String, Codable, Equatable, Hashable {
    case protectedSubjectClosedEyes = "protected_subject_closed_eyes"
    case protectedSubjectFocusFailed = "protected_subject_focus_failed"
    case protectedSubjectFaceBlur = "protected_subject_face_blur"
    case protectedSubjectFaceLightUnusable = "protected_subject_face_light_unusable"
    case protectedSubjectFaceExposureUnusable = "protected_subject_face_exposure_unusable"
    case protectedSubjectMissing = "protected_subject_missing"
    case deadOrStiffExpression = "dead_or_stiff_expression"
    case missingRequiredInteraction = "missing_required_interaction"
    case cropHeadroomNotPreserved = "crop_headroom_not_preserved"
    case assetUnreadable = "asset_unreadable"
    case burstFrameCorrupt = "burst_frame_corrupt"
}

enum FinalMomentRuntimeAffordanceSignal: String, Codable, Equatable, Hashable {
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

struct FinalMomentAssetRef: Codable, Equatable {
    let assetId: String
    let uri: String
    let role: FinalMomentAssetRole
    let width: Int
    let height: Int
    let mimeType: String
}

struct FinalMomentNormalizedRect: Codable, Equatable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct FinalMomentSceneInputQualityContext: Codable, Equatable {
    let sceneInputStatus: String
    let allowsSuboptimalSceneInput: Bool
    let sceneInputFailureReason: String?
}

struct FinalMomentFocusRecommendation: Codable, Equatable {
    let target: String
    let mode: String
    let priority: String
}

struct FinalMomentExposureRecommendation: Codable, Equatable {
    let meteringTarget: String
    let bias: Double
    let protectHighlights: Bool
    let avoidFaceClipping: Bool
}

struct FinalMomentWhiteBalanceRecommendation: Codable, Equatable {
    let mode: String
    let lockWhenReady: Bool
}

struct FinalMomentDepthRecommendation: Codable, Equatable {
    let mode: String
    let portraitBlurStrength: Double
    let keepArchitecturalAnchorReadable: Bool
}

struct FinalMomentFramingRecommendation: Codable, Equatable {
    let shootWide: Bool
    let safetyMargin: String
    let orientation: String
    let compositionTarget: String
}

struct FinalMomentColorAndTonePreview: Codable, Equatable {
    let contrast: String
    let saturation: String
    let highlightRecovery: String
}

struct FinalMomentCaptureRecommendation: Codable, Equatable {
    let burstCount: Int
    let highestPracticalResolution: Bool
    let photoQualityPrioritization: String
    let flashMode: String
}

struct FinalMomentInitialCameraSettingsRecommendation: Codable, Equatable {
    let recommendationId: String
    let focus: FinalMomentFocusRecommendation
    let exposure: FinalMomentExposureRecommendation
    let whiteBalance: FinalMomentWhiteBalanceRecommendation
    let depth: FinalMomentDepthRecommendation
    let framing: FinalMomentFramingRecommendation
    let colorAndTonePreview: FinalMomentColorAndTonePreview
    let capture: FinalMomentCaptureRecommendation
}

struct FinalMomentCameraSettingActual: Codable, Equatable {
    let status: FinalMomentCapabilityStatus
    let requested: String
    let applied: String
    let reason: String?
}

struct FinalMomentCameraSettingsUsed: Codable, Equatable {
    let settingsId: String
    let appliedRecommendationId: String
    let dynamicCameraSettingsAdjustmentId: String
    let focusModeUsed: String
    let exposureBiasUsed: Double
    let whiteBalanceModeUsed: String
    let depthModeUsed: String
    let zoomLensModeUsed: String
    let burstCountRequested: Int
    let burstCountCaptured: Int
    let highestPracticalResolutionUsed: Bool
    let focus: FinalMomentCameraSettingActual
    let exposure: FinalMomentCameraSettingActual
    let whiteBalance: FinalMomentCameraSettingActual
    let depthPortrait: FinalMomentCameraSettingActual
    let zoomLens: FinalMomentCameraSettingActual
    let framing: FinalMomentCameraSettingActual
    let captureQuality: FinalMomentCameraSettingActual
    let flashLowLightPolicy: FinalMomentCameraSettingActual
    let capabilityStatus: [String: FinalMomentCapabilityStatus]
    let capabilityGaps: [String]
}

struct FinalMomentPostCapturePrerequisites: Codable, Equatable {
    let mustCaptureCorrectly: [String]
    let protectedSubjectFocusRequired: Bool
    let usableFaceLightRequired: Bool
    let naturalExpressionOrInteractionRequired: Bool
    let cropHeadroomRequired: Bool
}

struct FinalMomentCapturedAffordanceMetadata: Codable, Equatable {
    let protectedSubjectFocusReady: Bool
    let faceExposureUsable: Bool
    let rimHairEdgeLightPreserved: Bool
    let projectedShadowPatternPreserved: Bool
    let architecturalAnchorPreserved: Bool
    let naturalExpressionOrInteractionObserved: Bool
    let cropHeadroomPreserved: Bool
    let postCaptureFineTuneEligible: [String]
}

struct FinalMomentCameraSettingsIntentSnapshot: Codable, Equatable {
    let styleProfileId: String
    let styleProfileVersion: String
    let nativeCameraParameterIntentVersion: String
    let initialCameraSettingsRecommendationId: String
    let dynamicCameraSettingsAdjustmentId: String
}

struct FinalMomentProfessionalHappyMomentAssessment: Codable, Equatable {
    let protectedSubjectFocusUsable: Bool
    let protectedSubjectFaceLightUsable: Bool
    let naturalExpressionOrInteractionPresent: Bool
    let cropHeadroomPreserved: Bool
    let capturedAffordances: [FinalMomentRuntimeAffordanceSignal]
    let weakOrMissingPrerequisites: [String]
}

struct FinalMomentAssetProvenance: Codable, Equatable {
    let frameId: String
    let originalAssetRef: FinalMomentAssetRef
    let cameraSettingsUsedId: String
    let captureResultId: String?
}

struct FinalMomentCaptureContext: Codable, Equatable {
    let sessionId: String
    let scenarioId: String
    let sceneTitle: String
    let sourcePortfolioId: String
}

struct FinalMomentRuntimeCaptureHandoff: Codable, Equatable {
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let styleProfileVersion: String
    let profileSchemaVersion: String
    let nativeCameraParameterIntentVersion: String
    let sceneInputQualityContext: FinalMomentSceneInputQualityContext
    let initialCameraSettingsRecommendation: FinalMomentInitialCameraSettingsRecommendation
    let dynamicCameraSettingsAdjustmentId: String
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let postCapturePrerequisites: FinalMomentPostCapturePrerequisites
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
}

struct FinalMomentCaptureRequest: Codable, Equatable {
    let context: FinalMomentCaptureContext
    let runtimeHandoff: FinalMomentRuntimeCaptureHandoff
}

struct FinalMomentFrame: Codable, Identifiable, Equatable {
    var id: String { frameId }

    let frameId: String
    let assetRef: FinalMomentAssetRef
    let timestamp: String
    let burstIndex: Int
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed?
}

struct FinalMomentCaptureResult: Codable, Equatable {
    let captureResultId: String
    let sessionId: String
    let scenarioId: String
    let sceneTitle: String
    let sourcePortfolioId: String
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let sceneInputQualityContext: FinalMomentSceneInputQualityContext
    let initialCameraSettingsRecommendation: FinalMomentInitialCameraSettingsRecommendation
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let postCapturePrerequisites: FinalMomentPostCapturePrerequisites
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let professionalHappyMomentAssessment: FinalMomentProfessionalHappyMomentAssessment
    let cameraSettingsIntentSnapshot: FinalMomentCameraSettingsIntentSnapshot
    let assetProvenance: [FinalMomentAssetProvenance]
    let frames: [FinalMomentFrame]
}

struct FinalMomentAutoCullRequest: Codable, Equatable {
    let captureResultId: String
    let protectedSubjectSetId: String
}

struct FinalMomentProtectedSubjectCheck: Codable, Equatable {
    let frameId: String
    let subjectId: String
    let eyesOpen: Bool
    let faceSharpness: Double
    let faceExposure: Double
    let focusUsable: Bool
    let faceExposureUsable: Bool
    let faceLightQuality: String
    let expressionNaturalness: Double
    let interactionPresent: Bool
    let cropProtectionStatus: String
    let protectedSubjectInFrame: Bool
}

struct FinalMomentAcceptedFrame: Codable, Identifiable, Equatable {
    var id: String { frameId }

    let frameId: String
    let assetRef: FinalMomentAssetRef
    let qualityScore: Double
    let expressionScore: Double
    let protectedSubjectChecks: [FinalMomentProtectedSubjectCheck]
}

struct FinalMomentRejectedFrame: Codable, Identifiable, Equatable {
    var id: String { frameId }

    let frameId: String
    let assetRef: FinalMomentAssetRef
    let reasons: [FinalMomentRejectionReason]
    let protectedSubjectChecks: [FinalMomentProtectedSubjectCheck]
}

struct FinalMomentAutoCullFrameProvenance: Codable, Equatable {
    let frameId: String
    let cameraSettingsUsedId: String
    let cameraStatusEvidence: [String]
    let assessmentConfidence: Double
    let assessmentProvenanceNotes: [String]
}

struct FinalMomentAutoCullResult: Codable, Equatable {
    let autoCullResultId: String
    let captureResultId: String
    let acceptedFrames: [FinalMomentAcceptedFrame]
    let rejectedFrames: [FinalMomentRejectedFrame]
    let rejectionReasons: [String: [FinalMomentRejectionReason]]
    let allFramesRejected: Bool
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
    let frameProvenance: [FinalMomentAutoCullFrameProvenance]
}

struct FinalMomentKeeperSelectionRequest: Codable, Equatable {
    let autoCullResultId: String
    let selectedFrameIds: [String]
}

struct FinalMomentKeeperSelection: Codable, Equatable {
    let keeperSelectionId: String
    let autoCullResultId: String
    let captureResultId: String
    let protectedSubjectSetId: String
    let selectedFrameIds: [String]
}

struct FinalMomentCropGenerationRequest: Codable, Equatable {
    let keeperSelectionId: String
    let styleProfileId: String
    let scenePlanId: String
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let postCapturePrerequisites: FinalMomentPostCapturePrerequisites
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
}

struct FinalMomentCropCandidate: Codable, Identifiable, Equatable {
    var id: String { cropId }

    let cropId: String
    let frameId: String
    let label: String
    let cropBox: FinalMomentNormalizedRect
    let cropPreviewAssetRef: FinalMomentAssetRef
    let compositionRationale: String
    let isDefaultFallback: Bool
    let protectedSubjectCropSafety: String
    let preservedAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let lostAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let cropHeadroomUsage: String
    let affordanceLossRisk: String
    let defaultFallbackReason: String?
}

struct FinalMomentCropGenerationResult: Codable, Equatable {
    let cropGenerationResultId: String
    let keeperSelectionId: String
    let cropCandidates: [FinalMomentCropCandidate]
    let recommendedCropByFrame: [String: String]
}

struct FinalMomentFineTuneRequest: Codable, Equatable {
    let keeperSelectionId: String
    let cropGenerationResultId: String
    let styleProfileId: String
    let styleProfileVersion: String
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
}

struct FinalMomentEditParameters: Codable, Equatable {
    let exposure: Double
    let contrast: Double
    let warmth: Double
    let highlightRecovery: Double
    let shadowRecovery: Double
    let toneCurve: String
    let localCrispness: Double
    let localSoftness: Double
    let skinToneProtection: Double
    let shadowPatternEmphasis: Double
    let rimLightEmphasis: Double
    let backgroundReadability: Double
    let subjectSeparation: Double
    let grainOrTexture: Double
}

struct FinalMomentConsumedSignals: Codable, Equatable {
    let styleProfileSignals: [String]
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: [String]
    let cameraSettingsUsed: [String]
}

struct FinalMomentFineTuneItem: Codable, Identifiable, Equatable {
    var id: String { frameId }

    let frameId: String
    let originalAssetRef: FinalMomentAssetRef
    let croppedAssetRef: FinalMomentAssetRef
    let editedAssetRef: FinalMomentAssetRef
    let recommendedCropId: String
    let editParameters: FinalMomentEditParameters
    let consumedSignals: FinalMomentConsumedSignals
    let enhancedAffordances: [String]
    let cannotRecoverWarnings: [String]
    let isRegeneration: Bool
}

struct FinalMomentFineTuneResult: Codable, Equatable {
    let fineTuneResultId: String
    let keeperSelectionId: String
    let cropGenerationResultId: String
    let presetApplied: String
    let items: [FinalMomentFineTuneItem]
}

enum FinalMomentSelectedOutput: String, Codable, Equatable {
    case edited
    case croppedOriginal
}

struct FinalMomentPhotoDecision: Codable, Equatable {
    let frameId: String
    let selectedOutput: FinalMomentSelectedOutput
}

struct FinalMomentSaveRequest: Codable, Equatable {
    let fineTuneResultId: String
    let decisions: [FinalMomentPhotoDecision]
}

struct FinalMomentResumeCaptureContext: Codable, Equatable {
    let sessionId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let scenePlanId: String
}

struct FinalMomentSavedConfirmationState: Codable, Equatable {
    struct Actions: Codable, Equatable {
        let viewProfile: Bool
        let takeMorePhotos: Bool
    }

    let savedMomentIds: [String]
    let savedCount: Int
    let savedAssets: [FinalMomentAssetRef]
    let actions: Actions
    let resumeCaptureContext: FinalMomentResumeCaptureContext?
}

struct FinalMomentProvenance: Codable, Equatable {
    let captureResultId: String
    let autoCullResultId: String
    let keeperSelectionId: String
    let cropGenerationResultId: String
    let fineTuneResultId: String
    let scenePlanId: String
    let styleProfileId: String
    let styleProfileVersion: String
    let profileSchemaVersion: String
    let protectedSubjectSetId: String
    let nativeCameraParameterIntentSnapshot: FinalMomentCameraSettingsIntentSnapshot
    let initialCameraSettingsRecommendation: FinalMomentInitialCameraSettingsRecommendation
    let dynamicCameraSettingsAdjustmentId: String
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let postCapturePrerequisites: FinalMomentPostCapturePrerequisites
    let consumedSignals: FinalMomentConsumedSignals
    let cropDecisionId: String
    let fineTuneAccepted: Bool
    let originalAssetRef: FinalMomentAssetRef
    let croppedAssetRef: FinalMomentAssetRef
    let editedAssetRef: FinalMomentAssetRef
    let finalAssetRef: FinalMomentAssetRef
    let isRegeneration: Bool
}

struct FinalMomentSavedMoment: Codable, Identifiable, Equatable {
    var id: String { savedMomentId }

    let savedMomentId: String
    let sceneTitle: String
    let finalAssetRef: FinalMomentAssetRef
    let thumbnailAssetRef: FinalMomentAssetRef
    let isFineTuned: Bool
    let sourcePortfolioId: String
    let createdAt: String
    let provenance: FinalMomentProvenance
}

struct FinalMomentSaveResult: Codable, Equatable {
    let savedMoments: [FinalMomentSavedMoment]
    let savedConfirmation: FinalMomentSavedConfirmationState
}

struct FinalMomentProfileRequest: Codable, Equatable {
    let includeSavedPortfolios: Bool
}

struct FinalMomentGroup: Codable, Identifiable, Equatable {
    var id: String { sceneTitle }

    let sceneTitle: String
    let savedMomentIds: [String]
}

struct FinalMomentSavedPortfolio: Codable, Identifiable, Equatable {
    var id: String { portfolioId }

    let portfolioId: String
    let folderIds: [String]
}

struct FinalMomentBookmarkFolder: Codable, Identifiable, Equatable {
    var id: String { folderId }

    let folderId: String
    let name: String
    let portfolioIds: [String]
}

enum FinalMomentProfileSheetState: String, Codable {
    case none
    case momentsFolder
    case imagePreview
    case portfoliosOverlay
    case bookmarkFolderDetail
}

struct FinalMomentProfileState: Codable, Equatable {
    let savedMoments: [FinalMomentSavedMoment]
    let momentGroups: [FinalMomentGroup]
    let savedPortfolios: [FinalMomentSavedPortfolio]
    let bookmarkFolders: [FinalMomentBookmarkFolder]
    let profileSheetState: FinalMomentProfileSheetState
}

struct FinalMomentDemoBundle: Codable, Equatable {
    let captureResult: FinalMomentCaptureResult
    let autoCullResult: FinalMomentAutoCullResult
    let keeperSelection: FinalMomentKeeperSelection
    let cropGenerationResult: FinalMomentCropGenerationResult
    let fineTuneResult: FinalMomentFineTuneResult
    let saveResult: FinalMomentSaveResult
    let profileState: FinalMomentProfileState
}

enum FinalMomentMockServiceError: LocalizedError {
    case noKeeperSelected

    var errorDescription: String? {
        switch self {
        case .noKeeperSelected:
            return "Choose at least one accepted frame before fine tune."
        }
    }
}

final class FinalMomentMockService {
    private var captureResult: FinalMomentCaptureResult?
    private var autoCullResult: FinalMomentAutoCullResult?
    private var keeperSelection: FinalMomentKeeperSelection?
    private var cropGenerationResult: FinalMomentCropGenerationResult?
    private var fineTuneResult: FinalMomentFineTuneResult?
    private var savedMoments: [FinalMomentSavedMoment] = []

    func makeDemoCaptureRequest() -> FinalMomentCaptureRequest {
        let initialRecommendation = FinalMomentInitialCameraSettingsRecommendation(
            recommendationId: "camera_recommendation_demo_001",
            focus: FinalMomentFocusRecommendation(
                target: "all_protected_subjects",
                mode: "continuous_then_lock_when_ready",
                priority: "faces_and_bodies"
            ),
            exposure: FinalMomentExposureRecommendation(
                meteringTarget: "protected_subject_faces",
                bias: -0.3,
                protectHighlights: true,
                avoidFaceClipping: true
            ),
            whiteBalance: FinalMomentWhiteBalanceRecommendation(
                mode: "warm_daylight",
                lockWhenReady: true
            ),
            depth: FinalMomentDepthRecommendation(
                mode: "environmental_depth",
                portraitBlurStrength: 0.2,
                keepArchitecturalAnchorReadable: true
            ),
            framing: FinalMomentFramingRecommendation(
                shootWide: true,
                safetyMargin: "high",
                orientation: "vertical",
                compositionTarget: "wide_environmental"
            ),
            colorAndTonePreview: FinalMomentColorAndTonePreview(
                contrast: "medium",
                saturation: "slightly_warm",
                highlightRecovery: "moderate"
            ),
            capture: FinalMomentCaptureRecommendation(
                burstCount: 4,
                highestPracticalResolution: true,
                photoQualityPrioritization: "quality",
                flashMode: "off"
            )
        )
        let cameraSettingsUsed = makeDemoCameraSettingsUsed(recommendationId: initialRecommendation.recommendationId)

        return FinalMomentCaptureRequest(
            context: FinalMomentCaptureContext(
                sessionId: "session_demo_001",
                scenarioId: "graduation",
                sceneTitle: "Graduation",
                sourcePortfolioId: "campus_editorial_graduation"
            ),
            runtimeHandoff: FinalMomentRuntimeCaptureHandoff(
                scenePlanId: "scene_plan_demo_001",
                styleProfileId: "style_profile_demo_001",
                protectedSubjectSetId: "subject_set_demo_001",
                styleProfileVersion: "1.0.0",
                profileSchemaVersion: "2026-06-04",
                nativeCameraParameterIntentVersion: "camera_intent_demo_v1",
                sceneInputQualityContext: FinalMomentSceneInputQualityContext(
                    sceneInputStatus: "accepted",
                    allowsSuboptimalSceneInput: false,
                    sceneInputFailureReason: nil
                ),
                initialCameraSettingsRecommendation: initialRecommendation,
                dynamicCameraSettingsAdjustmentId: cameraSettingsUsed.dynamicCameraSettingsAdjustmentId,
                cameraSettingsUsed: cameraSettingsUsed,
                runtimeAffordanceSignals: demoRuntimeAffordanceSignals(),
                postCapturePrerequisites: demoPostCapturePrerequisites(),
                capturedAffordanceMetadata: demoCapturedAffordanceMetadata()
            )
        )
    }

    func recordCaptureResult(request: FinalMomentCaptureRequest) -> FinalMomentCaptureResult {
        let context = request.context
        let handoff = request.runtimeHandoff
        let settingsUsed = handoff.cameraSettingsUsed

        let frames = (1...settingsUsed.burstCountCaptured).map { index in
            FinalMomentFrame(
                frameId: "frame_demo_\(index)",
                assetRef: asset("frame_demo_\(index)", role: .original),
                timestamp: "2026-06-03T10:00:0\(index)Z",
                burstIndex: index,
                cameraSettingsUsed: settingsUsed
            )
        }
        let intentSnapshot = FinalMomentCameraSettingsIntentSnapshot(
            styleProfileId: handoff.styleProfileId,
            styleProfileVersion: handoff.styleProfileVersion,
            nativeCameraParameterIntentVersion: handoff.nativeCameraParameterIntentVersion,
            initialCameraSettingsRecommendationId: handoff.initialCameraSettingsRecommendation.recommendationId,
            dynamicCameraSettingsAdjustmentId: handoff.dynamicCameraSettingsAdjustmentId
        )
        let assetProvenance = frames.map {
            FinalMomentAssetProvenance(
                frameId: $0.frameId,
                originalAssetRef: $0.assetRef,
                cameraSettingsUsedId: settingsUsed.settingsId,
                captureResultId: "capture_result_demo_001"
            )
        }

        let result = FinalMomentCaptureResult(
            captureResultId: "capture_result_demo_001",
            sessionId: context.sessionId,
            scenarioId: context.scenarioId,
            sceneTitle: context.sceneTitle,
            sourcePortfolioId: context.sourcePortfolioId,
            scenePlanId: handoff.scenePlanId,
            styleProfileId: handoff.styleProfileId,
            protectedSubjectSetId: handoff.protectedSubjectSetId,
            sceneInputQualityContext: handoff.sceneInputQualityContext,
            initialCameraSettingsRecommendation: handoff.initialCameraSettingsRecommendation,
            cameraSettingsUsed: settingsUsed,
            runtimeAffordanceSignals: handoff.runtimeAffordanceSignals,
            postCapturePrerequisites: handoff.postCapturePrerequisites,
            capturedAffordanceMetadata: handoff.capturedAffordanceMetadata,
            professionalHappyMomentAssessment: FinalMomentProfessionalHappyMomentAssessment(
                protectedSubjectFocusUsable: handoff.capturedAffordanceMetadata.protectedSubjectFocusReady,
                protectedSubjectFaceLightUsable: handoff.capturedAffordanceMetadata.faceExposureUsable,
                naturalExpressionOrInteractionPresent: handoff.capturedAffordanceMetadata.naturalExpressionOrInteractionObserved,
                cropHeadroomPreserved: handoff.capturedAffordanceMetadata.cropHeadroomPreserved,
                capturedAffordances: handoff.runtimeAffordanceSignals,
                weakOrMissingPrerequisites: handoff.capturedAffordanceMetadata.naturalExpressionOrInteractionObserved ? [] : ["natural_expression_or_interaction_weak"]
            ),
            cameraSettingsIntentSnapshot: intentSnapshot,
            assetProvenance: assetProvenance,
            frames: frames
        )
        captureResult = result
        return result
    }

    func autoCullFrames(_ request: FinalMomentAutoCullRequest) -> FinalMomentAutoCullResult {
        let frames = captureResult?.frames ?? []
        let accepted = frames.enumerated().compactMap { item -> FinalMomentAcceptedFrame? in
            let frame = item.element
            guard item.offset != 1 else { return nil }
            return FinalMomentAcceptedFrame(
                frameId: frame.frameId,
                assetRef: frame.assetRef,
                qualityScore: item.offset == 0 ? 0.91 : 0.84,
                expressionScore: item.offset == 0 ? 0.88 : 0.81,
                protectedSubjectChecks: [
                    protectedSubjectCheck(frameId: frame.frameId, eyesOpen: true)
                ]
            )
        }

        let rejected = frames.enumerated().compactMap { item -> FinalMomentRejectedFrame? in
            guard item.offset == 1 else { return nil }
            let frame = item.element
            return FinalMomentRejectedFrame(
                frameId: frame.frameId,
                assetRef: frame.assetRef,
                reasons: [.protectedSubjectClosedEyes],
                protectedSubjectChecks: [
                    protectedSubjectCheck(frameId: frame.frameId, eyesOpen: false)
                ]
            )
        }

        let result = FinalMomentAutoCullResult(
            autoCullResultId: "auto_cull_demo_001",
            captureResultId: request.captureResultId,
            acceptedFrames: accepted,
            rejectedFrames: rejected,
            rejectionReasons: Dictionary(uniqueKeysWithValues: rejected.map {
                ($0.frameId, $0.reasons)
            }),
            allFramesRejected: accepted.isEmpty,
            cameraSettingsUsed: captureResult?.cameraSettingsUsed ?? makeDemoCameraSettingsUsed(recommendationId: "camera_recommendation_demo_001"),
            frameProvenance: frames.map { frame in
                FinalMomentAutoCullFrameProvenance(
                    frameId: frame.frameId,
                    cameraSettingsUsedId: frame.cameraSettingsUsed?.settingsId ?? "camera_settings_used_demo_001",
                    cameraStatusEvidence: [
                        "focus.applied",
                        "exposure.adjusted",
                        "captureQuality.applied"
                    ],
                    assessmentConfidence: frame.frameId == "frame_demo_2" ? 0.34 : 0.88,
                    assessmentProvenanceNotes: frame.frameId == "frame_demo_2"
                        ? ["protected_subject_closed_eyes"]
                        : ["protected_subject_focus_usable", "face_light_usable", "expression_interaction_usable"]
                )
            }
        )
        autoCullResult = result
        return result
    }

    func createKeeperSelection(_ request: FinalMomentKeeperSelectionRequest) throws -> FinalMomentKeeperSelection {
        guard !request.selectedFrameIds.isEmpty else {
            throw FinalMomentMockServiceError.noKeeperSelected
        }

        let acceptedIds = Set(autoCullResult?.acceptedFrames.map(\.frameId) ?? [])
        let selectedIds = request.selectedFrameIds.filter { acceptedIds.contains($0) }
        guard !selectedIds.isEmpty else {
            throw FinalMomentMockServiceError.noKeeperSelected
        }

        let selection = FinalMomentKeeperSelection(
            keeperSelectionId: "keeper_selection_demo_001",
            autoCullResultId: request.autoCullResultId,
            captureResultId: autoCullResult?.captureResultId ?? captureResult?.captureResultId ?? "capture_result_demo_001",
            protectedSubjectSetId: captureResult?.protectedSubjectSetId ?? "subject_set_demo_001",
            selectedFrameIds: selectedIds
        )
        keeperSelection = selection
        return selection
    }

    func generateInternalCrops(_ request: FinalMomentCropGenerationRequest) -> FinalMomentCropGenerationResult {
        let selectedIds = keeperSelection?.selectedFrameIds ?? []
        var candidates: [FinalMomentCropCandidate] = []
        var recommended: [String: String] = [:]

        for frameId in selectedIds {
            let environmentalId = "crop_\(frameId)_environmental"
            let balancedId = "crop_\(frameId)_balanced"
            let standardId = "crop_\(frameId)_standard_default"

            let frameCandidates = [
                FinalMomentCropCandidate(
                    cropId: environmentalId,
                    frameId: frameId,
                    label: "Environmental",
                    cropBox: FinalMomentNormalizedRect(x: 0.05, y: 0.02, w: 0.90, h: 0.92),
                    cropPreviewAssetRef: asset(environmentalId, role: .cropPreview),
                    compositionRationale: "Keeps the subject small and preserves the architectural anchor.",
                    isDefaultFallback: false,
                    protectedSubjectCropSafety: "all_protected_subjects_preserved",
                    preservedAffordanceSignals: [.architecturalAnchor, .rimHairEdgeLight, .cropHeadroomAvailable],
                    lostAffordanceSignals: [],
                    cropHeadroomUsage: "moderate",
                    affordanceLossRisk: "low",
                    defaultFallbackReason: nil
                ),
                FinalMomentCropCandidate(
                    cropId: balancedId,
                    frameId: frameId,
                    label: "Balanced",
                    cropBox: FinalMomentNormalizedRect(x: 0.12, y: 0.08, w: 0.76, h: 0.82),
                    cropPreviewAssetRef: asset(balancedId, role: .cropPreview),
                    compositionRationale: "Balances subject presence with scene depth.",
                    isDefaultFallback: false,
                    protectedSubjectCropSafety: "all_protected_subjects_preserved",
                    preservedAffordanceSignals: [.architecturalAnchor, .cropHeadroomAvailable],
                    lostAffordanceSignals: [.rimHairEdgeLight],
                    cropHeadroomUsage: "medium_high",
                    affordanceLossRisk: "medium",
                    defaultFallbackReason: nil
                ),
                FinalMomentCropCandidate(
                    cropId: standardId,
                    frameId: frameId,
                    label: "Standard",
                    cropBox: FinalMomentNormalizedRect(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
                    cropPreviewAssetRef: asset(standardId, role: .cropPreview),
                    compositionRationale: "Default safe framing if no special crop is useful.",
                    isDefaultFallback: true,
                    protectedSubjectCropSafety: "all_protected_subjects_preserved",
                    preservedAffordanceSignals: demoRuntimeAffordanceSignals(),
                    lostAffordanceSignals: [],
                    cropHeadroomUsage: "none",
                    affordanceLossRisk: "low",
                    defaultFallbackReason: "standard_safe_framing"
                )
            ]
            candidates.append(contentsOf: frameCandidates)
            recommended[frameId] = environmentalId
        }

        let result = FinalMomentCropGenerationResult(
            cropGenerationResultId: "crop_generation_demo_001",
            keeperSelectionId: request.keeperSelectionId,
            cropCandidates: candidates,
            recommendedCropByFrame: recommended
        )
        cropGenerationResult = result
        return result
    }

    func prepareFineTuneReview(_ request: FinalMomentFineTuneRequest) -> FinalMomentFineTuneResult {
        let framesById = Dictionary(uniqueKeysWithValues: (captureResult?.frames ?? []).map { ($0.frameId, $0) })
        let candidatesById = Dictionary(uniqueKeysWithValues: (cropGenerationResult?.cropCandidates ?? []).map { ($0.cropId, $0) })
        let recommended = cropGenerationResult?.recommendedCropByFrame ?? [:]

        let items = (keeperSelection?.selectedFrameIds ?? []).compactMap { frameId -> FinalMomentFineTuneItem? in
            guard let original = framesById[frameId]?.assetRef else { return nil }
            let cropId = recommended[frameId] ?? "crop_\(frameId)_standard_default"
            let cropped = candidatesById[cropId].map { _ in asset("cropped_\(cropId)", role: .cropped) } ?? asset("cropped_\(cropId)", role: .cropped)
            return FinalMomentFineTuneItem(
                frameId: frameId,
                originalAssetRef: original,
                croppedAssetRef: cropped,
                editedAssetRef: asset("edited_\(frameId)", role: .edited),
                recommendedCropId: cropId,
                editParameters: FinalMomentEditParameters(
                    exposure: 0.10,
                    contrast: 0.08,
                    warmth: 0.12,
                    highlightRecovery: 0.20,
                    shadowRecovery: 0.05,
                    toneCurve: "warm_editorial_medium_contrast",
                    localCrispness: 0.10,
                    localSoftness: 0.02,
                    skinToneProtection: 0.85,
                    shadowPatternEmphasis: 0.08,
                    rimLightEmphasis: 0.06,
                    backgroundReadability: 0.12,
                    subjectSeparation: 0.08,
                    grainOrTexture: 0.03
                ),
                consumedSignals: FinalMomentConsumedSignals(
                    styleProfileSignals: ["portfolio_color_tone", "local_crispness", "skin_tone_protection"],
                    runtimeAffordanceSignals: [.rimHairEdgeLight, .architecturalAnchor],
                    capturedAffordanceMetadata: ["faceExposureUsable", "cropHeadroomPreserved", "rimHairEdgeLightPreserved"],
                    cameraSettingsUsed: ["focus.applied", "exposure.adjusted", "whiteBalance.locked", "zoomLens.applied"]
                ),
                enhancedAffordances: ["portfolio_color_tone", "light_shadow_contrast", "rim_light_emphasis"],
                cannotRecoverWarnings: [],
                isRegeneration: false
            )
        }

        let result = FinalMomentFineTuneResult(
            fineTuneResultId: "fine_tune_demo_001",
            keeperSelectionId: request.keeperSelectionId,
            cropGenerationResultId: request.cropGenerationResultId,
            presetApplied: "warm_editorial",
            items: items
        )
        fineTuneResult = result
        return result
    }

    func saveMoment(_ request: FinalMomentSaveRequest) -> FinalMomentSaveResult {
        let fineTuneItems = Dictionary(uniqueKeysWithValues: (fineTuneResult?.items ?? []).map { ($0.frameId, $0) })
        let capture = captureResult
        let autoCullId = autoCullResult?.autoCullResultId ?? "auto_cull_demo_001"
        let keeperId = keeperSelection?.keeperSelectionId ?? "keeper_selection_demo_001"
        let cropId = cropGenerationResult?.cropGenerationResultId ?? "crop_generation_demo_001"

        let newMoments = request.decisions.enumerated().compactMap { offset, decision -> FinalMomentSavedMoment? in
            guard let item = fineTuneItems[decision.frameId], let capture else { return nil }
            let finalAsset = decision.selectedOutput == .edited ? item.editedAssetRef : item.croppedAssetRef
            let fineTuneAccepted = decision.selectedOutput == .edited
            return FinalMomentSavedMoment(
                savedMomentId: "saved_moment_demo_00\(offset + 1)",
                sceneTitle: capture.sceneTitle,
                finalAssetRef: finalAsset,
                thumbnailAssetRef: asset("thumb_\(decision.frameId)", role: .thumbnail),
                isFineTuned: fineTuneAccepted,
                sourcePortfolioId: capture.sourcePortfolioId,
                createdAt: "2026-06-03T10:05:00Z",
                provenance: FinalMomentProvenance(
                    captureResultId: capture.captureResultId,
                    autoCullResultId: autoCullId,
                    keeperSelectionId: keeperId,
                    cropGenerationResultId: cropId,
                    fineTuneResultId: request.fineTuneResultId,
                    scenePlanId: capture.scenePlanId,
                    styleProfileId: capture.styleProfileId,
                    styleProfileVersion: capture.cameraSettingsIntentSnapshot.styleProfileVersion,
                    profileSchemaVersion: "2026-06-04",
                    protectedSubjectSetId: capture.protectedSubjectSetId,
                    nativeCameraParameterIntentSnapshot: capture.cameraSettingsIntentSnapshot,
                    initialCameraSettingsRecommendation: capture.initialCameraSettingsRecommendation,
                    dynamicCameraSettingsAdjustmentId: capture.cameraSettingsUsed.dynamicCameraSettingsAdjustmentId,
                    cameraSettingsUsed: capture.cameraSettingsUsed,
                    runtimeAffordanceSignals: capture.runtimeAffordanceSignals,
                    capturedAffordanceMetadata: capture.capturedAffordanceMetadata,
                    postCapturePrerequisites: capture.postCapturePrerequisites,
                    consumedSignals: item.consumedSignals,
                    cropDecisionId: item.recommendedCropId,
                    fineTuneAccepted: fineTuneAccepted,
                    originalAssetRef: item.originalAssetRef,
                    croppedAssetRef: item.croppedAssetRef,
                    editedAssetRef: item.editedAssetRef,
                    finalAssetRef: finalAsset,
                    isRegeneration: false
                )
            )
        }

        savedMoments = newMoments + savedMoments
        let confirmation = FinalMomentSavedConfirmationState(
            savedMomentIds: newMoments.map(\.savedMomentId),
            savedCount: newMoments.count,
            savedAssets: newMoments.map(\.finalAssetRef),
            actions: FinalMomentSavedConfirmationState.Actions(
                viewProfile: true,
                takeMorePhotos: true
            ),
            resumeCaptureContext: capture.map {
                FinalMomentResumeCaptureContext(
                    sessionId: $0.sessionId,
                    styleProfileId: $0.styleProfileId,
                    protectedSubjectSetId: $0.protectedSubjectSetId,
                    scenePlanId: $0.scenePlanId
                )
            }
        )

        return FinalMomentSaveResult(
            savedMoments: newMoments,
            savedConfirmation: confirmation
        )
    }

    func getProfileState(_ request: FinalMomentProfileRequest = FinalMomentProfileRequest(includeSavedPortfolios: true)) -> FinalMomentProfileState {
        let groups = Dictionary(grouping: savedMoments, by: \.sceneTitle)
            .map { FinalMomentGroup(sceneTitle: $0.key, savedMomentIds: $0.value.map(\.savedMomentId)) }
            .sorted { $0.sceneTitle < $1.sceneTitle }

        let savedPortfolios = request.includeSavedPortfolios
            ? [FinalMomentSavedPortfolio(portfolioId: "campus_editorial_graduation", folderIds: ["graduation_inspiration"])]
            : []

        let bookmarkFolders = request.includeSavedPortfolios
            ? [FinalMomentBookmarkFolder(folderId: "graduation_inspiration", name: "Graduation Inspiration", portfolioIds: ["campus_editorial_graduation"])]
            : []

        return FinalMomentProfileState(
            savedMoments: savedMoments,
            momentGroups: groups,
            savedPortfolios: savedPortfolios,
            bookmarkFolders: bookmarkFolders,
            profileSheetState: .none
        )
    }

    func makeDemoBundle() throws -> FinalMomentDemoBundle {
        let captureRequest = makeDemoCaptureRequest()
        let capture = recordCaptureResult(request: captureRequest)
        let autoCull = autoCullFrames(FinalMomentAutoCullRequest(
            captureResultId: capture.captureResultId,
            protectedSubjectSetId: capture.protectedSubjectSetId
        ))
        let selectedIds = Array(autoCull.acceptedFrames.prefix(2).map(\.frameId))
        let keeper = try createKeeperSelection(FinalMomentKeeperSelectionRequest(
            autoCullResultId: autoCull.autoCullResultId,
            selectedFrameIds: selectedIds
        ))
        let crops = generateInternalCrops(FinalMomentCropGenerationRequest(
            keeperSelectionId: keeper.keeperSelectionId,
            styleProfileId: capture.styleProfileId,
            scenePlanId: capture.scenePlanId,
            runtimeAffordanceSignals: capture.runtimeAffordanceSignals,
            capturedAffordanceMetadata: capture.capturedAffordanceMetadata,
            postCapturePrerequisites: capture.postCapturePrerequisites,
            cameraSettingsUsed: capture.cameraSettingsUsed
        ))
        let fineTune = prepareFineTuneReview(FinalMomentFineTuneRequest(
            keeperSelectionId: keeper.keeperSelectionId,
            cropGenerationResultId: crops.cropGenerationResultId,
            styleProfileId: capture.styleProfileId,
            styleProfileVersion: capture.cameraSettingsIntentSnapshot.styleProfileVersion,
            runtimeAffordanceSignals: capture.runtimeAffordanceSignals,
            capturedAffordanceMetadata: capture.capturedAffordanceMetadata,
            cameraSettingsUsed: capture.cameraSettingsUsed
        ))
        let save = saveMoment(FinalMomentSaveRequest(
            fineTuneResultId: fineTune.fineTuneResultId,
            decisions: fineTune.items.map {
                FinalMomentPhotoDecision(frameId: $0.frameId, selectedOutput: .edited)
            }
        ))
        let profile = getProfileState()

        return FinalMomentDemoBundle(
            captureResult: capture,
            autoCullResult: autoCull,
            keeperSelection: keeper,
            cropGenerationResult: crops,
            fineTuneResult: fineTune,
            saveResult: save,
            profileState: profile
        )
    }

    private func demoRuntimeAffordanceSignals() -> [FinalMomentRuntimeAffordanceSignal] {
        [
            .softSideLight,
            .rimHairEdgeLight,
            .architecturalAnchor,
            .cropHeadroomAvailable,
            .relationshipInteractionOpportunity,
            .focusDepthOpportunity
        ]
    }

    private func demoPostCapturePrerequisites() -> FinalMomentPostCapturePrerequisites {
        FinalMomentPostCapturePrerequisites(
            mustCaptureCorrectly: [
                "protected_subject_focus",
                "usable_face_light",
                "natural_expression_or_interaction",
                "crop_headroom"
            ],
            protectedSubjectFocusRequired: true,
            usableFaceLightRequired: true,
            naturalExpressionOrInteractionRequired: true,
            cropHeadroomRequired: true
        )
    }

    private func demoCapturedAffordanceMetadata() -> FinalMomentCapturedAffordanceMetadata {
        FinalMomentCapturedAffordanceMetadata(
            protectedSubjectFocusReady: true,
            faceExposureUsable: true,
            rimHairEdgeLightPreserved: true,
            projectedShadowPatternPreserved: false,
            architecturalAnchorPreserved: true,
            naturalExpressionOrInteractionObserved: true,
            cropHeadroomPreserved: true,
            postCaptureFineTuneEligible: [
                "portfolio_color_tone",
                "crop_composition",
                "light_shadow_contrast",
                "local_crispness",
                "background_readability"
            ]
        )
    }

    private func makeCameraSetting(
        status: FinalMomentCapabilityStatus,
        requested: String,
        applied: String,
        reason: String? = nil
    ) -> FinalMomentCameraSettingActual {
        FinalMomentCameraSettingActual(
            status: status,
            requested: requested,
            applied: applied,
            reason: reason
        )
    }

    private func makeDemoCameraSettingsUsed(recommendationId: String) -> FinalMomentCameraSettingsUsed {
        FinalMomentCameraSettingsUsed(
            settingsId: "camera_settings_used_demo_001",
            appliedRecommendationId: recommendationId,
            dynamicCameraSettingsAdjustmentId: "dynamic_camera_adjustment_demo_001",
            focusModeUsed: "continuous_face_priority_locked",
            exposureBiasUsed: -0.4,
            whiteBalanceModeUsed: "warm_daylight_locked",
            depthModeUsed: "environmental_depth",
            zoomLensModeUsed: "wide_1x",
            burstCountRequested: 4,
            burstCountCaptured: 4,
            highestPracticalResolutionUsed: true,
            focus: makeCameraSetting(
                status: .applied,
                requested: "continuous_then_lock_when_ready:protected_subject_face_group",
                applied: "continuous_face_priority_locked"
            ),
            exposure: makeCameraSetting(
                status: .adjusted,
                requested: "bias_-0.3_faces_protected",
                applied: "bias_-0.4_faces_protected",
                reason: "face_highlights_near_clipping"
            ),
            whiteBalance: makeCameraSetting(
                status: .locked,
                requested: "warm_daylight_auto_then_lock",
                applied: "warm_daylight_locked"
            ),
            depthPortrait: makeCameraSetting(
                status: .available,
                requested: "environmental_depth_subtle",
                applied: "depth_data_available_environment_readable"
            ),
            zoomLens: makeCameraSetting(
                status: .applied,
                requested: "wide_1x_preserve_crop_headroom",
                applied: "wide_1x"
            ),
            framing: makeCameraSetting(
                status: .applied,
                requested: "shoot_wide_high_safety_margin",
                applied: "wide_environmental_with_headroom"
            ),
            captureQuality: makeCameraSetting(
                status: .applied,
                requested: "quality_high_resolution_burst",
                applied: "quality_high_resolution_burst"
            ),
            flashLowLightPolicy: makeCameraSetting(
                status: .applied,
                requested: "flash_off_unless_recovery_needed",
                applied: "flash_off"
            ),
            capabilityStatus: [
                "focusPoint": .applied,
                "exposureBias": .adjusted,
                "whiteBalanceLock": .locked,
                "depthData": .available,
                "portraitEffectsMatte": .unavailable,
                "highResolution": .applied,
                "burst": .applied,
                "zoomLens": .applied,
                "flashMode": .applied
            ],
            capabilityGaps: ["portraitEffectsMatte"]
        )
    }

    private func asset(_ id: String, role: FinalMomentAssetRole) -> FinalMomentAssetRef {
        let dimensions: (width: Int, height: Int)
        switch role {
        case .thumbnail:
            dimensions = (480, 600)
        case .cropPreview, .cropped, .edited:
            dimensions = (2400, 3000)
        case .original:
            dimensions = (4032, 3024)
        }

        return FinalMomentAssetRef(
            assetId: "asset_\(id)",
            uri: "asset://\(id)",
            role: role,
            width: dimensions.width,
            height: dimensions.height,
            mimeType: role == .original ? "image/heic" : "image/jpeg"
        )
    }

    private func protectedSubjectCheck(frameId: String, eyesOpen: Bool) -> FinalMomentProtectedSubjectCheck {
        FinalMomentProtectedSubjectCheck(
            frameId: frameId,
            subjectId: "subject_demo_1",
            eyesOpen: eyesOpen,
            faceSharpness: eyesOpen ? 0.82 : 0.76,
            faceExposure: 0.78,
            focusUsable: eyesOpen,
            faceExposureUsable: true,
            faceLightQuality: "usable_soft_side_light",
            expressionNaturalness: eyesOpen ? 0.86 : 0.24,
            interactionPresent: true,
            cropProtectionStatus: "protectable",
            protectedSubjectInFrame: true
        )
    }
}
