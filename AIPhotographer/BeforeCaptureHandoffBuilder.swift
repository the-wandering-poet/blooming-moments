import Foundation

enum BeforeCaptureHandoffBuilderSchema {
    static let currentVersion = "2026-06-04.before-capture-handoff-builder.v1"
}

enum BeforeCaptureHandoffBuilderError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case validationFailed(fieldPath: String, message: String)
    case missingFinalCameraSettings
    case missingCapturedAffordanceEvidence(String)
}

struct BeforeCaptureHandoffBuilderInput: Codable, Equatable {
    let schemaVersion: String
    let sceneInputQualityContext: SceneRuntimeModels.SceneInputQualityContext
    let runtimeAffordanceSignals: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let postCapturePrerequisites: SceneRuntimeModels.PostCapturePrerequisites
    let finalLiveReadinessAttempt: LiveReadinessAttemptRecord

    init(
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion,
        sceneInputQualityContext: SceneRuntimeModels.SceneInputQualityContext,
        runtimeAffordanceSignals: [SceneRuntimeModels.RuntimeAffordanceSignal],
        postCapturePrerequisites: SceneRuntimeModels.PostCapturePrerequisites,
        finalLiveReadinessAttempt: LiveReadinessAttemptRecord
    ) {
        self.schemaVersion = schemaVersion
        self.sceneInputQualityContext = sceneInputQualityContext
        self.runtimeAffordanceSignals = runtimeAffordanceSignals
        self.postCapturePrerequisites = postCapturePrerequisites
        self.finalLiveReadinessAttempt = finalLiveReadinessAttempt
    }
}

struct BeforeCaptureHandoffBuildResult: Codable, Equatable {
    let handoff: SceneRuntimeModels.BeforeCaptureFinalMomentHandoff
    let record: BeforeCaptureHandoffRecord
}

struct BeforeCaptureHandoffRecord: Codable, Equatable {
    let schemaVersion: String
    let builderVersion: String
    let handoffId: String
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let liveReadinessAttemptId: String?
    let sceneInputQualityContext: SceneRuntimeModels.SceneInputQualityContext
    let initialCameraSettingsRecommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation
    let cameraSettingsUsed: SceneRuntimeModels.CameraSettingsUsed
    let cameraSettingSubstitutions: [SceneRuntimeModels.CameraSettingSubstitution]
    let capabilityGaps: [String]
    let capturedAffordanceMetadata: SceneRuntimeModels.CapturedAffordanceMetadata
    let runtimeAffordanceSignals: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let postCapturePrerequisites: SceneRuntimeModels.PostCapturePrerequisites
    let provenanceIds: [String: String]
    let handoff: SceneRuntimeModels.BeforeCaptureFinalMomentHandoff
}

protocol BeforeCaptureHandoffRepository: AnyObject {
    func saveBeforeCaptureHandoff(_ record: BeforeCaptureHandoffRecord) async throws
    func beforeCaptureHandoffRecord(handoffId: String) async -> BeforeCaptureHandoffRecord?
    func beforeCaptureHandoffRecords(scenePlanId: String) async -> [BeforeCaptureHandoffRecord]
}

final class InMemoryBeforeCaptureHandoffRepository: BeforeCaptureHandoffRepository {
    private var recordsByHandoffId: [String: BeforeCaptureHandoffRecord] = [:]

    func saveBeforeCaptureHandoff(_ record: BeforeCaptureHandoffRecord) async throws {
        recordsByHandoffId[record.handoffId] = record
    }

    func beforeCaptureHandoffRecord(handoffId: String) async -> BeforeCaptureHandoffRecord? {
        recordsByHandoffId[handoffId]
    }

    func beforeCaptureHandoffRecords(scenePlanId: String) async -> [BeforeCaptureHandoffRecord] {
        recordsByHandoffId.values
            .filter { $0.scenePlanId == scenePlanId }
            .sorted { $0.handoffId < $1.handoffId }
    }
}

struct BeforeCaptureHandoffBuilder {
    let repository: BeforeCaptureHandoffRepository

    init(repository: BeforeCaptureHandoffRepository = InMemoryBeforeCaptureHandoffRepository()) {
        self.repository = repository
    }

    func build(
        _ input: BeforeCaptureHandoffBuilderInput
    ) async throws -> BeforeCaptureHandoffBuildResult {
        try validate(input)
        let liveRecord = input.finalLiveReadinessAttempt
        let settingsUsed = cameraSettingsUsed(from: liveRecord)
        let prerequisitesAtCapture = postCapturePrerequisitesAtCapture(
            input.postCapturePrerequisites,
            statusAtCapture: liveRecord.postCapturePrerequisiteStatus
        )
        let request = SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest(
            scenePlanId: liveRecord.scenePlanId,
            styleProfileId: liveRecord.styleProfileId,
            protectedSubjectSetId: liveRecord.protectedSubjectSetId,
            sceneInputQualityContext: input.sceneInputQualityContext,
            initialCameraSettingsRecommendation: liveRecord.initialCameraSettingsRecommendation,
            runtimeAffordanceSignals: input.runtimeAffordanceSignals,
            postCapturePrerequisites: prerequisitesAtCapture,
            capturedAffordanceMetadata: liveRecord.capturedAffordanceMetadata,
            cameraSettingsUsed: settingsUsed
        )
        return try await buildFromLockedRequest(
            request,
            schemaVersion: input.schemaVersion,
            liveReadinessAttemptId: liveRecord.liveReadinessAttemptId,
            nativeSubstitutions: liveRecord.nativeCameraSubstitutions
        )
    }

    func buildFromLockedRequest(
        _ request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest,
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion
    ) async throws -> BeforeCaptureHandoffBuildResult {
        try await buildFromLockedRequest(
            request,
            schemaVersion: schemaVersion,
            liveReadinessAttemptId: nil,
            nativeSubstitutions: request.cameraSettingsUsed?.substitutions ?? []
        )
    }

    func cameraSettingsUsed(
        from liveRecord: LiveReadinessAttemptRecord
    ) -> SceneRuntimeModels.CameraSettingsUsed {
        let adjustment = liveRecord.dynamicCameraSettingsAdjustment
        let recommendation = liveRecord.initialCameraSettingsRecommendation

        return SceneRuntimeModels.CameraSettingsUsed(
            settingsId: BeforeCaptureHandoffIdFactory.cameraSettingsUsedId(
                liveReadinessAttemptId: liveRecord.liveReadinessAttemptId
            ),
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
            capabilityGaps: liveRecord.capabilityGaps,
            substitutions: liveRecord.nativeCameraSubstitutions.isEmpty ? nil : liveRecord.nativeCameraSubstitutions
        )
    }

    private func buildFromLockedRequest(
        _ request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest,
        schemaVersion: String,
        liveReadinessAttemptId: String?,
        nativeSubstitutions: [SceneRuntimeModels.CameraSettingSubstitution]
    ) async throws -> BeforeCaptureHandoffBuildResult {
        try validate(schemaVersion: schemaVersion, request: request)
        guard let settingsUsed = request.cameraSettingsUsed else {
            throw BeforeCaptureHandoffBuilderError.missingFinalCameraSettings
        }
        let substitutions = settingsUsed.substitutions ?? nativeSubstitutions
        let handoff = SceneRuntimeModels.BeforeCaptureFinalMomentHandoff(
            scenePlanId: request.scenePlanId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            sceneInputQualityContext: request.sceneInputQualityContext,
            initialCameraSettingsRecommendation: request.initialCameraSettingsRecommendation,
            runtimeAffordanceSignals: request.runtimeAffordanceSignals,
            postCapturePrerequisites: request.postCapturePrerequisites,
            capturedAffordanceMetadata: request.capturedAffordanceMetadata,
            cameraSettingsUsed: settingsUsed,
            persistenceWriteIntent: [
                "beforeCaptureFinalMomentHandoff",
                "cameraSettingsUsed",
                "cameraSettingsRequested",
                "cameraSettingSubstitutions",
                "runtimeAffordanceMetadata",
                "provenanceIds"
            ]
        )
        let record = BeforeCaptureHandoffRecord(
            schemaVersion: schemaVersion,
            builderVersion: BeforeCaptureHandoffBuilderSchema.currentVersion,
            handoffId: BeforeCaptureHandoffIdFactory.handoffId(
                scenePlanId: request.scenePlanId,
                settingsId: settingsUsed.settingsId
            ),
            scenePlanId: request.scenePlanId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            liveReadinessAttemptId: liveReadinessAttemptId,
            sceneInputQualityContext: request.sceneInputQualityContext,
            initialCameraSettingsRecommendation: request.initialCameraSettingsRecommendation,
            cameraSettingsUsed: settingsUsed,
            cameraSettingSubstitutions: substitutions,
            capabilityGaps: settingsUsed.capabilityGaps,
            capturedAffordanceMetadata: request.capturedAffordanceMetadata,
            runtimeAffordanceSignals: request.runtimeAffordanceSignals,
            postCapturePrerequisites: request.postCapturePrerequisites,
            provenanceIds: provenanceIds(
                request: request,
                settingsUsed: settingsUsed,
                liveReadinessAttemptId: liveReadinessAttemptId
            ),
            handoff: handoff
        )

        try await repository.saveBeforeCaptureHandoff(record)
        return BeforeCaptureHandoffBuildResult(handoff: handoff, record: record)
    }

    private func validate(_ input: BeforeCaptureHandoffBuilderInput) throws {
        guard input.schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw BeforeCaptureHandoffBuilderError.unsupportedSchemaVersion(input.schemaVersion)
        }
        try requireNonEmpty(input.finalLiveReadinessAttempt.scenePlanId, fieldPath: "finalLiveReadinessAttempt.scenePlanId")
        try requireNonEmpty(input.finalLiveReadinessAttempt.styleProfileId, fieldPath: "finalLiveReadinessAttempt.styleProfileId")
        try requireNonEmpty(input.finalLiveReadinessAttempt.protectedSubjectSetId, fieldPath: "finalLiveReadinessAttempt.protectedSubjectSetId")
        try requireNonEmpty(input.finalLiveReadinessAttempt.liveReadinessAttemptId, fieldPath: "finalLiveReadinessAttempt.liveReadinessAttemptId")
        if input.runtimeAffordanceSignals.isEmpty {
            throw BeforeCaptureHandoffBuilderError.validationFailed(
                fieldPath: "runtimeAffordanceSignals",
                message: "Before-capture handoff requires runtime affordance signals."
            )
        }
        if input.postCapturePrerequisites.mustCaptureCorrectly.isEmpty {
            throw BeforeCaptureHandoffBuilderError.validationFailed(
                fieldPath: "postCapturePrerequisites.mustCaptureCorrectly",
                message: "Before-capture handoff requires post-capture prerequisites."
            )
        }
    }

    private func validate(
        schemaVersion: String,
        request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest
    ) throws {
        guard schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw BeforeCaptureHandoffBuilderError.unsupportedSchemaVersion(schemaVersion)
        }
        try requireNonEmpty(request.scenePlanId, fieldPath: "scenePlanId")
        try requireNonEmpty(request.styleProfileId, fieldPath: "styleProfileId")
        try requireNonEmpty(request.protectedSubjectSetId, fieldPath: "protectedSubjectSetId")
        try requireNonEmpty(
            request.initialCameraSettingsRecommendation.recommendationId,
            fieldPath: "initialCameraSettingsRecommendation.recommendationId"
        )
        guard request.cameraSettingsUsed != nil else {
            throw BeforeCaptureHandoffBuilderError.missingFinalCameraSettings
        }
        if request.runtimeAffordanceSignals.isEmpty {
            throw BeforeCaptureHandoffBuilderError.validationFailed(
                fieldPath: "runtimeAffordanceSignals",
                message: "Before-capture handoff requires runtime affordance signals."
            )
        }
        if request.postCapturePrerequisites.mustCaptureCorrectly.isEmpty {
            throw BeforeCaptureHandoffBuilderError.validationFailed(
                fieldPath: "postCapturePrerequisites.mustCaptureCorrectly",
                message: "Before-capture handoff requires post-capture prerequisites."
            )
        }
        try validateCapturedAffordanceEvidence(
            signals: request.runtimeAffordanceSignals,
            metadata: request.capturedAffordanceMetadata
        )
    }

    private func validateCapturedAffordanceEvidence(
        signals: [SceneRuntimeModels.RuntimeAffordanceSignal],
        metadata: SceneRuntimeModels.CapturedAffordanceMetadata
    ) throws {
        if signals.contains(where: { $0.type == .rimHairEdgeLight }),
           metadata.rimHairEdgeLightPreserved == nil {
            throw BeforeCaptureHandoffBuilderError.missingCapturedAffordanceEvidence("rim_hair_edge_light")
        }
    }

    private func postCapturePrerequisitesAtCapture(
        _ prerequisites: SceneRuntimeModels.PostCapturePrerequisites,
        statusAtCapture: [String: String]
    ) -> SceneRuntimeModels.PostCapturePrerequisites {
        SceneRuntimeModels.PostCapturePrerequisites(
            mustCaptureCorrectly: prerequisites.mustCaptureCorrectly,
            canFineTuneLater: prerequisites.canFineTuneLater,
            statusAtCapture: statusAtCapture
        )
    }

    private func provenanceIds(
        request: SceneRuntimeModels.BuildBeforeCaptureFinalMomentHandoffRequest,
        settingsUsed: SceneRuntimeModels.CameraSettingsUsed,
        liveReadinessAttemptId: String?
    ) -> [String: String] {
        var ids = [
            "scenePlanId": request.scenePlanId,
            "styleProfileId": request.styleProfileId,
            "protectedSubjectSetId": request.protectedSubjectSetId,
            "initialCameraSettingsRecommendationId": request.initialCameraSettingsRecommendation.recommendationId,
            "cameraSettingsUsedId": settingsUsed.settingsId
        ]
        if let liveReadinessAttemptId {
            ids["liveReadinessAttemptId"] = liveReadinessAttemptId
        }
        if let intentId = request.initialCameraSettingsRecommendation.sourceNativeCameraParameterIntentId {
            ids["sourceNativeCameraParameterIntentId"] = intentId
        }
        return ids
    }

    private func requireNonEmpty(_ value: String, fieldPath: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BeforeCaptureHandoffBuilderError.validationFailed(
                fieldPath: fieldPath,
                message: "\(fieldPath) must not be empty."
            )
        }
    }
}

enum BeforeCaptureHandoffIdFactory {
    static func cameraSettingsUsedId(liveReadinessAttemptId: String) -> String {
        "camera_settings_used_\(sanitize(liveReadinessAttemptId))"
    }

    static func handoffId(scenePlanId: String, settingsId: String) -> String {
        "before_capture_handoff_\(sanitize(scenePlanId))_\(sanitize(settingsId))"
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
