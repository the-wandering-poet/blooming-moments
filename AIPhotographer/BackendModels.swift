import Foundation

enum SceneInputKind: String, Codable {
    case scenePhoto
    case sceneVideo
}

enum SubjectScenarioKind: String, Codable {
    case single
    case couple
    case family
    case group
}

enum SubjectAction: String, Codable {
    case stand
    case sit
    case lean
    case walk
}

enum MovementDirection: String, Codable {
    case left
    case right
    case forward
    case backward
    case still
}

enum LensPreference: String, Codable {
    case ultraWide
    case wide
    case telephoto
}

enum ReadinessState: String, Codable {
    case needsAdjustment
    case nearlyReady
    case ready
}

struct CuratedPortfolio: Codable {
    let id: String
    let title: String
    let author: String
    let styleSummary: String
    let referenceImages: [PortfolioReferenceImage]
    let targetLook: PortfolioStyleLook
}

struct PortfolioReferenceImage: Codable {
    let assetName: String
    let notes: String
    let tags: [String]
}

struct PortfolioStyleLook: Codable {
    let landmarkScaleBias: Double
    let sideLightBias: Double
    let warmth: Double
    let contrast: Double
    let saturation: Double
    let framingBias: String
    let poseBias: String
}

struct SubjectProfileInput: Codable {
    let scenario: SubjectScenarioKind
    let subjectCount: Int
    let ageMix: String
    let mobilityNotes: [String]
}

struct SceneUpload: Codable {
    let id: UUID
    let kind: SceneInputKind
    let localImagePath: String
    let referenceVideoPath: String?
    let title: String
    let locationHint: String
}

struct GuidanceRequest: Codable {
    let portfolioId: String
    let subjectProfile: SubjectProfileInput
    let scene: SceneUpload
}

struct GuidanceRequestValidationError: Codable, Error {
    let message: String
}

extension GuidanceRequest {
    func validate() throws {
        guard !portfolioId.isEmpty else {
            throw GuidanceRequestValidationError(message: "portfolioId is required.")
        }
        guard subjectProfile.subjectCount > 0 else {
            throw GuidanceRequestValidationError(message: "subjectCount must be positive.")
        }
        guard !scene.localImagePath.isEmpty else {
            throw GuidanceRequestValidationError(message: "scene.localImagePath is required.")
        }
    }
}

struct SceneAnalysis: Codable {
    let sceneId: UUID
    let landmarkLabel: String
    let lightDirection: String
    let lightQuality: String
    let depthScore: Int
    let clutterScore: Int
    let skylineClearanceScore: Int
    let primaryWalkwayAngleDegrees: Double
    let recommendedSubjectZone: SubjectZone
    let cameraOrigin: CameraOrigin
    let appleVisionObservations: [VisionObservation]
    let notes: [String]
}

struct SubjectZone: Codable {
    let normalizedCenterX: Double
    let normalizedCenterY: Double
    let normalizedWidth: Double
    let normalizedHeight: Double
    let action: SubjectAction
    let movement: MovementDirection
    let distanceFromCameraMeters: Double
}

struct CameraOrigin: Codable {
    let normalizedX: Double
    let normalizedY: Double
    let heightMeters: Double
}

struct VisionObservation: Codable {
    let label: String
    let confidence: Double
    let normalizedRect: NormalizedRect
}

struct NormalizedRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct StyleExtraction: Codable {
    let styleId: String
    let compositionDirectives: [String]
    let lightingDirectives: [String]
    let poseDirectives: [String]
    let editingDirectives: [String]
}

struct PlacementRecommendation: Codable {
    let headline: String
    let subjectZone: SubjectZone
    let footPlacement: String
    let movementCue: String
}

struct PoseRecommendation: Codable {
    let headline: String
    let bodyArrangement: String
    let faceDirection: String
    let handPlacement: String
}

struct CompositionRecommendation: Codable {
    let framing: String
    let horizonTreatment: String
    let landmarkUsage: String
    let keepOutZones: [NormalizedRect]
}

struct CameraSettingsRecommendation: Codable {
    let lens: LensPreference
    let zoomFactor: Double
    let exposureBiasEV: Double
    let brightness: Double
    let contrast: Double
    let saturation: Double
    let whiteBalanceKelvin: Double
    let highlightProtection: String
    let focusDistanceMeters: Double
    let shutterSuggestion: String
    let stabilization: String
}

struct CaptureReadiness: Codable {
    let state: ReadinessState
    let score: Int
    let reasons: [String]
    let appleVisionSignals: [String]
}

struct PostCaptureEditPlan: Codable {
    let recipeName: String
    let editSummary: String
    let brightnessDelta: Double
    let contrastDelta: Double
    let saturationDelta: Double
    let warmthDelta: Double
    let vignette: Double
}

struct GuidanceResponse: Codable {
    let request: GuidanceRequest
    let styleExtraction: StyleExtraction
    let sceneAnalysis: SceneAnalysis
    let placement: PlacementRecommendation
    let pose: PoseRecommendation
    let composition: CompositionRecommendation
    let cameraSettings: CameraSettingsRecommendation
    let readiness: CaptureReadiness
    let postCaptureEdit: PostCaptureEditPlan
    let createdAt: Date
}

struct CaptureSessionRecord: Codable {
    let id: UUID
    let response: GuidanceResponse
    let guidedImagePath: String
    let editedImagePath: String
    let notes: [String]
}

enum BackendPreviewFactory {
    static let portfolio = CuratedPortfolio(
        id: "campus_editorial_graduation",
        title: "Campus Editorial Graduation",
        author: "Ann Li",
        styleSummary: "Landmark scale, motion-aware posing, and warm editorial contrast for campus portraits.",
        referenceImages: [
            PortfolioReferenceImage(assetName: "HooverTower", notes: "Hero landmark scale with tall vertical framing.", tags: ["landmark", "vertical", "warm"]),
            PortfolioReferenceImage(assetName: "ArchesWalk", notes: "Depth and motion through repeating arches.", tags: ["motion", "walkway", "depth"]),
            PortfolioReferenceImage(assetName: "StripedLight", notes: "Directional light with quiet negative space.", tags: ["dramatic light", "quiet background", "contrast"])
        ],
        targetLook: PortfolioStyleLook(
            landmarkScaleBias: 0.92,
            sideLightBias: 0.88,
            warmth: 0.16,
            contrast: 0.12,
            saturation: 0.06,
            framingBias: "subjects anchored near the lower middle third with architecture rising above",
            poseBias: "calm, confident, lightly interactive poses"
        )
    )

    static func defaultSceneTitle(for kind: SceneInputKind) -> String {
        switch kind {
        case .scenePhoto:
            return "Stanford sandstone arcade"
        case .sceneVideo:
            return "Stanford campus scout pass"
        }
    }
}
