import Foundation

enum LiveCoachEvaluatorSchema {
    static let currentVersion = "2026-06-04.live-coach-evaluator.v1"
    static let readyThreshold = 0.90
    static let almostReadyThreshold = 0.75
    static let coachingThreshold = 0.45
}

enum LiveCoachEvaluatorError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case validationFailed(fieldPath: String, message: String)
}

enum LivePrerequisiteStatus: String, Codable, Equatable {
    case passed
    case weak
    case failed
}

enum LiveAffordanceDisposition: String, Codable, Equatable {
    case preserved
    case downgraded
    case removed
}

struct LiveAffordanceEvaluation: Codable, Equatable {
    let signal: SceneRuntimeModels.RuntimeAffordanceSignal
    let disposition: LiveAffordanceDisposition
    let reason: String?
}

struct LiveCoachEvaluatorInput: Codable, Equatable {
    let schemaVersion: String
    let request: SceneRuntimeModels.EvaluateLiveFrameReadinessRequest
    let bestEffortAllowed: Bool

    init(
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion,
        request: SceneRuntimeModels.EvaluateLiveFrameReadinessRequest,
        bestEffortAllowed: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.request = request
        self.bestEffortAllowed = bestEffortAllowed
    }
}

struct LiveCoachEvaluationResult: Codable, Equatable {
    let response: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse
    let record: LiveReadinessAttemptRecord
}

struct LiveReadinessAttemptRecord: Codable, Equatable {
    let schemaVersion: String
    let evaluatorVersion: String
    let liveReadinessAttemptId: String
    let scenePlanId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let initialCameraSettingsRecommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation
    let liveFrameSummary: SceneRuntimeModels.LiveFrameSummary
    let readiness: SceneRuntimeModels.Readiness
    let readinessScore: Double
    let blockingIssues: [String]
    let cues: [SceneRuntimeModels.CoachingCue]
    let dynamicCameraSettingsAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    let capturedAffordanceMetadata: SceneRuntimeModels.CapturedAffordanceMetadata
    let postCapturePrerequisiteStatus: [String: String]
    let runtimeAffordanceEvaluations: [LiveAffordanceEvaluation]
    let capabilityGaps: [String]
    let capabilityStatus: [String: SceneRuntimeModels.CameraCapabilityStatus]
    let downgradedSettings: [String: SceneRuntimeModels.CameraCapabilityStatus]
    let nativeAdapterCommands: [NativeCameraCommand]
    let nativeCameraSubstitutions: [SceneRuntimeModels.CameraSettingSubstitution]
    let response: SceneRuntimeModels.EvaluateLiveFrameReadinessResponse
}

protocol LiveCoachReadinessRepository: AnyObject {
    func nextLiveReadinessAttemptSequence(scenePlanId: String) async -> Int
    func saveLiveReadinessAttempt(_ record: LiveReadinessAttemptRecord) async throws
    func liveReadinessAttemptRecord(attemptId: String) async -> LiveReadinessAttemptRecord?
    func liveReadinessAttemptRecords(scenePlanId: String) async -> [LiveReadinessAttemptRecord]
}

final class InMemoryLiveCoachReadinessRepository: LiveCoachReadinessRepository {
    private var recordsByAttemptId: [String: LiveReadinessAttemptRecord] = [:]

    func nextLiveReadinessAttemptSequence(scenePlanId: String) async -> Int {
        recordsByAttemptId.values.filter { $0.scenePlanId == scenePlanId }.count + 1
    }

    func saveLiveReadinessAttempt(_ record: LiveReadinessAttemptRecord) async throws {
        recordsByAttemptId[record.liveReadinessAttemptId] = record
    }

    func liveReadinessAttemptRecord(attemptId: String) async -> LiveReadinessAttemptRecord? {
        recordsByAttemptId[attemptId]
    }

    func liveReadinessAttemptRecords(scenePlanId: String) async -> [LiveReadinessAttemptRecord] {
        recordsByAttemptId.values
            .filter { $0.scenePlanId == scenePlanId }
            .sorted { $0.liveReadinessAttemptId < $1.liveReadinessAttemptId }
    }
}

struct LiveCoachEvaluator {
    let repository: LiveCoachReadinessRepository
    let nativeCameraAdapter: any NativeCameraAdapterBoundary

    init(
        repository: LiveCoachReadinessRepository = InMemoryLiveCoachReadinessRepository(),
        nativeCameraAdapter: any NativeCameraAdapterBoundary = AVFoundationNativeCameraAdapter()
    ) {
        self.repository = repository
        self.nativeCameraAdapter = nativeCameraAdapter
    }

    func evaluate(_ input: LiveCoachEvaluatorInput) async throws -> LiveCoachEvaluationResult {
        try validate(input)

        let request = input.request
        let adapterResult = try nativeCameraAdapter.prepareCameraAdjustment(
            NativeCameraAdapterInput(
                schemaVersion: input.schemaVersion,
                scenePlanId: request.scenePlanId,
                recommendation: request.initialCameraSettingsRecommendation,
                nativeCapabilities: request.liveFrameSummary.nativeCapabilities
            )
        )
        let prerequisiteStatus = prerequisiteStatuses(
            liveFrameSummary: request.liveFrameSummary,
            prerequisites: request.postCapturePrerequisites.mustCaptureCorrectly
        )
        let affordanceEvaluations = evaluateAffordances(
            request.runtimeAffordanceSignals,
            liveFrameSummary: request.liveFrameSummary,
            prerequisiteStatus: prerequisiteStatus
        )
        let dynamicAdjustment = dynamicAdjustment(
            adapterResult.dynamicCameraSettingsAdjustment,
            liveFrameSummary: request.liveFrameSummary,
            prerequisiteStatus: prerequisiteStatus
        )
        let capabilityGaps = capabilityGaps(
            adapterGaps: adapterResult.capabilityGaps,
            dynamicAdjustment: dynamicAdjustment
        )
        let blockingIssues = blockingIssues(
            prerequisiteStatus: prerequisiteStatus,
            liveFrameSummary: request.liveFrameSummary,
            capabilityGaps: capabilityGaps
        )
        let canCaptureBestEffort = canCaptureBestEffort(
            bestEffortAllowed: input.bestEffortAllowed,
            prerequisiteStatus: prerequisiteStatus,
            liveFrameSummary: request.liveFrameSummary
        )
        let readinessScore = score(
            prerequisiteStatus: prerequisiteStatus,
            dynamicAdjustment: dynamicAdjustment,
            liveFrameSummary: request.liveFrameSummary
        )
        let readiness = readiness(
            score: readinessScore,
            prerequisiteStatus: prerequisiteStatus,
            dynamicAdjustment: dynamicAdjustment,
            canCaptureBestEffort: canCaptureBestEffort
        )
        let cues = mergedCues(
            adapterResult.operatorCues,
            liveFrameSummary: request.liveFrameSummary,
            prerequisiteStatus: prerequisiteStatus,
            dynamicAdjustment: dynamicAdjustment,
            readiness: readiness
        )
        let capturedMetadata = capturedAffordanceMetadata(
            prerequisites: request.postCapturePrerequisites,
            prerequisiteStatus: prerequisiteStatus,
            affordanceEvaluations: affordanceEvaluations,
            canCaptureBestEffort: canCaptureBestEffort
        )
        let response = SceneRuntimeModels.EvaluateLiveFrameReadinessResponse(
            scenePlanId: request.scenePlanId,
            readiness: readiness,
            score: readinessScore,
            blockingIssues: blockingIssues,
            cues: cues,
            dynamicCameraSettingsAdjustment: dynamicAdjustment,
            capturedAffordanceMetadata: capturedMetadata,
            postCapturePrerequisiteStatus: postCapturePrerequisiteStatus(prerequisiteStatus),
            cameraSettingsUsed: nil,
            canCaptureBestEffort: canCaptureBestEffort,
            persistenceWriteIntent: [
                "liveReadinessAttempt",
                "readinessCues",
                "readinessScore",
                "cameraCapabilityStatus",
                "downgradedSettings",
                "runtimeAffordanceEvidence"
            ]
        )
        let sequence = await repository.nextLiveReadinessAttemptSequence(scenePlanId: request.scenePlanId)
        let record = LiveReadinessAttemptRecord(
            schemaVersion: input.schemaVersion,
            evaluatorVersion: LiveCoachEvaluatorSchema.currentVersion,
            liveReadinessAttemptId: LiveCoachIdFactory.liveReadinessAttemptId(
                scenePlanId: request.scenePlanId,
                sequence: sequence
            ),
            scenePlanId: request.scenePlanId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            initialCameraSettingsRecommendation: request.initialCameraSettingsRecommendation,
            liveFrameSummary: request.liveFrameSummary,
            readiness: readiness,
            readinessScore: readinessScore,
            blockingIssues: blockingIssues,
            cues: cues,
            dynamicCameraSettingsAdjustment: dynamicAdjustment,
            capturedAffordanceMetadata: capturedMetadata,
            postCapturePrerequisiteStatus: postCapturePrerequisiteStatus(prerequisiteStatus),
            runtimeAffordanceEvaluations: affordanceEvaluations,
            capabilityGaps: capabilityGaps,
            capabilityStatus: dynamicAdjustment.capabilityStatus,
            downgradedSettings: downgradedSettings(dynamicAdjustment.capabilityStatus),
            nativeAdapterCommands: adapterResult.commands,
            nativeCameraSubstitutions: adapterResult.substitutions,
            response: response
        )

        try await repository.saveLiveReadinessAttempt(record)
        return LiveCoachEvaluationResult(response: response, record: record)
    }

    private func validate(_ input: LiveCoachEvaluatorInput) throws {
        guard input.schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw LiveCoachEvaluatorError.unsupportedSchemaVersion(input.schemaVersion)
        }
        try requireNonEmpty(input.request.scenePlanId, fieldPath: "request.scenePlanId")
        try requireNonEmpty(input.request.styleProfileId, fieldPath: "request.styleProfileId")
        try requireNonEmpty(input.request.protectedSubjectSetId, fieldPath: "request.protectedSubjectSetId")
        try requireNonEmpty(
            input.request.initialCameraSettingsRecommendation.recommendationId,
            fieldPath: "request.initialCameraSettingsRecommendation.recommendationId"
        )
        if input.request.runtimeAffordanceSignals.isEmpty {
            throw LiveCoachEvaluatorError.validationFailed(
                fieldPath: "request.runtimeAffordanceSignals",
                message: "Live Coach requires runtime affordance signals."
            )
        }
        if input.request.postCapturePrerequisites.mustCaptureCorrectly.isEmpty {
            throw LiveCoachEvaluatorError.validationFailed(
                fieldPath: "request.postCapturePrerequisites.mustCaptureCorrectly",
                message: "Live Coach requires post-capture prerequisites."
            )
        }
    }

    private func requireNonEmpty(_ value: String, fieldPath: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LiveCoachEvaluatorError.validationFailed(
                fieldPath: fieldPath,
                message: "\(fieldPath) must not be empty."
            )
        }
    }

    private func prerequisiteStatuses(
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary,
        prerequisites: [SceneRuntimeModels.PostCapturePrerequisite]
    ) -> [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus] {
        var statuses: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus] = [:]
        for prerequisite in prerequisites {
            switch prerequisite {
            case .protectedSubjectsVisible:
                statuses[prerequisite] = liveFrameSummary.protectedSubjectsVisible ? .passed : .failed
            case .protectedSubjectFocus:
                statuses[prerequisite] = liveFrameSummary.protectedSubjectsVisible
                    ? focusStatus(liveFrameSummary.protectedSubjectFocusState)
                    : .failed
            case .usableFaceLight:
                statuses[prerequisite] = liveFrameSummary.protectedSubjectsVisible
                    ? faceExposureStatus(liveFrameSummary.faceExposureState)
                    : .failed
            case .naturalExpressionOrInteraction:
                statuses[prerequisite] = expressionStatus(liveFrameSummary.expressionInteractionState)
            case .cropHeadroom:
                statuses[prerequisite] = cropHeadroomStatus(liveFrameSummary.cropHeadroomState)
            }
        }

        if liveFrameSummary.lightChangedFromSceneAnalysis == true,
           statuses[.usableFaceLight] == .passed {
            statuses[.usableFaceLight] = .weak
        }
        if isReadinessTimeout(liveFrameSummary),
           statuses[.naturalExpressionOrInteraction] == .passed {
            statuses[.naturalExpressionOrInteraction] = .weak
        }
        return statuses
    }

    private func focusStatus(_ rawValue: String) -> LivePrerequisiteStatus {
        let value = rawValue.lowercased()
        if containsAny(value, ["cannot", "failed", "missing", "infeasible", "not_locked", "unlocked"]) {
            return .failed
        }
        if containsAny(value, ["soft", "searching", "weak", "almost"]) {
            return .weak
        }
        if containsAny(value, ["locked", "sharp", "ready", "focused", "available"]) {
            return .passed
        }
        return .weak
    }

    private func faceExposureStatus(_ rawValue: String) -> LivePrerequisiteStatus {
        let value = rawValue.lowercased()
        if containsAny(value, ["unusable", "clipped", "too_dark", "overexposed", "shadow_crushed"]) {
            return .failed
        }
        if containsAny(value, ["low", "shadow", "changed", "recoverable", "harsh", "uneven"]) {
            return .weak
        }
        if containsAny(value, ["usable", "balanced", "good", "protected"]) {
            return .passed
        }
        return .weak
    }

    private func expressionStatus(_ rawValue: String?) -> LivePrerequisiteStatus {
        guard let rawValue else {
            return .weak
        }
        let value = rawValue.lowercased()
        if containsAny(value, ["none", "stiff", "dead", "missing", "not_observed"]) {
            return .failed
        }
        if containsAny(value, ["neutral", "forming", "almost", "waiting", "timeout"]) {
            return .weak
        }
        if containsAny(value, ["natural", "connected", "smiling", "playful", "observed", "relaxed"]) {
            return .passed
        }
        return .weak
    }

    private func cropHeadroomStatus(_ rawValue: String) -> LivePrerequisiteStatus {
        let value = rawValue.lowercased()
        if containsAny(value, ["too_tight", "unavailable", "cut_off", "missing"]) {
            return .failed
        }
        if containsAny(value, ["tight", "low", "edge", "barely"]) {
            return .weak
        }
        if containsAny(value, ["available", "preserved", "safe", "good"]) {
            return .passed
        }
        return .weak
    }

    private func evaluateAffordances(
        _ signals: [SceneRuntimeModels.RuntimeAffordanceSignal],
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary,
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus]
    ) -> [LiveAffordanceEvaluation] {
        let detected = Set(liveFrameSummary.detectedAffordances ?? [])
        let hasDetectedAffordances = liveFrameSummary.detectedAffordances != nil
        return signals.map { signal in
            let requiredPrerequisite = prerequisite(for: signal.type)
            if hasDetectedAffordances && !detected.contains(signal.type) {
                return LiveAffordanceEvaluation(
                    signal: signal,
                    disposition: .removed,
                    reason: "Affordance was not observed in the live frame."
                )
            }
            if let requiredPrerequisite,
               let status = prerequisiteStatus[requiredPrerequisite] {
                if status == .failed {
                    return LiveAffordanceEvaluation(
                        signal: signal,
                        disposition: .removed,
                        reason: "Required live prerequisite failed."
                    )
                }
                if status == .weak {
                    return LiveAffordanceEvaluation(
                        signal: signal,
                        disposition: .downgraded,
                        reason: "Required live prerequisite is weak."
                    )
                }
            }
            if liveFrameSummary.lightChangedFromSceneAnalysis == true && isLightAffordance(signal.type) {
                return LiveAffordanceEvaluation(
                    signal: signal,
                    disposition: .downgraded,
                    reason: "Light changed from scene analysis."
                )
            }
            return LiveAffordanceEvaluation(signal: signal, disposition: .preserved, reason: nil)
        }
    }

    private func dynamicAdjustment(
        _ adapterAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment,
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary,
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus]
    ) -> SceneRuntimeModels.DynamicCameraSettingsAdjustment {
        var focus = adapterAdjustment.focus
        var exposure = adapterAdjustment.exposure
        var whiteBalance = adapterAdjustment.whiteBalance
        var zoomLens = adapterAdjustment.zoomLens
        var framing = adapterAdjustment.framing
        var capture = adapterAdjustment.capture
        var flashLowLight = adapterAdjustment.flashLowLight

        if prerequisiteStatus[.protectedSubjectsVisible] == .failed {
            focus = overriding(
                focus,
                status: .needsOperatorAdjustment,
                reason: "Protected subjects are missing from the live frame.",
                capabilityGap: "protected_subject_missing_from_live_frame",
                cue: "Move the phone until all protected subjects are visible."
            )
            framing = overriding(
                framing,
                status: .needsOperatorAdjustment,
                reason: "Framing cannot be ready while protected subjects are missing.",
                capabilityGap: "protected_subject_missing_from_live_frame",
                cue: "Move the phone until all protected subjects are visible."
            )
        } else if prerequisiteStatus[.protectedSubjectFocus] == .failed {
            focus = overriding(
                focus,
                status: mostSevere(focus.status, .needsOperatorAdjustment),
                reason: "Protected-subject focus is not ready in the live frame.",
                capabilityGap: focus.capabilityGap ?? "protected_subject_focus_not_ready",
                cue: "Hold steady and keep protected faces centered."
            )
        } else if prerequisiteStatus[.protectedSubjectFocus] == .weak {
            focus = overriding(
                focus,
                status: mostSevere(focus.status, .adjusted),
                reason: "Protected-subject focus is still settling.",
                capabilityGap: focus.capabilityGap,
                cue: "Hold steady for focus to settle."
            )
        }

        if prerequisiteStatus[.usableFaceLight] == .failed {
            exposure = overriding(
                exposure,
                status: .needsOperatorAdjustment,
                reason: "Protected-subject face light is unusable in the live frame.",
                capabilityGap: exposure.capabilityGap ?? "unusable_face_light",
                cue: "Turn protected subjects toward softer light."
            )
            flashLowLight = overriding(
                flashLowLight,
                status: mostSevere(flashLowLight.status, .needsOperatorAdjustment),
                reason: flashLowLight.reason ?? "Low-light recovery requires physical repositioning.",
                capabilityGap: flashLowLight.capabilityGap,
                cue: "Move toward brighter natural light."
            )
        } else if prerequisiteStatus[.usableFaceLight] == .weak {
            exposure = overriding(
                exposure,
                status: mostSevere(exposure.status, .adjusted),
                reason: "Protected-subject face light is weak.",
                capabilityGap: exposure.capabilityGap,
                cue: "Turn slightly toward the softer light."
            )
        }

        if liveFrameSummary.lightChangedFromSceneAnalysis == true {
            whiteBalance = overriding(
                whiteBalance,
                status: mostSevere(whiteBalance.status, .adjusted),
                reason: "Light changed since scene analysis; white balance lock should wait.",
                capabilityGap: whiteBalance.capabilityGap,
                cue: "Pause in steadier light before capture."
            )
        }

        if prerequisiteStatus[.cropHeadroom] == .failed {
            framing = overriding(
                framing,
                status: .needsOperatorAdjustment,
                reason: "Crop headroom is unavailable in the live frame.",
                capabilityGap: framing.capabilityGap ?? "crop_headroom_unavailable",
                cue: "Step back until heads and scene anchor have breathing room."
            )
            zoomLens = overriding(
                zoomLens,
                status: mostSevere(zoomLens.status, .needsOperatorAdjustment),
                reason: zoomLens.reason ?? "Operator is too close for the requested framing.",
                capabilityGap: zoomLens.capabilityGap ?? "operator_too_close",
                cue: "Step back instead of relying on tighter zoom."
            )
        } else if prerequisiteStatus[.cropHeadroom] == .weak {
            framing = overriding(
                framing,
                status: mostSevere(framing.status, .adjusted),
                reason: "Crop headroom is weak.",
                capabilityGap: framing.capabilityGap,
                cue: "Leave a little more room around heads and shoulders."
            )
        }

        if prerequisiteStatus[.naturalExpressionOrInteraction] == .failed {
            capture = overriding(
                capture,
                status: mostSevere(capture.status, .needsOperatorAdjustment),
                reason: "Natural expression or interaction is not present yet.",
                capabilityGap: capture.capabilityGap,
                cue: "Give the subjects a simple movement cue and wait for the moment."
            )
        }

        let capabilityStatus = [
            NativeCameraParameterGroup.focus.rawValue: focus.status,
            NativeCameraParameterGroup.exposure.rawValue: exposure.status,
            NativeCameraParameterGroup.whiteBalance.rawValue: whiteBalance.status,
            NativeCameraParameterGroup.zoomLens.rawValue: zoomLens.status,
            NativeCameraParameterGroup.depth.rawValue: adapterAdjustment.depth.status,
            NativeCameraParameterGroup.framing.rawValue: framing.status,
            NativeCameraParameterGroup.capture.rawValue: capture.status,
            NativeCameraParameterGroup.flashLowLight.rawValue: flashLowLight.status
        ]

        return SceneRuntimeModels.DynamicCameraSettingsAdjustment(
            focus: focus,
            exposure: exposure,
            whiteBalance: whiteBalance,
            zoomLens: zoomLens,
            depth: adapterAdjustment.depth,
            framing: framing,
            capture: capture,
            flashLowLight: flashLowLight,
            capabilityStatus: capabilityStatus
        )
    }

    private func overriding(
        _ adjustment: SceneRuntimeModels.CameraAdjustment,
        status: SceneRuntimeModels.CameraCapabilityStatus,
        reason: String?,
        capabilityGap: String?,
        cue: String?
    ) -> SceneRuntimeModels.CameraAdjustment {
        SceneRuntimeModels.CameraAdjustment(
            status: status,
            value: adjustment.value,
            reason: reason ?? adjustment.reason,
            capabilityGap: capabilityGap ?? adjustment.capabilityGap,
            lockedOn: adjustment.lockedOn,
            adjustment: adjustment.adjustment,
            meteringTarget: adjustment.meteringTarget,
            bias: adjustment.bias,
            mode: adjustment.mode,
            temperatureBias: adjustment.temperatureBias,
            portraitBlurStrength: adjustment.portraitBlurStrength,
            depthDataDelivery: adjustment.depthDataDelivery,
            portraitEffectsMatteDelivery: adjustment.portraitEffectsMatteDelivery,
            lensUsed: adjustment.lensUsed,
            zoomFactor: adjustment.zoomFactor,
            cue: cue ?? adjustment.cue,
            shootWide: adjustment.shootWide,
            burstCount: adjustment.burstCount,
            highestPracticalResolution: adjustment.highestPracticalResolution,
            photoQualityPrioritization: adjustment.photoQualityPrioritization,
            captureResponsiveness: adjustment.captureResponsiveness,
            flashMode: adjustment.flashMode,
            torchMode: adjustment.torchMode
        )
    }

    private func score(
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus],
        dynamicAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment,
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary
    ) -> Double {
        var score = 1.0
        for status in prerequisiteStatus.values {
            switch status {
            case .passed:
                break
            case .weak:
                score -= 0.12
            case .failed:
                score -= 0.27
            }
        }
        for status in dynamicAdjustment.capabilityStatus.values {
            switch status {
            case .applied, .pending:
                break
            case .adjusted:
                score -= 0.03
            case .needsOperatorAdjustment:
                score -= 0.07
            case .unavailable:
                score -= 0.10
            }
        }
        if liveFrameSummary.lightChangedFromSceneAnalysis == true {
            score -= 0.08
        }
        if isReadinessTimeout(liveFrameSummary) {
            score -= 0.08
        }
        return rounded(min(max(score, 0), 1))
    }

    private func readiness(
        score: Double,
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus],
        dynamicAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment,
        canCaptureBestEffort: Bool
    ) -> SceneRuntimeModels.Readiness {
        if canCaptureBestEffort {
            return .bestEffort
        }
        if prerequisiteStatus.values.contains(.failed) {
            return .blocked
        }
        if dynamicAdjustment.capabilityStatus.values.contains(.needsOperatorAdjustment) {
            return .coaching
        }
        if score >= LiveCoachEvaluatorSchema.readyThreshold,
           !prerequisiteStatus.values.contains(.weak) {
            return .ready
        }
        if score >= LiveCoachEvaluatorSchema.almostReadyThreshold {
            return .almostReady
        }
        if score >= LiveCoachEvaluatorSchema.coachingThreshold {
            return .coaching
        }
        return .blocked
    }

    private func canCaptureBestEffort(
        bestEffortAllowed: Bool,
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus],
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary
    ) -> Bool {
        guard bestEffortAllowed else {
            return false
        }
        if prerequisiteStatus[.protectedSubjectsVisible] == .failed {
            return false
        }
        if prerequisiteStatus[.protectedSubjectFocus] == .failed {
            return false
        }
        if prerequisiteStatus[.usableFaceLight] == .failed {
            return false
        }
        if prerequisiteStatus[.cropHeadroom] == .failed {
            return false
        }
        return prerequisiteStatus.values.contains(.weak) || isReadinessTimeout(liveFrameSummary)
    }

    private func blockingIssues(
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus],
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary,
        capabilityGaps: [String]
    ) -> [String] {
        var issues: [String] = []
        for (prerequisite, status) in prerequisiteStatus {
            if status == .failed {
                issues.append(prerequisite.rawValue)
            }
        }
        if liveFrameSummary.lightChangedFromSceneAnalysis == true {
            issues.append("light_changed_since_scene_analysis")
        }
        if isReadinessTimeout(liveFrameSummary) {
            issues.append("readiness_timeout")
        }
        issues.append(contentsOf: capabilityGaps)
        return Array(Set(issues)).sorted()
    }

    private func capabilityGaps(
        adapterGaps: [String],
        dynamicAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    ) -> [String] {
        let liveGaps = [
            dynamicAdjustment.focus.capabilityGap,
            dynamicAdjustment.exposure.capabilityGap,
            dynamicAdjustment.whiteBalance.capabilityGap,
            dynamicAdjustment.zoomLens.capabilityGap,
            dynamicAdjustment.depth.capabilityGap,
            dynamicAdjustment.framing.capabilityGap,
            dynamicAdjustment.capture.capabilityGap,
            dynamicAdjustment.flashLowLight.capabilityGap
        ].compactMap { $0 }
        return Array(Set(adapterGaps + liveGaps)).sorted()
    }

    private func downgradedSettings(
        _ capabilityStatus: [String: SceneRuntimeModels.CameraCapabilityStatus]
    ) -> [String: SceneRuntimeModels.CameraCapabilityStatus] {
        capabilityStatus.filter { _, status in
            status == .adjusted || status == .unavailable || status == .needsOperatorAdjustment
        }
    }

    private func mergedCues(
        _ adapterCues: [SceneRuntimeModels.CoachingCue],
        liveFrameSummary: SceneRuntimeModels.LiveFrameSummary,
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus],
        dynamicAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment,
        readiness: SceneRuntimeModels.Readiness
    ) -> [SceneRuntimeModels.CoachingCue] {
        var cues = adapterCues

        if prerequisiteStatus[.protectedSubjectsVisible] == .failed {
            cues.append(cue("operator", "Move the phone until all protected subjects are visible."))
        }
        if prerequisiteStatus[.protectedSubjectFocus] == .failed || prerequisiteStatus[.protectedSubjectFocus] == .weak {
            cues.append(cue("operator", "Hold steady with protected faces centered."))
        }
        if prerequisiteStatus[.usableFaceLight] == .failed || prerequisiteStatus[.usableFaceLight] == .weak {
            cues.append(cue("operator", "Turn protected subjects toward softer light."))
            cues.append(cue("subjects", "Face gently toward the brighter side."))
        }
        if prerequisiteStatus[.cropHeadroom] == .failed || prerequisiteStatus[.cropHeadroom] == .weak {
            cues.append(cue("operator", "Step back until heads and scene anchor have breathing room."))
        }
        if prerequisiteStatus[.naturalExpressionOrInteraction] == .failed || prerequisiteStatus[.naturalExpressionOrInteraction] == .weak {
            cues.append(cue("subjects", "Walk together slowly and keep talking to each other."))
            cues.append(cue("operator", "Wait for the relaxed moment before capture."))
        }
        if liveFrameSummary.lightChangedFromSceneAnalysis == true {
            cues.append(cue("operator", "Pause in steadier light before capture."))
        }
        for adjustment in [
            dynamicAdjustment.focus,
            dynamicAdjustment.exposure,
            dynamicAdjustment.whiteBalance,
            dynamicAdjustment.zoomLens,
            dynamicAdjustment.framing,
            dynamicAdjustment.capture,
            dynamicAdjustment.flashLowLight
        ] {
            if let cueMessage = adjustment.cue,
               adjustment.status == .needsOperatorAdjustment {
                cues.append(cue("operator", cueMessage))
            }
        }
        if readiness == .ready {
            cues.append(cue("operator", "Hold steady and capture now."))
        }
        return uniqueCues(cues)
    }

    private func capturedAffordanceMetadata(
        prerequisites: SceneRuntimeModels.PostCapturePrerequisites,
        prerequisiteStatus: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus],
        affordanceEvaluations: [LiveAffordanceEvaluation],
        canCaptureBestEffort: Bool
    ) -> SceneRuntimeModels.CapturedAffordanceMetadata {
        let rimEvaluation = affordanceEvaluations.first { $0.signal.type == .rimHairEdgeLight }
        let focusReady = prerequisiteStatus[.protectedSubjectFocus] == .passed
        let faceLightUsable = prerequisiteStatus[.usableFaceLight] == .passed
        let cropReady = prerequisiteStatus[.cropHeadroom] == .passed
        let fineTuneEligible = focusReady && faceLightUsable && prerequisiteStatus[.cropHeadroom] != .failed
            ? (prerequisites.canFineTuneLater ?? [])
            : []

        let weakPrerequisites = prerequisiteStatus
            .filter { _, status in status == .weak || (canCaptureBestEffort && status == .failed) }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }

        return SceneRuntimeModels.CapturedAffordanceMetadata(
            protectedSubjectFocusReady: focusReady,
            faceExposureUsable: faceLightUsable,
            rimHairEdgeLightPreserved: rimEvaluation.map { $0.disposition == .preserved },
            naturalExpressionOrInteractionObserved: prerequisiteStatus[.naturalExpressionOrInteraction] == .passed,
            cropHeadroomPreserved: cropReady,
            postCaptureFineTuneEligible: fineTuneEligible,
            weakPrerequisites: weakPrerequisites.isEmpty ? nil : weakPrerequisites
        )
    }

    private func postCapturePrerequisiteStatus(
        _ statuses: [SceneRuntimeModels.PostCapturePrerequisite: LivePrerequisiteStatus]
    ) -> [String: String] {
        Dictionary(uniqueKeysWithValues: statuses.map { ($0.key.rawValue, $0.value.rawValue) })
    }

    private func prerequisite(
        for signal: SceneRuntimeModels.RuntimeAffordanceSignalType
    ) -> SceneRuntimeModels.PostCapturePrerequisite? {
        switch signal {
        case .softFrontLight, .softSideLight, .rimHairEdgeLight, .dramaticSideLightUsable:
            return .usableFaceLight
        case .cropHeadroomAvailable:
            return .cropHeadroom
        case .naturalMotionOpportunity, .relationshipInteractionOpportunity:
            return .naturalExpressionOrInteraction
        case .focusDepthOpportunity:
            return .protectedSubjectFocus
        case .projectedShadowPattern, .classicLocationAnchor, .openSpaceAnchor, .architecturalAnchor:
            return nil
        }
    }

    private func isLightAffordance(_ signal: SceneRuntimeModels.RuntimeAffordanceSignalType) -> Bool {
        switch signal {
        case .softFrontLight, .softSideLight, .rimHairEdgeLight, .projectedShadowPattern, .dramaticSideLightUsable:
            return true
        case .classicLocationAnchor, .openSpaceAnchor, .architecturalAnchor, .cropHeadroomAvailable,
             .naturalMotionOpportunity, .relationshipInteractionOpportunity, .focusDepthOpportunity:
            return false
        }
    }

    private func isReadinessTimeout(_ liveFrameSummary: SceneRuntimeModels.LiveFrameSummary) -> Bool {
        containsAny(liveFrameSummary.expressionInteractionState?.lowercased() ?? "", ["timeout"])
            || containsAny(liveFrameSummary.protectedSubjectFocusState.lowercased(), ["timeout"])
            || containsAny(liveFrameSummary.faceExposureState.lowercased(), ["timeout"])
            || containsAny(liveFrameSummary.cropHeadroomState.lowercased(), ["timeout"])
    }

    private func mostSevere(
        _ lhs: SceneRuntimeModels.CameraCapabilityStatus,
        _ rhs: SceneRuntimeModels.CameraCapabilityStatus
    ) -> SceneRuntimeModels.CameraCapabilityStatus {
        severity(lhs) >= severity(rhs) ? lhs : rhs
    }

    private func severity(_ status: SceneRuntimeModels.CameraCapabilityStatus) -> Int {
        switch status {
        case .pending:
            return 0
        case .applied:
            return 1
        case .adjusted:
            return 2
        case .needsOperatorAdjustment:
            return 3
        case .unavailable:
            return 4
        }
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private func cue(_ target: String, _ message: String) -> SceneRuntimeModels.CoachingCue {
        SceneRuntimeModels.CoachingCue(target: target, message: message)
    }

    private func uniqueCues(_ cues: [SceneRuntimeModels.CoachingCue]) -> [SceneRuntimeModels.CoachingCue] {
        var seen = Set<String>()
        var unique: [SceneRuntimeModels.CoachingCue] = []
        for cue in cues {
            let key = "\(cue.target)|\(cue.message)"
            if seen.insert(key).inserted {
                unique.append(cue)
            }
        }
        return unique
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}

enum LiveCoachIdFactory {
    static func liveReadinessAttemptId(scenePlanId: String, sequence: Int) -> String {
        "live_readiness_attempt_\(sanitize(scenePlanId))_\(String(format: "%03d", sequence))"
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
