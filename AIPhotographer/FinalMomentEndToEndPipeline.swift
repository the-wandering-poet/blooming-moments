import Foundation

struct FinalMomentEndToEndRequest: Codable, Equatable {
    let captureResult: FinalMomentCaptureResult
    let frameAssessmentInputs: [FinalMomentFrameAssessmentInput]
    let selectedFrameIds: [String]
    let protectedSubjectGeometry: [FinalMomentProtectedSubjectCropGeometry]
    let preset: FinalMomentPublishedPreset
    let requestedEnhancements: [String]
    let saveDecisions: [FinalMomentPhotoDecision]?
    let profileSchemaVersion: String
    let createdAt: String
    let captureSessionIsActive: Bool
    let resumeCaptureContextAvailable: Bool
    let nonRecoverableFailuresByFrame: [String: [FinalMomentAssessmentFailure]]
}

struct FinalMomentEndToEndResult: Codable, Equatable {
    let captureResult: FinalMomentCaptureResult
    let autoCullResult: FinalMomentAutoCullResult
    let keeperSelection: FinalMomentKeeperSelection
    let cropGenerationResult: FinalMomentCropGenerationResult
    let fineTuneResult: FinalMomentFineTuneResult
    let saveResult: FinalMomentSaveResult
    let profileState: FinalMomentProfileState
}

final class FinalMomentEndToEndPipeline {
    private let repository: any FinalMomentRepository
    private let assetRepository: any FinalMomentAssetRepository
    private let assessmentAdapter: any FinalMomentPostCaptureAssessmentAdapter

    init(
        repository: any FinalMomentRepository,
        assetRepository: any FinalMomentAssetRepository,
        assessmentAdapter: any FinalMomentPostCaptureAssessmentAdapter = FinalMomentLocalTestAssessmentAdapter()
    ) {
        self.repository = repository
        self.assetRepository = assetRepository
        self.assessmentAdapter = assessmentAdapter
    }

    func runAfterCapture(
        _ request: FinalMomentEndToEndRequest
    ) throws -> FinalMomentEndToEndResult {
        try persistCaptureAssets(request.captureResult)

        let autoCullResult = try FinalMomentAutoCullService(
            assessmentAdapter: assessmentAdapter,
            repository: repository
        ).autoCull(FinalMomentAutoCullServiceRequest(
            autoCullResultId: "auto_cull_\(request.captureResult.captureResultId)",
            captureResult: request.captureResult,
            frameAssessmentInputs: request.frameAssessmentInputs
        ))

        let keeperSelection = try FinalMomentKeeperSelectionService(
            repository: repository,
            assetRepository: assetRepository
        ).createKeeperSelection(FinalMomentKeeperSelectionServiceRequest(
            keeperSelectionId: "keeper_selection_\(request.captureResult.captureResultId)",
            request: FinalMomentKeeperSelectionRequest(
                autoCullResultId: autoCullResult.autoCullResultId,
                selectedFrameIds: request.selectedFrameIds
            ),
            autoCullResult: autoCullResult,
            captureResultId: request.captureResult.captureResultId,
            protectedSubjectSetId: request.captureResult.protectedSubjectSetId,
            captureSessionIsActive: request.captureSessionIsActive
        ))

        let cropGenerationRequest = FinalMomentCropGenerationRequest(
            keeperSelectionId: keeperSelection.keeperSelectionId,
            styleProfileId: request.captureResult.styleProfileId,
            scenePlanId: request.captureResult.scenePlanId,
            runtimeAffordanceSignals: request.captureResult.runtimeAffordanceSignals,
            capturedAffordanceMetadata: request.captureResult.capturedAffordanceMetadata,
            postCapturePrerequisites: request.captureResult.postCapturePrerequisites,
            cameraSettingsUsed: request.captureResult.cameraSettingsUsed
        )
        let cropGenerationResult = try FinalMomentCropService(
            repository: repository,
            assetRepository: assetRepository
        ).generateInternalCrops(FinalMomentCropServiceRequest(
            cropGenerationResultId: "crop_generation_\(request.captureResult.captureResultId)",
            request: cropGenerationRequest,
            keeperSelection: keeperSelection,
            acceptedFrames: autoCullResult.acceptedFrames,
            protectedSubjectGeometry: request.protectedSubjectGeometry
        ))

        let cropDecisions = try cropGenerationResult.recommendedCropByFrame.values.sorted().map {
            try repository.loadCropDecisionRef(cropDecisionId: $0)
        }
        let fineTuneRequest = FinalMomentFineTuneRequest(
            keeperSelectionId: keeperSelection.keeperSelectionId,
            cropGenerationResultId: cropGenerationResult.cropGenerationResultId,
            styleProfileId: request.captureResult.styleProfileId,
            styleProfileVersion: request.captureResult.cameraSettingsIntentSnapshot.styleProfileVersion,
            runtimeAffordanceSignals: request.captureResult.runtimeAffordanceSignals,
            capturedAffordanceMetadata: request.captureResult.capturedAffordanceMetadata,
            cameraSettingsUsed: request.captureResult.cameraSettingsUsed
        )
        let fineTuneResult = try FinalMomentFineTuneService(
            repository: repository,
            assetRepository: assetRepository
        ).prepareFineTuneReview(FinalMomentFineTuneServiceRequest(
            fineTuneResultId: "fine_tune_\(request.captureResult.captureResultId)",
            request: fineTuneRequest,
            keeperSelection: keeperSelection,
            cropGenerationResult: cropGenerationResult,
            originalFrames: request.captureResult.frames,
            cropDecisions: cropDecisions,
            preset: request.preset,
            requestedEnhancements: request.requestedEnhancements,
            nonRecoverableFailuresByFrame: request.nonRecoverableFailuresByFrame
        ))

        let decisions = request.saveDecisions ?? fineTuneResult.items.map {
            FinalMomentPhotoDecision(frameId: $0.frameId, selectedOutput: .edited)
        }
        let saveService = FinalMomentSaveService(
            repository: repository,
            assetRepository: assetRepository
        )
        let saveResult = try saveService.saveMoment(FinalMomentSaveServiceRequest(
            saveRequest: FinalMomentSaveRequest(
                fineTuneResultId: fineTuneResult.fineTuneResultId,
                decisions: decisions
            ),
            captureResult: request.captureResult,
            autoCullResultId: autoCullResult.autoCullResultId,
            keeperSelection: keeperSelection,
            cropGenerationResult: cropGenerationResult,
            fineTuneResult: fineTuneResult,
            profileSchemaVersion: request.profileSchemaVersion,
            resumeCaptureContextAvailable: request.resumeCaptureContextAvailable,
            createdAt: request.createdAt
        ))
        let profileState = try saveService.getProfileState()

        return FinalMomentEndToEndResult(
            captureResult: request.captureResult,
            autoCullResult: autoCullResult,
            keeperSelection: keeperSelection,
            cropGenerationResult: cropGenerationResult,
            fineTuneResult: fineTuneResult,
            saveResult: saveResult,
            profileState: profileState
        )
    }

    private func persistCaptureAssets(_ captureResult: FinalMomentCaptureResult) throws {
        for frame in captureResult.frames {
            _ = try assetRepository.upsertAsset(FinalMomentAssetRecord(
                assetRef: frame.assetRef,
                sourceStage: "capture_original",
                captureResultId: captureResult.captureResultId,
                frameId: frame.frameId,
                isReadable: true,
                contentFingerprint: "\(captureResult.captureResultId)_\(frame.frameId)"
            ))
            _ = try repository.upsertCaptureAsset(FinalMomentCaptureAssetRecord(
                recordId: "\(captureResult.captureResultId)_\(frame.frameId)",
                captureResultId: captureResult.captureResultId,
                frameId: frame.frameId,
                originalAssetRef: frame.assetRef,
                styleProfileId: captureResult.styleProfileId,
                styleProfileVersion: captureResult.cameraSettingsIntentSnapshot.styleProfileVersion,
                scenePlanId: captureResult.scenePlanId,
                protectedSubjectSetId: captureResult.protectedSubjectSetId,
                runtimeAffordanceSignals: captureResult.runtimeAffordanceSignals,
                capturedAffordanceMetadata: captureResult.capturedAffordanceMetadata,
                cameraSettingsUsed: captureResult.cameraSettingsUsed
            ))
        }
    }
}
