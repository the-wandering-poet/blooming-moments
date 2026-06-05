import Foundation

enum SceneRuntimeDetectorSchema {
    static let currentAffordanceSignalVersion = "2026-06-04.runtime-affordance.v1"
    static let minimumSignalConfidence = 0.60
}

enum RuntimeDetectorKind: String, Codable, Equatable, CaseIterable {
    case lightDirectionQuality = "light_direction_quality"
    case protectedSubjectFaceLightFeasibility = "protected_subject_face_light_feasibility"
    case rimHairEdgeLight = "rim_hair_edge_light"
    case projectedShadowPattern = "projected_shadow_pattern"
    case sceneAnchor = "scene_anchor"
    case cropHeadroom = "crop_headroom"
    case naturalMotionInteraction = "natural_motion_interaction"
    case focusDepthOpportunity = "focus_depth_opportunity"
}

enum RuntimeDetectorOutcome: String, Codable, Equatable {
    case supported
    case unsupported
    case lowConfidence = "low_confidence"
    case unknown
}

enum RuntimeLightDirection: String, Codable, Equatable {
    case front
    case sideFront = "side_front"
    case side
    case back
    case mixed
    case unknown
}

enum RuntimeLightQuality: String, Codable, Equatable {
    case soft
    case dramatic
    case harsh
    case low
    case unknown
}

enum RuntimeSceneAnchor: String, Codable, Equatable {
    case classicLocation = "classic_location"
    case openSpace = "open_space"
    case architecture
}

struct RuntimeDetectorModelMetadata: Codable, Equatable {
    let provider: String
    let modelId: String
    let routingProfile: String
    let promptSchemaVersion: String
    let latencyMs: Int?
    let qualityGateResult: String?
    let estimatedCost: Double?
}

struct RuntimeDetectorObservationSet: Codable, Equatable {
    let lightDirection: RuntimeLightDirection?
    let lightQuality: RuntimeLightQuality?
    let protectedSubjectFaceLightUsable: Bool?
    let faceLightConfidence: Double?
    let dramaticSideLightUsable: Bool?
    let hasRimHairEdgeLight: Bool?
    let hasProjectedShadowPattern: Bool?
    let sceneAnchors: [RuntimeSceneAnchor]?
    let openSpaceAvailable: Bool?
    let cropHeadroomAvailable: Bool?
    let naturalMotionOpportunity: Bool?
    let relationshipInteractionOpportunity: Bool?
    let focusDepthFeasible: Bool?
    let focusDepthConfidence: Double?

    init(
        lightDirection: RuntimeLightDirection? = nil,
        lightQuality: RuntimeLightQuality? = nil,
        protectedSubjectFaceLightUsable: Bool? = nil,
        faceLightConfidence: Double? = nil,
        dramaticSideLightUsable: Bool? = nil,
        hasRimHairEdgeLight: Bool? = nil,
        hasProjectedShadowPattern: Bool? = nil,
        sceneAnchors: [RuntimeSceneAnchor]? = nil,
        openSpaceAvailable: Bool? = nil,
        cropHeadroomAvailable: Bool? = nil,
        naturalMotionOpportunity: Bool? = nil,
        relationshipInteractionOpportunity: Bool? = nil,
        focusDepthFeasible: Bool? = nil,
        focusDepthConfidence: Double? = nil
    ) {
        self.lightDirection = lightDirection
        self.lightQuality = lightQuality
        self.protectedSubjectFaceLightUsable = protectedSubjectFaceLightUsable
        self.faceLightConfidence = faceLightConfidence
        self.dramaticSideLightUsable = dramaticSideLightUsable
        self.hasRimHairEdgeLight = hasRimHairEdgeLight
        self.hasProjectedShadowPattern = hasProjectedShadowPattern
        self.sceneAnchors = sceneAnchors
        self.openSpaceAvailable = openSpaceAvailable
        self.cropHeadroomAvailable = cropHeadroomAvailable
        self.naturalMotionOpportunity = naturalMotionOpportunity
        self.relationshipInteractionOpportunity = relationshipInteractionOpportunity
        self.focusDepthFeasible = focusDepthFeasible
        self.focusDepthConfidence = focusDepthConfidence
    }
}

struct RuntimeDetectorInput: Codable, Equatable {
    let schemaVersion: String
    let sceneInputId: String
    let sceneAnalysisId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let observations: RuntimeDetectorObservationSet
    let modelMetadata: RuntimeDetectorModelMetadata?
}

struct RuntimeDetectorEvidence: Codable, Equatable {
    let detectorKind: RuntimeDetectorKind
    let outcome: RuntimeDetectorOutcome
    let confidence: Double
    let evidenceFields: [String: String]
    let failureNotes: [String]
    let runtimeAffordanceSignalEvidence: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let modelMetadata: RuntimeDetectorModelMetadata?
    let affordanceSignalVersion: String

    init(
        detectorKind: RuntimeDetectorKind,
        outcome: RuntimeDetectorOutcome,
        confidence: Double,
        evidenceFields: [String: String],
        failureNotes: [String] = [],
        runtimeAffordanceSignalEvidence: [SceneRuntimeModels.RuntimeAffordanceSignal] = [],
        modelMetadata: RuntimeDetectorModelMetadata?,
        affordanceSignalVersion: String = SceneRuntimeDetectorSchema.currentAffordanceSignalVersion
    ) {
        self.detectorKind = detectorKind
        self.outcome = outcome
        self.confidence = Self.clampedConfidence(confidence)
        self.evidenceFields = evidenceFields
        self.failureNotes = failureNotes
        self.runtimeAffordanceSignalEvidence = runtimeAffordanceSignalEvidence
        self.modelMetadata = modelMetadata
        self.affordanceSignalVersion = affordanceSignalVersion
    }

    static func clampedConfidence(_ confidence: Double) -> Double {
        min(max(confidence, 0), 1)
    }
}

struct RuntimeDetectorEvidenceRecord: Codable, Equatable {
    let schemaVersion: String
    let sceneInputId: String
    let sceneAnalysisId: String
    let styleProfileId: String
    let protectedSubjectSetId: String
    let detectorEvidence: RuntimeDetectorEvidence
    let modelMetadata: RuntimeDetectorModelMetadata?
    let affordanceSignalVersion: String
}

enum RuntimeDetectorError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case validationFailed(fieldPath: String, message: String)
}

protocol RuntimeEvidenceDetector {
    var kind: RuntimeDetectorKind { get }
    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence
}

protocol RuntimeDetectorEvidenceRepository: AnyObject {
    func saveRuntimeDetectorEvidence(_ record: RuntimeDetectorEvidenceRecord) async throws
    func runtimeDetectorEvidenceRecords(sceneAnalysisId: String) async -> [RuntimeDetectorEvidenceRecord]
}

final class InMemoryRuntimeDetectorEvidenceRepository: RuntimeDetectorEvidenceRepository {
    private var recordsByKey: [String: RuntimeDetectorEvidenceRecord] = [:]

    func saveRuntimeDetectorEvidence(_ record: RuntimeDetectorEvidenceRecord) async throws {
        recordsByKey[Self.recordKey(record)] = record
    }

    func runtimeDetectorEvidenceRecords(sceneAnalysisId: String) async -> [RuntimeDetectorEvidenceRecord] {
        recordsByKey.values
            .filter { $0.sceneAnalysisId == sceneAnalysisId }
            .sorted { $0.detectorEvidence.detectorKind.rawValue < $1.detectorEvidence.detectorKind.rawValue }
    }

    private static func recordKey(_ record: RuntimeDetectorEvidenceRecord) -> String {
        "\(record.sceneAnalysisId)|\(record.detectorEvidence.detectorKind.rawValue)"
    }
}

struct RuntimeDetectorSuite {
    let detectors: [any RuntimeEvidenceDetector]
    let evidenceRepository: RuntimeDetectorEvidenceRepository

    init(
        detectors: [any RuntimeEvidenceDetector] = RuntimeDetectorSuite.defaultDetectors,
        evidenceRepository: RuntimeDetectorEvidenceRepository = InMemoryRuntimeDetectorEvidenceRepository()
    ) {
        self.detectors = detectors
        self.evidenceRepository = evidenceRepository
    }

    static var defaultDetectors: [any RuntimeEvidenceDetector] {
        [
            LightDirectionQualityDetector(),
            ProtectedSubjectFaceLightFeasibilityDetector(),
            RimHairEdgeLightDetector(),
            ProjectedShadowPatternDetector(),
            SceneAnchorDetector(),
            CropHeadroomDetector(),
            NaturalMotionInteractionDetector(),
            FocusDepthOpportunityDetector()
        ]
    }

    func evaluate(_ input: RuntimeDetectorInput) async throws -> [RuntimeDetectorEvidence] {
        try validate(input)

        let evidence = detectors.map { $0.detect(input) }
        for detectorEvidence in evidence {
            let record = RuntimeDetectorEvidenceRecord(
                schemaVersion: input.schemaVersion,
                sceneInputId: input.sceneInputId,
                sceneAnalysisId: input.sceneAnalysisId,
                styleProfileId: input.styleProfileId,
                protectedSubjectSetId: input.protectedSubjectSetId,
                detectorEvidence: detectorEvidence,
                modelMetadata: input.modelMetadata,
                affordanceSignalVersion: detectorEvidence.affordanceSignalVersion
            )
            try await evidenceRepository.saveRuntimeDetectorEvidence(record)
        }
        return evidence
    }

    private func validate(_ input: RuntimeDetectorInput) throws {
        guard input.schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw RuntimeDetectorError.unsupportedSchemaVersion(input.schemaVersion)
        }
        try requireNonEmpty(input.sceneInputId, fieldPath: "sceneInputId")
        try requireNonEmpty(input.sceneAnalysisId, fieldPath: "sceneAnalysisId")
        try requireNonEmpty(input.styleProfileId, fieldPath: "styleProfileId")
        try requireNonEmpty(input.protectedSubjectSetId, fieldPath: "protectedSubjectSetId")
    }

    private func requireNonEmpty(_ value: String, fieldPath: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw RuntimeDetectorError.validationFailed(
                fieldPath: fieldPath,
                message: "\(fieldPath) must not be empty."
            )
        }
    }
}

struct LightDirectionQualityDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .lightDirectionQuality

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        var evidenceFields = fields([
            ("lightDirection", observations.lightDirection?.rawValue),
            ("lightQuality", observations.lightQuality?.rawValue),
            ("protectedSubjectFaceLightUsable", observations.protectedSubjectFaceLightUsable.map(String.init)),
            ("dramaticSideLightUsable", observations.dramaticSideLightUsable.map(String.init))
        ])

        guard let direction = observations.lightDirection,
              let quality = observations.lightQuality else {
            evidenceFields["state"] = "unknown"
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_light_direction_quality_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        if observations.protectedSubjectFaceLightUsable == false {
            let note = quality == .dramatic
                ? "dramatic_light_without_usable_faces"
                : "light_direction_quality_without_usable_faces"
            return evidence(
                detectorKind: kind,
                outcome: .unsupported,
                confidence: confidence(observations.faceLightConfidence, defaultValue: 0.35),
                evidenceFields: evidenceFields,
                failureNotes: [note],
                modelMetadata: input.modelMetadata
            )
        }

        let faceConfidence = confidence(observations.faceLightConfidence, defaultValue: 0.72)
        switch (quality, direction) {
        case (.soft, .front):
            return supportedSignal(
                .softFrontLight,
                confidence: faceConfidence,
                evidenceText: "Soft front light can illuminate protected-subject faces.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        case (.soft, .sideFront), (.soft, .side):
            return supportedSignal(
                .softSideLight,
                confidence: faceConfidence,
                evidenceText: "Soft side-front light can shape faces while keeping exposure usable.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        case (.dramatic, .side), (.dramatic, .sideFront):
            guard observations.dramaticSideLightUsable == true else {
                return evidence(
                    detectorKind: kind,
                    outcome: .lowConfidence,
                    confidence: faceConfidence,
                    evidenceFields: evidenceFields,
                    failureNotes: ["dramatic_side_light_not_confirmed_usable"],
                    modelMetadata: input.modelMetadata
                )
            }
            return supportedSignal(
                .dramaticSideLightUsable,
                confidence: faceConfidence,
                evidenceText: "Dramatic side light remains usable for protected-subject faces.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        default:
            return evidence(
                detectorKind: kind,
                outcome: .unsupported,
                confidence: faceConfidence,
                evidenceFields: evidenceFields,
                failureNotes: ["light_direction_quality_not_a_supported_affordance"],
                modelMetadata: input.modelMetadata
            )
        }
    }
}

struct ProtectedSubjectFaceLightFeasibilityDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .protectedSubjectFaceLightFeasibility

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let evidenceFields = fields([
            ("protectedSubjectFaceLightUsable", observations.protectedSubjectFaceLightUsable.map(String.init)),
            ("faceLightConfidence", observations.faceLightConfidence.map { String($0) })
        ])

        guard let usable = observations.protectedSubjectFaceLightUsable else {
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_protected_subject_face_light_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        let faceConfidence = confidence(observations.faceLightConfidence, defaultValue: usable ? 0.72 : 0.40)
        if usable {
            return evidence(
                detectorKind: kind,
                outcome: faceConfidence >= SceneRuntimeDetectorSchema.minimumSignalConfidence ? .supported : .lowConfidence,
                confidence: faceConfidence,
                evidenceFields: evidenceFields,
                failureNotes: faceConfidence >= SceneRuntimeDetectorSchema.minimumSignalConfidence ? [] : ["face_light_confidence_below_signal_threshold"],
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .unsupported,
            confidence: faceConfidence,
            evidenceFields: evidenceFields,
            failureNotes: ["no_usable_face_light_opportunity"],
            modelMetadata: input.modelMetadata
        )
    }
}

struct RimHairEdgeLightDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .rimHairEdgeLight

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let evidenceFields = fields([
            ("hasRimHairEdgeLight", observations.hasRimHairEdgeLight.map(String.init)),
            ("protectedSubjectFaceLightUsable", observations.protectedSubjectFaceLightUsable.map(String.init))
        ])

        guard let hasRimLight = observations.hasRimHairEdgeLight else {
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_rim_hair_edge_light_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        if hasRimLight, observations.protectedSubjectFaceLightUsable != false {
            return supportedSignal(
                .rimHairEdgeLight,
                confidence: confidence(observations.faceLightConfidence, defaultValue: 0.76),
                evidenceText: "Edge light is visible while protected-subject face exposure remains usable.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .unsupported,
            confidence: confidence(observations.faceLightConfidence, defaultValue: 0.50),
            evidenceFields: evidenceFields,
            failureNotes: hasRimLight ? ["rim_light_requires_usable_face_exposure"] : ["no_rim_hair_edge_light_detected"],
            modelMetadata: input.modelMetadata
        )
    }
}

struct ProjectedShadowPatternDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .projectedShadowPattern

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let evidenceFields = fields([
            ("hasProjectedShadowPattern", observations.hasProjectedShadowPattern.map(String.init))
        ])

        guard let hasPattern = observations.hasProjectedShadowPattern else {
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_projected_shadow_pattern_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        if hasPattern {
            return supportedSignal(
                .projectedShadowPattern,
                confidence: 0.74,
                evidenceText: "Scene-level shadow pattern can strengthen place and light design.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .unsupported,
            confidence: 0.62,
            evidenceFields: evidenceFields,
            failureNotes: ["no_projected_shadow_pattern_detected"],
            modelMetadata: input.modelMetadata
        )
    }
}

struct SceneAnchorDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .sceneAnchor

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let anchors = observations.sceneAnchors ?? []
        let evidenceFields = fields([
            ("sceneAnchors", anchors.map(\.rawValue).joined(separator: ",")),
            ("openSpaceAvailable", observations.openSpaceAvailable.map(String.init))
        ])
        var signals: [SceneRuntimeModels.RuntimeAffordanceSignal] = []

        if anchors.contains(.classicLocation) {
            signals.append(signal(.classicLocationAnchor, confidence: 0.78, evidenceText: "Classic location anchor is visible."))
        }
        if anchors.contains(.architecture) {
            signals.append(signal(.architecturalAnchor, confidence: 0.76, evidenceText: "Architectural anchor can remain readable in the frame."))
        }
        if anchors.contains(.openSpace) || observations.openSpaceAvailable == true {
            signals.append(signal(.openSpaceAnchor, confidence: 0.75, evidenceText: "Open space gives the operator room to preserve subjects and crop headroom."))
        }

        if signals.isEmpty {
            return evidence(
                detectorKind: kind,
                outcome: .unsupported,
                confidence: 0.48,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_anchor"],
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .supported,
            confidence: signals.map(\.confidence).max() ?? 0,
            evidenceFields: evidenceFields,
            runtimeAffordanceSignalEvidence: signals,
            modelMetadata: input.modelMetadata
        )
    }
}

struct CropHeadroomDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .cropHeadroom

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let evidenceFields = fields([
            ("cropHeadroomAvailable", observations.cropHeadroomAvailable.map(String.init))
        ])

        guard let available = observations.cropHeadroomAvailable else {
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_crop_headroom_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        if available {
            return supportedSignal(
                .cropHeadroomAvailable,
                confidence: 0.82,
                evidenceText: "The frame has enough breathing room for post-capture crop choices.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .unsupported,
            confidence: 0.72,
            evidenceFields: evidenceFields,
            failureNotes: ["crop_headroom_unavailable"],
            modelMetadata: input.modelMetadata
        )
    }
}

struct NaturalMotionInteractionDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .naturalMotionInteraction

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let evidenceFields = fields([
            ("naturalMotionOpportunity", observations.naturalMotionOpportunity.map(String.init)),
            ("relationshipInteractionOpportunity", observations.relationshipInteractionOpportunity.map(String.init))
        ])
        var signals: [SceneRuntimeModels.RuntimeAffordanceSignal] = []

        if observations.naturalMotionOpportunity == true {
            signals.append(signal(.naturalMotionOpportunity, confidence: 0.73, evidenceText: "Scene has enough space or promptable context for natural movement."))
        }
        if observations.relationshipInteractionOpportunity == true {
            signals.append(signal(.relationshipInteractionOpportunity, confidence: 0.74, evidenceText: "Protected subjects have a plausible interaction opportunity."))
        }

        if !signals.isEmpty {
            return evidence(
                detectorKind: kind,
                outcome: .supported,
                confidence: signals.map(\.confidence).max() ?? 0,
                evidenceFields: evidenceFields,
                runtimeAffordanceSignalEvidence: signals,
                modelMetadata: input.modelMetadata
            )
        }

        if observations.naturalMotionOpportunity == nil && observations.relationshipInteractionOpportunity == nil {
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_expression_interaction_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .unsupported,
            confidence: 0.46,
            evidenceFields: evidenceFields,
            failureNotes: ["no_natural_expression_or_interaction_observed"],
            modelMetadata: input.modelMetadata
        )
    }
}

struct FocusDepthOpportunityDetector: RuntimeEvidenceDetector {
    let kind: RuntimeDetectorKind = .focusDepthOpportunity

    func detect(_ input: RuntimeDetectorInput) -> RuntimeDetectorEvidence {
        let observations = input.observations
        let evidenceFields = fields([
            ("focusDepthFeasible", observations.focusDepthFeasible.map(String.init)),
            ("focusDepthConfidence", observations.focusDepthConfidence.map { String($0) })
        ])

        guard let feasible = observations.focusDepthFeasible else {
            return evidence(
                detectorKind: kind,
                outcome: .unknown,
                confidence: 0,
                evidenceFields: evidenceFields,
                failureNotes: ["missing_focus_depth_evidence"],
                modelMetadata: input.modelMetadata
            )
        }

        let focusConfidence = confidence(observations.focusDepthConfidence, defaultValue: feasible ? 0.80 : 0.65)
        if feasible {
            return supportedSignal(
                .focusDepthOpportunity,
                confidence: focusConfidence,
                evidenceText: "Protected subjects can be the primary focus target with usable depth separation.",
                evidenceFields: evidenceFields,
                modelMetadata: input.modelMetadata
            )
        }

        return evidence(
            detectorKind: kind,
            outcome: .unsupported,
            confidence: focusConfidence,
            evidenceFields: evidenceFields,
            failureNotes: ["protected_subject_focus_infeasible"],
            modelMetadata: input.modelMetadata
        )
    }
}

private func fields(_ pairs: [(String, String?)]) -> [String: String] {
    pairs.reduce(into: [:]) { result, pair in
        guard let value = pair.1, !value.isEmpty else {
            return
        }
        result[pair.0] = value
    }
}

private func confidence(_ value: Double?, defaultValue: Double) -> Double {
    RuntimeDetectorEvidence.clampedConfidence(value ?? defaultValue)
}

private func evidence(
    detectorKind: RuntimeDetectorKind,
    outcome: RuntimeDetectorOutcome,
    confidence: Double,
    evidenceFields: [String: String],
    failureNotes: [String] = [],
    runtimeAffordanceSignalEvidence: [SceneRuntimeModels.RuntimeAffordanceSignal] = [],
    modelMetadata: RuntimeDetectorModelMetadata?
) -> RuntimeDetectorEvidence {
    RuntimeDetectorEvidence(
        detectorKind: detectorKind,
        outcome: outcome,
        confidence: confidence,
        evidenceFields: evidenceFields,
        failureNotes: failureNotes,
        runtimeAffordanceSignalEvidence: runtimeAffordanceSignalEvidence,
        modelMetadata: modelMetadata
    )
}

private func supportedSignal(
    _ type: SceneRuntimeModels.RuntimeAffordanceSignalType,
    confidence: Double,
    evidenceText: String,
    evidenceFields: [String: String],
    modelMetadata: RuntimeDetectorModelMetadata?
) -> RuntimeDetectorEvidence {
    let normalizedConfidence = RuntimeDetectorEvidence.clampedConfidence(confidence)
    let outcome: RuntimeDetectorOutcome = normalizedConfidence >= SceneRuntimeDetectorSchema.minimumSignalConfidence
        ? .supported
        : .lowConfidence
    return RuntimeDetectorEvidence(
        detectorKind: detectorKind(for: type),
        outcome: outcome,
        confidence: normalizedConfidence,
        evidenceFields: evidenceFields,
        failureNotes: outcome == .supported ? [] : ["confidence_below_affordance_signal_threshold"],
        runtimeAffordanceSignalEvidence: outcome == .supported
            ? [signal(type, confidence: normalizedConfidence, evidenceText: evidenceText)]
            : [],
        modelMetadata: modelMetadata
    )
}

private func signal(
    _ type: SceneRuntimeModels.RuntimeAffordanceSignalType,
    confidence: Double,
    evidenceText: String
) -> SceneRuntimeModels.RuntimeAffordanceSignal {
    SceneRuntimeModels.RuntimeAffordanceSignal(
        type: type,
        confidence: RuntimeDetectorEvidence.clampedConfidence(confidence),
        recommendedUse: "runtime_scene_planning",
        evidence: evidenceText
    )
}

private func detectorKind(for signalType: SceneRuntimeModels.RuntimeAffordanceSignalType) -> RuntimeDetectorKind {
    switch signalType {
    case .softFrontLight, .softSideLight, .dramaticSideLightUsable:
        return .lightDirectionQuality
    case .rimHairEdgeLight:
        return .rimHairEdgeLight
    case .projectedShadowPattern:
        return .projectedShadowPattern
    case .classicLocationAnchor, .openSpaceAnchor, .architecturalAnchor:
        return .sceneAnchor
    case .cropHeadroomAvailable:
        return .cropHeadroom
    case .naturalMotionOpportunity, .relationshipInteractionOpportunity:
        return .naturalMotionInteraction
    case .focusDepthOpportunity:
        return .focusDepthOpportunity
    }
}
