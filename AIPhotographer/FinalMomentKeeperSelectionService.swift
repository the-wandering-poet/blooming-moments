import Foundation

struct FinalMomentKeeperSelectionServiceRequest: Codable, Equatable {
    let keeperSelectionId: String
    let request: FinalMomentKeeperSelectionRequest
    let autoCullResult: FinalMomentAutoCullResult
    let captureResultId: String
    let protectedSubjectSetId: String
    let captureSessionIsActive: Bool
}

enum FinalMomentKeeperSelectionServiceError: Error, Equatable, LocalizedError {
    case emptySelection
    case duplicateFrameId(frameId: String)
    case rejectedFrameSelected(frameId: String)
    case unknownFrameSelected(frameId: String)
    case staleAutoCullId(expected: String, actual: String)
    case deletedAsset(assetId: String)
    case expiredCaptureSession(captureResultId: String)
    case allFramesRejected(autoCullResultId: String)

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "Choose at least one accepted frame."
        case .duplicateFrameId(let frameId):
            return "Duplicate selected frame ID: \(frameId)."
        case .rejectedFrameSelected(let frameId):
            return "Selected frame was rejected by auto-cull: \(frameId)."
        case .unknownFrameSelected(let frameId):
            return "Selected frame is unknown to the auto-cull result: \(frameId)."
        case .staleAutoCullId(let expected, let actual):
            return "Stale auto-cull ID. Expected \(expected), got \(actual)."
        case .deletedAsset(let assetId):
            return "Selected frame asset is no longer available: \(assetId)."
        case .expiredCaptureSession(let captureResultId):
            return "Capture session has expired for capture result: \(captureResultId)."
        case .allFramesRejected(let autoCullResultId):
            return "Cannot choose keepers because all frames were rejected: \(autoCullResultId)."
        }
    }
}

final class FinalMomentKeeperSelectionService {
    private let repository: (any FinalMomentRepository)?
    private let assetRepository: (any FinalMomentAssetRepository)?

    init(
        repository: (any FinalMomentRepository)? = nil,
        assetRepository: (any FinalMomentAssetRepository)? = nil
    ) {
        self.repository = repository
        self.assetRepository = assetRepository
    }

    func createKeeperSelection(
        _ serviceRequest: FinalMomentKeeperSelectionServiceRequest
    ) throws -> FinalMomentKeeperSelection {
        let request = serviceRequest.request
        let autoCullResult = serviceRequest.autoCullResult

        guard request.autoCullResultId == autoCullResult.autoCullResultId else {
            throw FinalMomentKeeperSelectionServiceError.staleAutoCullId(
                expected: autoCullResult.autoCullResultId,
                actual: request.autoCullResultId
            )
        }

        guard serviceRequest.captureSessionIsActive else {
            throw FinalMomentKeeperSelectionServiceError.expiredCaptureSession(
                captureResultId: serviceRequest.captureResultId
            )
        }

        guard autoCullResult.allFramesRejected == false else {
            throw FinalMomentKeeperSelectionServiceError.allFramesRejected(
                autoCullResultId: autoCullResult.autoCullResultId
            )
        }

        guard request.selectedFrameIds.isEmpty == false else {
            throw FinalMomentKeeperSelectionServiceError.emptySelection
        }

        let acceptedByFrameId = Dictionary(uniqueKeysWithValues: autoCullResult.acceptedFrames.map {
            ($0.frameId, $0)
        })
        let rejectedIds = Set(autoCullResult.rejectedFrames.map(\.frameId))
        let selectedFrameIds = try validateSelectedFrameIds(
            request.selectedFrameIds,
            acceptedByFrameId: acceptedByFrameId,
            rejectedIds: rejectedIds
        )

        try validateSelectedAssets(selectedFrameIds, acceptedByFrameId: acceptedByFrameId)

        let selection = FinalMomentKeeperSelection(
            keeperSelectionId: serviceRequest.keeperSelectionId,
            autoCullResultId: autoCullResult.autoCullResultId,
            captureResultId: serviceRequest.captureResultId,
            protectedSubjectSetId: serviceRequest.protectedSubjectSetId,
            selectedFrameIds: selectedFrameIds
        )

        _ = try repository?.upsertKeeperSelectionRef(FinalMomentKeeperSelectionRefRecord(
            keeperSelectionId: selection.keeperSelectionId,
            autoCullResultId: selection.autoCullResultId,
            captureResultId: selection.captureResultId,
            protectedSubjectSetId: selection.protectedSubjectSetId,
            selectedFrameIds: selection.selectedFrameIds
        ))

        return selection
    }

    private func validateSelectedFrameIds(
        _ selectedFrameIds: [String],
        acceptedByFrameId: [String: FinalMomentAcceptedFrame],
        rejectedIds: Set<String>
    ) throws -> [String] {
        var seen: Set<String> = []
        for frameId in selectedFrameIds {
            guard seen.insert(frameId).inserted else {
                throw FinalMomentKeeperSelectionServiceError.duplicateFrameId(frameId: frameId)
            }
            if rejectedIds.contains(frameId) {
                throw FinalMomentKeeperSelectionServiceError.rejectedFrameSelected(frameId: frameId)
            }
            guard acceptedByFrameId[frameId] != nil else {
                throw FinalMomentKeeperSelectionServiceError.unknownFrameSelected(frameId: frameId)
            }
        }
        return selectedFrameIds
    }

    private func validateSelectedAssets(
        _ selectedFrameIds: [String],
        acceptedByFrameId: [String: FinalMomentAcceptedFrame]
    ) throws {
        guard let assetRepository else { return }

        for frameId in selectedFrameIds {
            guard let acceptedFrame = acceptedByFrameId[frameId] else {
                throw FinalMomentKeeperSelectionServiceError.unknownFrameSelected(frameId: frameId)
            }
            do {
                let record = try assetRepository.loadAsset(assetId: acceptedFrame.assetRef.assetId)
                guard record.isReadable else {
                    throw FinalMomentKeeperSelectionServiceError.deletedAsset(assetId: acceptedFrame.assetRef.assetId)
                }
            } catch let error as FinalMomentStoreError {
                switch error {
                case .missingAsset, .unreadableAssetRef:
                    throw FinalMomentKeeperSelectionServiceError.deletedAsset(assetId: acceptedFrame.assetRef.assetId)
                default:
                    throw error
                }
            }
        }
    }
}
