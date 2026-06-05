import Foundation

struct FinalMomentSaveServiceRequest: Codable, Equatable {
    let saveRequest: FinalMomentSaveRequest
    let captureResult: FinalMomentCaptureResult
    let autoCullResultId: String
    let keeperSelection: FinalMomentKeeperSelection
    let cropGenerationResult: FinalMomentCropGenerationResult
    let fineTuneResult: FinalMomentFineTuneResult
    let profileSchemaVersion: String
    let resumeCaptureContextAvailable: Bool
    let createdAt: String
}

enum FinalMomentSaveServiceError: Error, Equatable, LocalizedError {
    case emptyDecisions
    case staleFineTuneResultId(expected: String, actual: String)
    case staleFineTuneResult(fineTuneResultId: String)
    case missingFineTuneItem(frameId: String)
    case duplicateFrameDecision(frameId: String)
    case missingFinalAsset(assetId: String)
    case missingPreviewAsset(assetId: String)
    case persistenceUnavailable
    case resumeCaptureContextUnavailable(captureResultId: String)
    case regenerationNotAllowed(frameId: String)

    var errorDescription: String? {
        switch self {
        case .emptyDecisions:
            return "Save Moment requires at least one final photo decision."
        case .staleFineTuneResultId(let expected, let actual):
            return "Stale fine tune result ID. Expected \(expected), got \(actual)."
        case .staleFineTuneResult(let fineTuneResultId):
            return "Fine tune result is stale or missing persisted parameters: \(fineTuneResultId)."
        case .missingFineTuneItem(let frameId):
            return "Missing fine tune item for selected frame: \(frameId)."
        case .duplicateFrameDecision(let frameId):
            return "Duplicate save decision for frame: \(frameId)."
        case .missingFinalAsset(let assetId):
            return "Final selected asset is missing or unreadable: \(assetId)."
        case .missingPreviewAsset(let assetId):
            return "Saved moment preview or thumbnail asset could not be written: \(assetId)."
        case .persistenceUnavailable:
            return "Final Moment save/profile persistence is unavailable."
        case .resumeCaptureContextUnavailable(let captureResultId):
            return "Take More Photos context is unavailable for capture result: \(captureResultId)."
        case .regenerationNotAllowed(let frameId):
            return "Saved Moment must preserve isRegeneration=false for frame: \(frameId)."
        }
    }
}

final class FinalMomentSaveService {
    private let repository: any FinalMomentRepository
    private let assetRepository: any FinalMomentAssetRepository

    init(
        repository: any FinalMomentRepository,
        assetRepository: any FinalMomentAssetRepository
    ) {
        self.repository = repository
        self.assetRepository = assetRepository
    }

    func saveMoment(
        _ serviceRequest: FinalMomentSaveServiceRequest
    ) throws -> FinalMomentSaveResult {
        guard serviceRequest.saveRequest.fineTuneResultId == serviceRequest.fineTuneResult.fineTuneResultId else {
            throw FinalMomentSaveServiceError.staleFineTuneResultId(
                expected: serviceRequest.fineTuneResult.fineTuneResultId,
                actual: serviceRequest.saveRequest.fineTuneResultId
            )
        }
        guard serviceRequest.saveRequest.decisions.isEmpty == false else {
            throw FinalMomentSaveServiceError.emptyDecisions
        }
        guard serviceRequest.resumeCaptureContextAvailable else {
            throw FinalMomentSaveServiceError.resumeCaptureContextUnavailable(
                captureResultId: serviceRequest.captureResult.captureResultId
            )
        }

        let decisions = try validatedDecisions(serviceRequest.saveRequest.decisions)
        let fineTuneItemsByFrameId = Dictionary(uniqueKeysWithValues: serviceRequest.fineTuneResult.items.map {
            ($0.frameId, $0)
        })

        var savedMoments: [FinalMomentSavedMoment] = []
        for decision in decisions {
            guard let item = fineTuneItemsByFrameId[decision.frameId] else {
                throw FinalMomentSaveServiceError.missingFineTuneItem(frameId: decision.frameId)
            }
            guard item.isRegeneration == false else {
                throw FinalMomentSaveServiceError.regenerationNotAllowed(frameId: item.frameId)
            }

            try requirePersistedFineTuneItem(item, fineTuneResultId: serviceRequest.fineTuneResult.fineTuneResultId)

            let finalAssetRef = finalAsset(for: decision, item: item)
            try requireFinalAsset(finalAssetRef)

            let thumbnailAssetRef = thumbnailAsset(savedMomentId: savedMomentId(
                fineTuneResultId: serviceRequest.fineTuneResult.fineTuneResultId,
                frameId: item.frameId
            ))
            try writeThumbnailAsset(
                thumbnailAssetRef,
                source: finalAssetRef,
                serviceRequest: serviceRequest,
                frameId: item.frameId
            )

            let savedMoment = try persistSavedMoment(
                item: item,
                decision: decision,
                finalAssetRef: finalAssetRef,
                thumbnailAssetRef: thumbnailAssetRef,
                serviceRequest: serviceRequest
            )
            savedMoments.append(savedMoment)
        }

        let confirmation = FinalMomentSavedConfirmationState(
            savedMomentIds: savedMoments.map(\.savedMomentId),
            savedCount: savedMoments.count,
            savedAssets: savedMoments.map(\.finalAssetRef),
            actions: FinalMomentSavedConfirmationState.Actions(
                viewProfile: true,
                takeMorePhotos: true
            ),
            resumeCaptureContext: FinalMomentResumeCaptureContext(
                sessionId: serviceRequest.captureResult.sessionId,
                styleProfileId: serviceRequest.captureResult.styleProfileId,
                protectedSubjectSetId: serviceRequest.captureResult.protectedSubjectSetId,
                scenePlanId: serviceRequest.captureResult.scenePlanId
            )
        )

        try persistConfirmation(
            confirmation,
            fineTuneResultId: serviceRequest.fineTuneResult.fineTuneResultId
        )

        return FinalMomentSaveResult(
            savedMoments: savedMoments,
            savedConfirmation: confirmation
        )
    }

    func getProfileState(
        _ request: FinalMomentProfileRequest = FinalMomentProfileRequest(includeSavedPortfolios: true)
    ) throws -> FinalMomentProfileState {
        let savedMoments = try mapRepositoryError {
            try repository.listSavedMoments()
        }
        let groups = Dictionary(grouping: savedMoments, by: \.sceneTitle)
            .map { FinalMomentGroup(sceneTitle: $0.key, savedMomentIds: $0.value.map(\.savedMomentId)) }
            .sorted { $0.sceneTitle < $1.sceneTitle }

        let portfolios = request.includeSavedPortfolios
            ? try mapRepositoryError { try repository.listSavedPortfolios() }
            : []
        let folders = request.includeSavedPortfolios
            ? try mapRepositoryError { try repository.listBookmarkFolders() }
            : []

        return FinalMomentProfileState(
            savedMoments: savedMoments,
            momentGroups: groups,
            savedPortfolios: portfolios,
            bookmarkFolders: folders,
            profileSheetState: .none
        )
    }

    func getSavedMomentDetail(savedMomentId: String) throws -> FinalMomentSavedMoment {
        try mapRepositoryError {
            try repository.loadSavedMoment(savedMomentId: savedMomentId)
        }
    }

    func getImagePreview(savedMomentId: String) throws -> FinalMomentAssetRef {
        let savedMoment = try getSavedMomentDetail(savedMomentId: savedMomentId)
        try requireFinalAsset(savedMoment.thumbnailAssetRef)
        return savedMoment.thumbnailAssetRef
    }

    func upsertSavedPortfolio(_ portfolio: FinalMomentSavedPortfolio) throws -> FinalMomentSavedPortfolio {
        try mapRepositoryError {
            try repository.upsertSavedPortfolio(portfolio)
        }
    }

    func createBookmarkFolder(
        folderId: String,
        name: String,
        portfolioIds: [String]
    ) throws -> FinalMomentBookmarkFolder {
        let folder = FinalMomentBookmarkFolder(
            folderId: folderId,
            name: name,
            portfolioIds: portfolioIds
        )
        return try mapRepositoryError {
            try repository.upsertBookmarkFolder(folder)
        }
    }

    func getBookmarkFolderDetail(folderId: String) throws -> FinalMomentBookmarkFolder {
        try mapRepositoryError {
            try repository.loadBookmarkFolder(folderId: folderId)
        }
    }

    func removeSavedPortfolio(portfolioId: String) throws -> Bool {
        try mapRepositoryError {
            try repository.removeSavedPortfolio(portfolioId: portfolioId)
        }
    }

    private func validatedDecisions(
        _ decisions: [FinalMomentPhotoDecision]
    ) throws -> [FinalMomentPhotoDecision] {
        var seen: Set<String> = []
        for decision in decisions {
            guard seen.insert(decision.frameId).inserted else {
                throw FinalMomentSaveServiceError.duplicateFrameDecision(frameId: decision.frameId)
            }
        }
        return decisions
    }

    private func requirePersistedFineTuneItem(
        _ item: FinalMomentFineTuneItem,
        fineTuneResultId: String
    ) throws {
        do {
            let record = try repository.loadFineTuneParameterRef(recordId: "\(item.frameId)_\(fineTuneResultId)")
            guard record.fineTuneResultId == fineTuneResultId,
                  record.frameId == item.frameId,
                  record.editParameters == item.editParameters,
                  record.isRegeneration == false else {
                throw FinalMomentSaveServiceError.staleFineTuneResult(fineTuneResultId: fineTuneResultId)
            }
        } catch let error as FinalMomentSaveServiceError {
            throw error
        } catch let error as FinalMomentStoreError {
            if error == .persistenceUnavailable {
                throw FinalMomentSaveServiceError.persistenceUnavailable
            }
            throw FinalMomentSaveServiceError.staleFineTuneResult(fineTuneResultId: fineTuneResultId)
        }
    }

    private func finalAsset(
        for decision: FinalMomentPhotoDecision,
        item: FinalMomentFineTuneItem
    ) -> FinalMomentAssetRef {
        switch decision.selectedOutput {
        case .edited:
            return item.editedAssetRef
        case .croppedOriginal:
            return item.croppedAssetRef
        }
    }

    private func requireFinalAsset(_ assetRef: FinalMomentAssetRef) throws {
        do {
            let record = try assetRepository.loadAsset(assetId: assetRef.assetId)
            guard record.isReadable else {
                throw FinalMomentSaveServiceError.missingFinalAsset(assetId: assetRef.assetId)
            }
        } catch let error as FinalMomentSaveServiceError {
            throw error
        } catch let error as FinalMomentStoreError {
            if error == .persistenceUnavailable {
                throw FinalMomentSaveServiceError.persistenceUnavailable
            }
            throw FinalMomentSaveServiceError.missingFinalAsset(assetId: assetRef.assetId)
        }
    }

    private func writeThumbnailAsset(
        _ thumbnailAssetRef: FinalMomentAssetRef,
        source: FinalMomentAssetRef,
        serviceRequest: FinalMomentSaveServiceRequest,
        frameId: String
    ) throws {
        do {
            _ = try assetRepository.upsertAsset(FinalMomentAssetRecord(
                assetRef: thumbnailAssetRef,
                sourceStage: "saved_moment_thumbnail",
                captureResultId: serviceRequest.captureResult.captureResultId,
                frameId: frameId,
                isReadable: true,
                contentFingerprint: "thumbnail_from_\(source.assetId)"
            ))
        } catch let error as FinalMomentStoreError {
            if error == .persistenceUnavailable {
                throw FinalMomentSaveServiceError.persistenceUnavailable
            }
            throw FinalMomentSaveServiceError.missingPreviewAsset(assetId: thumbnailAssetRef.assetId)
        } catch {
            throw FinalMomentSaveServiceError.missingPreviewAsset(assetId: thumbnailAssetRef.assetId)
        }
    }

    private func persistSavedMoment(
        item: FinalMomentFineTuneItem,
        decision: FinalMomentPhotoDecision,
        finalAssetRef: FinalMomentAssetRef,
        thumbnailAssetRef: FinalMomentAssetRef,
        serviceRequest: FinalMomentSaveServiceRequest
    ) throws -> FinalMomentSavedMoment {
        let savedMomentId = savedMomentId(
            fineTuneResultId: serviceRequest.fineTuneResult.fineTuneResultId,
            frameId: item.frameId
        )
        let fineTuneAccepted = decision.selectedOutput == .edited
        let provenance = FinalMomentProvenance(
            captureResultId: serviceRequest.captureResult.captureResultId,
            autoCullResultId: serviceRequest.autoCullResultId,
            keeperSelectionId: serviceRequest.keeperSelection.keeperSelectionId,
            cropGenerationResultId: serviceRequest.cropGenerationResult.cropGenerationResultId,
            fineTuneResultId: serviceRequest.fineTuneResult.fineTuneResultId,
            scenePlanId: serviceRequest.captureResult.scenePlanId,
            styleProfileId: serviceRequest.captureResult.styleProfileId,
            styleProfileVersion: serviceRequest.captureResult.cameraSettingsIntentSnapshot.styleProfileVersion,
            profileSchemaVersion: serviceRequest.profileSchemaVersion,
            protectedSubjectSetId: serviceRequest.captureResult.protectedSubjectSetId,
            nativeCameraParameterIntentSnapshot: serviceRequest.captureResult.cameraSettingsIntentSnapshot,
            initialCameraSettingsRecommendation: serviceRequest.captureResult.initialCameraSettingsRecommendation,
            dynamicCameraSettingsAdjustmentId: serviceRequest.captureResult.cameraSettingsUsed.dynamicCameraSettingsAdjustmentId,
            cameraSettingsUsed: serviceRequest.captureResult.cameraSettingsUsed,
            runtimeAffordanceSignals: serviceRequest.captureResult.runtimeAffordanceSignals,
            capturedAffordanceMetadata: serviceRequest.captureResult.capturedAffordanceMetadata,
            postCapturePrerequisites: serviceRequest.captureResult.postCapturePrerequisites,
            consumedSignals: item.consumedSignals,
            cropDecisionId: item.recommendedCropId,
            fineTuneAccepted: fineTuneAccepted,
            originalAssetRef: item.originalAssetRef,
            croppedAssetRef: item.croppedAssetRef,
            editedAssetRef: item.editedAssetRef,
            finalAssetRef: finalAssetRef,
            isRegeneration: false
        )
        let savedMoment = FinalMomentSavedMoment(
            savedMomentId: savedMomentId,
            sceneTitle: serviceRequest.captureResult.sceneTitle,
            finalAssetRef: finalAssetRef,
            thumbnailAssetRef: thumbnailAssetRef,
            isFineTuned: fineTuneAccepted,
            sourcePortfolioId: serviceRequest.captureResult.sourcePortfolioId,
            createdAt: serviceRequest.createdAt,
            provenance: provenance
        )

        do {
            _ = try repository.upsertSavedMomentRef(FinalMomentSavedMomentRefRecord(
                savedMomentId: savedMoment.savedMomentId,
                fineTuneResultId: provenance.fineTuneResultId,
                finalAssetRef: savedMoment.finalAssetRef,
                thumbnailAssetRef: savedMoment.thumbnailAssetRef,
                sceneTitle: savedMoment.sceneTitle,
                isFineTuned: savedMoment.isFineTuned,
                sourcePortfolioId: savedMoment.sourcePortfolioId,
                styleProfileId: provenance.styleProfileId,
                styleProfileVersion: provenance.styleProfileVersion,
                scenePlanId: provenance.scenePlanId,
                createdAt: savedMoment.createdAt,
                isRegeneration: provenance.isRegeneration
            ))
            _ = try repository.upsertProvenance(FinalMomentProvenanceRecord(
                provenanceId: "provenance_\(savedMoment.savedMomentId)",
                savedMomentId: savedMoment.savedMomentId,
                captureResultId: provenance.captureResultId,
                autoCullResultId: provenance.autoCullResultId,
                keeperSelectionId: provenance.keeperSelectionId,
                selectedFrameIds: serviceRequest.keeperSelection.selectedFrameIds,
                cropDecisionId: provenance.cropDecisionId,
                cropGenerationResultId: provenance.cropGenerationResultId,
                fineTuneResultId: provenance.fineTuneResultId,
                styleProfileId: provenance.styleProfileId,
                styleProfileVersion: provenance.styleProfileVersion,
                profileSchemaVersion: provenance.profileSchemaVersion,
                scenePlanId: provenance.scenePlanId,
                protectedSubjectSetId: provenance.protectedSubjectSetId,
                nativeCameraParameterIntentSnapshot: provenance.nativeCameraParameterIntentSnapshot,
                initialCameraSettingsRecommendation: provenance.initialCameraSettingsRecommendation,
                dynamicCameraSettingsAdjustmentId: provenance.dynamicCameraSettingsAdjustmentId,
                runtimeAffordanceSignals: provenance.runtimeAffordanceSignals,
                capturedAffordanceMetadata: provenance.capturedAffordanceMetadata,
                postCapturePrerequisites: provenance.postCapturePrerequisites,
                consumedSignals: provenance.consumedSignals,
                cameraSettingsUsed: provenance.cameraSettingsUsed,
                editParameters: item.editParameters,
                originalAssetRef: provenance.originalAssetRef,
                croppedAssetRef: provenance.croppedAssetRef,
                editedAssetRef: provenance.editedAssetRef,
                finalAssetRef: provenance.finalAssetRef,
                fineTuneAccepted: provenance.fineTuneAccepted,
                isRegeneration: provenance.isRegeneration
            ))
            _ = try repository.upsertSavedMomentRecord(FinalMomentSavedMomentRecord(savedMoment: savedMoment))
        } catch let error as FinalMomentStoreError {
            if error == .persistenceUnavailable {
                throw FinalMomentSaveServiceError.persistenceUnavailable
            }
            throw error
        }

        return savedMoment
    }

    private func persistConfirmation(
        _ confirmation: FinalMomentSavedConfirmationState,
        fineTuneResultId: String
    ) throws {
        do {
            _ = try repository.upsertSavedConfirmation(FinalMomentSavedConfirmationRecord(
                confirmationId: confirmationId(fineTuneResultId: fineTuneResultId),
                fineTuneResultId: fineTuneResultId,
                savedConfirmation: confirmation
            ))
        } catch let error as FinalMomentStoreError {
            if error == .persistenceUnavailable {
                throw FinalMomentSaveServiceError.persistenceUnavailable
            }
            throw error
        }
    }

    private func thumbnailAsset(savedMomentId: String) -> FinalMomentAssetRef {
        FinalMomentAssetRef(
            assetId: "asset_thumbnail_\(savedMomentId)",
            uri: "asset://thumbnail_\(savedMomentId)",
            role: .thumbnail,
            width: 480,
            height: 600,
            mimeType: "image/jpeg"
        )
    }

    private func savedMomentId(
        fineTuneResultId: String,
        frameId: String
    ) -> String {
        "saved_moment_\(fineTuneResultId)_\(frameId)"
    }

    private func confirmationId(fineTuneResultId: String) -> String {
        "saved_confirmation_\(fineTuneResultId)"
    }

    private func mapRepositoryError<T>(_ operation: () throws -> T) throws -> T {
        do {
            return try operation()
        } catch let error as FinalMomentStoreError {
            if error == .persistenceUnavailable {
                throw FinalMomentSaveServiceError.persistenceUnavailable
            }
            throw error
        }
    }
}
