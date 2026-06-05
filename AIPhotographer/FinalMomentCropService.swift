import Foundation

struct FinalMomentProtectedSubjectCropGeometry: Codable, Equatable {
    let frameId: String
    let subjectId: String
    let protectedBounds: FinalMomentNormalizedRect
    let minimumSafePadding: Double
}

struct FinalMomentCropServiceRequest: Codable, Equatable {
    let cropGenerationResultId: String
    let request: FinalMomentCropGenerationRequest
    let keeperSelection: FinalMomentKeeperSelection
    let acceptedFrames: [FinalMomentAcceptedFrame]
    let protectedSubjectGeometry: [FinalMomentProtectedSubjectCropGeometry]
}

enum FinalMomentCropServiceError: Error, Equatable, LocalizedError {
    case staleKeeperSelectionId(expected: String, actual: String)
    case missingAcceptedFrame(frameId: String)
    case missingProtectedSubjectGeometry(frameId: String)
    case unsafeProtectedSubjectCrop(frameId: String, cropId: String)

    var errorDescription: String? {
        switch self {
        case .staleKeeperSelectionId(let expected, let actual):
            return "Stale keeper selection ID. Expected \(expected), got \(actual)."
        case .missingAcceptedFrame(let frameId):
            return "Missing accepted frame for selected keeper: \(frameId)."
        case .missingProtectedSubjectGeometry(let frameId):
            return "Missing protected-subject crop geometry for frame: \(frameId)."
        case .unsafeProtectedSubjectCrop(let frameId, let cropId):
            return "Crop \(cropId) would unsafe-crop a protected subject in frame: \(frameId)."
        }
    }
}

final class FinalMomentCropService {
    private let repository: (any FinalMomentRepository)?
    private let assetRepository: (any FinalMomentAssetRepository)?

    init(
        repository: (any FinalMomentRepository)? = nil,
        assetRepository: (any FinalMomentAssetRepository)? = nil
    ) {
        self.repository = repository
        self.assetRepository = assetRepository
    }

    func generateInternalCrops(
        _ serviceRequest: FinalMomentCropServiceRequest
    ) throws -> FinalMomentCropGenerationResult {
        guard serviceRequest.request.keeperSelectionId == serviceRequest.keeperSelection.keeperSelectionId else {
            throw FinalMomentCropServiceError.staleKeeperSelectionId(
                expected: serviceRequest.keeperSelection.keeperSelectionId,
                actual: serviceRequest.request.keeperSelectionId
            )
        }

        let acceptedByFrameId = Dictionary(uniqueKeysWithValues: serviceRequest.acceptedFrames.map {
            ($0.frameId, $0)
        })
        let geometryByFrameId = Dictionary(grouping: serviceRequest.protectedSubjectGeometry, by: \.frameId)

        var allCandidates: [FinalMomentCropCandidate] = []
        var recommendedCropByFrame: [String: String] = [:]

        for frameId in serviceRequest.keeperSelection.selectedFrameIds {
            guard let acceptedFrame = acceptedByFrameId[frameId] else {
                throw FinalMomentCropServiceError.missingAcceptedFrame(frameId: frameId)
            }
            guard let protectedGeometry = geometryByFrameId[frameId], protectedGeometry.isEmpty == false else {
                throw FinalMomentCropServiceError.missingProtectedSubjectGeometry(frameId: frameId)
            }

            let candidates = try cropCandidates(
                frameId: frameId,
                acceptedFrame: acceptedFrame,
                protectedGeometry: protectedGeometry,
                request: serviceRequest.request
            )
            allCandidates.append(contentsOf: candidates)
            recommendedCropByFrame[frameId] = recommendedCropId(from: candidates)
        }

        let result = FinalMomentCropGenerationResult(
            cropGenerationResultId: serviceRequest.cropGenerationResultId,
            keeperSelectionId: serviceRequest.keeperSelection.keeperSelectionId,
            cropCandidates: allCandidates,
            recommendedCropByFrame: recommendedCropByFrame
        )

        try persist(result, serviceRequest: serviceRequest)
        return result
    }

    private func cropCandidates(
        frameId: String,
        acceptedFrame: FinalMomentAcceptedFrame,
        protectedGeometry: [FinalMomentProtectedSubjectCropGeometry],
        request: FinalMomentCropGenerationRequest
    ) throws -> [FinalMomentCropCandidate] {
        let subjectUnion = unionRect(protectedGeometry.map(\.protectedBounds))
        let usefulSignals = usefulAffordances(request.runtimeAffordanceSignals)
        let mode = cropMode(cameraSettingsUsed: request.cameraSettingsUsed)
        var candidates: [FinalMomentCropCandidate] = []

        if mode.allowsEnvironmental,
           request.capturedAffordanceMetadata.cropHeadroomPreserved,
           usefulSignals.isEmpty == false {
            let environmentalBox = expandedRect(
                subjectUnion,
                horizontalPadding: max(0.26, maximumPadding(protectedGeometry)),
                verticalPadding: max(0.24, maximumPadding(protectedGeometry))
            )
            let candidate = makeCandidate(
                cropId: "crop_\(frameId)_environmental",
                frameId: frameId,
                label: "Environmental",
                cropBox: environmentalBox,
                roleHint: "environmental",
                rationale: "Preserves protected subjects while keeping captured scene affordances available for fine tune.",
                isDefaultFallback: false,
                protectedGeometry: protectedGeometry,
                preservedSignals: usefulSignals,
                allSignals: request.runtimeAffordanceSignals,
                cropHeadroomUsage: "moderate",
                affordanceLossRisk: "low",
                defaultFallbackReason: nil
            )
            try validateProtectedSubjects(candidate, protectedGeometry: protectedGeometry)
            candidates.append(candidate)
        }

        if mode.allowsBalanced,
           request.capturedAffordanceMetadata.cropHeadroomPreserved {
            let balancedBox = expandedRect(
                subjectUnion,
                horizontalPadding: max(0.16, maximumPadding(protectedGeometry)),
                verticalPadding: max(0.16, maximumPadding(protectedGeometry))
            )
            let preserved = conservativePreservedSignals(usefulSignals)
            let candidate = makeCandidate(
                cropId: "crop_\(frameId)_balanced",
                frameId: frameId,
                label: "Balanced",
                cropBox: balancedBox,
                roleHint: "balanced",
                rationale: "Keeps protected subjects safe with a conservative crop around the keeper moment.",
                isDefaultFallback: false,
                protectedGeometry: protectedGeometry,
                preservedSignals: preserved,
                allSignals: request.runtimeAffordanceSignals,
                cropHeadroomUsage: mode.isConservative ? "low" : "medium",
                affordanceLossRisk: mode.isConservative ? "medium" : "low_medium",
                defaultFallbackReason: nil
            )
            try validateProtectedSubjects(candidate, protectedGeometry: protectedGeometry)
            candidates.append(candidate)
        }

        let fallbackReason = fallbackReason(
            mode: mode,
            capturedAffordanceMetadata: request.capturedAffordanceMetadata,
            usefulSignals: usefulSignals,
            hasSpecialCandidates: candidates.isEmpty == false
        )
        let standard = makeCandidate(
            cropId: "crop_\(frameId)_standard_default",
            frameId: frameId,
            label: "Standard",
            cropBox: FinalMomentNormalizedRect(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
            roleHint: "standard_default",
            rationale: "Default safe framing preserves the captured photo when no special crop is preferable.",
            isDefaultFallback: true,
            protectedGeometry: protectedGeometry,
            preservedSignals: request.runtimeAffordanceSignals,
            allSignals: request.runtimeAffordanceSignals,
            cropHeadroomUsage: "none",
            affordanceLossRisk: "low",
            defaultFallbackReason: fallbackReason
        )
        try validateProtectedSubjects(standard, protectedGeometry: protectedGeometry)
        candidates.append(standard)

        return candidates
    }

    private struct CropMode {
        let allowsEnvironmental: Bool
        let allowsBalanced: Bool
        let isConservative: Bool
        let fallbackReason: String?
    }

    private func cropMode(cameraSettingsUsed: FinalMomentCameraSettingsUsed) -> CropMode {
        let statuses = [
            cameraSettingsUsed.zoomLens.status,
            cameraSettingsUsed.framing.status,
            cameraSettingsUsed.captureQuality.status
        ]

        if statuses.contains(.unavailable) || statuses.contains(.needsOperatorAdjustment) {
            return CropMode(
                allowsEnvironmental: false,
                allowsBalanced: false,
                isConservative: true,
                fallbackReason: "camera_status_conservative_fallback"
            )
        }

        if statuses.contains(.adjusted) {
            return CropMode(
                allowsEnvironmental: false,
                allowsBalanced: true,
                isConservative: true,
                fallbackReason: "camera_status_adjusted_conservative_crop"
            )
        }

        return CropMode(
            allowsEnvironmental: true,
            allowsBalanced: true,
            isConservative: false,
            fallbackReason: nil
        )
    }

    private func fallbackReason(
        mode: CropMode,
        capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata,
        usefulSignals: [FinalMomentRuntimeAffordanceSignal],
        hasSpecialCandidates: Bool
    ) -> String? {
        if hasSpecialCandidates {
            return "standard_safe_framing"
        }
        if let reason = mode.fallbackReason {
            return reason
        }
        if capturedAffordanceMetadata.cropHeadroomPreserved == false {
            return "crop_headroom_not_preserved"
        }
        if usefulSignals.isEmpty {
            return "no_special_crop_affordance"
        }
        return "standard_safe_framing"
    }

    private func recommendedCropId(from candidates: [FinalMomentCropCandidate]) -> String {
        if let environmental = candidates.first(where: { $0.cropId.hasSuffix("_environmental") }) {
            return environmental.cropId
        }
        if let balanced = candidates.first(where: { $0.cropId.hasSuffix("_balanced") }) {
            return balanced.cropId
        }
        return candidates.first(where: { $0.isDefaultFallback })?.cropId ?? candidates[0].cropId
    }

    private func makeCandidate(
        cropId: String,
        frameId: String,
        label: String,
        cropBox: FinalMomentNormalizedRect,
        roleHint: String,
        rationale: String,
        isDefaultFallback: Bool,
        protectedGeometry: [FinalMomentProtectedSubjectCropGeometry],
        preservedSignals: [FinalMomentRuntimeAffordanceSignal],
        allSignals: [FinalMomentRuntimeAffordanceSignal],
        cropHeadroomUsage: String,
        affordanceLossRisk: String,
        defaultFallbackReason: String?
    ) -> FinalMomentCropCandidate {
        let uniquePreserved = uniqueAffordances(preservedSignals)
        let lost = uniqueAffordances(allSignals).filter { uniquePreserved.contains($0) == false }
        return FinalMomentCropCandidate(
            cropId: cropId,
            frameId: frameId,
            label: label,
            cropBox: normalized(cropBox),
            cropPreviewAssetRef: cropPreviewAsset(cropId: cropId, roleHint: roleHint),
            compositionRationale: rationale,
            isDefaultFallback: isDefaultFallback,
            protectedSubjectCropSafety: protectedSubjectCropSafety(cropBox, protectedGeometry: protectedGeometry),
            preservedAffordanceSignals: uniquePreserved,
            lostAffordanceSignals: lost,
            cropHeadroomUsage: cropHeadroomUsage,
            affordanceLossRisk: affordanceLossRisk,
            defaultFallbackReason: defaultFallbackReason
        )
    }

    private func validateProtectedSubjects(
        _ candidate: FinalMomentCropCandidate,
        protectedGeometry: [FinalMomentProtectedSubjectCropGeometry]
    ) throws {
        guard protectedSubjectCropSafety(candidate.cropBox, protectedGeometry: protectedGeometry) == "all_protected_subjects_preserved" else {
            throw FinalMomentCropServiceError.unsafeProtectedSubjectCrop(
                frameId: candidate.frameId,
                cropId: candidate.cropId
            )
        }
    }

    private func protectedSubjectCropSafety(
        _ cropBox: FinalMomentNormalizedRect,
        protectedGeometry: [FinalMomentProtectedSubjectCropGeometry]
    ) -> String {
        let normalizedCrop = normalized(cropBox)
        let allSafe = protectedGeometry.allSatisfy { geometry in
            guard isValidNormalizedSubjectBounds(geometry.protectedBounds) else {
                return false
            }
            let padded = expandedRect(
                geometry.protectedBounds,
                horizontalPadding: geometry.minimumSafePadding,
                verticalPadding: geometry.minimumSafePadding
            )
            return contains(normalizedCrop, padded)
        }
        return allSafe ? "all_protected_subjects_preserved" : "unsafe_protected_subject_crop"
    }

    private func isValidNormalizedSubjectBounds(_ rect: FinalMomentNormalizedRect) -> Bool {
        rect.x >= 0.0
            && rect.y >= 0.0
            && rect.w > 0.0
            && rect.h > 0.0
            && rect.x + rect.w <= 1.0
            && rect.y + rect.h <= 1.0
    }

    private func usefulAffordances(
        _ signals: [FinalMomentRuntimeAffordanceSignal]
    ) -> [FinalMomentRuntimeAffordanceSignal] {
        let desired: Set<FinalMomentRuntimeAffordanceSignal> = [
            .rimHairEdgeLight,
            .projectedShadowPattern,
            .architecturalAnchor,
            .classicLocationAnchor,
            .relationshipInteractionOpportunity,
            .cropHeadroomAvailable
        ]
        return uniqueAffordances(signals.filter { desired.contains($0) })
    }

    private func conservativePreservedSignals(
        _ signals: [FinalMomentRuntimeAffordanceSignal]
    ) -> [FinalMomentRuntimeAffordanceSignal] {
        let conservative: Set<FinalMomentRuntimeAffordanceSignal> = [
            .relationshipInteractionOpportunity,
            .cropHeadroomAvailable,
            .rimHairEdgeLight
        ]
        let filtered = signals.filter { conservative.contains($0) }
        return filtered.isEmpty ? signals : filtered
    }

    private func uniqueAffordances(
        _ signals: [FinalMomentRuntimeAffordanceSignal]
    ) -> [FinalMomentRuntimeAffordanceSignal] {
        var seen: Set<FinalMomentRuntimeAffordanceSignal> = []
        return signals.filter { seen.insert($0).inserted }
    }

    private func unionRect(_ rects: [FinalMomentNormalizedRect]) -> FinalMomentNormalizedRect {
        let normalizedRects = rects.map(normalized)
        guard let first = normalizedRects.first else {
            return FinalMomentNormalizedRect(x: 0, y: 0, w: 1, h: 1)
        }
        let minX = normalizedRects.map(\.x).reduce(first.x, Swift.min)
        let minY = normalizedRects.map(\.y).reduce(first.y, Swift.min)
        let maxX = normalizedRects.map { $0.x + $0.w }.reduce(first.x + first.w, Swift.max)
        let maxY = normalizedRects.map { $0.y + $0.h }.reduce(first.y + first.h, Swift.max)
        return normalized(FinalMomentNormalizedRect(x: minX, y: minY, w: maxX - minX, h: maxY - minY))
    }

    private func expandedRect(
        _ rect: FinalMomentNormalizedRect,
        horizontalPadding: Double,
        verticalPadding: Double
    ) -> FinalMomentNormalizedRect {
        normalized(FinalMomentNormalizedRect(
            x: rect.x - horizontalPadding,
            y: rect.y - verticalPadding,
            w: rect.w + horizontalPadding * 2,
            h: rect.h + verticalPadding * 2
        ))
    }

    private func maximumPadding(
        _ geometry: [FinalMomentProtectedSubjectCropGeometry]
    ) -> Double {
        geometry.map(\.minimumSafePadding).max() ?? 0.06
    }

    private func contains(
        _ outer: FinalMomentNormalizedRect,
        _ inner: FinalMomentNormalizedRect
    ) -> Bool {
        inner.x >= outer.x
            && inner.y >= outer.y
            && inner.x + inner.w <= outer.x + outer.w
            && inner.y + inner.h <= outer.y + outer.h
    }

    private func normalized(_ rect: FinalMomentNormalizedRect) -> FinalMomentNormalizedRect {
        let x = min(max(rect.x, 0.0), 1.0)
        let y = min(max(rect.y, 0.0), 1.0)
        let maxWidth = max(0.0, 1.0 - x)
        let maxHeight = max(0.0, 1.0 - y)
        return FinalMomentNormalizedRect(
            x: x,
            y: y,
            w: min(max(rect.w, 0.0), maxWidth),
            h: min(max(rect.h, 0.0), maxHeight)
        )
    }

    private func cropPreviewAsset(
        cropId: String,
        roleHint: String
    ) -> FinalMomentAssetRef {
        FinalMomentAssetRef(
            assetId: "asset_\(cropId)_preview",
            uri: "asset://\(cropId)_preview",
            role: .cropPreview,
            width: roleHint == "standard_default" ? 2400 : 2200,
            height: roleHint == "standard_default" ? 3000 : 2750,
            mimeType: "image/jpeg"
        )
    }

    private func croppedAsset(
        cropId: String
    ) -> FinalMomentAssetRef {
        FinalMomentAssetRef(
            assetId: "asset_\(cropId)_cropped",
            uri: "asset://\(cropId)_cropped",
            role: .cropped,
            width: 2400,
            height: 3000,
            mimeType: "image/jpeg"
        )
    }

    private func persist(
        _ result: FinalMomentCropGenerationResult,
        serviceRequest: FinalMomentCropServiceRequest
    ) throws {
        guard let repository else { return }

        for candidate in result.cropCandidates {
            _ = try assetRepository?.upsertAsset(FinalMomentAssetRecord(
                assetRef: candidate.cropPreviewAssetRef,
                sourceStage: "crop_preview",
                captureResultId: serviceRequest.keeperSelection.captureResultId,
                frameId: candidate.frameId,
                isReadable: true,
                contentFingerprint: candidate.cropId
            ))
        }

        _ = try repository.upsertCropGenerationRef(FinalMomentCropGenerationRefRecord(
            cropGenerationResultId: result.cropGenerationResultId,
            keeperSelectionId: result.keeperSelectionId,
            captureResultId: serviceRequest.keeperSelection.captureResultId,
            protectedSubjectSetId: serviceRequest.keeperSelection.protectedSubjectSetId,
            styleProfileId: serviceRequest.request.styleProfileId,
            scenePlanId: serviceRequest.request.scenePlanId,
            cropCandidates: result.cropCandidates,
            recommendedCropByFrame: result.recommendedCropByFrame,
            runtimeAffordanceSignals: serviceRequest.request.runtimeAffordanceSignals,
            capturedAffordanceMetadata: serviceRequest.request.capturedAffordanceMetadata,
            cameraSettingsUsed: serviceRequest.request.cameraSettingsUsed
        ))

        let candidatesById = Dictionary(uniqueKeysWithValues: result.cropCandidates.map { ($0.cropId, $0) })
        for (frameId, cropId) in result.recommendedCropByFrame {
            guard let candidate = candidatesById[cropId] else { continue }
            let outputAsset = croppedAsset(cropId: cropId)
            _ = try assetRepository?.upsertAsset(FinalMomentAssetRecord(
                assetRef: outputAsset,
                sourceStage: "crop_output",
                captureResultId: serviceRequest.keeperSelection.captureResultId,
                frameId: frameId,
                isReadable: true,
                contentFingerprint: cropId
            ))
            _ = try repository.upsertCropDecisionRef(FinalMomentCropDecisionRefRecord(
                cropDecisionId: cropId,
                cropGenerationResultId: result.cropGenerationResultId,
                keeperSelectionId: result.keeperSelectionId,
                frameId: frameId,
                cropAssetRef: outputAsset,
                recommendedCropId: cropId,
                preservedAffordanceSignals: candidate.preservedAffordanceSignals
            ))
        }
    }
}
