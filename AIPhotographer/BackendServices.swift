import Foundation

protocol PortfolioStyleExtracting {
    func extractStyle(from portfolio: CuratedPortfolio) -> StyleExtraction
}

protocol AppleVisionSceneAnalyzing {
    func analyzeScene(request: GuidanceRequest, style: StyleExtraction) -> SceneAnalysis
}

protocol PlacementRecommending {
    func recommendPlacement(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> PlacementRecommendation
}

protocol PoseRecommending {
    func recommendPose(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> PoseRecommendation
}

protocol CompositionRecommending {
    func recommendComposition(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> CompositionRecommendation
}

protocol CameraSettingsRecommending {
    func recommendSettings(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> CameraSettingsRecommendation
}

protocol CaptureReadinessEvaluating {
    func evaluateReadiness(for request: GuidanceRequest, analysis: SceneAnalysis, placement: PlacementRecommendation, pose: PoseRecommendation, settings: CameraSettingsRecommendation) -> CaptureReadiness
}

protocol PostCaptureEditing {
    func buildEditPlan(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> PostCaptureEditPlan
}

protocol CaptureSessionPersisting {
    func save(_ session: CaptureSessionRecord) throws
}

struct GuidedCaptureBackend {
    let portfolio: CuratedPortfolio
    let styleExtractor: PortfolioStyleExtracting
    let sceneAnalyzer: AppleVisionSceneAnalyzing
    let placementRecommender: PlacementRecommending
    let poseRecommender: PoseRecommending
    let compositionRecommender: CompositionRecommending
    let cameraSettingsRecommender: CameraSettingsRecommending
    let readinessEvaluator: CaptureReadinessEvaluating
    let postCaptureEditor: PostCaptureEditing
    let persistence: CaptureSessionPersisting?

    func buildGuidance(request: GuidanceRequest) throws -> GuidanceResponse {
        try request.validate()

        let style = styleExtractor.extractStyle(from: portfolio)
        let analysis = sceneAnalyzer.analyzeScene(request: request, style: style)
        let placement = placementRecommender.recommendPlacement(for: request, analysis: analysis, style: style)
        let pose = poseRecommender.recommendPose(for: request, analysis: analysis, style: style)
        let composition = compositionRecommender.recommendComposition(for: request, analysis: analysis, style: style)
        let settings = cameraSettingsRecommender.recommendSettings(for: request, analysis: analysis, style: style)
        let readiness = readinessEvaluator.evaluateReadiness(
            for: request,
            analysis: analysis,
            placement: placement,
            pose: pose,
            settings: settings
        )
        let editPlan = postCaptureEditor.buildEditPlan(for: request, analysis: analysis, style: style)

        return GuidanceResponse(
            request: request,
            styleExtraction: style,
            sceneAnalysis: analysis,
            placement: placement,
            pose: pose,
            composition: composition,
            cameraSettings: settings,
            readiness: readiness,
            postCaptureEdit: editPlan,
            createdAt: Date()
        )
    }

    func persistSession(_ session: CaptureSessionRecord) throws {
        try persistence?.save(session)
    }

    static func preview(persistence: CaptureSessionPersisting? = nil) -> GuidedCaptureBackend {
        GuidedCaptureBackend(
            portfolio: BackendPreviewFactory.portfolio,
            styleExtractor: MockPortfolioStyleExtractor(),
            sceneAnalyzer: MockAppleVisionAdapter(),
            placementRecommender: MockPlacementRecommender(),
            poseRecommender: MockPoseRecommender(),
            compositionRecommender: MockCompositionRecommender(),
            cameraSettingsRecommender: MockAppleCameraAdapter(),
            readinessEvaluator: MockReadinessEvaluator(),
            postCaptureEditor: MockPostCaptureEditor(),
            persistence: persistence
        )
    }
}

struct MockPortfolioStyleExtractor: PortfolioStyleExtracting {
    func extractStyle(from portfolio: CuratedPortfolio) -> StyleExtraction {
        StyleExtraction(
            styleId: portfolio.id,
            compositionDirectives: [
                "Preserve landmark height above the subjects.",
                "Bias subject placement toward the lower middle third.",
                "Use architectural lines to steer the eye into the subject zone."
            ],
            lightingDirectives: [
                "Prefer warm side light over front-lit flat light.",
                "Protect sandstone highlights while keeping skin luminous."
            ],
            poseDirectives: [
                "Keep the stance calm and editorial rather than celebratory chaos.",
                "Use subtle interaction between subjects when there is more than one person."
            ],
            editingDirectives: [
                "Lift warmth slightly, deepen contrast carefully, and keep blues restrained.",
                "Maintain realistic skin tones while shaping the environment toward warm paper neutrals."
            ]
        )
    }
}

struct MockAppleVisionAdapter: AppleVisionSceneAnalyzing {
    func analyzeScene(request: GuidanceRequest, style: StyleExtraction) -> SceneAnalysis {
        let lowercased = request.scene.title.lowercased() + " " + request.scene.locationHint.lowercased()
        let landmark = lowercased.contains("hoover") ? "Hoover Tower corridor" : "Stanford sandstone arcade"
        let isVideo = request.scene.kind == .sceneVideo
        let groupBias = request.subjectProfile.subjectCount >= 4
        let zoneWidth = groupBias ? 0.56 : 0.36
        let zoneHeight = groupBias ? 0.28 : 0.34

        return SceneAnalysis(
            sceneId: request.scene.id,
            landmarkLabel: landmark,
            lightDirection: lowercased.contains("west") ? "camera left warm side light" : "camera right warm side light",
            lightQuality: isVideo ? "scouted directional light with moving highlight pockets" : "directional warm side light",
            depthScore: isVideo ? 90 : 87,
            clutterScore: lowercased.contains("quad") ? 76 : 84,
            skylineClearanceScore: 89,
            primaryWalkwayAngleDegrees: groupBias ? 8 : 12,
            recommendedSubjectZone: SubjectZone(
                normalizedCenterX: groupBias ? 0.50 : 0.54,
                normalizedCenterY: 0.64,
                normalizedWidth: zoneWidth,
                normalizedHeight: zoneHeight,
                action: groupBias ? .stand : .lean,
                movement: isVideo ? .forward : .still,
                distanceFromCameraMeters: groupBias ? 4.8 : 3.2
            ),
            cameraOrigin: CameraOrigin(
                normalizedX: 0.21,
                normalizedY: 0.88,
                heightMeters: 1.35
            ),
            appleVisionObservations: [
                VisionObservation(label: "person candidate zone", confidence: 0.93, normalizedRect: NormalizedRect(x: 0.34, y: 0.48, width: zoneWidth, height: zoneHeight)),
                VisionObservation(label: "architectural vanishing line", confidence: 0.88, normalizedRect: NormalizedRect(x: 0.08, y: 0.32, width: 0.84, height: 0.44)),
                VisionObservation(label: "highlight risk", confidence: 0.81, normalizedRect: NormalizedRect(x: 0.62, y: 0.12, width: 0.18, height: 0.20))
            ],
            notes: [
                "Scene differs from the reference portfolio but shares sandstone tones and depth structure.",
                "Candidate zone avoids the brightest highlight patch while keeping landmark geometry visible."
            ]
        )
    }
}

struct MockPlacementRecommender: PlacementRecommending {
    func recommendPlacement(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> PlacementRecommendation {
        let scenario = request.subjectProfile.scenario
        let cue: String
        let feet: String

        switch scenario {
        case .single:
            cue = "Stand inside the gold guide box, then lean your weight onto the back foot toward the darker arch."
            feet = "Place the front foot on the seam one meter inside the arch opening."
        case .couple:
            cue = "Stagger shoulder lines so one subject sits half a step behind the other near the inside edge of the guide zone."
            feet = "Lead subject on the center seam, second subject half a step back and inward."
        case .family, .group:
            cue = "Build the group in a shallow arc centered in the guide zone so every face keeps the side light."
            feet = "Tallest subjects center-back, smaller subjects slightly forward with no one crossing the guide edge."
        }

        return PlacementRecommendation(
            headline: "Anchor the subjects in the lower middle third and keep breathing room for the landmark.",
            subjectZone: analysis.recommendedSubjectZone,
            footPlacement: feet,
            movementCue: cue
        )
    }
}

struct MockPoseRecommender: PoseRecommending {
    func recommendPose(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> PoseRecommendation {
        switch request.subjectProfile.scenario {
        case .single:
            return PoseRecommendation(
                headline: "Relaxed editorial lean.",
                bodyArrangement: "Turn hips 25 degrees away from camera and let one shoulder lead back toward the light.",
                faceDirection: "Eyes back toward camera with chin slightly toward the light source.",
                handPlacement: "One hand relaxed at the side, the other lightly touching gown lapel or pocket."
            )
        case .couple:
            return PoseRecommendation(
                headline: "Quiet linked pose.",
                bodyArrangement: "Inside shoulders closer together, outside shoulders open to the architecture.",
                faceDirection: "Lead subject to camera, second subject to the light with a shared eye line.",
                handPlacement: "Link arms or place hands behind backs to keep the front silhouette clean."
            )
        case .family, .group:
            return PoseRecommendation(
                headline: "Layered family arc.",
                bodyArrangement: "Create two shallow rows with the tallest center-back and everyone angled five degrees inward.",
                faceDirection: "All faces turn slightly toward the warm side light before looking to camera.",
                handPlacement: "Keep hands low or linked; children and smaller subjects slightly forward."
            )
        }
    }
}

struct MockCompositionRecommender: CompositionRecommending {
    func recommendComposition(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> CompositionRecommendation {
        CompositionRecommendation(
            framing: "Hold the subject zone at the lower middle third and keep vertical lines straight enough to emphasize scale.",
            horizonTreatment: "No visible horizon correction needed; prioritize upright architecture.",
            landmarkUsage: "Keep the full arch rhythm or tower rise above the subjects for contextual Stanford identity.",
            keepOutZones: [
                NormalizedRect(x: 0.62, y: 0.12, width: 0.18, height: 0.20),
                NormalizedRect(x: 0.00, y: 0.86, width: 0.16, height: 0.14)
            ]
        )
    }
}

struct MockAppleCameraAdapter: CameraSettingsRecommending {
    func recommendSettings(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> CameraSettingsRecommendation {
        let group = request.subjectProfile.subjectCount >= 4
        return CameraSettingsRecommendation(
            lens: group ? .wide : .telephoto,
            zoomFactor: group ? 1.2 : 2.0,
            exposureBiasEV: -0.3,
            brightness: -0.04,
            contrast: 0.14,
            saturation: 0.05,
            whiteBalanceKelvin: 5750,
            highlightProtection: "Prioritize sandstone highlight retention before lifting shadows in post.",
            focusDistanceMeters: analysis.recommendedSubjectZone.distanceFromCameraMeters,
            shutterSuggestion: group ? "1/250 or faster" : "1/320 or faster",
            stabilization: "Lock exposure/focus once faces are inside the target zone."
        )
    }
}

struct MockReadinessEvaluator: CaptureReadinessEvaluating {
    func evaluateReadiness(for request: GuidanceRequest, analysis: SceneAnalysis, placement: PlacementRecommendation, pose: PoseRecommendation, settings: CameraSettingsRecommendation) -> CaptureReadiness {
        let hasSafeClutter = analysis.clutterScore >= 80
        let hasGoodDepth = analysis.depthScore >= 85
        let score = (hasSafeClutter ? 44 : 34) + (hasGoodDepth ? 38 : 28) + 16
        let state: ReadinessState = score >= 92 ? .ready : (score >= 80 ? .nearlyReady : .needsAdjustment)

        return CaptureReadiness(
            state: state,
            score: score,
            reasons: [
                placement.movementCue,
                pose.faceDirection,
                hasSafeClutter ? "Background clutter is acceptable." : "Reframe to remove passersby and bright signage."
            ],
            appleVisionSignals: [
                "AE/AF lock when faces are within \(Int(analysis.recommendedSubjectZone.normalizedWidth * 100))% target width.",
                "Flag highlight warning if bright stone patch overlaps the subject zone.",
                "Require all detected faces to remain above 0.82 confidence before shutter enable."
            ]
        )
    }
}

struct MockPostCaptureEditor: PostCaptureEditing {
    func buildEditPlan(for request: GuidanceRequest, analysis: SceneAnalysis, style: StyleExtraction) -> PostCaptureEditPlan {
        PostCaptureEditPlan(
            recipeName: "Editorial Warm Contrast",
            editSummary: "Recover highlights, add a warm paper bias, deepen architectural contrast, and keep skin natural.",
            brightnessDelta: 0.02,
            contrastDelta: 0.16,
            saturationDelta: 0.04,
            warmthDelta: 0.09,
            vignette: 0.12
        )
    }
}
