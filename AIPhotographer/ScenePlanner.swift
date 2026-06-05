import Foundation

enum ScenePlannerSchema {
    static let currentPlannerVersion = "2026-06-04.scene-planner.v1"
    static let lowConfidenceBestEffortThreshold = 0.45
    static let highConfidenceStyleRuleThreshold = 0.80
}

enum ScenePlannerError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case validationFailed(fieldPath: String, message: String)
}

enum RuntimeStylePreferenceKind: String, Codable, Equatable {
    case exactSubjectPosition = "exact_subject_position"
    case exactSubjectScale = "exact_subject_scale"
    case exactGesture = "exact_gesture"
    case colorTone = "color_tone"
    case contrast = "contrast"
    case crispness = "crispness"
    case backgroundReadability = "background_readability"
    case emotionalTemperature = "emotional_temperature"
    case lightTolerance = "light_tolerance"

    var isExactCompositionRule: Bool {
        self == .exactSubjectPosition || self == .exactSubjectScale || self == .exactGesture
    }
}

struct RuntimeStylePreferenceEvidence: Codable, Equatable {
    let kind: RuntimeStylePreferenceKind
    let confidence: Double
    let matchScore: Double
    let modeConditioned: Bool
    let supportedByProfile: Bool
    let requestedAsHardRule: Bool
    let description: String?

    init(
        kind: RuntimeStylePreferenceKind,
        confidence: Double,
        matchScore: Double,
        modeConditioned: Bool = false,
        supportedByProfile: Bool = true,
        requestedAsHardRule: Bool = false,
        description: String? = nil
    ) {
        self.kind = kind
        self.confidence = RuntimeDetectorEvidence.clampedConfidence(confidence)
        self.matchScore = RuntimeDetectorEvidence.clampedConfidence(matchScore)
        self.modeConditioned = modeConditioned
        self.supportedByProfile = supportedByProfile
        self.requestedAsHardRule = requestedAsHardRule
        self.description = description
    }
}

struct ScenePlannerScoringWeights: Codable, Equatable {
    static let lightFirstDefault = ScenePlannerScoringWeights(
        faceLight: 0.36,
        focus: 0.22,
        expressionInteraction: 0.14,
        cropHeadroom: 0.12,
        anchors: 0.08,
        styleTasteDeltas: 0.08
    )

    let faceLight: Double
    let focus: Double
    let expressionInteraction: Double
    let cropHeadroom: Double
    let anchors: Double
    let styleTasteDeltas: Double
}

struct ScenePlanGuidance: Codable, Equatable {
    let standPoint: SceneRuntimeModels.LabeledDescription
    let subjectPosition: SceneRuntimeModels.SubjectPosition
    let operatorPosition: SceneRuntimeModels.OperatorPosition
    let facingDirection: SceneRuntimeModels.FacingDirection
    let roughFraming: SceneRuntimeModels.RoughFraming
    let coachingCues: [SceneRuntimeModels.CoachingCue]
}

struct ScenePlanCandidate: Codable, Equatable {
    let candidateId: String
    let label: String
    let detectorEvidence: [RuntimeDetectorEvidence]
    let detectedPersonIds: [String]
    let isCluttered: Bool
    let guidance: ScenePlanGuidance
    let stylePreferenceEvidence: [RuntimeStylePreferenceEvidence]
}

struct ScenePlanningInput: Codable, Equatable {
    let schemaVersion: String
    let sceneInputId: String
    let sceneAnalysisId: String
    let styleProfileId: String
    let protectedSubjectSet: SceneRuntimeModels.ProtectedSubjectSet
    let sceneInputQualityContext: SceneRuntimeModels.SceneInputQualityContext
    let candidates: [ScenePlanCandidate]
    let styleProfileConfidence: [String: Double]
    let analysisTimedOut: Bool
    let scoringWeights: ScenePlannerScoringWeights

    init(
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion,
        sceneInputId: String,
        sceneAnalysisId: String,
        styleProfileId: String,
        protectedSubjectSet: SceneRuntimeModels.ProtectedSubjectSet,
        sceneInputQualityContext: SceneRuntimeModels.SceneInputQualityContext,
        candidates: [ScenePlanCandidate],
        styleProfileConfidence: [String: Double] = [:],
        analysisTimedOut: Bool = false,
        scoringWeights: ScenePlannerScoringWeights = .lightFirstDefault
    ) {
        self.schemaVersion = schemaVersion
        self.sceneInputId = sceneInputId
        self.sceneAnalysisId = sceneAnalysisId
        self.styleProfileId = styleProfileId
        self.protectedSubjectSet = protectedSubjectSet
        self.sceneInputQualityContext = sceneInputQualityContext
        self.candidates = candidates
        self.styleProfileConfidence = styleProfileConfidence
        self.analysisTimedOut = analysisTimedOut
        self.scoringWeights = scoringWeights
    }
}

struct ScenePlanCandidateScore: Codable, Equatable {
    let candidateId: String
    let totalScore: Double
    let faceLightScore: Double
    let focusScore: Double
    let expressionInteractionScore: Double
    let cropHeadroomScore: Double
    let anchorScore: Double
    let styleTasteDeltaScore: Double
    let protectedSubjectIdsUsed: [String]
    let backgroundPersonIds: [String]
    let selectedAffordances: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let rejectedStyleRules: [RuntimeStylePreferenceKind]
    let failureNotes: [String]
}

struct SceneAnalysisRecord: Codable, Equatable {
    let schemaVersion: String
    let plannerVersion: String
    let sceneInputId: String
    let sceneAnalysisId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let candidateScores: [ScenePlanCandidateScore]
    let selectedCandidateId: String?
    let selectedAffordances: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let professionalHappyMomentAssessment: SceneRuntimeModels.ProfessionalHappyMomentAssessment
    let fallbackReason: SceneRuntimeModels.ScenePlanFallback?
    let confidence: Double
}

struct ScenePlanDraft: Codable, Equatable {
    let scenePlanId: String
    let sceneAnalysisId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let sceneMatchType: SceneRuntimeModels.SceneMatchType
    let selectedCandidateId: String?
    let confidence: Double
    let selectedAffordances: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let protectedSubjectIdsUsed: [String]
    let backgroundPersonIds: [String]
    let rejectedStyleRules: [RuntimeStylePreferenceKind]
    let guidance: ScenePlanGuidance?
    let fallbackReason: SceneRuntimeModels.ScenePlanFallback?
}

struct ScenePlanRecord: Codable, Equatable {
    let schemaVersion: String
    let plannerVersion: String
    let scenePlan: ScenePlanDraft
}

struct ScenePlanningResult: Codable, Equatable {
    let sceneAnalysis: SceneAnalysisRecord
    let scenePlan: ScenePlanDraft
    let rankedCandidates: [ScenePlanCandidateScore]
    let fallbackReason: SceneRuntimeModels.ScenePlanFallback?
}

protocol ScenePlannerRepository: AnyObject {
    func saveSceneAnalysis(_ record: SceneAnalysisRecord) async throws
    func saveScenePlan(_ record: ScenePlanRecord) async throws
    func sceneAnalysisRecord(sceneAnalysisId: String) async -> SceneAnalysisRecord?
    func scenePlanRecord(scenePlanId: String) async -> ScenePlanRecord?
}

final class InMemoryScenePlannerRepository: ScenePlannerRepository {
    private var sceneAnalysisRecords: [String: SceneAnalysisRecord] = [:]
    private var scenePlanRecords: [String: ScenePlanRecord] = [:]

    func saveSceneAnalysis(_ record: SceneAnalysisRecord) async throws {
        sceneAnalysisRecords[record.sceneAnalysisId] = record
    }

    func saveScenePlan(_ record: ScenePlanRecord) async throws {
        scenePlanRecords[record.scenePlan.scenePlanId] = record
    }

    func sceneAnalysisRecord(sceneAnalysisId: String) async -> SceneAnalysisRecord? {
        sceneAnalysisRecords[sceneAnalysisId]
    }

    func scenePlanRecord(scenePlanId: String) async -> ScenePlanRecord? {
        scenePlanRecords[scenePlanId]
    }
}

struct ScenePlanner {
    let repository: ScenePlannerRepository

    init(repository: ScenePlannerRepository = InMemoryScenePlannerRepository()) {
        self.repository = repository
    }

    func plan(_ input: ScenePlanningInput) async throws -> ScenePlanningResult {
        try validate(input)

        let protectedSubjectIds = Set(
            input.protectedSubjectSet.subjects
                .filter { $0.includedInSubjectCount && $0.facingCamera }
                .map(\.subjectId)
        )
        let candidateScores = input.candidates
            .map { score($0, input: input, protectedSubjectIds: protectedSubjectIds) }
            .sorted(by: deterministicRank)
        let selectedScore = candidateScores.first
        let selectedCandidate = selectedScore.flatMap { score in
            input.candidates.first { $0.candidateId == score.candidateId }
        }
        let fallbackReason = fallbackReason(
            input: input,
            candidateScores: candidateScores,
            selectedScore: selectedScore
        )
        let selectedAffordances = selectedScore?.selectedAffordances ?? []
        let confidence = adjustedConfidence(
            selectedScore: selectedScore,
            fallbackReason: fallbackReason,
            analysisTimedOut: input.analysisTimedOut
        )
        let assessment = professionalHappyMomentAssessment(
            selectedScore: selectedScore,
            fallbackReason: fallbackReason
        )
        let scenePlanId = ScenePlannerIdFactory.scenePlanId(sceneAnalysisId: input.sceneAnalysisId)
        let sceneMatchType: SceneRuntimeModels.SceneMatchType = fallbackReason == nil
            ? .styleSynthesis
            : .bestEffortFallback
        let scenePlan = ScenePlanDraft(
            scenePlanId: scenePlanId,
            sceneAnalysisId: input.sceneAnalysisId,
            styleProfileId: input.styleProfileId,
            protectedSubjectSetId: input.protectedSubjectSet.protectedSubjectSetId,
            sceneMatchType: sceneMatchType,
            selectedCandidateId: selectedScore?.candidateId,
            confidence: confidence,
            selectedAffordances: selectedAffordances,
            protectedSubjectIdsUsed: selectedScore?.protectedSubjectIdsUsed ?? [],
            backgroundPersonIds: selectedScore?.backgroundPersonIds ?? [],
            rejectedStyleRules: selectedScore?.rejectedStyleRules ?? [],
            guidance: selectedCandidate?.guidance,
            fallbackReason: fallbackReason
        )
        let sceneAnalysis = SceneAnalysisRecord(
            schemaVersion: input.schemaVersion,
            plannerVersion: ScenePlannerSchema.currentPlannerVersion,
            sceneInputId: input.sceneInputId,
            sceneAnalysisId: input.sceneAnalysisId,
            styleProfileId: input.styleProfileId,
            protectedSubjectSetId: input.protectedSubjectSet.protectedSubjectSetId,
            candidateScores: candidateScores,
            selectedCandidateId: selectedScore?.candidateId,
            selectedAffordances: selectedAffordances,
            professionalHappyMomentAssessment: assessment,
            fallbackReason: fallbackReason,
            confidence: confidence
        )
        let planRecord = ScenePlanRecord(
            schemaVersion: input.schemaVersion,
            plannerVersion: ScenePlannerSchema.currentPlannerVersion,
            scenePlan: scenePlan
        )

        try await repository.saveSceneAnalysis(sceneAnalysis)
        try await repository.saveScenePlan(planRecord)

        return ScenePlanningResult(
            sceneAnalysis: sceneAnalysis,
            scenePlan: scenePlan,
            rankedCandidates: candidateScores,
            fallbackReason: fallbackReason
        )
    }

    private func validate(_ input: ScenePlanningInput) throws {
        guard input.schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw ScenePlannerError.unsupportedSchemaVersion(input.schemaVersion)
        }
        try requireNonEmpty(input.sceneInputId, fieldPath: "sceneInputId")
        try requireNonEmpty(input.sceneAnalysisId, fieldPath: "sceneAnalysisId")
        try requireNonEmpty(input.styleProfileId, fieldPath: "styleProfileId")
        try requireNonEmpty(input.protectedSubjectSet.protectedSubjectSetId, fieldPath: "protectedSubjectSet.protectedSubjectSetId")
    }

    private func requireNonEmpty(_ value: String, fieldPath: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ScenePlannerError.validationFailed(
                fieldPath: fieldPath,
                message: "\(fieldPath) must not be empty."
            )
        }
    }

    private func score(
        _ candidate: ScenePlanCandidate,
        input: ScenePlanningInput,
        protectedSubjectIds: Set<String>
    ) -> ScenePlanCandidateScore {
        let evidenceByKind = Dictionary(grouping: candidate.detectorEvidence, by: \.detectorKind)
        let selectedAffordances = candidate.detectorEvidence
            .filter { $0.outcome == .supported }
            .flatMap(\.runtimeAffordanceSignalEvidence)
        let detectedPersonIds = Set(candidate.detectedPersonIds)
        let protectedIdsUsed = protectedSubjectIds.intersection(detectedPersonIds).sorted()
        let backgroundIds = detectedPersonIds.subtracting(protectedSubjectIds).sorted()

        var failureNotes = candidate.detectorEvidence.flatMap(\.failureNotes)
        if protectedIdsUsed.isEmpty {
            failureNotes.append("protected_subject_missing_from_candidate")
        }
        if candidate.isCluttered {
            failureNotes.append("cluttered_scene")
        }

        let faceLightScore = supportedConfidence(evidenceByKind[.protectedSubjectFaceLightFeasibility])
        let focusScore = supportedConfidence(evidenceByKind[.focusDepthOpportunity])
        let expressionScore = supportedConfidence(evidenceByKind[.naturalMotionInteraction])
        let cropScore = supportedConfidence(evidenceByKind[.cropHeadroom])
        let anchorScore = supportedConfidence(evidenceByKind[.sceneAnchor])
        let styleScoreResult = styleTasteDeltaScore(
            candidate.stylePreferenceEvidence,
            styleProfileConfidence: input.styleProfileConfidence
        )
        let candidatePenalty = candidate.isCluttered ? 0.12 : 0
        let subjectPenalty = protectedIdsUsed.isEmpty ? 0.30 : 0
        let total = max(
            0,
            (faceLightScore * input.scoringWeights.faceLight)
                + (focusScore * input.scoringWeights.focus)
                + (expressionScore * input.scoringWeights.expressionInteraction)
                + (cropScore * input.scoringWeights.cropHeadroom)
                + (anchorScore * input.scoringWeights.anchors)
                + (styleScoreResult.score * input.scoringWeights.styleTasteDeltas)
                - candidatePenalty
                - subjectPenalty
        )

        return ScenePlanCandidateScore(
            candidateId: candidate.candidateId,
            totalScore: rounded(total),
            faceLightScore: rounded(faceLightScore),
            focusScore: rounded(focusScore),
            expressionInteractionScore: rounded(expressionScore),
            cropHeadroomScore: rounded(cropScore),
            anchorScore: rounded(anchorScore),
            styleTasteDeltaScore: rounded(styleScoreResult.score),
            protectedSubjectIdsUsed: protectedIdsUsed,
            backgroundPersonIds: backgroundIds,
            selectedAffordances: selectedAffordances,
            rejectedStyleRules: styleScoreResult.rejectedRules,
            failureNotes: Array(Set(failureNotes)).sorted()
        )
    }

    private func supportedConfidence(_ evidence: [RuntimeDetectorEvidence]?) -> Double {
        guard let evidence else {
            return 0
        }
        return evidence
            .filter { $0.outcome == .supported }
            .map(\.confidence)
            .max() ?? 0
    }

    private func styleTasteDeltaScore(
        _ preferences: [RuntimeStylePreferenceEvidence],
        styleProfileConfidence: [String: Double]
    ) -> (score: Double, rejectedRules: [RuntimeStylePreferenceKind]) {
        var acceptedScores: [Double] = []
        var rejectedRules: [RuntimeStylePreferenceKind] = []

        for preference in preferences {
            let profileConfidence = RuntimeDetectorEvidence.clampedConfidence(
                styleProfileConfidence[preference.kind.rawValue] ?? preference.confidence
            )
            if preference.kind.isExactCompositionRule {
                let exactRuleSupported = preference.modeConditioned
                    && preference.supportedByProfile
                    && preference.confidence >= ScenePlannerSchema.highConfidenceStyleRuleThreshold
                    && profileConfidence >= ScenePlannerSchema.highConfidenceStyleRuleThreshold
                if !exactRuleSupported {
                    rejectedRules.append(preference.kind)
                    continue
                }
            }
            guard preference.supportedByProfile else {
                rejectedRules.append(preference.kind)
                continue
            }
            acceptedScores.append(preference.matchScore * preference.confidence * profileConfidence)
        }

        guard !acceptedScores.isEmpty else {
            return (0, Array(Set(rejectedRules)).sorted { $0.rawValue < $1.rawValue })
        }
        let score = acceptedScores.reduce(0, +) / Double(acceptedScores.count)
        return (RuntimeDetectorEvidence.clampedConfidence(score), Array(Set(rejectedRules)).sorted { $0.rawValue < $1.rawValue })
    }

    private func deterministicRank(
        _ lhs: ScenePlanCandidateScore,
        _ rhs: ScenePlanCandidateScore
    ) -> Bool {
        if lhs.totalScore != rhs.totalScore {
            return lhs.totalScore > rhs.totalScore
        }
        if lhs.faceLightScore != rhs.faceLightScore {
            return lhs.faceLightScore > rhs.faceLightScore
        }
        if lhs.focusScore != rhs.focusScore {
            return lhs.focusScore > rhs.focusScore
        }
        return lhs.candidateId < rhs.candidateId
    }

    private func fallbackReason(
        input: ScenePlanningInput,
        candidateScores: [ScenePlanCandidateScore],
        selectedScore: ScenePlanCandidateScore?
    ) -> SceneRuntimeModels.ScenePlanFallback? {
        if input.analysisTimedOut {
            return fallback(
                type: "analysis_timeout",
                message: "Scene analysis timed out before all detector evidence was complete.",
                nextAction: "Use the strongest available light candidate or rescan if time allows.",
                canContinueBestEffort: selectedScore != nil
            )
        }
        guard !candidateScores.isEmpty else {
            return fallback(
                type: "no_usable_scene_candidate",
                message: "No scene candidate was available for planning.",
                nextAction: "Scan a wider area with the protected subjects still in view.",
                canContinueBestEffort: false
            )
        }
        if candidateScores.allSatisfy({ $0.failureNotes.contains("cluttered_scene") }) {
            return fallback(
                type: "cluttered_scene",
                message: "All candidate positions are too cluttered to preserve subjects and scene context reliably.",
                nextAction: "Step toward a cleaner background or wider open space.",
                canContinueBestEffort: false
            )
        }
        if candidateScores.allSatisfy({ $0.protectedSubjectIdsUsed.isEmpty }) {
            return fallback(
                type: "no_usable_scene_candidate",
                message: "No candidate contains the calibrated protected subjects.",
                nextAction: "Bring the protected subjects back into the scan and retry.",
                canContinueBestEffort: false
            )
        }
        if candidateScores.allSatisfy({ $0.faceLightScore == 0 }) {
            return fallback(
                type: "bad_light",
                message: "No candidate has usable protected-subject face light.",
                nextAction: "Turn the subjects toward softer front or side-front light and rescan.",
                canContinueBestEffort: false
            )
        }
        if let selectedScore, !selectedScore.rejectedStyleRules.isEmpty,
           selectedScore.styleTasteDeltaScore == 0,
           selectedScore.failureNotes.contains("unsupported_style_match") || selectedScore.rejectedStyleRules.count >= 3 {
            return fallback(
                type: "unsupported_style_match",
                message: "Exact style rules were not supported strongly enough by the precomputed profile.",
                nextAction: "Continue with the light-first plan and treat style as a soft taste delta.",
                canContinueBestEffort: true
            )
        }
        if let selectedScore, selectedScore.totalScore < ScenePlannerSchema.lowConfidenceBestEffortThreshold {
            return fallback(
                type: "low_confidence_best_effort",
                message: "Planner confidence is low, but a best-effort scene plan can continue.",
                nextAction: "Follow the simplest light and framing cues, or rescan for a stronger scene.",
                canContinueBestEffort: true
            )
        }
        return nil
    }

    private func adjustedConfidence(
        selectedScore: ScenePlanCandidateScore?,
        fallbackReason: SceneRuntimeModels.ScenePlanFallback?,
        analysisTimedOut: Bool
    ) -> Double {
        guard let selectedScore else {
            return 0
        }
        var confidence = selectedScore.totalScore
        if fallbackReason != nil {
            confidence *= 0.80
        }
        if analysisTimedOut {
            confidence *= 0.75
        }
        return rounded(RuntimeDetectorEvidence.clampedConfidence(confidence))
    }

    private func professionalHappyMomentAssessment(
        selectedScore: ScenePlanCandidateScore?,
        fallbackReason: SceneRuntimeModels.ScenePlanFallback?
    ) -> SceneRuntimeModels.ProfessionalHappyMomentAssessment {
        let risks = selectedScore?.failureNotes ?? []
        return SceneRuntimeModels.ProfessionalHappyMomentAssessment(
            faceLightUsable: (selectedScore?.faceLightScore ?? 0) > 0,
            naturalExpressionOpportunity: (selectedScore?.expressionInteractionScore ?? 0) > 0,
            relationshipInteractionOpportunity: (selectedScore?.selectedAffordances.contains { $0.type == .relationshipInteractionOpportunity } ?? false),
            protectedSubjectFocusFeasible: (selectedScore?.focusScore ?? 0) > 0,
            cropHeadroomFeasible: (selectedScore?.cropHeadroomScore ?? 0) > 0,
            unrecoverableRisks: risks.isEmpty && fallbackReason == nil ? nil : risks + [fallbackReason?.type].compactMap { $0 }
        )
    }

    private func fallback(
        type: String,
        message: String,
        nextAction: String,
        canContinueBestEffort: Bool
    ) -> SceneRuntimeModels.ScenePlanFallback {
        SceneRuntimeModels.ScenePlanFallback(
            type: type,
            message: message,
            nextAction: nextAction,
            canContinueBestEffort: canContinueBestEffort
        )
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}

enum ScenePlannerIdFactory {
    static func scenePlanId(sceneAnalysisId: String) -> String {
        "scene_plan_\(sanitize(sceneAnalysisId.replacingOccurrences(of: "scene_analysis_", with: "")))"
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
