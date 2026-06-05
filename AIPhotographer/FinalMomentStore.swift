import Foundation

struct FinalMomentRepositoryConfiguration: Equatable {
    let databaseURL: String?
    let databaseSSLMode: String?
    let databasePoolSize: Int
    let isLocalTestStore: Bool

    static func localTest() -> FinalMomentRepositoryConfiguration {
        FinalMomentRepositoryConfiguration(
            databaseURL: nil,
            databaseSSLMode: nil,
            databasePoolSize: 1,
            isLocalTestStore: true
        )
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> FinalMomentRepositoryConfiguration {
        let poolSize = environment["DATABASE_POOL_SIZE"].flatMap(Int.init) ?? 5
        return FinalMomentRepositoryConfiguration(
            databaseURL: environment["DATABASE_URL"],
            databaseSSLMode: environment["DATABASE_SSL_MODE"],
            databasePoolSize: poolSize,
            isLocalTestStore: environment["DATABASE_URL"] == nil
        )
    }

    var requiresCommittedSecrets: Bool {
        false
    }
}

enum FinalMomentStoreError: Error, Equatable, LocalizedError {
    case persistenceUnavailable
    case unreadableAssetRef(assetId: String)
    case missingAsset(assetId: String)
    case duplicateRecordId(recordType: String, id: String)
    case staleProvenanceReference(recordType: String, id: String)
    case regenerationNotAllowed(recordType: String, id: String)

    var errorDescription: String? {
        switch self {
        case .persistenceUnavailable:
            return "Final Moment persistence is unavailable."
        case .unreadableAssetRef(let assetId):
            return "Asset ref is unreadable: \(assetId)."
        case .missingAsset(let assetId):
            return "Missing asset: \(assetId)."
        case .duplicateRecordId(let recordType, let id):
            return "Conflicting \(recordType) record already exists: \(id)."
        case .staleProvenanceReference(let recordType, let id):
            return "Provenance references missing or stale \(recordType): \(id)."
        case .regenerationNotAllowed(let recordType, let id):
            return "\(recordType) must preserve isRegeneration=false: \(id)."
        }
    }
}

struct FinalMomentAssetRecord: Codable, Equatable {
    let assetRef: FinalMomentAssetRef
    let sourceStage: String
    let captureResultId: String?
    let frameId: String?
    let isReadable: Bool
    let contentFingerprint: String?
}

struct FinalMomentCaptureAssetRecord: Codable, Equatable {
    let recordId: String
    let captureResultId: String
    let frameId: String
    let originalAssetRef: FinalMomentAssetRef
    let styleProfileId: String
    let styleProfileVersion: String
    let scenePlanId: String
    let protectedSubjectSetId: String
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
}

struct FinalMomentAutoCullResultRefRecord: Codable, Equatable {
    let autoCullResultId: String
    let captureResultId: String
    let acceptedFrameIds: [String]
    let rejectedFrameIds: [String]
    let rejectionReasonsByFrame: [String: [FinalMomentRejectionReason]]
}

struct FinalMomentKeeperSelectionRefRecord: Codable, Equatable {
    let keeperSelectionId: String
    let autoCullResultId: String
    let captureResultId: String
    let protectedSubjectSetId: String
    let selectedFrameIds: [String]
}

struct FinalMomentCropDecisionRefRecord: Codable, Equatable {
    let cropDecisionId: String
    let cropGenerationResultId: String
    let keeperSelectionId: String
    let frameId: String
    let cropAssetRef: FinalMomentAssetRef
    let recommendedCropId: String
    let preservedAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
}

struct FinalMomentCropGenerationRefRecord: Codable, Equatable {
    let cropGenerationResultId: String
    let keeperSelectionId: String
    let captureResultId: String
    let protectedSubjectSetId: String
    let styleProfileId: String
    let scenePlanId: String
    let cropCandidates: [FinalMomentCropCandidate]
    let recommendedCropByFrame: [String: String]
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
}

struct FinalMomentFineTuneParameterRefRecord: Codable, Equatable {
    let recordId: String
    let fineTuneResultId: String
    let cropGenerationResultId: String
    let frameId: String
    let presetApplied: String
    let editParameters: FinalMomentEditParameters
    let consumedSignals: FinalMomentConsumedSignals
    let enhancedAffordances: [String]
    let cannotRecoverWarnings: [String]
    let originalAssetRef: FinalMomentAssetRef
    let croppedAssetRef: FinalMomentAssetRef
    let editedAssetRef: FinalMomentAssetRef
    let isRegeneration: Bool
}

struct FinalMomentSavedMomentRefRecord: Codable, Equatable {
    let savedMomentId: String
    let fineTuneResultId: String
    let finalAssetRef: FinalMomentAssetRef
    let thumbnailAssetRef: FinalMomentAssetRef
    let sceneTitle: String
    let isFineTuned: Bool
    let sourcePortfolioId: String
    let styleProfileId: String
    let styleProfileVersion: String
    let scenePlanId: String
    let createdAt: String
    let isRegeneration: Bool
}

struct FinalMomentProvenanceRecord: Codable, Equatable {
    let provenanceId: String
    let savedMomentId: String
    let captureResultId: String
    let autoCullResultId: String
    let keeperSelectionId: String
    let selectedFrameIds: [String]
    let cropDecisionId: String
    let cropGenerationResultId: String
    let fineTuneResultId: String
    let styleProfileId: String
    let styleProfileVersion: String
    let profileSchemaVersion: String
    let scenePlanId: String
    let protectedSubjectSetId: String
    let nativeCameraParameterIntentSnapshot: FinalMomentCameraSettingsIntentSnapshot
    let initialCameraSettingsRecommendation: FinalMomentInitialCameraSettingsRecommendation
    let dynamicCameraSettingsAdjustmentId: String
    let runtimeAffordanceSignals: [FinalMomentRuntimeAffordanceSignal]
    let capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata
    let postCapturePrerequisites: FinalMomentPostCapturePrerequisites
    let consumedSignals: FinalMomentConsumedSignals
    let cameraSettingsUsed: FinalMomentCameraSettingsUsed
    let editParameters: FinalMomentEditParameters
    let originalAssetRef: FinalMomentAssetRef
    let croppedAssetRef: FinalMomentAssetRef
    let editedAssetRef: FinalMomentAssetRef
    let finalAssetRef: FinalMomentAssetRef
    let fineTuneAccepted: Bool
    let isRegeneration: Bool
}

struct FinalMomentSavedMomentRecord: Codable, Equatable {
    let savedMoment: FinalMomentSavedMoment
}

struct FinalMomentSavedConfirmationRecord: Codable, Equatable {
    let confirmationId: String
    let fineTuneResultId: String
    let savedConfirmation: FinalMomentSavedConfirmationState
}

protocol FinalMomentAssetRepository {
    func upsertAsset(_ record: FinalMomentAssetRecord) throws -> FinalMomentAssetRecord
    func loadAsset(assetId: String) throws -> FinalMomentAssetRecord
}

protocol FinalMomentRepository {
    func upsertCaptureAsset(_ record: FinalMomentCaptureAssetRecord) throws -> FinalMomentCaptureAssetRecord
    func loadCaptureAsset(recordId: String) throws -> FinalMomentCaptureAssetRecord
    func upsertAutoCullResultRef(_ record: FinalMomentAutoCullResultRefRecord) throws -> FinalMomentAutoCullResultRefRecord
    func loadAutoCullResultRef(autoCullResultId: String) throws -> FinalMomentAutoCullResultRefRecord
    func upsertKeeperSelectionRef(_ record: FinalMomentKeeperSelectionRefRecord) throws -> FinalMomentKeeperSelectionRefRecord
    func loadKeeperSelectionRef(keeperSelectionId: String) throws -> FinalMomentKeeperSelectionRefRecord
    func upsertCropGenerationRef(_ record: FinalMomentCropGenerationRefRecord) throws -> FinalMomentCropGenerationRefRecord
    func loadCropGenerationRef(cropGenerationResultId: String) throws -> FinalMomentCropGenerationRefRecord
    func upsertCropDecisionRef(_ record: FinalMomentCropDecisionRefRecord) throws -> FinalMomentCropDecisionRefRecord
    func loadCropDecisionRef(cropDecisionId: String) throws -> FinalMomentCropDecisionRefRecord
    func upsertFineTuneParameterRef(_ record: FinalMomentFineTuneParameterRefRecord) throws -> FinalMomentFineTuneParameterRefRecord
    func loadFineTuneParameterRef(recordId: String) throws -> FinalMomentFineTuneParameterRefRecord
    func upsertSavedMomentRef(_ record: FinalMomentSavedMomentRefRecord) throws -> FinalMomentSavedMomentRefRecord
    func loadSavedMomentRef(savedMomentId: String) throws -> FinalMomentSavedMomentRefRecord
    func upsertSavedMomentRecord(_ record: FinalMomentSavedMomentRecord) throws -> FinalMomentSavedMomentRecord
    func loadSavedMoment(savedMomentId: String) throws -> FinalMomentSavedMoment
    func listSavedMoments() throws -> [FinalMomentSavedMoment]
    func upsertSavedConfirmation(_ record: FinalMomentSavedConfirmationRecord) throws -> FinalMomentSavedConfirmationRecord
    func loadSavedConfirmation(confirmationId: String) throws -> FinalMomentSavedConfirmationState
    func upsertSavedPortfolio(_ portfolio: FinalMomentSavedPortfolio) throws -> FinalMomentSavedPortfolio
    func loadSavedPortfolio(portfolioId: String) throws -> FinalMomentSavedPortfolio
    func listSavedPortfolios() throws -> [FinalMomentSavedPortfolio]
    func removeSavedPortfolio(portfolioId: String) throws -> Bool
    func upsertBookmarkFolder(_ folder: FinalMomentBookmarkFolder) throws -> FinalMomentBookmarkFolder
    func loadBookmarkFolder(folderId: String) throws -> FinalMomentBookmarkFolder
    func listBookmarkFolders() throws -> [FinalMomentBookmarkFolder]
    func upsertProvenance(_ record: FinalMomentProvenanceRecord) throws -> FinalMomentProvenanceRecord
    func loadProvenance(savedMomentId: String) throws -> FinalMomentProvenanceRecord
}

final class FinalMomentLocalTestStore: FinalMomentAssetRepository, FinalMomentRepository {
    let configuration: FinalMomentRepositoryConfiguration

    private var available: Bool
    private var assetsById: [String: FinalMomentAssetRecord] = [:]
    private var captureAssetsById: [String: FinalMomentCaptureAssetRecord] = [:]
    private var autoCullRefsById: [String: FinalMomentAutoCullResultRefRecord] = [:]
    private var keeperRefsById: [String: FinalMomentKeeperSelectionRefRecord] = [:]
    private var cropGenerationRefsById: [String: FinalMomentCropGenerationRefRecord] = [:]
    private var cropRefsById: [String: FinalMomentCropDecisionRefRecord] = [:]
    private var fineTuneRefsById: [String: FinalMomentFineTuneParameterRefRecord] = [:]
    private var savedMomentRefsById: [String: FinalMomentSavedMomentRefRecord] = [:]
    private var savedMomentRecordsById: [String: FinalMomentSavedMomentRecord] = [:]
    private var savedConfirmationsById: [String: FinalMomentSavedConfirmationRecord] = [:]
    private var savedPortfoliosById: [String: FinalMomentSavedPortfolio] = [:]
    private var bookmarkFoldersById: [String: FinalMomentBookmarkFolder] = [:]
    private var provenanceBySavedMomentId: [String: FinalMomentProvenanceRecord] = [:]

    init(
        configuration: FinalMomentRepositoryConfiguration = .localTest(),
        available: Bool = true
    ) {
        self.configuration = configuration
        self.available = available
    }

    func setAvailable(_ available: Bool) {
        self.available = available
    }

    func upsertAsset(_ record: FinalMomentAssetRecord) throws -> FinalMomentAssetRecord {
        try requireAvailable()
        try validateAsset(record.assetRef, isReadable: record.isReadable)
        try upsert(record, id: record.assetRef.assetId, recordType: "asset", into: &assetsById)
        return record
    }

    func loadAsset(assetId: String) throws -> FinalMomentAssetRecord {
        try requireAvailable()
        guard let record = assetsById[assetId] else {
            throw FinalMomentStoreError.missingAsset(assetId: assetId)
        }
        return record
    }

    func upsertCaptureAsset(_ record: FinalMomentCaptureAssetRecord) throws -> FinalMomentCaptureAssetRecord {
        try requireAvailable()
        try requireAsset(record.originalAssetRef.assetId)
        try requireNonEmpty(record.styleProfileId, recordType: "captureAsset", id: record.recordId)
        try requireNonEmpty(record.styleProfileVersion, recordType: "captureAsset", id: record.recordId)
        try requireNonEmpty(record.scenePlanId, recordType: "captureAsset", id: record.recordId)
        try requireNonEmpty(record.protectedSubjectSetId, recordType: "captureAsset", id: record.recordId)
        try upsert(record, id: record.recordId, recordType: "captureAsset", into: &captureAssetsById)
        return record
    }

    func loadCaptureAsset(recordId: String) throws -> FinalMomentCaptureAssetRecord {
        try requireAvailable()
        return try load(recordId, recordType: "captureAsset", from: captureAssetsById)
    }

    func upsertAutoCullResultRef(_ record: FinalMomentAutoCullResultRefRecord) throws -> FinalMomentAutoCullResultRefRecord {
        try requireAvailable()
        try requireCaptureResult(record.captureResultId)
        try upsert(record, id: record.autoCullResultId, recordType: "autoCullResult", into: &autoCullRefsById)
        return record
    }

    func loadAutoCullResultRef(autoCullResultId: String) throws -> FinalMomentAutoCullResultRefRecord {
        try requireAvailable()
        return try load(autoCullResultId, recordType: "autoCullResult", from: autoCullRefsById)
    }

    func upsertKeeperSelectionRef(_ record: FinalMomentKeeperSelectionRefRecord) throws -> FinalMomentKeeperSelectionRefRecord {
        try requireAvailable()
        guard let autoCullRef = autoCullRefsById[record.autoCullResultId] else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "autoCullResult", id: record.autoCullResultId)
        }
        guard autoCullRef.captureResultId == record.captureResultId else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "captureResult", id: record.captureResultId)
        }
        try requireNonEmpty(record.protectedSubjectSetId, recordType: "keeperSelection", id: record.keeperSelectionId)
        guard record.selectedFrameIds.isEmpty == false else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "selectedFrameIds", id: record.keeperSelectionId)
        }
        let acceptedIds = Set(autoCullRef.acceptedFrameIds)
        guard record.selectedFrameIds.allSatisfy({ acceptedIds.contains($0) }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "acceptedFrameIds", id: record.keeperSelectionId)
        }
        try upsert(record, id: record.keeperSelectionId, recordType: "keeperSelection", into: &keeperRefsById)
        return record
    }

    func loadKeeperSelectionRef(keeperSelectionId: String) throws -> FinalMomentKeeperSelectionRefRecord {
        try requireAvailable()
        return try load(keeperSelectionId, recordType: "keeperSelection", from: keeperRefsById)
    }

    func upsertCropGenerationRef(_ record: FinalMomentCropGenerationRefRecord) throws -> FinalMomentCropGenerationRefRecord {
        try requireAvailable()
        guard keeperRefsById[record.keeperSelectionId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "keeperSelection", id: record.keeperSelectionId)
        }
        try requireNonEmpty(record.captureResultId, recordType: "cropGeneration", id: record.cropGenerationResultId)
        try requireNonEmpty(record.protectedSubjectSetId, recordType: "cropGeneration", id: record.cropGenerationResultId)
        try requireNonEmpty(record.styleProfileId, recordType: "cropGeneration", id: record.cropGenerationResultId)
        try requireNonEmpty(record.scenePlanId, recordType: "cropGeneration", id: record.cropGenerationResultId)
        guard record.cropCandidates.isEmpty == false else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "cropCandidates", id: record.cropGenerationResultId)
        }
        guard record.recommendedCropByFrame.isEmpty == false else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "recommendedCropByFrame", id: record.cropGenerationResultId)
        }
        let candidateIds = Set(record.cropCandidates.map(\.cropId))
        guard record.recommendedCropByFrame.values.allSatisfy({ candidateIds.contains($0) }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "recommendedCropId", id: record.cropGenerationResultId)
        }
        try upsert(record, id: record.cropGenerationResultId, recordType: "cropGeneration", into: &cropGenerationRefsById)
        return record
    }

    func loadCropGenerationRef(cropGenerationResultId: String) throws -> FinalMomentCropGenerationRefRecord {
        try requireAvailable()
        return try load(cropGenerationResultId, recordType: "cropGeneration", from: cropGenerationRefsById)
    }

    func upsertCropDecisionRef(_ record: FinalMomentCropDecisionRefRecord) throws -> FinalMomentCropDecisionRefRecord {
        try requireAvailable()
        guard keeperRefsById[record.keeperSelectionId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "keeperSelection", id: record.keeperSelectionId)
        }
        guard let cropGeneration = cropGenerationRefsById[record.cropGenerationResultId] else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "cropGeneration", id: record.cropGenerationResultId)
        }
        guard cropGeneration.cropCandidates.contains(where: { $0.cropId == record.recommendedCropId && $0.frameId == record.frameId }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "cropCandidate", id: record.recommendedCropId)
        }
        try requireAsset(record.cropAssetRef.assetId)
        try upsert(record, id: record.cropDecisionId, recordType: "cropDecision", into: &cropRefsById)
        return record
    }

    func loadCropDecisionRef(cropDecisionId: String) throws -> FinalMomentCropDecisionRefRecord {
        try requireAvailable()
        return try load(cropDecisionId, recordType: "cropDecision", from: cropRefsById)
    }

    func upsertFineTuneParameterRef(_ record: FinalMomentFineTuneParameterRefRecord) throws -> FinalMomentFineTuneParameterRefRecord {
        try requireAvailable()
        guard cropRefsById.values.contains(where: { $0.cropGenerationResultId == record.cropGenerationResultId }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "cropGenerationResult", id: record.cropGenerationResultId)
        }
        try requireAsset(record.originalAssetRef.assetId)
        try requireAsset(record.croppedAssetRef.assetId)
        try requireAsset(record.editedAssetRef.assetId)
        guard record.enhancedAffordances.allSatisfy({ $0.hasPrefix("recovered_") == false }) else {
            throw FinalMomentStoreError.regenerationNotAllowed(recordType: "fineTuneEnhancement", id: record.recordId)
        }
        guard record.isRegeneration == false else {
            throw FinalMomentStoreError.regenerationNotAllowed(recordType: "fineTuneResult", id: record.fineTuneResultId)
        }
        try upsert(record, id: record.recordId, recordType: "fineTuneParameter", into: &fineTuneRefsById)
        return record
    }

    func loadFineTuneParameterRef(recordId: String) throws -> FinalMomentFineTuneParameterRefRecord {
        try requireAvailable()
        return try load(recordId, recordType: "fineTuneParameter", from: fineTuneRefsById)
    }

    func upsertSavedMomentRef(_ record: FinalMomentSavedMomentRefRecord) throws -> FinalMomentSavedMomentRefRecord {
        try requireAvailable()
        guard fineTuneRefsById.values.contains(where: { $0.fineTuneResultId == record.fineTuneResultId }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "fineTuneResult", id: record.fineTuneResultId)
        }
        try requireAsset(record.finalAssetRef.assetId)
        try requireAsset(record.thumbnailAssetRef.assetId)
        try requireNonEmpty(record.sceneTitle, recordType: "savedMoment", id: record.savedMomentId)
        try requireNonEmpty(record.sourcePortfolioId, recordType: "savedMoment", id: record.savedMomentId)
        try requireNonEmpty(record.styleProfileId, recordType: "savedMoment", id: record.savedMomentId)
        try requireNonEmpty(record.styleProfileVersion, recordType: "savedMoment", id: record.savedMomentId)
        try requireNonEmpty(record.scenePlanId, recordType: "savedMoment", id: record.savedMomentId)
        guard record.isRegeneration == false else {
            throw FinalMomentStoreError.regenerationNotAllowed(recordType: "savedMoment", id: record.savedMomentId)
        }
        try upsert(record, id: record.savedMomentId, recordType: "savedMoment", into: &savedMomentRefsById)
        return record
    }

    func loadSavedMomentRef(savedMomentId: String) throws -> FinalMomentSavedMomentRefRecord {
        try requireAvailable()
        return try load(savedMomentId, recordType: "savedMoment", from: savedMomentRefsById)
    }

    func upsertSavedMomentRecord(_ record: FinalMomentSavedMomentRecord) throws -> FinalMomentSavedMomentRecord {
        try requireAvailable()
        guard savedMomentRefsById[record.savedMoment.savedMomentId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "savedMomentRef", id: record.savedMoment.savedMomentId)
        }
        guard provenanceBySavedMomentId[record.savedMoment.savedMomentId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "provenance", id: record.savedMoment.savedMomentId)
        }
        try requireAsset(record.savedMoment.finalAssetRef.assetId)
        try requireAsset(record.savedMoment.thumbnailAssetRef.assetId)
        guard record.savedMoment.provenance.isRegeneration == false else {
            throw FinalMomentStoreError.regenerationNotAllowed(recordType: "savedMoment", id: record.savedMoment.savedMomentId)
        }
        try upsert(record, id: record.savedMoment.savedMomentId, recordType: "savedMomentRecord", into: &savedMomentRecordsById)
        return record
    }

    func loadSavedMoment(savedMomentId: String) throws -> FinalMomentSavedMoment {
        try requireAvailable()
        return try load(savedMomentId, recordType: "savedMomentRecord", from: savedMomentRecordsById).savedMoment
    }

    func listSavedMoments() throws -> [FinalMomentSavedMoment] {
        try requireAvailable()
        return savedMomentRecordsById.values.map(\.savedMoment).sorted {
            if $0.createdAt == $1.createdAt {
                return $0.savedMomentId < $1.savedMomentId
            }
            return $0.createdAt > $1.createdAt
        }
    }

    func upsertSavedConfirmation(_ record: FinalMomentSavedConfirmationRecord) throws -> FinalMomentSavedConfirmationRecord {
        try requireAvailable()
        guard fineTuneRefsById.values.contains(where: { $0.fineTuneResultId == record.fineTuneResultId }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "fineTuneResult", id: record.fineTuneResultId)
        }
        guard record.savedConfirmation.savedMomentIds.isEmpty == false else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "savedConfirmation", id: record.confirmationId)
        }
        for savedMomentId in record.savedConfirmation.savedMomentIds {
            guard savedMomentRecordsById[savedMomentId] != nil else {
                throw FinalMomentStoreError.staleProvenanceReference(recordType: "savedMomentRecord", id: savedMomentId)
            }
        }
        for asset in record.savedConfirmation.savedAssets {
            try requireAsset(asset.assetId)
        }
        try upsert(record, id: record.confirmationId, recordType: "savedConfirmation", into: &savedConfirmationsById)
        return record
    }

    func loadSavedConfirmation(confirmationId: String) throws -> FinalMomentSavedConfirmationState {
        try requireAvailable()
        return try load(confirmationId, recordType: "savedConfirmation", from: savedConfirmationsById).savedConfirmation
    }

    func upsertSavedPortfolio(_ portfolio: FinalMomentSavedPortfolio) throws -> FinalMomentSavedPortfolio {
        try requireAvailable()
        try requireNonEmpty(portfolio.portfolioId, recordType: "savedPortfolio", id: portfolio.portfolioId)
        try upsert(portfolio, id: portfolio.portfolioId, recordType: "savedPortfolio", into: &savedPortfoliosById)
        return portfolio
    }

    func loadSavedPortfolio(portfolioId: String) throws -> FinalMomentSavedPortfolio {
        try requireAvailable()
        return try load(portfolioId, recordType: "savedPortfolio", from: savedPortfoliosById)
    }

    func listSavedPortfolios() throws -> [FinalMomentSavedPortfolio] {
        try requireAvailable()
        return savedPortfoliosById.values.sorted { $0.portfolioId < $1.portfolioId }
    }

    func removeSavedPortfolio(portfolioId: String) throws -> Bool {
        try requireAvailable()
        guard savedPortfoliosById.removeValue(forKey: portfolioId) != nil else {
            return false
        }
        bookmarkFoldersById = bookmarkFoldersById.mapValues { folder in
            FinalMomentBookmarkFolder(
                folderId: folder.folderId,
                name: folder.name,
                portfolioIds: folder.portfolioIds.filter { $0 != portfolioId }
            )
        }
        return true
    }

    func upsertBookmarkFolder(_ folder: FinalMomentBookmarkFolder) throws -> FinalMomentBookmarkFolder {
        try requireAvailable()
        try requireNonEmpty(folder.folderId, recordType: "bookmarkFolder", id: folder.folderId)
        try requireNonEmpty(folder.name, recordType: "bookmarkFolder", id: folder.folderId)
        try upsert(folder, id: folder.folderId, recordType: "bookmarkFolder", into: &bookmarkFoldersById)
        return folder
    }

    func loadBookmarkFolder(folderId: String) throws -> FinalMomentBookmarkFolder {
        try requireAvailable()
        return try load(folderId, recordType: "bookmarkFolder", from: bookmarkFoldersById)
    }

    func listBookmarkFolders() throws -> [FinalMomentBookmarkFolder] {
        try requireAvailable()
        return bookmarkFoldersById.values.sorted { $0.folderId < $1.folderId }
    }

    func upsertProvenance(_ record: FinalMomentProvenanceRecord) throws -> FinalMomentProvenanceRecord {
        try requireAvailable()
        guard savedMomentRefsById[record.savedMomentId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "savedMoment", id: record.savedMomentId)
        }
        try requireCaptureResult(record.captureResultId)
        guard autoCullRefsById[record.autoCullResultId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "autoCullResult", id: record.autoCullResultId)
        }
        guard keeperRefsById[record.keeperSelectionId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "keeperSelection", id: record.keeperSelectionId)
        }
        guard cropRefsById[record.cropDecisionId] != nil else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "cropDecision", id: record.cropDecisionId)
        }
        guard fineTuneRefsById.values.contains(where: { $0.fineTuneResultId == record.fineTuneResultId }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "fineTuneResult", id: record.fineTuneResultId)
        }
        try requireAsset(record.originalAssetRef.assetId)
        try requireAsset(record.croppedAssetRef.assetId)
        try requireAsset(record.editedAssetRef.assetId)
        try requireAsset(record.finalAssetRef.assetId)
        try requireNonEmpty(record.styleProfileId, recordType: "provenance", id: record.provenanceId)
        try requireNonEmpty(record.styleProfileVersion, recordType: "provenance", id: record.provenanceId)
        try requireNonEmpty(record.profileSchemaVersion, recordType: "provenance", id: record.provenanceId)
        try requireNonEmpty(record.scenePlanId, recordType: "provenance", id: record.provenanceId)
        try requireNonEmpty(record.protectedSubjectSetId, recordType: "provenance", id: record.provenanceId)
        try requireNonEmpty(record.dynamicCameraSettingsAdjustmentId, recordType: "provenance", id: record.provenanceId)
        guard record.runtimeAffordanceSignals.isEmpty == false else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "runtimeAffordanceSignals", id: record.provenanceId)
        }
        guard record.isRegeneration == false else {
            throw FinalMomentStoreError.regenerationNotAllowed(recordType: "provenance", id: record.provenanceId)
        }
        try upsert(record, id: record.savedMomentId, recordType: "provenance", into: &provenanceBySavedMomentId)
        return record
    }

    func loadProvenance(savedMomentId: String) throws -> FinalMomentProvenanceRecord {
        try requireAvailable()
        return try load(savedMomentId, recordType: "provenance", from: provenanceBySavedMomentId)
    }

    private func requireAvailable() throws {
        guard available else {
            throw FinalMomentStoreError.persistenceUnavailable
        }
    }

    private func validateAsset(_ assetRef: FinalMomentAssetRef, isReadable: Bool) throws {
        guard isReadable,
              assetRef.assetId.isEmpty == false,
              assetRef.uri.isEmpty == false,
              assetRef.width > 0,
              assetRef.height > 0,
              assetRef.mimeType.isEmpty == false
        else {
            throw FinalMomentStoreError.unreadableAssetRef(assetId: assetRef.assetId)
        }
    }

    private func requireAsset(_ assetId: String) throws {
        guard assetsById[assetId] != nil else {
            throw FinalMomentStoreError.missingAsset(assetId: assetId)
        }
    }

    private func requireCaptureResult(_ captureResultId: String) throws {
        guard captureAssetsById.values.contains(where: { $0.captureResultId == captureResultId }) else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: "captureResult", id: captureResultId)
        }
    }

    private func requireNonEmpty(_ value: String, recordType: String, id: String) throws {
        guard value.isEmpty == false else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: recordType, id: id)
        }
    }

    private func upsert<T: Equatable>(
        _ record: T,
        id: String,
        recordType: String,
        into storage: inout [String: T]
    ) throws {
        if let existing = storage[id] {
            guard existing == record else {
                throw FinalMomentStoreError.duplicateRecordId(recordType: recordType, id: id)
            }
            return
        }
        storage[id] = record
    }

    private func load<T>(
        _ id: String,
        recordType: String,
        from storage: [String: T]
    ) throws -> T {
        guard let record = storage[id] else {
            throw FinalMomentStoreError.staleProvenanceReference(recordType: recordType, id: id)
        }
        return record
    }
}
