import Foundation

enum PhoneTestSubjectAnalysisSource: String, Codable, Equatable {
    case iosSubjectHeuristic = "ios_subject_heuristic"
    case cloudSubjectAnalysis = "cloud_subject_analysis"
    case deterministicSubjectFallback = "deterministic_subject_fallback"
}

enum PhoneTestScenePlanSource: String, Codable, Equatable {
    case iosSceneHeuristic = "ios_scene_heuristic"
    case digitalocean = "digitalocean"
    case deterministicLocalFallback = "deterministic_local_fallback"
}

struct PhoneTestSubjectSelfieSignals: Codable, Equatable {
    let source: PhoneTestSubjectAnalysisSource
    let selfieAssetRef: String
    let observedFaceCount: Int?
    let visibleFacingSubjectCount: Int?
    let ignoredBackgroundPersonCount: Int?
    let facesVisibleEnough: Bool?
    let confidence: Double?
    let readinessNotes: [String]

    init(
        source: PhoneTestSubjectAnalysisSource,
        selfieAssetRef: String,
        observedFaceCount: Int? = nil,
        visibleFacingSubjectCount: Int? = nil,
        ignoredBackgroundPersonCount: Int? = nil,
        facesVisibleEnough: Bool? = nil,
        confidence: Double? = nil,
        readinessNotes: [String] = []
    ) {
        self.source = source
        self.selfieAssetRef = selfieAssetRef
        self.observedFaceCount = observedFaceCount
        self.visibleFacingSubjectCount = visibleFacingSubjectCount
        self.ignoredBackgroundPersonCount = ignoredBackgroundPersonCount
        self.facesVisibleEnough = facesVisibleEnough
        self.confidence = confidence
        self.readinessNotes = readinessNotes
    }
}

struct PhoneTestSubjectProfile: Codable, Equatable {
    let subjectProfileId: String
    let selfieAssetRef: String
    let protectedSubjectSetId: String
    let protectedSubjectCount: Int
    let visibilityReadinessNotes: [String]
    let source: PhoneTestSubjectAnalysisSource
    let confidence: Double
    let protectedSubjectSet: SceneRuntimeModels.ProtectedSubjectSet
}

struct PhoneTestSceneInputSignals: Codable, Equatable {
    let source: PhoneTestScenePlanSource
    let sceneMediaRef: String
    let sceneInputMode: SceneRuntimeModels.SceneInputMode
    let uploadAnyway: Bool
    let qualitySignals: SceneRuntimeModels.SceneInputQualitySignals
    let failureReason: SceneRuntimeModels.SceneInputFailureReason?
    let candidateTitle: String?
    let candidateNotes: [String]
    let confidence: Double?

    init(
        source: PhoneTestScenePlanSource,
        sceneMediaRef: String,
        sceneInputMode: SceneRuntimeModels.SceneInputMode,
        uploadAnyway: Bool = false,
        qualitySignals: SceneRuntimeModels.SceneInputQualitySignals = .empty,
        failureReason: SceneRuntimeModels.SceneInputFailureReason? = nil,
        candidateTitle: String? = nil,
        candidateNotes: [String] = [],
        confidence: Double? = nil
    ) {
        self.source = source
        self.sceneMediaRef = sceneMediaRef
        self.sceneInputMode = sceneInputMode
        self.uploadAnyway = uploadAnyway
        self.qualitySignals = qualitySignals
        self.failureReason = failureReason
        self.candidateTitle = candidateTitle
        self.candidateNotes = candidateNotes
        self.confidence = confidence
    }
}

struct PhoneTestSceneInputAnalysisResult: Codable, Equatable {
    let analysisSource: PhoneTestScenePlanSource
    let source: PhoneTestScenePlanSource
    let sourceLabel: String
    let sceneInputId: String
    let sceneInputAttemptId: String
    let scenePhotoId: String?
    let sceneScanId: String?
    let sceneAnalysisId: String
    let sceneInputStatus: SceneRuntimeModels.SceneInputStatus
    let sceneInputQualityContext: SceneRuntimeModels.SceneInputQualityContext
    let sceneInputFailureReason: SceneRuntimeModels.SceneInputFailureReason?
    let sceneMediaRef: String
    let candidateTitle: String
    let candidateNotes: [String]
    let confidence: Double
    let captureContext: SceneRuntimeFrontendCaptureContext
    let scenePlanRequest: SceneRuntimeModels.GenerateScenePlanRequest?

    var canGenerateScenePlan: Bool {
        scenePlanRequest != nil
    }
}

struct PhoneTestScenePlanOutput: Codable, Equatable {
    let analysisSource: PhoneTestScenePlanSource
    let sourceLabel: String
    let sceneInputId: String
    let sceneInputAttemptId: String
    let sceneAnalysisId: String
    let scenePlanId: String
    let scenePlan: SceneRuntimeModels.GenerateScenePlanResponse
    let standPoint: SceneRuntimeModels.LabeledDescription
    let subjectPosition: SceneRuntimeModels.SubjectPosition
    let operatorPosition: SceneRuntimeModels.OperatorPosition
    let facingDirection: SceneRuntimeModels.FacingDirection
    let roughFraming: SceneRuntimeModels.RoughFraming
    let coachingCues: [SceneRuntimeModels.CoachingCue]
    let initialCameraSettingsRecommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation
    let runtimeAffordanceSignals: [SceneRuntimeModels.RuntimeAffordanceSignal]
    let postCapturePrerequisites: SceneRuntimeModels.PostCapturePrerequisites
    let fallback: SceneRuntimeModels.ScenePlanFallback?
    let lowConfidenceRationale: String?
    let cameraSettingsApplicationStage: String
    let canProceedToLiveShooting: Bool
}

enum PhoneTestSubjectSceneAnalysisAdapter {
    static func subjectProfile(
        from signals: PhoneTestSubjectSelfieSignals,
        sessionId: String,
        fallbackProtectedSubjectCount: Int = 1
    ) -> PhoneTestSubjectProfile {
        let safeSessionId = stableIdentifier(sessionId)
        let protectedSubjectCount = protectedSubjectCount(
            from: signals,
            fallbackProtectedSubjectCount: fallbackProtectedSubjectCount
        )
        let protectedSubjectSetId = "protected_subject_set_\(safeSessionId)"
        let confidence = normalizedConfidence(
            signals.confidence,
            fallback: signals.source == .deterministicSubjectFallback ? 0.25 : 0.70
        )
        let notes = subjectNotes(
            from: signals,
            protectedSubjectCount: protectedSubjectCount
        )
        let protectedSubjectSet = SceneRuntimeModels.ProtectedSubjectSet(
            protectedSubjectSetId: protectedSubjectSetId,
            protectedSubjectCount: protectedSubjectCount,
            subjects: protectedSubjects(
                count: protectedSubjectCount,
                facesVisibleEnough: signals.facesVisibleEnough == true,
                source: signals.source
            ),
            rules: SceneRuntimeModels.ProtectedSubjectRules(
                mustKeepAllInFrame: true,
                closedEyesRejectFrame: nil,
                focusAllSubjects: true
            ),
            ignoredDetections: ignoredDetections(from: signals)
        )

        return PhoneTestSubjectProfile(
            subjectProfileId: "subject_profile_\(safeSessionId)",
            selfieAssetRef: signals.selfieAssetRef,
            protectedSubjectSetId: protectedSubjectSetId,
            protectedSubjectCount: protectedSubjectCount,
            visibilityReadinessNotes: notes,
            source: signals.source,
            confidence: confidence,
            protectedSubjectSet: protectedSubjectSet
        )
    }

    static func sceneInputAnalysis(
        from signals: PhoneTestSceneInputSignals,
        sessionId: String,
        styleProfileId: String,
        protectedSubjectSetId: String
    ) -> PhoneTestSceneInputAnalysisResult {
        let safeSessionId = stableIdentifier(sessionId)
        let ids = sceneInputIds(mode: signals.sceneInputMode, safeSessionId: safeSessionId)
        let status = sceneInputStatus(from: signals)
        let qualityContext = SceneRuntimeModels.SceneInputQualityContext(
            sceneInputMode: signals.sceneInputMode,
            sceneInputStatus: status,
            allowsSuboptimalSceneInput: status == .acceptedSuboptimal,
            sceneInputFailureReason: signals.failureReason,
            qualitySignals: signals.qualitySignals
        )
        let sourceLabel = "source = \(signals.source.rawValue)"
        let candidateTitle = signals.candidateTitle ?? defaultCandidateTitle(for: signals.source)
        let candidateNotes = sceneNotes(
            from: signals,
            sourceLabel: sourceLabel,
            sceneInputStatus: status
        )
        let context = SceneRuntimeFrontendCaptureContext(
            sessionId: sessionId,
            styleProfileId: styleProfileId,
            protectedSubjectSetId: protectedSubjectSetId,
            sceneInputAttemptId: ids.sceneInputAttemptId,
            sceneInputMode: signals.sceneInputMode,
            mediaRefs: [signals.sceneMediaRef],
            uploadAnyway: signals.uploadAnyway,
            qualitySignals: signals.qualitySignals,
            uploadFailureReason: signals.failureReason
        )
        let planRequest = canContinueToScenePlan(status)
            ? SceneRuntimeModels.GenerateScenePlanRequest(
                sceneAnalysisId: ids.sceneAnalysisId,
                styleProfileId: styleProfileId,
                protectedSubjectSetId: protectedSubjectSetId,
                sceneInputQualityContext: qualityContext
            )
            : nil

        return PhoneTestSceneInputAnalysisResult(
            analysisSource: signals.source,
            source: signals.source,
            sourceLabel: sourceLabel,
            sceneInputId: ids.sceneInputId,
            sceneInputAttemptId: ids.sceneInputAttemptId,
            scenePhotoId: ids.scenePhotoId,
            sceneScanId: ids.sceneScanId,
            sceneAnalysisId: ids.sceneAnalysisId,
            sceneInputStatus: status,
            sceneInputQualityContext: qualityContext,
            sceneInputFailureReason: signals.failureReason,
            sceneMediaRef: signals.sceneMediaRef,
            candidateTitle: candidateTitle,
            candidateNotes: candidateNotes,
            confidence: normalizedConfidence(
                signals.confidence,
                fallback: signals.source == .deterministicLocalFallback ? 0.35 : 0.72
            ),
            captureContext: context,
            scenePlanRequest: planRequest
        )
    }

    static func scenePlan(
        from analysis: PhoneTestSceneInputAnalysisResult
    ) -> PhoneTestScenePlanOutput? {
        guard let request = analysis.scenePlanRequest else {
            return nil
        }
        let plan = deterministicScenePlan(from: request, analysis: analysis)
        return PhoneTestScenePlanOutput(
            analysisSource: analysis.analysisSource,
            sourceLabel: analysis.sourceLabel,
            sceneInputId: analysis.sceneInputId,
            sceneInputAttemptId: analysis.sceneInputAttemptId,
            sceneAnalysisId: analysis.sceneAnalysisId,
            scenePlanId: plan.scenePlanId,
            scenePlan: plan,
            standPoint: plan.standPoint,
            subjectPosition: plan.subjectPosition,
            operatorPosition: plan.operatorPosition,
            facingDirection: plan.facingDirection,
            roughFraming: plan.roughFraming,
            coachingCues: plan.coachingCues,
            initialCameraSettingsRecommendation: plan.initialCameraSettingsRecommendation,
            runtimeAffordanceSignals: plan.runtimeAffordanceSignals,
            postCapturePrerequisites: plan.postCapturePrerequisites,
            fallback: plan.fallback,
            lowConfidenceRationale: lowConfidenceRationale(for: analysis),
            cameraSettingsApplicationStage: "recommended_not_applied_until_live_coach",
            canProceedToLiveShooting: true
        )
    }

    private static func protectedSubjectCount(
        from signals: PhoneTestSubjectSelfieSignals,
        fallbackProtectedSubjectCount: Int
    ) -> Int {
        if signals.source == .deterministicSubjectFallback {
            return max(1, fallbackProtectedSubjectCount)
        }
        if let visibleFacingSubjectCount = signals.visibleFacingSubjectCount {
            return max(0, visibleFacingSubjectCount)
        }
        if signals.facesVisibleEnough == true,
           let observedFaceCount = signals.observedFaceCount {
            return max(0, observedFaceCount)
        }
        return 0
    }

    private static func protectedSubjects(
        count: Int,
        facesVisibleEnough: Bool,
        source: PhoneTestSubjectAnalysisSource
    ) -> [SceneRuntimeModels.ProtectedSubject] {
        guard count > 0 else {
            return []
        }
        return (1...count).map { index in
            SceneRuntimeModels.ProtectedSubject(
                subjectId: "protected_subject_\(index)",
                role: "selfie_confirmed_subject",
                displayLabel: count == 1 ? "Subject" : "Subject \(index)",
                includedInSubjectCount: true,
                facingCamera: source == .deterministicSubjectFallback ? false : facesVisibleEnough
            )
        }
    }

    private static func ignoredDetections(
        from signals: PhoneTestSubjectSelfieSignals
    ) -> [SceneRuntimeModels.IgnoredDetection]? {
        guard let ignoredCount = signals.ignoredBackgroundPersonCount, ignoredCount > 0 else {
            return nil
        }
        return [
            SceneRuntimeModels.IgnoredDetection(
                reason: "Ignored \(ignoredCount) background person/persons not intentionally included in the subject selfie.",
                countsAsProtectedSubject: false
            )
        ]
    }

    private static func subjectNotes(
        from signals: PhoneTestSubjectSelfieSignals,
        protectedSubjectCount: Int
    ) -> [String] {
        var notes = signals.readinessNotes
        notes.append("source = \(signals.source.rawValue)")
        if protectedSubjectCount == 0 {
            notes.append("No protected subject was confidently visible; retake is recommended before relying on guidance.")
        } else {
            notes.append("protectedSubjectCount = \(protectedSubjectCount)")
        }
        if signals.source == .deterministicSubjectFallback {
            notes.append("Deterministic fallback is a phone-test continuity path, not real subject analysis.")
        }
        if let ignoredCount = signals.ignoredBackgroundPersonCount, ignoredCount > 0 {
            notes.append("Ignored background people do not count as protected subjects.")
        }
        return notes
    }

    private static func sceneNotes(
        from signals: PhoneTestSceneInputSignals,
        sourceLabel: String,
        sceneInputStatus: SceneRuntimeModels.SceneInputStatus
    ) -> [String] {
        var notes = signals.candidateNotes
        notes.append(sourceLabel)
        notes.append("sceneInputStatus = \(sceneInputStatus.rawValue)")
        if signals.source == .deterministicLocalFallback {
            notes.append("Deterministic local fallback is phone-test guidance, not successful cloud scene analysis.")
        }
        if let failureReason = signals.failureReason {
            notes.append("failureReason = \(failureReason.code)")
        }
        if signals.uploadAnyway {
            notes.append("uploadAnyway = true")
        }
        return notes
    }

    private static func sceneInputIds(
        mode: SceneRuntimeModels.SceneInputMode,
        safeSessionId: String
    ) -> (
        sceneInputId: String,
        sceneInputAttemptId: String,
        scenePhotoId: String?,
        sceneScanId: String?,
        sceneAnalysisId: String
    ) {
        switch mode {
        case .singlePhoto:
            return (
                sceneInputId: "scene_photo_\(safeSessionId)",
                sceneInputAttemptId: "scene_photo_attempt_\(safeSessionId)",
                scenePhotoId: "scene_photo_asset_\(safeSessionId)",
                sceneScanId: nil,
                sceneAnalysisId: "scene_analysis_\(safeSessionId)"
            )
        case .scanVideo:
            return (
                sceneInputId: "scene_scan_\(safeSessionId)",
                sceneInputAttemptId: "scene_scan_attempt_\(safeSessionId)",
                scenePhotoId: nil,
                sceneScanId: "scene_scan_asset_\(safeSessionId)",
                sceneAnalysisId: "scene_analysis_\(safeSessionId)"
            )
        }
    }

    private static func sceneInputStatus(
        from signals: PhoneTestSceneInputSignals
    ) -> SceneRuntimeModels.SceneInputStatus {
        if signals.qualitySignals.uploadFailed == true,
           signals.uploadAnyway == false {
            return .uploadFailed
        }
        if hasQualityWarning(signals.qualitySignals) || signals.failureReason != nil || signals.uploadAnyway {
            return signals.uploadAnyway ? .acceptedSuboptimal : .rejectedRetryRequired
        }
        return .accepted
    }

    private static func canContinueToScenePlan(
        _ status: SceneRuntimeModels.SceneInputStatus
    ) -> Bool {
        status == .accepted || status == .acceptedSuboptimal
    }

    private static func hasQualityWarning(
        _ signals: SceneRuntimeModels.SceneInputQualitySignals
    ) -> Bool {
        signals.tooDark
            || signals.overexposed
            || signals.motionBlur
            || signals.scanTooShort
            || signals.noUsefulCompositionSpace
            || signals.uploadFailed == true
    }

    private static func deterministicScenePlan(
        from request: SceneRuntimeModels.GenerateScenePlanRequest,
        analysis: PhoneTestSceneInputAnalysisResult
    ) -> SceneRuntimeModels.GenerateScenePlanResponse {
        let qualitySignals = request.sceneInputQualityContext.qualitySignals
        let suboptimal = request.sceneInputQualityContext.allowsSuboptimalSceneInput
        let deterministicFallback = analysis.analysisSource == .deterministicLocalFallback
        let faceLightUsable = qualitySignals?.tooDark != true && qualitySignals?.overexposed != true
        let cropHeadroomFeasible = qualitySignals?.noUsefulCompositionSpace != true
        let scenePlanId = "scene_plan_\(request.sceneAnalysisId.replacingOccurrences(of: "scene_analysis_", with: ""))"

        return SceneRuntimeModels.GenerateScenePlanResponse(
            scenePlanId: scenePlanId,
            sceneAnalysisId: request.sceneAnalysisId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            sceneInputQualityContext: request.sceneInputQualityContext,
            sceneMatchType: suboptimal || deterministicFallback ? .bestEffortFallback : .styleSynthesis,
            professionalHappyMomentAssessment: SceneRuntimeModels.ProfessionalHappyMomentAssessment(
                faceLightUsable: faceLightUsable,
                naturalExpressionOpportunity: true,
                relationshipInteractionOpportunity: true,
                protectedSubjectFocusFeasible: true,
                cropHeadroomFeasible: cropHeadroomFeasible,
                unrecoverableRisks: professionalRisks(
                    qualitySignals: qualitySignals,
                    suboptimal: suboptimal,
                    deterministicFallback: deterministicFallback
                )
            ),
            runtimeAffordanceSignals: runtimeAffordanceSignals(
                analysis: analysis,
                faceLightUsable: faceLightUsable,
                cropHeadroomFeasible: cropHeadroomFeasible
            ),
            postCapturePrerequisites: postCapturePrerequisites(),
            postCaptureFineTuneSignals: [
                .portfolioColorTone,
                .cropComposition,
                .lightShadowContrast,
                .backgroundReadabilityOrSubjectSeparation
            ],
            standPoint: SceneRuntimeModels.LabeledDescription(
                label: suboptimal ? "Best-effort soft light edge" : "Soft light near the current scene anchor",
                description: suboptimal
                    ? "Use the safest visible light first; preserve the scene only where it does not compromise protected-subject faces."
                    : "Keep protected-subject faces in usable soft light while preserving the current place cue."
            ),
            subjectPosition: SceneRuntimeModels.SubjectPosition(
                zone: suboptimal ? "nearest_usable_light" : "open_light_edge",
                distanceCue: suboptimal
                    ? "stand where faces are most readable, even if the background becomes simpler"
                    : "stand where faces stay bright and the background remains readable"
            ),
            operatorPosition: SceneRuntimeModels.OperatorPosition(
                distanceCue: cropHeadroomFeasible ? "step back until heads and the scene anchor have room" : "step back until heads are safely inside the frame",
                heightCue: "hold the phone around chest height",
                framingCue: "keep all protected subjects inside the guide before trying to preserve the background"
            ),
            facingDirection: SceneRuntimeModels.FacingDirection(
                subjectCue: faceLightUsable ? "turn gently toward the softer light" : "turn toward the brightest soft light before posing",
                operatorCue: "face the phone toward protected subjects first, then include the scene anchor"
            ),
            roughFraming: SceneRuntimeModels.RoughFraming(
                style: "wide_environmental",
                safetyMargin: suboptimal ? "extra_high" : "high",
                orientation: "vertical"
            ),
            coachingCues: coachingCues(
                faceLightUsable: faceLightUsable,
                cropHeadroomFeasible: cropHeadroomFeasible,
                suboptimal: suboptimal
            ),
            initialCameraSettingsRecommendation: initialCameraSettingsRecommendation(
                scenePlanId: scenePlanId,
                analysisSource: analysis.analysisSource,
                suboptimal: suboptimal,
                faceLightUsable: faceLightUsable
            ),
            fallback: fallback(
                analysis: analysis,
                suboptimal: suboptimal,
                deterministicFallback: deterministicFallback,
                faceLightUsable: faceLightUsable
            ),
            persistenceWriteIntent: ["phoneTestSceneAnalysis", "scenePlan", "initialCameraSettingsRecommendation"]
        )
    }

    private static func professionalRisks(
        qualitySignals: SceneRuntimeModels.SceneInputQualitySignals?,
        suboptimal: Bool,
        deterministicFallback: Bool
    ) -> [String]? {
        var risks: [String] = []
        if suboptimal {
            risks.append("scene_input_suboptimal_preserved_for_lower_confidence")
        }
        if deterministicFallback {
            risks.append("deterministic_local_fallback_not_cloud_analysis")
        }
        if qualitySignals?.tooDark == true {
            risks.append("protected_subject_face_light_may_be_too_dark")
        }
        if qualitySignals?.overexposed == true {
            risks.append("protected_subject_face_light_may_be_overexposed")
        }
        if qualitySignals?.scanTooShort == true {
            risks.append("scene_scan_too_short_for_full_affordance_detection")
        }
        if qualitySignals?.motionBlur == true {
            risks.append("scene_input_blur_reduces_confidence")
        }
        if qualitySignals?.noUsefulCompositionSpace == true {
            risks.append("crop_headroom_or_scene_anchor_may_be_limited")
        }
        return risks.isEmpty ? nil : risks
    }

    private static func runtimeAffordanceSignals(
        analysis: PhoneTestSceneInputAnalysisResult,
        faceLightUsable: Bool,
        cropHeadroomFeasible: Bool
    ) -> [SceneRuntimeModels.RuntimeAffordanceSignal] {
        var signals: [SceneRuntimeModels.RuntimeAffordanceSignal] = []
        if faceLightUsable {
            signals.append(signal(.softSideLight, analysis: analysis, confidence: 0.70))
        }
        if cropHeadroomFeasible {
            signals.append(signal(.cropHeadroomAvailable, analysis: analysis, confidence: 0.78))
        }
        signals.append(signal(.naturalMotionOpportunity, analysis: analysis, confidence: 0.72))
        signals.append(signal(.relationshipInteractionOpportunity, analysis: analysis, confidence: 0.70))
        signals.append(signal(.focusDepthOpportunity, analysis: analysis, confidence: 0.74))
        signals.append(signal(.openSpaceAnchor, analysis: analysis, confidence: 0.60))
        return signals
    }

    private static func signal(
        _ type: SceneRuntimeModels.RuntimeAffordanceSignalType,
        analysis: PhoneTestSceneInputAnalysisResult,
        confidence: Double
    ) -> SceneRuntimeModels.RuntimeAffordanceSignal {
        SceneRuntimeModels.RuntimeAffordanceSignal(
            type: type,
            confidence: analysis.analysisSource == .deterministicLocalFallback ? min(confidence, 0.55) : confidence,
            recommendedUse: recommendedUse(for: type),
            evidence: "\(analysis.sourceLabel); sceneInputId = \(analysis.sceneInputId)"
        )
    }

    private static func recommendedUse(
        for type: SceneRuntimeModels.RuntimeAffordanceSignalType
    ) -> String {
        switch type {
        case .softSideLight:
            return "turn protected-subject faces toward the usable soft light"
        case .cropHeadroomAvailable:
            return "capture wide enough for crop and final-moment options"
        case .naturalMotionOpportunity:
            return "use simple walking or shifting movement"
        case .relationshipInteractionOpportunity:
            return "cue protected subjects to interact naturally"
        case .focusDepthOpportunity:
            return "keep protected subjects as the focus target"
        case .openSpaceAnchor:
            return "use open space as a simple place anchor"
        default:
            return "preserve this affordance only if protected-subject prerequisites remain ready"
        }
    }

    private static func postCapturePrerequisites() -> SceneRuntimeModels.PostCapturePrerequisites {
        SceneRuntimeModels.PostCapturePrerequisites(
            mustCaptureCorrectly: [
                .protectedSubjectsVisible,
                .protectedSubjectFocus,
                .usableFaceLight,
                .naturalExpressionOrInteraction,
                .cropHeadroom
            ],
            canFineTuneLater: [
                .portfolioColorTone,
                .cropComposition,
                .lightShadowContrast,
                .backgroundReadabilityOrSubjectSeparation
            ],
            statusAtCapture: nil
        )
    }

    private static func coachingCues(
        faceLightUsable: Bool,
        cropHeadroomFeasible: Bool,
        suboptimal: Bool
    ) -> [SceneRuntimeModels.CoachingCue] {
        var cues: [SceneRuntimeModels.CoachingCue] = []
        cues.append(
            SceneRuntimeModels.CoachingCue(
                target: "operator",
                message: cropHeadroomFeasible
                    ? "Step back until protected subjects and the scene anchor fit."
                    : "Step back until every protected subject has safe headroom."
            )
        )
        cues.append(
            SceneRuntimeModels.CoachingCue(
                target: "subjects",
                message: faceLightUsable
                    ? "Turn gently toward the softer light."
                    : "Turn toward the brightest soft light before moving."
            )
        )
        cues.append(
            SceneRuntimeModels.CoachingCue(
                target: "subjects",
                message: suboptimal
                    ? "Keep the motion simple and relaxed."
                    : "Walk together slowly and keep talking to each other."
            )
        )
        return cues
    }

    private static func initialCameraSettingsRecommendation(
        scenePlanId: String,
        analysisSource: PhoneTestScenePlanSource,
        suboptimal: Bool,
        faceLightUsable: Bool
    ) -> SceneRuntimeModels.InitialCameraSettingsRecommendation {
        SceneRuntimeModels.InitialCameraSettingsRecommendation(
            recommendationId: "camera_rec_\(scenePlanId.replacingOccurrences(of: "scene_plan_", with: ""))",
            sourceNativeCameraParameterIntentId: "phone_test_scene_plan.\(analysisSource.rawValue).native_camera_intent",
            focus: SceneRuntimeModels.FocusRecommendation(
                target: "all_protected_subjects",
                mode: "continuous_then_lock_when_ready",
                priority: "faces_and_bodies",
                focusPointStrategy: "protected_subject_face_group"
            ),
            exposure: SceneRuntimeModels.ExposureRecommendation(
                meteringTarget: "protected_subject_faces",
                bias: faceLightUsable ? -0.2 : 0.0,
                protectHighlights: true,
                avoidFaceClipping: true,
                avoidFaceShadowCrush: true
            ),
            whiteBalance: SceneRuntimeModels.WhiteBalanceRecommendation(
                mode: "auto_then_lock_when_ready",
                lockWhenReady: true,
                temperatureBias: "warm",
                tintBias: "neutral"
            ),
            zoomLens: SceneRuntimeModels.ZoomLensRecommendation(
                preferredLens: "wide",
                targetZoomFactor: 1.0,
                maxDigitalZoomFactor: suboptimal ? 1.5 : 2.0,
                allowUltraWideIfOperatorTooClose: true,
                avoidLensSwitchDuringCapture: true
            ),
            depth: SceneRuntimeModels.DepthRecommendation(
                mode: "environmental_depth",
                portraitBlurStrength: 0.2,
                keepArchitecturalAnchorReadable: true,
                depthDataDeliveryPreferred: true,
                portraitEffectsMattePreferred: false
            ),
            framing: SceneRuntimeModels.FramingRecommendation(
                shootWide: true,
                safetyMargin: suboptimal ? "extra_high" : "high",
                orientation: "vertical",
                compositionTarget: "wide_environmental"
            ),
            colorAndTonePreview: SceneRuntimeModels.ColorAndTonePreview(
                contrast: "medium",
                saturation: "slightly_warm",
                highlightRecovery: faceLightUsable ? "moderate" : "high"
            ),
            capture: SceneRuntimeModels.CaptureRecommendation(
                burstCount: suboptimal ? 6 : 10,
                highestPracticalResolution: true,
                photoQualityPrioritization: "quality",
                captureResponsiveness: "balanced",
                stabilizationPreferred: true
            ),
            flashLowLight: SceneRuntimeModels.FlashLowLightRecommendation(
                preferNaturalLight: true,
                flashMode: "off_unless_recovery_needed",
                torchAllowed: false,
                lowLightRecoveryPolicy: "move_subjects_or_best_effort_before_flash"
            ),
            capabilityRequirements: SceneRuntimeModels.CapabilityRequirements(
                reportUnavailableSettings: true,
                allowedFallbackBehavior: "closest_available_with_explicit_gap_reporting",
                statusValues: [.pending, .adjusted, .unavailable, .needsOperatorAdjustment]
            )
        )
    }

    private static func fallback(
        analysis: PhoneTestSceneInputAnalysisResult,
        suboptimal: Bool,
        deterministicFallback: Bool,
        faceLightUsable: Bool
    ) -> SceneRuntimeModels.ScenePlanFallback? {
        if suboptimal {
            return SceneRuntimeModels.ScenePlanFallback(
                type: "accepted_suboptimal_scene_input",
                message: "Scene input was accepted with preserved quality warnings.",
                nextAction: faceLightUsable
                    ? "Coach conservatively and verify live focus, light, and headroom before capture."
                    : "Move protected subjects toward brighter soft light before capture.",
                canContinueBestEffort: true
            )
        }
        if deterministicFallback {
            return SceneRuntimeModels.ScenePlanFallback(
                type: "deterministic_local_scene_plan",
                message: "Scene plan uses deterministic phone-test fallback, not confirmed cloud scene analysis.",
                nextAction: "Use live frame readiness to verify subject visibility, focus, face light, and headroom.",
                canContinueBestEffort: true
            )
        }
        if !faceLightUsable {
            return SceneRuntimeModels.ScenePlanFallback(
                type: "weak_face_light",
                message: "Scene input suggests protected-subject face light may be weak.",
                nextAction: "Turn protected subjects toward softer usable light.",
                canContinueBestEffort: true
            )
        }
        return nil
    }

    private static func lowConfidenceRationale(
        for analysis: PhoneTestSceneInputAnalysisResult
    ) -> String? {
        var reasons: [String] = []
        if analysis.analysisSource == .deterministicLocalFallback {
            reasons.append("analysisSource = deterministic_local_fallback")
        }
        if analysis.sceneInputQualityContext.allowsSuboptimalSceneInput {
            reasons.append("sceneInputStatus = accepted_suboptimal")
        }
        if let failureReason = analysis.sceneInputFailureReason {
            reasons.append("failureReason = \(failureReason.code)")
        }
        return reasons.isEmpty ? nil : reasons.joined(separator: "; ")
    }

    private static func defaultCandidateTitle(for source: PhoneTestScenePlanSource) -> String {
        switch source {
        case .iosSceneHeuristic:
            return "Current scene from iOS heuristic"
        case .digitalocean:
            return "Current scene from DigitalOcean"
        case .deterministicLocalFallback:
            return "Current scene from deterministic local fallback"
        }
    }

    private static func normalizedConfidence(_ value: Double?, fallback: Double) -> Double {
        min(max(value ?? fallback, 0.0), 1.0)
    }

    private static func stableIdentifier(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let identifier = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return identifier.isEmpty ? "phone_test" : identifier
    }
}
