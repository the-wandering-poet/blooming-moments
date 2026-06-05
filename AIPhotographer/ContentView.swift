import AVFoundation
import SwiftUI
import UIKit

enum AppStep {
    case welcome
    case scenarioSelect
    case portfolioList
    case portfolioDetail
    case subjectCalibration
    case sceneChoice
    case scanSurroundings
    case currentScene
    case sceneCalculating
    case liveCoach
    case finalShooting
    case preview
    case saved
}

enum AppTab {
    case home
    case invite
    case profile
}

enum AppSheet: Identifiable {
    case comments(CuratedPortfolio)
    case bookmark(CuratedPortfolio)
    case momentsSaved(count: Int, assets: [String])

    var id: String {
        switch self {
        case .comments(let portfolio):
            return "comments-\(portfolio.id)"
        case .bookmark(let portfolio):
            return "bookmark-\(portfolio.id)"
        case .momentsSaved(let count, let assets):
            return "moments-saved-\(count)-\(assets.joined(separator: "-"))"
        }
    }
}

enum SceneInputMethod: String {
    case scanSurroundings = "Scan surroundings"
    case currentScene = "Current scene"
}

enum SceneUploadStatus: Equatable {
    case empty
    case ready
    case failed(SceneUploadFailureReason)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

enum SceneUploadFailureReason: Equatable {
    case scanTooShort
    case scanTooFastOrBlurry
    case tooDark
    case uploadFailed
    case noUsableScene
    case photoUnavailable
    case overexposed
    case noCompositionSpace

    var message: String {
        switch self {
        case .scanTooShort:
            return "The scan was too short. Turn once slowly so Blooming can read the whole place."
        case .scanTooFastOrBlurry:
            return "The scan moved too fast or became blurry. Please retry with a slower turn."
        case .tooDark:
            return "The scene is too dark for a reliable recommendation. Try a brighter spot."
        case .uploadFailed:
            return "The upload did not complete. Check connection and try again."
        case .noUsableScene:
            return "Blooming could not find a usable scene. Try a nearby angle with more depth."
        case .photoUnavailable:
            return "The photo could not be analyzed. Please retake a steady scene photo."
        case .overexposed:
            return "The photo is overexposed. Try a softer angle away from harsh light."
        case .noCompositionSpace:
            return "There is not enough composition space for people. Step back or choose a wider frame."
        }
    }
}

struct PhotographyStyle {
    let id: String
    let title: String
    let author: String
    let assets: [String]
    let tags: [String]
}

struct PhotoScenario: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let heroAsset: String
    let tags: [String]
    let portfolios: [CuratedPortfolio]
}

struct CuratedPortfolio: Identifiable {
    let id: String
    let title: String
    let author: String
    let avatarAsset: String
    let photographerBio: String
    let locationSummary: String
    let styleSummary: String
    let assets: [String]
    let tags: [String]
    let shots: [PortfolioShot]
    let styleProfileId: String
    let styleProfileVersion: String
    let profileStatus: String
    let publishStatus: String
    let contentSource: String
}

struct PortfolioShot: Identifiable {
    let id: String
    let assetName: String
    let title: String
    let location: String
    let gesture: String
    let tags: [String]
}

struct PortfolioComment: Identifiable {
    let id = UUID()
    let userName: String
    let avatarAsset: String
    let text: String
    let timestamp: Date
}

struct SubjectProfile: Equatable {
    let subjectProfileId: String
    let selfieAssetRef: String
    let protectedSubjectSetId: String
    let protectedSubjectCount: Int
    let count: Int
    let readinessNotes: [String]
    let analysisSource: String
    let confidence: Double
    let protectedSubjectSet: SceneRuntimeModels.ProtectedSubjectSet?

    init(
        subjectProfileId: String = "subject_profile_local_ui_fallback",
        selfieAssetRef: String = "local_ui_subject_selfie",
        protectedSubjectSetId: String? = nil,
        protectedSubjectCount: Int? = nil,
        count: Int,
        readinessNotes: [String],
        analysisSource: String = PhoneTestSubjectAnalysisSource.deterministicSubjectFallback.rawValue,
        confidence: Double = 0.25,
        protectedSubjectSet: SceneRuntimeModels.ProtectedSubjectSet? = nil
    ) {
        let resolvedCount = max(0, protectedSubjectCount ?? count)
        self.subjectProfileId = subjectProfileId
        self.selfieAssetRef = selfieAssetRef
        self.protectedSubjectSetId = protectedSubjectSetId ?? "protected_subject_set_local_ui_\(resolvedCount)"
        self.protectedSubjectCount = resolvedCount
        self.count = resolvedCount
        self.readinessNotes = readinessNotes
        self.analysisSource = analysisSource
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.protectedSubjectSet = protectedSubjectSet
    }

    init(phoneTestProfile: PhoneTestSubjectProfile) {
        self.init(
            subjectProfileId: phoneTestProfile.subjectProfileId,
            selfieAssetRef: phoneTestProfile.selfieAssetRef,
            protectedSubjectSetId: phoneTestProfile.protectedSubjectSetId,
            protectedSubjectCount: phoneTestProfile.protectedSubjectCount,
            count: phoneTestProfile.protectedSubjectCount,
            readinessNotes: phoneTestProfile.visibilityReadinessNotes,
            analysisSource: phoneTestProfile.source.rawValue,
            confidence: phoneTestProfile.confidence,
            protectedSubjectSet: phoneTestProfile.protectedSubjectSet
        )
    }
}

struct PhoneTestSubjectCalibrationResult: Equatable {
    let profile: SubjectProfile
    let source: String
    let confidenceLabel: String

    static func fromAdapter(for image: UIImage, sessionId: String) -> PhoneTestSubjectCalibrationResult {
        SubjectSelfieVisionAnalyzer.calibrationResult(for: image, sessionId: sessionId)
    }
}

struct SceneCandidate {
    let title: String
    let reason: String
    let score: Int
    let assetName: String
}

struct CoachingCue: Identifiable {
    let id = UUID()
    let title: String
    let status: CueStatus
}

enum CueStatus {
    case pending
    case active
    case complete
}

struct SavedBloomingMoment: Identifiable {
    let id = UUID()
    let sceneTitle: String
    let assetName: String
    let isFineTuned: Bool
}

struct BookmarkFolder: Identifiable {
    let id: String
    var name: String
    var portfolioIds: Set<String>
}

struct PhoneTestFinalMomentABCResult {
    let requestBundle: FinalCaptureRendererRequestBundle
    let renderResult: CoreImageFineTuneRenderResult

    var imageA: UIImage {
        renderResult.originalImage
    }

    var imageB: UIImage {
        renderResult.croppedImage
    }

    var imageC: UIImage {
        renderResult.fineTunedImage
    }
}

private enum PhoneTestFinalCaptureFlowError: Error {
    case missingScenePlan
}

struct ContentView: View {
    private let scenarios = AppContent.scenarios
    private static let launchArguments = ProcessInfo.processInfo.arguments

    @State private var step: AppStep = .welcome
    @State private var selectedScenarioIndex = 0
    @State private var selectedPortfolioIndex = 0
    @State private var selectedShotIndex = 1
    @State private var subjectProfile: SubjectProfile?
    @State private var sceneInputMethod: SceneInputMethod = .scanSurroundings
    @State private var scanUploadStatus: SceneUploadStatus = .empty
    @State private var currentSceneUploadStatus: SceneUploadStatus = .empty
    @State private var allowsSuboptimalSceneInput = false
    @State private var sceneCandidate = SceneCandidate(
        title: "South arcade, late side light",
        reason: "Clean background, side light, enough depth.",
        score: 91,
        assetName: "ArchesWalk"
    )
    @State private var sceneRuntimeIntegration = SceneRuntimeFrontendNativeCoordinator.phoneTestCloudFirst()
    @State private var sceneRuntimeScenePlan: SceneRuntimeModels.GenerateScenePlanResponse?
    @State private var sceneRuntimeAnalysisState: SceneRuntimeSceneAnalysisDisplayState?
    @State private var sceneRuntimeLiveCoachState = SceneRuntimeLiveCoachUIState.waiting
    @State private var beforeCaptureRuntimeHandoff: SceneRuntimeModels.BeforeCaptureFinalMomentHandoff?
    @State private var phoneTestScenePlanOutput: PhoneTestScenePlanOutput?
    @State private var phoneTestLiveReadinessOutput: PhoneTestLiveReadinessOutput?
    @State private var subjectReferenceImage: UIImage?
    @State private var sceneReferenceImage: UIImage?
    @State private var sceneInputAnalysis: PhoneTestSceneInputAnalysisResult?
    @State private var finalCapturedPhotoA: UIImage?
    @State private var finalCaptureRenderHandoff: FinalCaptureRenderHandoff?
    @State private var finalCaptureErrorMessage: String?
    @State private var finalMomentABCResult: PhoneTestFinalMomentABCResult?
    @State private var finalMomentRendererErrorMessage: String?
    @State private var isFinalCaptureInProgress = false
    @State private var isReadyToCapture = false
    @State private var finalMomentService = FinalMomentLocalTestPipelineFacade()
    @State private var finalCaptureResult: FinalMomentCaptureResult?
    @State private var finalAutoCullResult: FinalMomentAutoCullResult?
    @State private var selectedKeeperFrameIds: Set<String> = []
    @State private var finalKeeperSelection: FinalMomentKeeperSelection?
    @State private var finalCropGenerationResult: FinalMomentCropGenerationResult?
    @State private var finalFineTuneResult: FinalMomentFineTuneResult?
    @State private var finalTuneDecisions: [String: FinalMomentSelectedOutput] = [:]
    @State private var finalSaveResult: FinalMomentSaveResult?
    @State private var hasSavedFineTuneSelection = false
    @State private var activeTab: AppTab = .home
    @State private var activeSheet: AppSheet?
    @State private var savedPortfolioIds: Set<String> = []
    @State private var likedPortfolioIds: Set<String> = []
    @State private var portfolioComments: [String: [PortfolioComment]] = [:]
    @State private var bookmarkFolders: [BookmarkFolder] = [
        BookmarkFolder(id: "graduation_inspiration", name: "Graduation Inspiration", portfolioIds: [])
    ]
    @State private var savedMoments: [SavedBloomingMoment] = []
    @State private var profileSessionReturnPayload: (count: Int, assets: [String])?

    init() {
        let args = Self.launchArguments
        if args.contains("--debug-subject-calibration") || args.contains("--debug-subject-calibration-uploaded") {
            _step = State(initialValue: .subjectCalibration)
        }
        if args.contains("--debug-scene-choice") {
            _step = State(initialValue: .sceneChoice)
        }
        if args.contains("--debug-portfolio-list") {
            _activeTab = State(initialValue: .home)
            _step = State(initialValue: .portfolioList)
            _selectedScenarioIndex = State(initialValue: 0)
            _selectedPortfolioIndex = State(initialValue: 0)
        }
        if args.contains("--debug-wedding-portfolio-list") {
            _activeTab = State(initialValue: .home)
            _step = State(initialValue: .portfolioList)
            _selectedScenarioIndex = State(initialValue: 1)
            _selectedPortfolioIndex = State(initialValue: 0)
        }
        if args.contains("--debug-parenthood-portfolio-list") {
            _activeTab = State(initialValue: .home)
            _step = State(initialValue: .portfolioList)
            _selectedScenarioIndex = State(initialValue: 2)
            _selectedPortfolioIndex = State(initialValue: 0)
        }
        if args.contains("--debug-scan-surroundings") {
            _step = State(initialValue: .scanSurroundings)
        }
        if args.contains("--debug-scan-failed") {
            _step = State(initialValue: .scanSurroundings)
            _sceneInputMethod = State(initialValue: .scanSurroundings)
            _scanUploadStatus = State(initialValue: .failed(.scanTooFastOrBlurry))
        }
        if args.contains("--debug-current-scene-failed") {
            _step = State(initialValue: .currentScene)
            _sceneInputMethod = State(initialValue: .currentScene)
            _currentSceneUploadStatus = State(initialValue: .failed(.overexposed))
        }
        if args.contains("--debug-scene-analysis") || args.contains("--debug-scene-analysis-failed") {
            _step = State(initialValue: .sceneCalculating)
        }
        if args.contains("--debug-live-coach") {
            _step = State(initialValue: .liveCoach)
        }
        if args.contains("--debug-keeper-selection") {
            _step = State(initialValue: .preview)
        }
        if args.contains("--debug-current-scene") {
            _step = State(initialValue: .currentScene)
            _sceneInputMethod = State(initialValue: .currentScene)
        }
        if args.contains("--debug-fine-tune-review") {
            _step = State(initialValue: .saved)
        }
        if args.contains("--debug-invite") {
            _activeTab = State(initialValue: .invite)
        }
        if args.contains("--debug-saved-sheet") {
            _step = State(initialValue: .saved)
            _hasSavedFineTuneSelection = State(initialValue: true)
            _activeSheet = State(initialValue: .momentsSaved(count: 3, assets: ["ArchesWalk", "HooverTower", "StripedLight"]))
        }
        if args.contains("--debug-profile") {
            _activeTab = State(initialValue: .profile)
            _savedPortfolioIds = State(initialValue: ["renee_graduation_training_set"])
            _bookmarkFolders = State(initialValue: [
                BookmarkFolder(id: "graduation_inspiration", name: "Graduation Inspiration", portfolioIds: ["renee_graduation_training_set"])
            ])
            _savedMoments = State(initialValue: [
                SavedBloomingMoment(sceneTitle: "Graduation", assetName: "HooverTower", isFineTuned: true),
                SavedBloomingMoment(sceneTitle: "Graduation", assetName: "ArchesWalk", isFineTuned: true),
                SavedBloomingMoment(sceneTitle: "Graduation", assetName: "StripedLight", isFineTuned: true),
                SavedBloomingMoment(sceneTitle: "Graduation", assetName: "HooverTower", isFineTuned: false),
                SavedBloomingMoment(sceneTitle: "Graduation", assetName: "ArchesWalk", isFineTuned: true),
                SavedBloomingMoment(sceneTitle: "Graduation", assetName: "StripedLight", isFineTuned: true)
            ])
        }
        if args.contains("--debug-subject-calibration-uploaded") {
            _subjectReferenceImage = State(initialValue: UIImage(named: "SubjectSelfieCleanReference") ?? DemoSelfieImage.make())
            _subjectProfile = State(initialValue: SubjectProfile(
                count: 2,
                readinessNotes: ["selfie uploaded", "face is clear", "ready for processing"]
            ))
        }
        if args.contains("--debug-keeper-selection") {
            _activeTab = State(initialValue: .home)
            _step = State(initialValue: .preview)
        }
        if args.contains("--debug-fine-tune-review") {
            _activeTab = State(initialValue: .home)
            _step = State(initialValue: .saved)
        }
        if args.contains("--debug-saved-sheet") {
            _activeTab = State(initialValue: .home)
            _step = State(initialValue: .saved)
            _hasSavedFineTuneSelection = State(initialValue: true)
            _activeSheet = State(initialValue: .momentsSaved(count: 3, assets: ["ArchesWalk", "HooverTower", "StripedLight"]))
        }
        if args.contains("--debug-keeper-selection") || args.contains("--debug-fine-tune-review") || args.contains("--debug-saved-sheet") {
            let service = FinalMomentMockService()
            if let bundle = try? service.makeDemoBundle() {
                _finalCaptureResult = State(initialValue: bundle.captureResult)
                _finalAutoCullResult = State(initialValue: bundle.autoCullResult)
                _finalKeeperSelection = State(initialValue: bundle.keeperSelection)
                _finalCropGenerationResult = State(initialValue: bundle.cropGenerationResult)
                _finalFineTuneResult = State(initialValue: bundle.fineTuneResult)
                _selectedKeeperFrameIds = State(initialValue: Set(bundle.keeperSelection.selectedFrameIds))
                if args.contains("--debug-fine-tune-review") || args.contains("--debug-saved-sheet") {
                    _finalTuneDecisions = State(initialValue: Dictionary(
                        uniqueKeysWithValues: bundle.fineTuneResult.items.map { ($0.frameId, FinalMomentSelectedOutput.edited) }
                    ))
                }
                if args.contains("--debug-saved-sheet") {
                    _finalSaveResult = State(initialValue: bundle.saveResult)
                }
            }
        }
    }

    private var selectedScenario: PhotoScenario {
        scenarios[min(selectedScenarioIndex, scenarios.count - 1)]
    }

    private var selectedPortfolio: CuratedPortfolio {
        selectedScenario.portfolios[min(selectedPortfolioIndex, selectedScenario.portfolios.count - 1)]
    }

    private var selectedShot: PortfolioShot {
        selectedPortfolio.shots[min(selectedShotIndex, selectedPortfolio.shots.count - 1)]
    }

    private var style: PhotographyStyle {
        PhotographyStyle(
            id: selectedPortfolio.id,
            title: selectedPortfolio.title,
            author: selectedPortfolio.author,
            assets: selectedPortfolio.assets,
            tags: selectedPortfolio.tags
        )
    }

    private var allPortfolios: [CuratedPortfolio] {
        var seen = Set<String>()
        return scenarios
            .flatMap(\.portfolios)
            .filter { seen.insert($0.id).inserted }
    }

    private var savedPortfolios: [CuratedPortfolio] {
        allPortfolios.filter { savedPortfolioIds.contains($0.id) }
    }

    private var showsBottomNavigation: Bool {
        switch activeTab {
        case .invite, .profile:
            return true
        case .home:
            switch step {
            case .portfolioDetail:
                return true
            case .welcome, .scenarioSelect, .subjectCalibration, .sceneChoice, .scanSurroundings, .currentScene, .sceneCalculating, .liveCoach, .finalShooting, .preview, .saved:
                return false
            default:
                return true
            }
        }
    }

    private var systemSheetBinding: Binding<AppSheet?> {
        Binding(
            get: {
                if case .momentsSaved = activeSheet {
                    return nil
                }
                return activeSheet
            },
            set: { newValue in
                if let newValue {
                    activeSheet = newValue
                } else {
                    switch activeSheet {
                    case .comments, .bookmark:
                        activeSheet = nil
                    case .momentsSaved, nil:
                        break
                    }
                }
            }
        )
    }

    var body: some View {
        ZStack {
            MemoryBackdrop()

            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(AppPalette.ivory)
                    .animation(.spring(response: 0.38, dampingFraction: 0.86), value: step)
                    .animation(.spring(response: 0.34, dampingFraction: 0.88), value: activeTab)

                if showsBottomNavigation {
                    AppBottomNavigationBar(
                        activeTab: $activeTab,
                        avatarAsset: "HooverTower",
                        homeAction: {
                            activeTab = .home
                            profileSessionReturnPayload = nil
                            step = .welcome
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if case .momentsSaved(let count, let assets) = activeSheet {
                MomentsSavedOverlay(
                    savedCount: count,
                    savedAssets: assets,
                    viewProfileAction: {
                        showSavedBloomingMoments(count: count, assets: assets)
                    },
                    takeMoreAction: takeMorePhotosAfterSave,
                    dismissAction: {
                        activeSheet = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(step == .welcome)
        .sheet(item: systemSheetBinding) { sheet in
            switch sheet {
            case .comments(let portfolio):
                CommentSheetView(
                    portfolio: portfolio,
                    avatarAsset: "HooverTower",
                    comments: portfolioComments[portfolio.id, default: []],
                    postAction: addComment
                )
                    .presentationDetents([.fraction(0.58), .large])
                    .presentationDragIndicator(.visible)
            case .bookmark(let portfolio):
                BookmarkSheetView(
                    portfolio: portfolio,
                    folders: $bookmarkFolders,
                    saveAction: savePortfolio
                )
                .presentationDetents([.fraction(0.48), .medium])
                .presentationDragIndicator(.visible)
            case .momentsSaved:
                EmptyView()
            }
        }
    }

    private func showSavedBloomingMoments(count: Int, assets: [String]) {
        activeSheet = nil
        profileSessionReturnPayload = (count: count, assets: assets)
        activeTab = .profile
    }

    private func takeMorePhotosAfterSave() {
        activeSheet = nil
        profileSessionReturnPayload = nil
        resetCaptureState(clearSubject: false)
        activeTab = .home
        step = .sceneChoice
    }

    private func returnFromProfileToSavedSession() {
        guard let payload = profileSessionReturnPayload else { return }
        activeTab = .home
        step = .saved
        activeSheet = .momentsSaved(count: payload.count, assets: payload.assets)
        profileSessionReturnPayload = nil
    }

    private func resetCaptureState(clearSubject: Bool) {
        finalCaptureResult = nil
        finalAutoCullResult = nil
        selectedKeeperFrameIds = []
        finalKeeperSelection = nil
        finalCropGenerationResult = nil
        finalFineTuneResult = nil
        finalTuneDecisions = [:]
        finalSaveResult = nil
        hasSavedFineTuneSelection = false
        isReadyToCapture = false
        sceneReferenceImage = nil
        sceneInputAnalysis = nil
        phoneTestScenePlanOutput = nil
        phoneTestLiveReadinessOutput = nil
        finalCapturedPhotoA = nil
        finalCaptureRenderHandoff = nil
        finalCaptureErrorMessage = nil
        finalMomentABCResult = nil
        finalMomentRendererErrorMessage = nil
        isFinalCaptureInProgress = false
        if clearSubject {
            subjectProfile = nil
            subjectReferenceImage = nil
        }
    }

    private func resetSceneRuntimeBeforeCaptureState() {
        sceneRuntimeScenePlan = nil
        sceneRuntimeAnalysisState = nil
        sceneRuntimeLiveCoachState = .waiting
        beforeCaptureRuntimeHandoff = nil
        sceneReferenceImage = nil
        sceneInputAnalysis = nil
        phoneTestScenePlanOutput = nil
        phoneTestLiveReadinessOutput = nil
        finalCapturedPhotoA = nil
        finalCaptureRenderHandoff = nil
        finalCaptureErrorMessage = nil
        finalMomentABCResult = nil
        finalMomentRendererErrorMessage = nil
        isFinalCaptureInProgress = false
        isReadyToCapture = false
    }

    private func buildSceneRuntimePlan() async throws -> SceneRuntimeModels.GenerateScenePlanResponse {
        let qualityContext = sceneRuntimeQualitySignals()
        let uploadFailureReason = sceneRuntimeUploadFailureReason()
        let fallbackPlanOutput = sceneInputAnalysis.flatMap { PhoneTestSubjectSceneAnalysisAdapter.scenePlan(from: $0) }
        let context = sceneInputAnalysis?.captureContext ?? SceneRuntimeFrontendCaptureContext(
            sessionId: "session_\(selectedScenario.id)_before_capture",
            styleProfileId: selectedPortfolio.styleProfileId,
            protectedSubjectSetId: subjectProfile?.protectedSubjectSetId ?? "protected_subject_set_1",
            sceneInputAttemptId: "attempt_\(selectedScenario.id)_\(sceneInputMethod == .scanSurroundings ? "scan" : "photo")",
            sceneInputMode: sceneInputMethod == .scanSurroundings ? .scanVideo : .singlePhoto,
            mediaRefs: ["local_test://scene-runtime/\(sceneCandidate.assetName)"],
            uploadAnyway: allowsSuboptimalSceneInput,
            qualitySignals: qualityContext,
            uploadFailureReason: uploadFailureReason
        )

        do {
            return try await sceneRuntimeIntegration.ingestAndGenerateScenePlan(context: context)
        } catch {
            if let fallbackPlanOutput {
                return fallbackPlanOutput.scenePlan
            }
            throw error
        }
    }

    private func handleCurrentScenePhotoCapture(_ image: UIImage) {
        sceneInputMethod = .currentScene
        currentSceneUploadStatus = .ready
        allowsSuboptimalSceneInput = false
        sceneReferenceImage = image
        analyzeSceneInputImage(image, mode: .singlePhoto, uploadAnyway: false)
    }

    private func handleScanSurroundingsCapture(_ image: UIImage) {
        sceneInputMethod = .scanSurroundings
        scanUploadStatus = .ready
        allowsSuboptimalSceneInput = false
        sceneReferenceImage = image
        analyzeSceneInputImage(image, mode: .scanVideo, uploadAnyway: false)
    }

    private func continueFromCurrentScene(uploadAnyway: Bool) {
        allowsSuboptimalSceneInput = uploadAnyway
        if uploadAnyway, let sceneReferenceImage {
            analyzeSceneInputImage(sceneReferenceImage, mode: .singlePhoto, uploadAnyway: true)
        }
        step = .sceneCalculating
    }

    private func analyzeSceneInputImage(
        _ image: UIImage,
        mode: SceneRuntimeModels.SceneInputMode,
        uploadAnyway: Bool
    ) {
        let hasRenderableImage = image.size.width > 0 && image.size.height > 0
        let protectedSubjectSetId = subjectProfile?.protectedSubjectSetId ?? "protected_subject_set_1"
        let sceneMediaRefPrefix = mode == .scanVideo ? "phone-test-scene-scan-frame" : "phone-test-scene-photo"
        let sceneMediaRef = "\(sceneMediaRefPrefix)://\(UUID().uuidString.lowercased())"
        sceneInputAnalysis = PhoneTestSubjectSceneAnalysisAdapter.sceneInputAnalysis(
            from: PhoneTestSceneInputSignals(
                source: .iosSceneHeuristic,
                sceneMediaRef: sceneMediaRef,
                sceneInputMode: mode,
                uploadAnyway: uploadAnyway,
                qualitySignals: sceneRuntimeQualitySignals(),
                failureReason: sceneRuntimeUploadFailureReason(),
                candidateTitle: sceneCandidate.title,
                candidateNotes: [
                    mode == .scanVideo
                        ? "surroundings scan captured from native back camera as a representative scene frame"
                        : "scene photo captured from native back camera",
                    "not reused from subject selfie",
                    "styleProfileId = \(selectedPortfolio.styleProfileId)",
                    "protectedSubjectSetId = \(protectedSubjectSetId)"
                ],
                confidence: hasRenderableImage ? 0.35 : 0.05
            ),
            sessionId: "session_\(selectedScenario.id)_scene_input",
            styleProfileId: selectedPortfolio.styleProfileId,
            protectedSubjectSetId: protectedSubjectSetId
        )
    }

    private func resolvedPhoneTestScenePlanOutput() -> PhoneTestScenePlanOutput? {
        if let phoneTestScenePlanOutput {
            return phoneTestScenePlanOutput
        }
        guard let sceneInputAnalysis else {
            return nil
        }
        return PhoneTestSubjectSceneAnalysisAdapter.scenePlan(from: sceneInputAnalysis)
    }

    private func storeScenePlanForLiveShooting(_ scenePlan: SceneRuntimeModels.GenerateScenePlanResponse) {
        if let sceneInputAnalysis,
           scenePlan.fallback != nil,
           let scenePlanOutput = PhoneTestSubjectSceneAnalysisAdapter.scenePlan(from: sceneInputAnalysis) {
            phoneTestScenePlanOutput = scenePlanOutput
        } else {
            phoneTestScenePlanOutput = nil
        }
        sceneRuntimeScenePlan = scenePlan
        sceneRuntimeAnalysisState = SceneRuntimeSceneAnalysisDisplayState(scenePlan: scenePlan)
        sceneRuntimeLiveCoachState = SceneRuntimeLiveCoachUIState(scenePlan: scenePlan)
        phoneTestLiveReadinessOutput = nil
        beforeCaptureRuntimeHandoff = nil
        finalCapturedPhotoA = nil
        finalCaptureRenderHandoff = nil
        finalCaptureErrorMessage = nil
        isReadyToCapture = false
    }

    @MainActor
    private func makeConservativeLiveReadinessState(
        for scenePlan: SceneRuntimeModels.GenerateScenePlanResponse
    ) async throws -> SceneRuntimeLiveCoachUIState {
        if let scenePlanOutput = resolvedPhoneTestScenePlanOutput() {
            phoneTestScenePlanOutput = scenePlanOutput
            let liveReadiness = try await PhoneTestFrameSignalAdapter.noVisionLiveReadiness(
                scenePlanOutput: scenePlanOutput,
                nativeCapabilities: PhoneTestFrameSignalAdapter.conservativeFallbackCapabilities(),
                bestEffortAllowed: true
            )
            phoneTestLiveReadinessOutput = liveReadiness
            let state = SceneRuntimeLiveCoachUIState(response: liveReadiness.response)
            sceneRuntimeLiveCoachState = state
            isReadyToCapture = state.isReadyToCapture
            return state
        }

        let state = try await sceneRuntimeIntegration.evaluateLiveFrame(
            scenePlan: scenePlan,
            liveFrameSummary: PhoneTestFrameSignalAdapter.noVisionDataFallback()
        )
        sceneRuntimeLiveCoachState = state
        isReadyToCapture = state.isReadyToCapture
        return state
    }

    @MainActor
    private func runSceneRuntimeReadiness() async {
        guard let scenePlan = sceneRuntimeScenePlan else { return }
        do {
            _ = try await makeConservativeLiveReadinessState(for: scenePlan)
        } catch {
            sceneRuntimeLiveCoachState = .waiting
            isReadyToCapture = false
        }
    }

    @MainActor
    private func buildFinalCaptureHandoff() async throws -> SceneRuntimeModels.BeforeCaptureFinalMomentHandoff {
        guard let scenePlan = sceneRuntimeScenePlan else {
            throw PhoneTestFinalCaptureFlowError.missingScenePlan
        }

        let liveState = sceneRuntimeLiveCoachState.response == nil
            ? try await makeConservativeLiveReadinessState(for: scenePlan)
            : sceneRuntimeLiveCoachState
        return try await sceneRuntimeIntegration.buildCaptureHandoff(
            scenePlan: scenePlan,
            liveCoachState: liveState
        )
    }

    @MainActor
    private func prepareFinalShootingCamera() async {
        guard !isFinalCaptureInProgress else { return }
        isFinalCaptureInProgress = true
        await runFinalCapturePreparation {
            step = .finalShooting
        }
        isFinalCaptureInProgress = false
    }

    @MainActor
    private func captureFinalPhotoFromLiveCoach() async {
        guard !isFinalCaptureInProgress else { return }
        isFinalCaptureInProgress = true
        await runFinalCapturePreparation {
            let image = UIImage(named: sceneCandidate.assetName) ?? sceneReferenceImage ?? DemoSelfieImage.make()
            handleFinalPhotoCapture(image)
        }
        isFinalCaptureInProgress = false
    }

    @MainActor
    private func runFinalCapturePreparation(onPrepared: () -> Void) async {
        do {
            let handoff = try await buildFinalCaptureHandoff()
            beforeCaptureRuntimeHandoff = handoff
            finalCapturedPhotoA = nil
            finalCaptureRenderHandoff = nil
            finalCaptureErrorMessage = nil
            finalMomentABCResult = nil
            finalMomentRendererErrorMessage = nil
            onPrepared()
        } catch {
            if let handoff = makeDemoBestEffortHandoff() {
                beforeCaptureRuntimeHandoff = handoff
                finalCapturedPhotoA = nil
                finalCaptureRenderHandoff = nil
                finalCaptureErrorMessage = nil
                finalMomentABCResult = nil
                finalMomentRendererErrorMessage = nil
                onPrepared()
            } else {
                finalCaptureErrorMessage = "Final shooting handoff could not be prepared from the current scene plan."
                isReadyToCapture = false
            }
        }
    }

    private func makeDemoBestEffortHandoff() -> SceneRuntimeModels.BeforeCaptureFinalMomentHandoff? {
        guard let scenePlan = sceneRuntimeScenePlan else { return nil }
        let recommendation = scenePlan.initialCameraSettingsRecommendation
        let capturedAffordanceMetadata = sceneRuntimeLiveCoachState.response?.capturedAffordanceMetadata
            ?? SceneRuntimeModels.CapturedAffordanceMetadata(
                protectedSubjectFocusReady: false,
                faceExposureUsable: false,
                rimHairEdgeLightPreserved: nil,
                naturalExpressionOrInteractionObserved: false,
                cropHeadroomPreserved: false,
                postCaptureFineTuneEligible: scenePlan.postCapturePrerequisites.canFineTuneLater ?? [],
                weakPrerequisites: scenePlan.postCapturePrerequisites.mustCaptureCorrectly
            )
        let statusAtCapture = sceneRuntimeLiveCoachState.response?.postCapturePrerequisiteStatus
            ?? Dictionary(uniqueKeysWithValues: scenePlan.postCapturePrerequisites.mustCaptureCorrectly.map {
                ($0.rawValue, "best_effort_demo")
            })
        let settingsUsed = SceneRuntimeModels.CameraSettingsUsed(
            settingsId: "camera_settings_used_demo_\(scenePlan.scenePlanId)",
            appliedRecommendationId: recommendation.recommendationId,
            focusModeUsed: recommendation.focus.mode,
            focusPointStrategyUsed: recommendation.focus.focusPointStrategy,
            focusStatus: .needsOperatorAdjustment,
            exposureMeteringTargetUsed: recommendation.exposure.meteringTarget,
            exposureBiasUsed: recommendation.exposure.bias,
            exposureStatus: .needsOperatorAdjustment,
            whiteBalanceModeUsed: recommendation.whiteBalance.mode,
            whiteBalanceStatus: .pending,
            lensUsed: recommendation.zoomLens?.preferredLens,
            zoomFactorUsed: recommendation.zoomLens?.targetZoomFactor,
            zoomLensStatus: .pending,
            depthModeUsed: recommendation.depth?.mode,
            depthDataDeliveryUsed: recommendation.depth?.depthDataDeliveryPreferred,
            portraitEffectsMatteUsed: recommendation.depth?.portraitEffectsMattePreferred,
            depthStatus: recommendation.depth == nil ? .unavailable : .pending,
            photoQualityPrioritizationUsed: recommendation.capture?.photoQualityPrioritization,
            burstCountRequested: recommendation.capture?.burstCount,
            burstCountCaptured: nil,
            highestPracticalResolutionUsed: recommendation.capture?.highestPracticalResolution,
            flashModeUsed: recommendation.flashLowLight?.flashMode,
            lowLightPolicyUsed: recommendation.flashLowLight?.lowLightRecoveryPolicy,
            capabilityGaps: ["live_readiness_blocked_demo_best_effort"],
            substitutions: nil
        )
        return SceneRuntimeModels.BeforeCaptureFinalMomentHandoff(
            scenePlanId: scenePlan.scenePlanId,
            styleProfileId: scenePlan.styleProfileId,
            protectedSubjectSetId: scenePlan.protectedSubjectSetId,
            sceneInputQualityContext: scenePlan.sceneInputQualityContext,
            initialCameraSettingsRecommendation: recommendation,
            runtimeAffordanceSignals: scenePlan.runtimeAffordanceSignals,
            postCapturePrerequisites: SceneRuntimeModels.PostCapturePrerequisites(
                mustCaptureCorrectly: scenePlan.postCapturePrerequisites.mustCaptureCorrectly,
                canFineTuneLater: scenePlan.postCapturePrerequisites.canFineTuneLater,
                statusAtCapture: statusAtCapture
            ),
            capturedAffordanceMetadata: capturedAffordanceMetadata,
            cameraSettingsUsed: settingsUsed,
            persistenceWriteIntent: ["demo_best_effort_before_capture_handoff"]
        )
    }

    private func handleFinalPhotoCapture(_ image: UIImage) {
        guard let beforeCaptureRuntimeHandoff else {
            finalCaptureErrorMessage = "Missing scene-plan handoff for final capture."
            return
        }
        let finalMomentHandoff = FinalMomentLocalTestPipelineFacade.convert(
            sceneRuntimeHandoff: beforeCaptureRuntimeHandoff,
            styleProfileVersion: selectedPortfolio.styleProfileVersion
        )
        let captureResultId = "capture_result_\(sanitizedPhoneTestId(beforeCaptureRuntimeHandoff.scenePlanId))"
        let assetRef = finalCapturedAssetRef(
            image: image,
            captureResultId: captureResultId
        )
        finalCapturedPhotoA = image
        finalCaptureRenderHandoff = FinalCaptureRenderHandoff(
            finalCapturedImage: image,
            finalCapturedAssetRef: assetRef,
            captureResultId: captureResultId,
            scenePlanId: finalMomentHandoff.scenePlanId,
            styleProfileId: finalMomentHandoff.styleProfileId,
            protectedSubjectSetId: finalMomentHandoff.protectedSubjectSetId,
            sceneInputQualityContext: finalMomentHandoff.sceneInputQualityContext,
            capturedAffordanceMetadata: finalMomentHandoff.capturedAffordanceMetadata,
            cameraSettingsUsed: finalMomentHandoff.cameraSettingsUsed
        )
        if let finalCaptureRenderHandoff {
            renderFinalMomentABC(from: finalCaptureRenderHandoff)
        }
        finalCaptureErrorMessage = nil
        startFinalMomentCapture()
    }

    private func renderFinalMomentABC(from handoff: FinalCaptureRenderHandoff) {
        do {
            let bundle = try handoff.makeRendererRequestBundle()
            let renderResult = try CoreImageFineTuneRenderer().render(bundle.request)
            finalMomentABCResult = PhoneTestFinalMomentABCResult(
                requestBundle: bundle,
                renderResult: renderResult
            )
            finalMomentRendererErrorMessage = nil
        } catch {
            finalMomentABCResult = nil
            finalMomentRendererErrorMessage = rendererFailureMessage(error)
        }
    }

    private func rendererFailureMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "Local CoreImage renderer could not create the crop and fine-tune images."
    }

    private func finalCapturedAssetRef(
        image: UIImage,
        captureResultId: String
    ) -> FinalMomentAssetRef {
        let width = max(1, Int((image.size.width * image.scale).rounded()))
        let height = max(1, Int((image.size.height * image.scale).rounded()))
        let assetId = "asset_\(captureResultId)_final_a"
        return FinalMomentAssetRef(
            assetId: assetId,
            uri: "phone-test-final-capture://\(assetId)",
            role: .original,
            width: width,
            height: height,
            mimeType: "image/jpeg"
        )
    }

    private func sanitizedPhoneTestId(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let identifier = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return identifier.isEmpty ? "phone_test" : identifier
    }

    private func sceneRuntimeQualitySignals() -> SceneRuntimeModels.SceneInputQualitySignals {
        let failure = sceneInputMethod == .scanSurroundings ? scanUploadStatus : currentSceneUploadStatus
        switch failure {
        case .failed(.scanTooShort):
            return SceneRuntimeModels.SceneInputQualitySignals(
                tooDark: false,
                overexposed: false,
                motionBlur: false,
                scanTooShort: true,
                noUsefulCompositionSpace: false,
                uploadFailed: false
            )
        case .failed(.scanTooFastOrBlurry):
            return SceneRuntimeModels.SceneInputQualitySignals(
                tooDark: false,
                overexposed: false,
                motionBlur: true,
                scanTooShort: false,
                noUsefulCompositionSpace: false,
                uploadFailed: false
            )
        case .failed(.tooDark):
            return SceneRuntimeModels.SceneInputQualitySignals(
                tooDark: true,
                overexposed: false,
                motionBlur: false,
                scanTooShort: false,
                noUsefulCompositionSpace: false,
                uploadFailed: false
            )
        case .failed(.overexposed):
            return SceneRuntimeModels.SceneInputQualitySignals(
                tooDark: false,
                overexposed: true,
                motionBlur: false,
                scanTooShort: false,
                noUsefulCompositionSpace: false,
                uploadFailed: false
            )
        case .failed(.noUsableScene), .failed(.noCompositionSpace):
            return SceneRuntimeModels.SceneInputQualitySignals(
                tooDark: false,
                overexposed: false,
                motionBlur: false,
                scanTooShort: false,
                noUsefulCompositionSpace: true,
                uploadFailed: false
            )
        case .failed(.uploadFailed), .failed(.photoUnavailable):
            return SceneRuntimeModels.SceneInputQualitySignals(
                tooDark: false,
                overexposed: false,
                motionBlur: false,
                scanTooShort: false,
                noUsefulCompositionSpace: false,
                uploadFailed: true
            )
        case .empty, .ready:
            return .empty
        }
    }

    private func sceneRuntimeUploadFailureReason() -> SceneRuntimeModels.SceneInputFailureReason? {
        let failure = sceneInputMethod == .scanSurroundings ? scanUploadStatus : currentSceneUploadStatus
        guard case .failed(let reason) = failure else { return nil }
        return SceneRuntimeModels.SceneInputFailureReason(
            code: sceneRuntimeFailureCode(reason),
            message: reason.message,
            retryAction: sceneInputMethod == .scanSurroundings ? "Retry scene scan." : "Retake scene photo.",
            uploadAnywayChosen: allowsSuboptimalSceneInput
        )
    }

    private func sceneRuntimeFailureCode(_ reason: SceneUploadFailureReason) -> String {
        switch reason {
        case .scanTooShort:
            return "scene_input_too_short"
        case .scanTooFastOrBlurry:
            return "scene_input_motion_blur"
        case .tooDark:
            return "scene_input_too_dark"
        case .uploadFailed, .photoUnavailable:
            return "scene_input_upload_failed"
        case .noUsableScene, .noCompositionSpace:
            return "no_useful_scene_candidate"
        case .overexposed:
            return "scene_input_overexposed"
        }
    }

    private func startFinalMomentCapture() {
        let runtimeHandoff = beforeCaptureRuntimeHandoff.map {
            FinalMomentLocalTestPipelineFacade.convert(
                sceneRuntimeHandoff: $0,
                styleProfileVersion: selectedPortfolio.styleProfileVersion
            )
        } ?? FinalMomentLocalTestPipelineFacade.localTestRuntimeHandoff(
            styleProfileId: selectedPortfolio.styleProfileId,
            styleProfileVersion: selectedPortfolio.styleProfileVersion,
            protectedSubjectCount: subjectProfile?.protectedSubjectCount ?? 1
        )
        let request = FinalMomentCaptureRequest(
            context: FinalMomentCaptureContext(
                sessionId: "session_\(selectedScenario.id)_local_test",
                scenarioId: selectedScenario.id,
                sceneTitle: selectedScenario.title,
                sourcePortfolioId: selectedPortfolio.id
            ),
            runtimeHandoff: runtimeHandoff
        )

        do {
            let capture = try finalMomentService.recordCaptureResult(request: request)
            let autoCull = try finalMomentService.autoCullFrames(
                FinalMomentAutoCullRequest(
                    captureResultId: capture.captureResultId,
                    protectedSubjectSetId: capture.protectedSubjectSetId
                )
            )

            finalCaptureResult = capture
            finalAutoCullResult = autoCull
            selectedKeeperFrameIds = []
            finalKeeperSelection = nil
            finalCropGenerationResult = nil
            finalFineTuneResult = nil
            finalTuneDecisions = [:]
            finalSaveResult = nil
            hasSavedFineTuneSelection = false
            step = .preview
        } catch {
            finalCaptureResult = nil
            finalAutoCullResult = nil
            finalCaptureErrorMessage = "Final capture could not be prepared. Please check the scene again."
            isReadyToCapture = false
        }
    }

    private func prepareFinalFineTuneReview() {
        guard let capture = finalCaptureResult, let autoCull = finalAutoCullResult else {
            startFinalMomentCapture()
            return
        }

        let selectedFrameIds = autoCull.acceptedFrames
            .map(\.frameId)
            .filter { selectedKeeperFrameIds.contains($0) }
        guard !selectedFrameIds.isEmpty else { return }

        do {
            let keeper = try finalMomentService.createKeeperSelection(
                FinalMomentKeeperSelectionRequest(
                    autoCullResultId: autoCull.autoCullResultId,
                    selectedFrameIds: selectedFrameIds
                )
            )
            let crops = try finalMomentService.generateInternalCrops(
                FinalMomentCropGenerationRequest(
                    keeperSelectionId: keeper.keeperSelectionId,
                    styleProfileId: capture.styleProfileId,
                    scenePlanId: capture.scenePlanId,
                    runtimeAffordanceSignals: capture.runtimeAffordanceSignals,
                    capturedAffordanceMetadata: capture.capturedAffordanceMetadata,
                    postCapturePrerequisites: capture.postCapturePrerequisites,
                    cameraSettingsUsed: capture.cameraSettingsUsed
                )
            )
            let fineTune = try finalMomentService.prepareFineTuneReview(
                FinalMomentFineTuneRequest(
                    keeperSelectionId: keeper.keeperSelectionId,
                    cropGenerationResultId: crops.cropGenerationResultId,
                    styleProfileId: capture.styleProfileId,
                    styleProfileVersion: capture.cameraSettingsIntentSnapshot.styleProfileVersion,
                    runtimeAffordanceSignals: capture.runtimeAffordanceSignals,
                    capturedAffordanceMetadata: capture.capturedAffordanceMetadata,
                    cameraSettingsUsed: capture.cameraSettingsUsed
                )
            )
            finalKeeperSelection = keeper
            finalCropGenerationResult = crops
            finalFineTuneResult = fineTune
            finalTuneDecisions = [:]
            hasSavedFineTuneSelection = false
            step = .saved
        } catch {
            selectedKeeperFrameIds = []
        }
    }

    private func saveFinalMomentSelection() {
        guard let fineTune = finalFineTuneResult, !hasSavedFineTuneSelection else { return }
        let decisions = fineTune.items.compactMap { item -> FinalMomentPhotoDecision? in
            guard let selectedOutput = finalTuneDecisions[item.frameId] else { return nil }
            return FinalMomentPhotoDecision(frameId: item.frameId, selectedOutput: selectedOutput)
        }
        guard !decisions.isEmpty else { return }

        do {
            let saveResult = try finalMomentService.saveMoment(
                FinalMomentSaveRequest(
                    fineTuneResultId: fineTune.fineTuneResultId,
                    decisions: decisions
                )
            )
            finalSaveResult = saveResult
            let savedSelection = saveResult.savedMoments.map(adaptSavedMoment)
            savedMoments = Array((savedSelection + savedMoments).prefix(30))
            hasSavedFineTuneSelection = true
            isReadyToCapture = false
            activeSheet = .momentsSaved(
                count: saveResult.savedConfirmation.savedCount,
                assets: saveResult.savedConfirmation.savedAssets.map { displayAssetName(for: $0) }
            )
        } catch {
            hasSavedFineTuneSelection = false
        }
    }

    private func adaptSavedMoment(_ moment: FinalMomentSavedMoment) -> SavedBloomingMoment {
        SavedBloomingMoment(
            sceneTitle: moment.sceneTitle,
            assetName: displayAssetName(for: moment.finalAssetRef),
            isFineTuned: moment.isFineTuned
        )
    }

    private var finalMomentDisplayAssets: [String] {
        let assets = Array((selectedPortfolio.assets + selectedPortfolio.shots.map(\.assetName)).prefix(6))
        return assets.isEmpty ? ["HooverTower"] : assets
    }

    private func displayAssetName(for assetRef: FinalMomentAssetRef) -> String {
        let source = "\(assetRef.assetId)-\(assetRef.uri)"
        guard let frameIndex = localTestFrameIndex(from: source) else {
            return finalMomentDisplayAssets[0]
        }
        return finalMomentDisplayAssets[frameIndex % finalMomentDisplayAssets.count]
    }

    private func localTestFrameIndex(from source: String) -> Int? {
        for marker in ["frame_local_test_", "asset_local_test_", "frame_demo_", "asset_demo_"] {
            guard let range = source.range(of: marker) else { continue }
            let suffix = source[range.upperBound...]
            let numericRuns = suffix.split { !$0.isNumber }
            guard let frameNumberText = numericRuns.last,
                  let number = Int(frameNumberText),
                  number > 0 else {
                continue
            }
            return number - 1
        }
        return nil
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .home:
            content
        case .invite:
            InviteView()
        case .profile:
            ProfileView(
                savedPortfolios: savedPortfolios,
                bookmarkFolders: $bookmarkFolders,
                savedMoments: $savedMoments,
                avatarAsset: "HooverTower",
                deleteFolderAction: deleteBookmarkFolder,
                removeSavedPortfolioAction: removeSavedPortfolio,
                sessionBackAction: profileSessionReturnPayload == nil ? nil : returnFromProfileToSavedSession,
                openPortfolioAction: openPortfolioFromProfile
            )
        }
    }

    private func savePortfolio(_ portfolio: CuratedPortfolio, to folderId: String?) {
        savedPortfolioIds.insert(portfolio.id)
        guard let folderId else { return }
        if let index = bookmarkFolders.firstIndex(where: { $0.id == folderId }) {
            bookmarkFolders[index].portfolioIds.insert(portfolio.id)
        }
    }

    private func addComment(_ text: String, to portfolio: CuratedPortfolio) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let comment = PortfolioComment(
            userName: "You",
            avatarAsset: "HooverTower",
            text: trimmedText,
            timestamp: Date()
        )
        portfolioComments[portfolio.id, default: []].append(comment)
    }

    private func deleteBookmarkFolder(_ folder: BookmarkFolder) {
        bookmarkFolders.removeAll { $0.id == folder.id }
    }

    private func removeSavedPortfolio(_ portfolio: CuratedPortfolio) {
        savedPortfolioIds.remove(portfolio.id)
        for index in bookmarkFolders.indices {
            bookmarkFolders[index].portfolioIds.remove(portfolio.id)
        }
    }

    private func openPortfolioFromProfile(_ portfolio: CuratedPortfolio) {
        for scenarioIndex in scenarios.indices {
            if let portfolioIndex = scenarios[scenarioIndex].portfolios.firstIndex(where: { $0.id == portfolio.id }) {
                selectedScenarioIndex = scenarioIndex
                selectedPortfolioIndex = portfolioIndex
                selectedShotIndex = 0
                activeSheet = nil
                activeTab = .home
                step = .portfolioDetail
                return
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomeView {
                step = .scenarioSelect
            }
        case .scenarioSelect:
            ScenarioSelectView(
                scenarios: scenarios,
                selectedScenarioIndex: $selectedScenarioIndex,
                backToWelcomeAction: {
                    step = .welcome
                },
                continueAction: {
                    selectedPortfolioIndex = 0
                    selectedShotIndex = 0
                    step = .portfolioList
                }
            )
        case .portfolioList:
            PortfolioListView(
                scenario: selectedScenario,
                selectedPortfolioIndex: $selectedPortfolioIndex,
                savedPortfolioIds: savedPortfolioIds,
                likedPortfolioIds: likedPortfolioIds,
                commentCounts: portfolioComments.mapValues(\.count),
                openAction: { index in
                    selectedPortfolioIndex = index
                    selectedShotIndex = 0
                    step = .portfolioDetail
                },
                likeAction: { portfolio in
                    if likedPortfolioIds.contains(portfolio.id) {
                        likedPortfolioIds.remove(portfolio.id)
                    } else {
                        likedPortfolioIds.insert(portfolio.id)
                    }
                },
                commentAction: { portfolio in
                    activeSheet = .comments(portfolio)
                },
                bookmarkAction: { portfolio in
                    activeSheet = .bookmark(portfolio)
                },
                backAction: {
                    step = .scenarioSelect
                }
            )
        case .portfolioDetail:
            PortfolioDetailView(
                portfolio: selectedPortfolio,
                selectedShotIndex: $selectedShotIndex,
                bookmarkAction: {
                    activeSheet = .bookmark(selectedPortfolio)
                },
                continueAction: {
                    sceneCandidate = SceneCandidate(
                        title: selectedShot.location,
                        reason: "Selected from \(selectedPortfolio.author)'s curated portfolio.",
                        score: 88,
                        assetName: selectedShot.assetName
                    )
                    subjectReferenceImage = nil
                    subjectProfile = nil
                    step = .subjectCalibration
                },
                backAction: {
                    step = .portfolioList
                }
            )
        case .subjectCalibration:
            SubjectCalibrationView(
                referenceImage: $subjectReferenceImage,
                profile: subjectProfile,
                sessionId: "session_\(selectedScenario.id)_subject_calibration"
            ) { calibratedProfile in
                subjectProfile = calibratedProfile
            } continueAction: {
                step = .sceneChoice
            } backAction: {
                step = .portfolioDetail
            }
        case .sceneChoice:
            SceneChoiceView(
                scanAction: {
                    sceneInputMethod = .scanSurroundings
                    scanUploadStatus = .empty
                    allowsSuboptimalSceneInput = false
                    resetSceneRuntimeBeforeCaptureState()
                    sceneCandidate = SceneCandidate(
                        title: "Nearby campus pocket",
                        reason: "Clean background, side light, enough depth.",
                        score: 91,
                        assetName: selectedShot.assetName
                    )
                    step = .scanSurroundings
                },
                currentAction: {
                    sceneInputMethod = .currentScene
                    currentSceneUploadStatus = .empty
                    allowsSuboptimalSceneInput = false
                    resetSceneRuntimeBeforeCaptureState()
                    sceneCandidate = SceneCandidate(
                        title: selectedShot.location,
                        reason: "Strong style match with the chosen reference shot.",
                        score: 84,
                        assetName: selectedShot.assetName
                    )
                    step = .currentScene
                },
                backAction: {
                    step = .subjectCalibration
                }
            )
        case .scanSurroundings:
            ScanSurroundingsView(
                candidate: sceneCandidate,
                uploadStatus: $scanUploadStatus,
                captureAction: handleScanSurroundingsCapture
            ) { shouldUploadAnyway in
                allowsSuboptimalSceneInput = shouldUploadAnyway
                step = .sceneCalculating
            } backAction: {
                step = .sceneChoice
            }
        case .currentScene:
            CurrentSceneView(
                candidate: sceneCandidate,
                capturedImage: sceneReferenceImage,
                analysisResult: sceneInputAnalysis,
                uploadStatus: $currentSceneUploadStatus,
                captureAction: handleCurrentScenePhotoCapture
            ) { shouldUploadAnyway in
                continueFromCurrentScene(uploadAnyway: shouldUploadAnyway)
            } backAction: {
                step = .sceneChoice
            }
        case .sceneCalculating:
            SceneCalculatingView(
                inputMethod: sceneInputMethod,
                candidate: sceneCandidate,
                portfolioTitle: selectedPortfolio.title,
                portfolioAuthor: selectedPortfolio.author,
                analysisState: sceneRuntimeAnalysisState,
                allowsSuboptimalInput: allowsSuboptimalSceneInput,
                runSceneAnalysis: buildSceneRuntimePlan,
                backAction: {
                    step = sceneInputMethod == .scanSurroundings ? .scanSurroundings : .currentScene
                },
                failureAction: { reason in
                    allowsSuboptimalSceneInput = false
                    if sceneInputMethod == .scanSurroundings {
                        scanUploadStatus = .failed(reason)
                        step = .scanSurroundings
                    } else {
                        currentSceneUploadStatus = .failed(reason)
                        step = .currentScene
                    }
                }
            ) { scenePlan in
                allowsSuboptimalSceneInput = false
                storeScenePlanForLiveShooting(scenePlan)
                step = .liveCoach
            }
        case .liveCoach:
            LiveCoachingView(
                candidate: sceneCandidate,
                state: sceneRuntimeLiveCoachState,
                scenePlan: sceneRuntimeScenePlan,
                scenePlanOutput: phoneTestScenePlanOutput,
                liveReadinessOutput: phoneTestLiveReadinessOutput,
                canOpenFinalShooting: sceneRuntimeScenePlan != nil && !isFinalCaptureInProgress,
                runReadiness: {
                    Task {
                        await runSceneRuntimeReadiness()
                    }
                },
                captureAction: {
                    Task {
                        await prepareFinalShootingCamera()
                    }
                },
                backAction: {
                    isReadyToCapture = false
                    sceneRuntimeLiveCoachState = sceneRuntimeScenePlan.map(SceneRuntimeLiveCoachUIState.init(scenePlan:)) ?? .waiting
                    step = sceneInputMethod == .scanSurroundings ? .scanSurroundings : .currentScene
                }
            )
        case .finalShooting:
            FinalShootingCameraStep(
                candidate: sceneCandidate,
                scenePlan: sceneRuntimeScenePlan,
                scenePlanOutput: phoneTestScenePlanOutput,
                liveCoachState: sceneRuntimeLiveCoachState,
                runReadiness: {
                    Task {
                        await runSceneRuntimeReadiness()
                    }
                },
                captureAction: handleFinalPhotoCapture,
                backAction: {
                    step = .liveCoach
                }
            )
        case .preview:
            if let autoCullResult = finalAutoCullResult {
                PreviewKeeperView(
                    autoCullResult: autoCullResult,
                    selectedKeeperFrameIds: $selectedKeeperFrameIds,
                    displayAssetName: { displayAssetName(for: $0) },
                    backAction: {
                        step = .liveCoach
                    },
                    saveAction: prepareFinalFineTuneReview
                )
            } else {
                FinalMomentMissingStateView(
                    title: "Capture result missing",
                    actionTitle: "Run Capture",
                    backAction: {
                        step = .liveCoach
                    },
                    action: startFinalMomentCapture
                )
            }
        case .saved:
            if let fineTuneResult = finalFineTuneResult {
                FineTuneReviewView(
                    fineTuneResult: fineTuneResult,
                    fineTuneDecisions: $finalTuneDecisions,
                    displayAssetName: { displayAssetName(for: $0) },
                    isSaved: hasSavedFineTuneSelection,
                    viewProfileAction: {
                        let confirmation = finalSaveResult?.savedConfirmation
                        let assets = confirmation?.savedAssets.map { displayAssetName(for: $0) } ?? []
                        showSavedBloomingMoments(count: confirmation?.savedCount ?? assets.count, assets: assets)
                    },
                    takeMoreAction: takeMorePhotosAfterSave,
                    backAction: {
                        finalTuneDecisions = [:]
                        hasSavedFineTuneSelection = false
                        step = .preview
                    },
                    saveAction: saveFinalMomentSelection
                )
            } else {
                FinalMomentMissingStateView(
                    title: "Fine tune result missing",
                    actionTitle: "Prepare Fine Tune",
                    backAction: {
                        step = .preview
                    },
                    action: prepareFinalFineTuneReview
                )
            }
        }
    }
}

struct AppContent {
    static let reneeGraduationAssets = [
        "ReneeGraduationLead01", "ReneeGraduationLead02", "ReneeGraduationLead03",
        "ReneeGraduation01", "ReneeGraduation02", "ReneeGraduation03", "ReneeGraduation04", "ReneeGraduation05",
        "ReneeGraduation06", "ReneeGraduation07", "ReneeGraduation08", "ReneeGraduation09", "ReneeGraduation10",
        "ReneeGraduation11", "ReneeGraduation12", "ReneeGraduation13", "ReneeGraduation14", "ReneeGraduation15",
        "ReneeGraduation16", "ReneeGraduation17", "ReneeGraduation18", "ReneeGraduation19", "ReneeGraduation20",
        "ReneeGraduation21", "ReneeGraduation22", "ReneeGraduation23", "ReneeGraduation24", "ReneeGraduation25"
    ]

    static let kariWeddingAssets = [
        "KariWedding01", "KariWedding02", "KariWedding03", "KariWedding04", "KariWedding05",
        "KariWedding06", "KariWedding07", "KariWedding08", "KariWedding09", "KariWedding10",
        "KariWedding11", "KariWedding12", "KariWedding13", "KariWedding14", "KariWedding15",
        "KariWedding16", "KariWedding17", "KariWedding18", "KariWedding19", "KariWedding20",
        "KariWedding21", "KariWedding22", "KariWedding23", "KariWedding24", "KariWedding25",
        "KariWedding26", "KariWedding27", "KariWedding28", "KariWedding29", "KariWedding30", "KariWedding31"
    ]

    static let mockGradAssets = ["MockGradPhoto01", "MockGradPhoto02", "MockGradPhoto03"]
    static let alternateMockGradAssets = ["MockGradAltPhoto01", "MockGradAltPhoto02", "MockGradAltPhoto03"]
    static let mockWeddingAssets = ["MockWeddingPhoto01", "MockWeddingPhoto02", "MockWeddingPhoto03"]
    static let softWeddingAssets = ["MockWeddingAltPhoto01", "MockWeddingAltPhoto02", "MockWeddingAltPhoto03"]
    static let editorialWeddingAssets = ["MockWeddingAltPhoto04", "MockWeddingAltPhoto05", "MockWeddingAltPhoto06"]
    static let parenthoodMockAAssets = ["MockParenthoodPhoto01", "MockParenthoodPhoto02", "MockParenthoodPhoto03"]
    static let parenthoodMockBAssets = ["MockParenthoodPhoto04", "MockParenthoodPhoto05", "MockParenthoodPhoto06"]
    static let parenthoodMockCAssets = ["MockParenthoodPhoto07", "MockParenthoodPhoto08", "MockParenthoodPhoto09"]
    static let quietParenthoodAssets = ["MockParenthoodAltPhoto01", "MockParenthoodAltPhoto02", "MockParenthoodAltPhoto03"]
    static let goldenParenthoodAssets = ["MockParenthoodAltPhoto04", "MockParenthoodAltPhoto05", "MockParenthoodAltPhoto06"]
    static let editorialParenthoodAssets = ["MockParenthoodPhoto07", "MockParenthoodAltPhoto02", "MockParenthoodAltPhoto05"]

    static func generatedShots(
        for assets: [String],
        idPrefix: String,
        location: String,
        gesture: String,
        tags: [String]
    ) -> [PortfolioShot] {
        assets.enumerated().map { index, asset in
            PortfolioShot(
                id: "\(idPrefix)-\(index + 1)",
                assetName: asset,
                title: "Reference \(index + 1)",
                location: location,
                gesture: gesture,
                tags: tags
            )
        }
    }

    static let graduationPortfolio = CuratedPortfolio(
        id: "renee_graduation_training_set",
        title: "Spring delights",
        author: "Renee",
        avatarAsset: "AvatarReneeGraduation",
        photographerBio: "Renee photographs people at their happiest.\nShe lets sunlight, movement, and tenderness bloom.",
        locationSummary: "Campus lawns, arches, tower views, and graduation portraits",
        styleSummary: "Soft daylight, editorial framing, relaxed graduation movement",
        assets: reneeGraduationAssets,
        tags: ["soft daylight", "campus scale", "gentle motion"],
        shots: generatedShots(
            for: Array(reneeGraduationAssets.prefix(12)),
            idPrefix: "renee-graduation",
            location: "Campus graduation setting",
            gesture: "Keep the subject relaxed and let campus scale or natural movement lead the frame.",
            tags: ["soft daylight", "campus", "movement"]
        ),
        styleProfileId: "style_profile_training_graduation_local_same_photographer_v1",
        styleProfileVersion: "0.1.0-draft",
        profileStatus: "draft",
        publishStatus: "style_profile_review",
        contentSource: "real_training_set_graduation_renee"
    )

    static let softPortraitPortfolio = CuratedPortfolio(
        id: "mock_graduation_soft_campus",
        title: "Soft Campus Portraits",
        author: "Maya Lin",
        avatarAsset: "MockGradAvatarMaya",
        photographerBio: "Maya keeps portraits gentle and open.\nShe favors calm expressions, soft greens, and easy daylight.",
        locationSummary: "Open lawn, tower edges, shaded paths",
        styleSummary: "Clean portraits, soft greens, calm expressions",
        assets: mockGradAssets,
        tags: ["portrait", "soft light", "calm"],
        shots: generatedShots(
            for: mockGradAssets,
            idPrefix: "mock-grad-soft",
            location: "Campus graduation setting",
            gesture: "Stand naturally, turn toward soft light, keep the composition simple.",
            tags: ["portrait", "soft", "campus"]
        ),
        styleProfileId: "mock_graduation_soft_campus_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let cinematicCampusPortfolio = CuratedPortfolio(
        id: "mock_graduation_editorial_motion",
        title: "Editorial Campus Motion",
        author: "Elena Park",
        avatarAsset: "MockGradAvatarElena",
        photographerBio: "Elena frames graduation like a small film.\nShe looks for motion, scale, and warm campus architecture.",
        locationSummary: "Arches, tower paths, and warm campus courtyards",
        styleSummary: "Editorial motion, landmark scale, soft gold light",
        assets: alternateMockGradAssets,
        tags: ["editorial", "movement", "campus"],
        shots: generatedShots(
            for: alternateMockGradAssets,
            idPrefix: "mock-grad-editorial",
            location: "Campus editorial setting",
            gesture: "Move lightly through the frame and keep the campus background visible.",
            tags: ["motion", "editorial", "campus"]
        ),
        styleProfileId: "mock_graduation_editorial_motion_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let kariBjornWeddingPortfolio = CuratedPortfolio(
        id: "kari_bjorn_wedding_training_set",
        title: "Kari Bjorn Wedding Portfolio",
        author: "Kari Bjorn",
        avatarAsset: "AvatarKariBjorn",
        photographerBio: "Kari follows warmth, motion, and honest laughter.\nHis wedding frames feel open, bright, and deeply present.",
        locationSummary: "Outdoor wedding landscapes, intimate portraits, rings, and celebration details",
        styleSummary: "Warm natural light, romantic distance, candid movement",
        assets: kariWeddingAssets,
        tags: ["warm light", "candid motion", "romantic"],
        shots: generatedShots(
            for: Array(kariWeddingAssets.prefix(12)),
            idPrefix: "kari-wedding",
            location: "Outdoor wedding setting",
            gesture: "Let the couple move naturally, stay close enough for emotion, and protect warm backlight.",
            tags: ["warm light", "candid", "romantic"]
        ),
        styleProfileId: "style_profile_training_wedding_kari_bjorn_v1",
        styleProfileVersion: "0.1.0-draft",
        profileStatus: "draft",
        publishStatus: "style_profile_review",
        contentSource: "real_training_set_wedding_kari_bjorn"
    )

    static let mockWeddingSoftPortfolio = CuratedPortfolio(
        id: "mock_wedding_soft_hillside",
        title: "Soft Hillside Wedding",
        author: "Sofia Reyes",
        avatarAsset: "MockWeddingAvatarSofia",
        photographerBio: "Sofia favors open air and soft distance.\nHer couples feel relaxed, warm, and lightly windswept.",
        locationSummary: "Hillside vows, lake views, outdoor couple movement",
        styleSummary: "Warm backlight, romantic space, quiet gesture",
        assets: softWeddingAssets,
        tags: ["soft haze", "hillside", "warm air"],
        shots: generatedShots(
            for: softWeddingAssets,
            idPrefix: "mock-wedding-soft",
            location: "Hillside wedding setting",
            gesture: "Walk slowly together and keep the couple in warm side light.",
            tags: ["soft haze", "hillside", "warm"]
        ),
        styleProfileId: "mock_wedding_soft_hillside_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let mockWeddingEditorialPortfolio = CuratedPortfolio(
        id: "mock_wedding_editorial_light",
        title: "Editorial Wedding Light",
        author: "Miles Chen",
        avatarAsset: "MockWeddingAvatarMiles",
        photographerBio: "Miles keeps wedding frames polished and graphic.\nHe looks for clean lines, glow, and quiet contrast.",
        locationSummary: "Architecture, open fields, and soft couple portraits",
        styleSummary: "Clean frames, romantic contrast, polished natural light",
        assets: editorialWeddingAssets,
        tags: ["clean lines", "gold glow", "editorial"],
        shots: generatedShots(
            for: editorialWeddingAssets,
            idPrefix: "mock-wedding-editorial",
            location: "Editorial wedding setting",
            gesture: "Face each other naturally and let the background geometry stay simple.",
            tags: ["clean lines", "gold glow", "editorial"]
        ),
        styleProfileId: "mock_wedding_editorial_light_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let mockParenthoodQuietPortfolio = CuratedPortfolio(
        id: "mock_parenthood_quiet_nursery",
        title: "Quiet Nursery Keepsakes",
        author: "Lina Zhou",
        avatarAsset: "MockParenthoodAvatarLina",
        photographerBio: "Lina photographs the smallest pauses.\nShe keeps the light soft and the family contact gentle.",
        locationSummary: "Nursery light, newborn details, calm family touch",
        styleSummary: "Soft white light, gentle hands, intimate close framing",
        assets: quietParenthoodAssets,
        tags: ["soft white", "close touch", "nursery"],
        shots: generatedShots(
            for: quietParenthoodAssets,
            idPrefix: "mock-parenthood-nursery",
            location: "Nursery setting",
            gesture: "Keep hands relaxed and let small details carry the moment.",
            tags: ["soft white", "close touch", "nursery"]
        ),
        styleProfileId: "mock_parenthood_quiet_nursery_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let mockParenthoodGoldenPortfolio = CuratedPortfolio(
        id: "mock_parenthood_golden_family",
        title: "Golden Family Field",
        author: "Theo Morgan",
        avatarAsset: "MockParenthoodAvatarNoah",
        photographerBio: "Theo leans into warm movement and closeness.\nHis family frames feel sunlit, playful, and unforced.",
        locationSummary: "Outdoor fields, family holding, toddler portraits",
        styleSummary: "Golden light, close family contact, warm open space",
        assets: goldenParenthoodAssets,
        tags: ["golden hour", "family", "warm field"],
        shots: generatedShots(
            for: goldenParenthoodAssets,
            idPrefix: "mock-parenthood-golden",
            location: "Golden-hour field",
            gesture: "Hold close, move slowly, and let the child respond naturally.",
            tags: ["golden hour", "family", "warm"]
        ),
        styleProfileId: "mock_parenthood_golden_family_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let mockParenthoodEditorialPortfolio = CuratedPortfolio(
        id: "mock_parenthood_editorial_home",
        title: "Editorial Home Story",
        author: "Clara Bennett",
        avatarAsset: "MockParenthoodAvatarClara",
        photographerBio: "Clara brings a quiet editorial rhythm home.\nShe balances detail crops with relaxed family portraits.",
        locationSummary: "Home couch, baby hands, soft window light",
        styleSummary: "Close details, calm home composition, gentle warmth",
        assets: editorialParenthoodAssets,
        tags: ["window light", "home story", "details"],
        shots: generatedShots(
            for: editorialParenthoodAssets,
            idPrefix: "mock-parenthood-home",
            location: "Home parenthood setting",
            gesture: "Stay close, keep faces relaxed, and let small contact become the anchor.",
            tags: ["window light", "home", "details"]
        ),
        styleProfileId: "mock_parenthood_editorial_home_v1",
        styleProfileVersion: "mock",
        profileStatus: "mock",
        publishStatus: "mock_portfolio",
        contentSource: "generated_mock_portfolio"
    )

    static let scenarios: [PhotoScenario] = [
        PhotoScenario(
            id: "graduation",
            title: "Graduation",
            subtitle: "Campus memories, cap-and-gown portraits, friend groups, and landmark shots.",
            heroAsset: "GraduationScenePoster",
            tags: ["campus", "milestone", "editorial"],
            portfolios: [graduationPortfolio, softPortraitPortfolio, cinematicCampusPortfolio]
        ),
        PhotoScenario(
            id: "wedding",
            title: "Wedding",
            subtitle: "Warm portraits, movement, rings, quiet architecture, and celebration moments.",
            heroAsset: "WeddingScenePoster",
            tags: ["romantic", "warm", "candid"],
            portfolios: [kariBjornWeddingPortfolio, mockWeddingSoftPortfolio, mockWeddingEditorialPortfolio]
        ),
        PhotoScenario(
            id: "parenthood",
            title: "Parenthood",
            subtitle: "Soft portraits for expecting parents, quiet keepsakes, gentle gestures, and growing-family moments.",
            heroAsset: "ParenthoodScenePoster",
            tags: ["parenthood", "keepsake", "soft"],
            portfolios: [mockParenthoodQuietPortfolio, mockParenthoodGoldenPortfolio, mockParenthoodEditorialPortfolio]
        )
    ]
}

struct WelcomeView: View {
    let startAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("WelcomePageArtwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                Button(action: startAction) {
                    Color.clear
                        .frame(width: proxy.size.width * 0.80, height: proxy.size.height * 0.075)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start Blooming")
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.865)
            }
        }
        .ignoresSafeArea()
    }
}

struct ScenarioSelectView: View {
    let scenarios: [PhotoScenario]
    @Binding var selectedScenarioIndex: Int
    let backToWelcomeAction: () -> Void
    let continueAction: () -> Void

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        BloomingWordmark()
                            .frame(maxWidth: .infinity, alignment: .center)

                        BloomingBackButton(action: backToWelcomeAction)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("What’s blooming now?")
                        .font(AppType.homeHero)
                        .foregroundStyle(AppPalette.ivory)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("Select your themed scene")
                        .font(AppType.eyebrow)
                        .kerning(4.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.gold)
                }
                .padding(.top, 6)
                .padding(.horizontal, 18)

                VStack(spacing: 10) {
                    ForEach(Array(scenarios.enumerated()), id: \.element.id) { index, scenario in
                        ScenarioCard(
                            scenario: scenario,
                            isSelected: selectedScenarioIndex == index
                        ) {
                            selectedScenarioIndex = index
                            continueAction()
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .background(BloomingHomeBackdrop().ignoresSafeArea())
    }
}

struct PortfolioListView: View {
    let scenario: PhotoScenario
    @Binding var selectedPortfolioIndex: Int
    let savedPortfolioIds: Set<String>
    let likedPortfolioIds: Set<String>
    let commentCounts: [String: Int]
    let openAction: (Int) -> Void
    let likeAction: (CuratedPortfolio) -> Void
    let commentAction: (CuratedPortfolio) -> Void
    let bookmarkAction: (CuratedPortfolio) -> Void
    let backAction: () -> Void

    var body: some View {
        ZStack {
            PortfolioFeedBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    PortfolioFeedHeader(backAction: backAction)
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(scenario.title)
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 39))
                            .foregroundStyle(AppPalette.ivory)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text("Choose a photographer whose taste matches the moment.")
                            .font(.custom("AvenirNext-Regular", size: 13.5))
                            .foregroundStyle(AppPalette.ivory.opacity(0.66))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 18)

                    LazyVStack(spacing: 14) {
                        ForEach(Array(scenario.portfolios.enumerated()), id: \.element.id) { index, portfolio in
                            PhotographerPortfolioCard(
                                portfolio: portfolio,
                                avatarAsset: portfolio.avatarAsset,
                                likeCount: likedPortfolioIds.contains(portfolio.id) ? 1 : 0,
                                commentCount: commentCounts[portfolio.id, default: 0],
                                isLiked: likedPortfolioIds.contains(portfolio.id),
                                isSelected: selectedPortfolioIndex == index,
                                isBookmarked: savedPortfolioIds.contains(portfolio.id),
                                likeAction: {
                                    likeAction(portfolio)
                                },
                                commentAction: {
                                    commentAction(portfolio)
                                },
                                bookmarkAction: {
                                    bookmarkAction(portfolio)
                                }
                            ) {
                                selectedPortfolioIndex = index
                                openAction(index)
                            }
                        }
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
        }
    }

}

struct PortfolioFeedWordmark: View {
    var body: some View {
        Image("BloomingLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 116, height: 42)
            .accessibilityLabel("Blooming")
    }
}

struct PortfolioFeedHeader: View {
    let backAction: () -> Void

    var body: some View {
        ZStack {
            PortfolioFeedWordmark()
                .frame(maxWidth: .infinity, alignment: .center)

            PortfolioFeedBackButton(action: backAction)
                .frame(maxWidth: .infinity, alignment: .leading)

            PortfolioFeedIconButton(icon: "magnifyingglass", accessibilityLabel: "Search portfolios") {}
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct BloomingCenteredTopBar: View {
    var backAction: (() -> Void)?

    var body: some View {
        ZStack {
            PortfolioFeedWordmark()
                .frame(maxWidth: .infinity, alignment: .center)

            if let backAction {
                PortfolioFeedBackButton(action: backAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Color.clear
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }
}

struct PortfolioDetailView: View {
    let portfolio: CuratedPortfolio
    @Binding var selectedShotIndex: Int
    let bookmarkAction: () -> Void
    let continueAction: () -> Void
    let backAction: () -> Void
    @State private var previewPhoto: DetailPhotoPreview?

    var body: some View {
        ZStack {
            PortfolioDetailBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PortfolioDetailTopBar(
                    backAction: backAction,
                    bookmarkAction: bookmarkAction
                )
                .padding(.horizontal, 20)
                .padding(.top, 2)

                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        PortfolioDetailProfileHeader(portfolio: portfolio)
                            .padding(.top, 14)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(portfolio.title)
                                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 28))
                                .foregroundStyle(AppPalette.ivory)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)

                            Text("TIMELESS MOMENTS. CLASSIC SETTINGS.")
                                .font(.custom("AvenirNext-DemiBold", size: 8.4))
                                .kerning(3.3)
                                .foregroundStyle(AppPalette.gold)
                        }
                        .padding(.top, 2)

                        PortfolioDetailGallery(assets: detailGalleryAssets) { index in
                            previewPhoto = DetailPhotoPreview(startIndex: index)
                        }
                        .padding(.top, 4)

                        Color.clear
                            .frame(height: 92)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
            }

            VStack {
                Spacer()
                PortfolioAdoptionPanel(
                    continueAction: {
                        selectedShotIndex = 0
                        continueAction()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }

            if let photo = previewPhoto {
                DetailPhotoPreviewView(
                    assets: detailGalleryAssets,
                    startIndex: photo.startIndex,
                    dismissAction: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            previewPhoto = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(30)
            }
        }
    }

    private var detailGalleryAssets: [String] {
        let base = portfolio.assets + portfolio.shots.map(\.assetName)
        guard !base.isEmpty else { return ["HooverTower", "ArchesWalk", "StripedLight"] }
        var seen: Set<String> = []
        return base.filter { seen.insert($0).inserted }
    }
}

struct DetailPhotoPreview: Identifiable {
    let id = UUID()
    let startIndex: Int
}

struct PortfolioDetailTopBar: View {
    let backAction: () -> Void
    let bookmarkAction: () -> Void

    var body: some View {
        ZStack {
            PortfolioFeedWordmark()
                .frame(maxWidth: .infinity, alignment: .center)

            PortfolioFeedBackButton(action: backAction)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: bookmarkAction) {
                Image(systemName: "bookmark")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save portfolio")
            .foregroundStyle(AppPalette.ivory)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct PortfolioDetailProfileHeader: View {
    let portfolio: CuratedPortfolio

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(avatarAsset)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(AppPalette.gold.opacity(0.78), lineWidth: 1.2)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(portfolio.author)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                    .foregroundStyle(AppPalette.ivory)

                Text("STANFORD, CA")
                    .font(.custom("AvenirNext-DemiBold", size: 7.8))
                    .kerning(2.6)
                    .foregroundStyle(AppPalette.gold)

                Text(profileBio)
                    .font(.custom("AvenirNext-Regular", size: 10.2))
                    .foregroundStyle(AppPalette.ivory.opacity(0.72))
                    .lineSpacing(0.4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var avatarAsset: String {
        portfolio.avatarAsset
    }

    private var profileBio: String {
        portfolio.photographerBio
    }
}

struct PortfolioDetailGallery: View {
    let assets: [String]
    let openPhoto: (Int) -> Void
    private let spacing: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width

            VStack(spacing: spacing) {
                ForEach(Array(galleryGroups.enumerated()), id: \.offset) { sectionIndex, group in
                    mosaicSection(
                        group,
                        width: availableWidth,
                        variant: sectionIndex % 3
                    )
                }
            }
            .frame(width: availableWidth, alignment: .leading)
        }
        .frame(height: galleryHeight)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func mosaicSection(
        _ items: [(offset: Int, assetName: String)],
        width: CGFloat,
        variant: Int
    ) -> some View {
        let third = (width - spacing * 2) / 3
        let half = (width - spacing) / 2
        let twoThirds = third * 2 + spacing

        switch items.count {
        case 0:
            EmptyView()
        case 1:
            detailTile(item: items[0], width: width, height: 148)
        case 2:
            HStack(spacing: spacing) {
                detailTile(item: items[0], width: half, height: 152)
                detailTile(item: items[1], width: half, height: 152)
            }
        case 3:
            VStack(spacing: spacing) {
                detailTile(item: items[0], width: width, height: 138)
                HStack(spacing: spacing) {
                    detailTile(item: items[1], width: half, height: 154)
                    detailTile(item: items[2], width: half, height: 154)
                }
            }
        case 4:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    detailTile(item: items[0], width: twoThirds, height: 128)
                    detailTile(item: items[1], width: third, height: 128)
                }
                HStack(spacing: spacing) {
                    detailTile(item: items[2], width: third, height: 148)
                    detailTile(item: items[3], width: twoThirds, height: 148)
                }
            }
        case 5:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    detailTile(item: items[0], width: third, height: 218)
                    VStack(spacing: spacing) {
                        detailTile(item: items[1], width: twoThirds, height: 104)
                        detailTile(item: items[2], width: twoThirds, height: 107)
                    }
                }
                HStack(spacing: spacing) {
                    detailTile(item: items[3], width: half, height: 132)
                    detailTile(item: items[4], width: half, height: 132)
                }
            }
        case 6:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    detailTile(item: items[0], width: half, height: 142)
                    detailTile(item: items[1], width: half, height: 142)
                }
                HStack(spacing: spacing) {
                    detailTile(item: items[2], width: third, height: 176)
                    detailTile(item: items[3], width: third, height: 176)
                    detailTile(item: items[4], width: third, height: 176)
                }
                detailTile(item: items[5], width: width, height: 118)
            }
        default:
            fullMosaicSection(items, width: width, variant: variant)
        }
    }

    @ViewBuilder
    private func fullMosaicSection(
        _ items: [(offset: Int, assetName: String)],
        width: CGFloat,
        variant: Int
    ) -> some View {
        let third = (width - spacing * 2) / 3
        let twoThirds = third * 2 + spacing

        if variant == 1 {
            VStack(spacing: spacing) {
                detailTile(item: items[0], width: width, height: 126)
                HStack(spacing: spacing) {
                    detailTile(item: items[1], width: third, height: 212)
                    VStack(spacing: spacing) {
                        detailTile(item: items[2], width: twoThirds, height: 100)
                        HStack(spacing: spacing) {
                            detailTile(item: items[3], width: third, height: 105)
                            detailTile(item: items[4], width: third, height: 105)
                        }
                    }
                }
                HStack(spacing: spacing) {
                    detailTile(item: items[5], width: twoThirds, height: 124)
                    detailTile(item: items[6], width: third, height: 124)
                }
            }
        } else if variant == 2 {
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    detailTile(item: items[0], width: twoThirds, height: 136)
                    detailTile(item: items[1], width: third, height: 136)
                }
                HStack(spacing: spacing) {
                    VStack(spacing: spacing) {
                        detailTile(item: items[2], width: third, height: 104)
                        detailTile(item: items[3], width: third, height: 126)
                    }
                    detailTile(item: items[4], width: twoThirds, height: 237)
                }
                HStack(spacing: spacing) {
                    detailTile(item: items[5], width: third, height: 118)
                    detailTile(item: items[6], width: twoThirds, height: 118)
                }
            }
        } else {
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    detailTile(item: items[0], width: third, height: 232)
                    VStack(spacing: spacing) {
                        HStack(spacing: spacing) {
                            detailTile(item: items[1], width: third, height: 110)
                            detailTile(item: items[2], width: third, height: 110)
                        }
                        detailTile(item: items[3], width: twoThirds, height: 115)
                    }
                }
                HStack(spacing: spacing) {
                    detailTile(item: items[4], width: twoThirds, height: 132)
                    detailTile(item: items[5], width: third, height: 132)
                }
                detailTile(item: items[6], width: width, height: 118)
            }
        }
    }

    private var galleryHeight: CGFloat {
        guard !assets.isEmpty else { return 0 }
        return Array(galleryGroups.enumerated()).reduce(CGFloat.zero) { total, pair in
            total + sectionHeight(itemCount: pair.element.count, variant: pair.offset % 3)
        } + spacing * CGFloat(max(0, galleryGroups.count - 1))
    }

    private var galleryGroups: [[(offset: Int, assetName: String)]] {
        let items = assets.enumerated().map { (offset: $0.offset, assetName: $0.element) }
        var groups: [[(offset: Int, assetName: String)]] = []
        var index = 0

        while index < items.count {
            let remaining = items.count - index
            let count = remaining <= 7 ? remaining : 7
            groups.append(Array(items[index..<(index + count)]))
            index += count
        }

        return groups
    }

    private func sectionHeight(itemCount: Int, variant: Int) -> CGFloat {
        switch itemCount {
        case 0:
            return 0
        case 1:
            return 148
        case 2:
            return 152
        case 3:
            return 138 + spacing + 154
        case 4:
            return 128 + spacing + 148
        case 5:
            return 218 + spacing + 132
        case 6:
            return 142 + spacing + 176 + spacing + 118
        default:
            switch variant {
            case 1:
                return 126 + spacing + 212 + spacing + 124
            case 2:
                return 136 + spacing + 237 + spacing + 118
            default:
                return 232 + spacing + 132 + spacing + 118
            }
        }
    }

    private func detailTile(item: (offset: Int, assetName: String), width: CGFloat, height: CGFloat) -> some View {
        Button {
            openPhoto(item.offset)
        } label: {
            Image(item.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: AppPalette.oliveShadow.opacity(0.10), radius: 4, y: 2)
        }
        .frame(width: width, height: height)
        .buttonStyle(.plain)
        .accessibilityLabel("Open portfolio photo")
    }
}

struct DetailPhotoPreviewView: View {
    let assets: [String]
    let dismissAction: () -> Void
    @State private var selectedIndex: Int
    @GestureState private var dragOffset: CGFloat = 0

    init(assets: [String], startIndex: Int, dismissAction: @escaping () -> Void) {
        let fallbackAssets = assets.isEmpty ? ["HooverTower"] : assets
        self.assets = fallbackAssets
        self.dismissAction = dismissAction
        let safeIndex = min(max(startIndex, 0), fallbackAssets.count - 1)
        _selectedIndex = State(initialValue: safeIndex)
    }

    var body: some View {
        GeometryReader { proxy in
            let panelHeight = min(proxy.size.height * 0.78, 650)

            ZStack(alignment: .bottom) {
                Button(action: dismissAction) {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss photo preview")

                VStack(spacing: 0) {
                    Capsule()
                        .fill(AppPalette.ivory.opacity(0.24))
                        .frame(width: 42, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    ZStack(alignment: .bottom) {
                        TabView(selection: $selectedIndex) {
                            ForEach(Array(assets.enumerated()), id: \.offset) { index, assetName in
                                Image(assetName)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .padding(.horizontal, 18)
                                    .padding(.top, 6)
                                    .padding(.bottom, 58)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))

                        HStack(spacing: 7) {
                            ForEach(assets.indices, id: \.self) { index in
                                Circle()
                                    .fill(index == selectedIndex ? AppPalette.gold : AppPalette.ivory.opacity(0.28))
                                    .frame(width: index == selectedIndex ? 7 : 6, height: index == selectedIndex ? 7 : 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(AppPalette.paper.opacity(0.54), in: Capsule())
                        .padding(.bottom, 20)
                        .accessibilityLabel("Photo \(selectedIndex + 1) of \(assets.count)")
                    }
                }
                .frame(width: proxy.size.width, height: panelHeight)
                .background(
                    AppPalette.ink,
                    in: UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 30, style: .continuous)
                )
                .shadow(color: .black.opacity(0.18), radius: 24, y: -8)
                .offset(y: max(0, dragOffset))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .updating($dragOffset) { value, state, _ in
                            state = max(0, value.translation.height)
                        }
                        .onEnded { value in
                            if value.translation.height > 90 || value.predictedEndTranslation.height > 180 {
                                dismissAction()
                            }
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct PortfolioAdoptionPanel: View {
    let continueAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: continueAction) {
                Text("Adopt this portfolio style")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 20))
                    .foregroundStyle(AppPalette.buttonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppPalette.gold, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adopt this portfolio style")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [AppPalette.paperBright, AppPalette.paper.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: AppPalette.oliveShadow.opacity(0.20), radius: 14, y: 5)
    }
}

struct AdoptionTrait: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(AppPalette.gold)
            Text(title)
                .font(.custom("AvenirNext-Regular", size: 6.5))
                .foregroundStyle(AppPalette.ivory.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PhotographerProfileHeader: View {
    let portfolio: CuratedPortfolio

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                PhotographerAvatar(assetName: portfolio.avatarAsset, name: portfolio.author)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(portfolio.title)
                        .font(AppType.micro)
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.gold)
                    Text(portfolio.author)
                        .font(AppType.screenTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }

            Text(portfolio.photographerBio)
                .font(AppType.body)
                .foregroundStyle(AppPalette.ivory.opacity(0.72))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PortfolioDirectionPanel: View {
    let portfolio: CuratedPortfolio
    let selectedShot: PortfolioShot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.buttonText)
                    .frame(width: 38, height: 38)
                    .background(AppPalette.gold, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(portfolio.styleSummary)
                        .font(AppType.profileSection)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                    Text(portfolio.locationSummary)
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        .lineLimit(2)
                }
            }

            Divider()
                .overlay(AppPalette.hairline)

            VStack(alignment: .leading, spacing: 7) {
                Text("Current reference")
                    .font(AppType.micro)
                    .kerning(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.gold)
                Text(selectedShot.gesture)
                    .font(AppType.body)
                    .foregroundStyle(AppPalette.ivory.opacity(0.70))
                    .lineSpacing(3)
            }

            TagRow(tags: Array((portfolio.tags + selectedShot.tags).prefix(5)))
        }
        .padding(16)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
    }
}

struct PortfolioStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.gold)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(AppType.chip)
                    .lineLimit(1)
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(AppPalette.ivory.opacity(0.46))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.graphite.opacity(0.60), in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
    }
}

struct PortfolioMasonryGrid: View {
    let shots: [PortfolioShot]
    @Binding var selectedShotIndex: Int

    private var indexedShots: [(offset: Int, element: PortfolioShot)] {
        Array(shots.enumerated())
    }

    private var leftColumnShots: [(offset: Int, element: PortfolioShot)] {
        indexedShots.filter { $0.offset % 4 == 0 || $0.offset % 4 == 3 }
    }

    private var rightColumnShots: [(offset: Int, element: PortfolioShot)] {
        indexedShots.filter { $0.offset % 4 == 1 || $0.offset % 4 == 2 }
    }

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = (proxy.size.width - 10) / 2

            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(leftColumnShots, id: \.element.id) { item in
                        Button {
                            selectedShotIndex = item.offset
                        } label: {
                            PortfolioMasonryPhotoTile(
                                shot: item.element,
                                index: item.offset,
                                isSelected: selectedShotIndex == item.offset
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: columnWidth, height: tileHeight(for: item.element, columnWidth: columnWidth))
                        .accessibilityLabel("Choose reference shot \(item.element.title)")
                    }
                }

                VStack(spacing: 10) {
                    ForEach(rightColumnShots, id: \.element.id) { item in
                        Button {
                            selectedShotIndex = item.offset
                        } label: {
                            PortfolioMasonryPhotoTile(
                                shot: item.element,
                                index: item.offset,
                                isSelected: selectedShotIndex == item.offset
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: columnWidth, height: tileHeight(for: item.element, columnWidth: columnWidth))
                        .accessibilityLabel("Choose reference shot \(item.element.title)")
                    }
                }
            }
            .frame(width: proxy.size.width, alignment: .top)
        }
        .frame(height: gridHeight(forColumnWidth: referenceColumnWidth))
    }

    private var referenceColumnWidth: CGFloat {
        max(120, (UIScreen.main.bounds.width - 24 - 10) / 2)
    }

    private func tileHeight(for shot: PortfolioShot, columnWidth: CGFloat) -> CGFloat {
        let aspectRatio = imageAspectRatio(for: shot.assetName)
        return columnWidth / max(aspectRatio, 0.1)
    }

    private func gridHeight(forColumnWidth columnWidth: CGFloat) -> CGFloat {
        max(
            columnHeight(for: leftColumnShots, columnWidth: columnWidth),
            columnHeight(for: rightColumnShots, columnWidth: columnWidth)
        )
    }

    private func columnHeight(for items: [(offset: Int, element: PortfolioShot)], columnWidth: CGFloat) -> CGFloat {
        guard !items.isEmpty else { return 0 }
        let imageHeight = items.reduce(CGFloat.zero) { partial, item in
            partial + tileHeight(for: item.element, columnWidth: columnWidth)
        }
        return imageHeight + CGFloat(items.count - 1) * 10
    }

    private func imageAspectRatio(for assetName: String) -> CGFloat {
        if let image = UIImage(named: assetName), image.size.height > 0 {
            return image.size.width / image.size.height
        }

        switch assetName {
        case "ArchesWalk":
            return 1.5
        default:
            return 2.0 / 3.0
        }
    }
}

struct PortfolioMasonryPhotoTile: View {
    let shot: PortfolioShot
    let index: Int
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Image(shot.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.02), .black.opacity(0.56)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(String(format: "%02d", index + 1))
                            .font(AppType.micro)
                            .kerning(1.4)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundStyle(isSelected ? AppPalette.buttonText : AppPalette.paper)

                    Text(shot.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(AppPalette.paper)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Label(shot.location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(AppPalette.paper.opacity(0.78))
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? AppPalette.gold : AppPalette.hairline, lineWidth: isSelected ? 2.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppPalette.buttonText)
                        .frame(width: 30, height: 30)
                        .background(AppPalette.gold, in: Circle())
                        .padding(8)
                }
            }
            .shadow(color: .black.opacity(isSelected ? 0.11 : 0.055), radius: isSelected ? 16 : 12, y: isSelected ? 8 : 6)
        }
    }
}

struct StyleSelectView: View {
    let style: PhotographyStyle
    let startAction: () -> Void
    @State private var selectedAssetIndex = 1

    var body: some View {
        FixedFooterPage {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    AppWordmark()
                    Text("Borrow the eye. Keep the moment.")
                        .font(AppType.hero)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A guided campus style tuned for landmark scale, motion, and dramatic light.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.72))
                        .lineSpacing(3)
                }
                .padding(.top, 18)
                .frame(maxWidth: .infinity, alignment: .leading)

                StyleHeroCard(style: style, selectedIndex: $selectedAssetIndex)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Shot recipe")
                                .font(AppType.sectionTitle)
                            Text("Campus editorial guidance by \(style.author)")
                                .font(AppType.caption)
                                .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        }
                        Spacer()
                    }

                    TagRow(tags: style.tags)
                }
                .padding(18)
                .surfaceCard()
            }
        } footer: {
            PrimaryButton(title: "Start Shoot", icon: "camera.viewfinder", action: startAction)
        }
    }
}

struct StyleHeroCard: View {
    let style: PhotographyStyle
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(AppType.cardTitle)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text("reference mood set")
                        .font(AppType.micro)
                        .kerning(2.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                }
                Spacer()
                Text("\(selectedIndex + 1) of \(style.assets.count)")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppPalette.paper.opacity(0.82), in: Capsule())
            }

            HStack(alignment: .center, spacing: 12) {
                GeometryReader { proxy in
                    let cardWidth = (proxy.size.width - 24) / 3
                    HStack(alignment: .center, spacing: 12) {
                        ForEach(Array(style.assets.enumerated()), id: \.offset) { index, asset in
                            Button {
                                selectedIndex = index
                            } label: {
                                InstagramReferenceCard(
                                    assetName: asset,
                                    isSelected: index == selectedIndex,
                                    label: index == 0 ? "SCALE" : index == 1 ? "MOTION" : "LIGHT"
                                )
                                .frame(width: cardWidth, height: 150)
                                .opacity(index == selectedIndex ? 1 : 0.88)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Preview reference image \(index + 1)")
                        }
                    }
                    .frame(width: proxy.size.width, alignment: .center)
                }
            }
            .frame(height: 166)
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(AppPalette.mistBlue, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                .stroke(AppPalette.ivory.opacity(0.08), lineWidth: 1)
        }
    }
}

struct InstagramReferenceCard: View {
    let assetName: String
    let isSelected: Bool
    let label: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let topHeight: CGFloat = 25
            let bottomHeight: CGFloat = 29
            let imageHeight = max(76, height - topHeight - bottomHeight)

            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Circle()
                        .stroke(AppPalette.ivory.opacity(0.48), lineWidth: 1)
                        .frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppPalette.ivory.opacity(0.16))
                        .frame(width: 34, height: 4)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 8)
                .frame(width: width, height: topHeight)
                .background(AppPalette.paper)

                ZStack(alignment: .bottom) {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: imageHeight)
                        .clipped()
                        .saturation(0.88)
                        .contrast(0.96)
                        .overlay(AppPalette.paper.opacity(0.10))

                    Text(label)
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .kerning(1.9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: min(78, width - 18))
                        .background(AppPalette.paper.opacity(0.88), in: Capsule())
                        .padding(.bottom, 8)
                }
                .frame(width: width, height: imageHeight)

                HStack(spacing: 7) {
                    Image(systemName: "heart")
                    Image(systemName: "bubble.right")
                    Image(systemName: "paperplane")
                    Spacer()
                    Image(systemName: "bookmark")
                }
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 8)
                .frame(width: width, height: bottomHeight)
                .background(AppPalette.paper)
            }
            .frame(width: width, height: height)
        }
        .background(AppPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                .strokeBorder(
                    isSelected ? AppPalette.gold : AppPalette.paper.opacity(0.35),
                    lineWidth: isSelected ? 2.5 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.13 : 0.07), radius: isSelected ? 16 : 8, y: isSelected ? 8 : 4)
    }
}

struct ScenarioCard: View {
    let scenario: PhotoScenario
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(scenario.heroAsset)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(scenePosterAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.11), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(scenario.title) themed scene")
    }

    private var scenePosterAspectRatio: CGFloat {
        switch scenario.id {
        case "graduation":
            return 781.0 / 448.0
        case "wedding":
            return 779.0 / 415.0
        case "parenthood":
            return 779.0 / 411.0
        default:
            return 1.78
        }
    }
}

struct ThemedSceneIllustration: View {
    let kind: String

    private var accent: Color {
        switch kind {
        case "wedding":
            return Color(red: 0.710, green: 0.600, blue: 0.520)
        case "parenthood":
            return AppPalette.gold
        default:
            return AppPalette.mistBlue
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppPalette.paper.opacity(kind == "parenthood" ? 0.10 : 0.72))
                    .frame(width: width * 0.78, height: height * 0.82)
                    .offset(x: width * 0.05, y: height * 0.04)

                Circle()
                    .fill(accent.opacity(kind == "wedding" ? 0.22 : 0.28))
                    .frame(width: width * 0.48, height: width * 0.48)
                    .position(x: width * 0.70, y: height * 0.22)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppPalette.paper.opacity(kind == "parenthood" ? 0.92 : 0.96))
                    .frame(width: width * 0.58, height: height * 0.72)
                    .position(x: width * 0.45, y: height * 0.52)
                    .shadow(color: .black.opacity(0.07), radius: 18, y: 8)

                sceneMotif(width: width, height: height)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(kind == "parenthood" ? AppPalette.paper.opacity(0.72) : AppPalette.gold.opacity(0.78))
                        .frame(width: width * 0.30, height: 5)
                    Capsule()
                        .fill(accent.opacity(0.48))
                        .frame(width: width * 0.18, height: 5)
                }
                .position(x: width * 0.46, y: height * 0.84)
            }
        }
    }

    @ViewBuilder
    private func sceneMotif(width: CGFloat, height: CGFloat) -> some View {
        switch kind {
        case "wedding":
            ZStack {
                Circle()
                    .stroke(AppPalette.gold, lineWidth: 2.2)
                    .frame(width: width * 0.22, height: width * 0.22)
                    .position(x: width * 0.39, y: height * 0.47)
                Circle()
                    .stroke(accent.opacity(0.88), lineWidth: 2.2)
                    .frame(width: width * 0.22, height: width * 0.22)
                    .position(x: width * 0.51, y: height * 0.47)
                Path { path in
                    path.move(to: CGPoint(x: width * 0.30, y: height * 0.62))
                    path.addCurve(
                        to: CGPoint(x: width * 0.62, y: height * 0.61),
                        control1: CGPoint(x: width * 0.42, y: height * 0.70),
                        control2: CGPoint(x: width * 0.52, y: height * 0.54)
                    )
                }
                .stroke(AppPalette.gold.opacity(0.62), lineWidth: 1.6)
            }
        case "parenthood":
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(AppPalette.gold.opacity(0.82))
                        .frame(width: 8, height: width * 0.32)
                        .rotationEffect(.degrees(Double(index) * 45))
                        .position(x: width * 0.44, y: height * 0.50)
                }
                Circle()
                    .fill(AppPalette.paper.opacity(0.95))
                    .frame(width: width * 0.08, height: width * 0.08)
                    .position(x: width * 0.44, y: height * 0.50)
            }
        default:
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.25, y: height * 0.44))
                    path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.32))
                    path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.44))
                    path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.56))
                    path.closeSubpath()
                }
                .stroke(AppPalette.gold, lineWidth: 2.3)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.33, y: height * 0.49))
                    path.addLine(to: CGPoint(x: width * 0.33, y: height * 0.62))
                    path.addCurve(
                        to: CGPoint(x: width * 0.57, y: height * 0.62),
                        control1: CGPoint(x: width * 0.39, y: height * 0.70),
                        control2: CGPoint(x: width * 0.51, y: height * 0.70)
                    )
                    path.addLine(to: CGPoint(x: width * 0.57, y: height * 0.49))
                }
                .stroke(AppPalette.gold.opacity(0.88), lineWidth: 2.0)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.66, y: height * 0.44))
                    path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.64))
                    path.addLine(to: CGPoint(x: width * 0.70, y: height * 0.69))
                }
                .stroke(AppPalette.gold, lineWidth: 1.8)
            }
        }
    }
}

struct PortfolioCard: View {
    let portfolio: CuratedPortfolio
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(portfolio.title)
                        .font(AppType.cardTitle)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Text("by \(portfolio.author)")
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.gold)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppPalette.gold)
            }

            PortfolioMiniStrip(assets: portfolio.assets)
                .frame(height: 132)

            Text(portfolio.styleSummary)
                .font(AppType.body)
                .foregroundStyle(AppPalette.ivory.opacity(0.68))
                .lineSpacing(3)

            HStack(spacing: 8) {
                Label(portfolio.locationSummary, systemImage: "mappin.and.ellipse")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(portfolio.shots.count) shots")
            }
            .font(AppType.chip)
            .foregroundStyle(AppPalette.ivory.opacity(0.58))

            TagRow(tags: portfolio.tags)
        }
        .padding(16)
        .surfaceCard()
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                .strokeBorder(isSelected ? AppPalette.gold : .clear, lineWidth: 2)
        }
    }
}

struct PhotographerPortfolioCard: View {
    let portfolio: CuratedPortfolio
    let avatarAsset: String
    let likeCount: Int
    let commentCount: Int
    let isLiked: Bool
    let isSelected: Bool
    let isBookmarked: Bool
    let likeAction: () -> Void
    let commentAction: () -> Void
    let bookmarkAction: () -> Void
    let openAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openAction) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 11) {
                        PhotographerAvatar(assetName: avatarAsset, name: portfolio.author)
                            .frame(width: 38, height: 38)

                        Text(portfolio.author)
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21.5))
                            .foregroundStyle(AppPalette.ivory)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.ivory.opacity(0.42))
                    }

                    PortfolioPhotoCarousel(assets: carouselAssets)

                    PortfolioFeedTagRow(tags: Array(portfolio.tags.prefix(3)))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(portfolio.author)'s portfolio")

            Divider()
                .overlay(AppPalette.hairline.opacity(0.78))
                .opacity(0.70)
                .frame(height: 1)

            HStack(spacing: 18) {
                PortfolioActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    value: likeCount > 0 ? "\(likeCount)" : nil,
                    accessibilityLabel: "Like \(portfolio.author)'s portfolio",
                    action: likeAction
                )
                PortfolioActionButton(
                    icon: "bubble.right",
                    value: commentCount > 0 ? "\(commentCount)" : nil,
                    accessibilityLabel: "Comment on \(portfolio.author)'s portfolio",
                    action: commentAction
                )
                Spacer()
                PortfolioActionButton(
                    icon: isBookmarked ? "bookmark.fill" : "bookmark",
                    value: nil,
                    accessibilityLabel: "Bookmark \(portfolio.author)'s portfolio",
                    action: bookmarkAction
                )
            }
            .padding(.top, -5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [
                    AppPalette.paper.opacity(0.98),
                    AppPalette.panel.opacity(0.98),
                    AppPalette.paper.opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(isSelected ? AppPalette.gold.opacity(0.72) : AppPalette.hairline.opacity(0.78), lineWidth: isSelected ? 1.7 : 1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.045), radius: isSelected ? 16 : 9, y: isSelected ? 9 : 5)
        .shadow(color: AppPalette.oliveShadow.opacity(isSelected ? 0.68 : 0.28), radius: isSelected ? 22 : 10, y: isSelected ? 10 : 5)
    }

    private var carouselAssets: [String] {
        Array(portfolio.assets.prefix(6))
    }
}

struct PhotographerAvatar: View {
    let assetName: String
    let name: String

    var body: some View {
        GeometryReader { proxy in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(AppPalette.paperBright, lineWidth: 1.5)
                }
        }
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }
}

struct PortfolioPhotoCarousel: View {
    let assets: [String]
    @State private var visiblePhotoIndex: Int? = 0

    var body: some View {
        GeometryReader { proxy in
            let visibleAssets = Array(assets.prefix(3))
            let spacing: CGFloat = 8
            let photoWidth = (proxy.size.width - spacing * CGFloat(max(visibleAssets.count - 1, 0))) / CGFloat(max(visibleAssets.count, 1))

            ZStack(alignment: .bottom) {
                HStack(spacing: spacing) {
                    ForEach(Array(visibleAssets.enumerated()), id: \.offset) { index, asset in
                        Image(asset)
                            .resizable()
                            .scaledToFill()
                            .frame(width: photoWidth, height: proxy.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(AppPalette.hairline, lineWidth: 1)
                            }
                            .id(index)
                    }
                }

                CarouselDots(count: min(assets.count, 6), activeIndex: min(visiblePhotoIndex ?? 0, max(min(assets.count, 6) - 1, 0)))
                    .padding(.bottom, 6)
            }
        }
        .frame(height: 116)
    }
}

struct PortfolioFeedTagRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                Label {
                    Text(tag.uppercased())
                        .font(.custom("AvenirNext-DemiBold", size: 8.2))
                        .kerning(0.9)
                        .lineLimit(1)
                        .minimumScaleFactor(1)
                } icon: {
                    Image(systemName: iconName(for: tag))
                        .font(.system(size: 9.5, weight: .medium))
                }
                .foregroundStyle(AppPalette.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(AppPalette.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func iconName(for tag: String) -> String {
        let lowercasedTag = tag.lowercased()
        if lowercasedTag.contains("landmark") || lowercasedTag.contains("campus") {
            return "building.columns"
        }
        if lowercasedTag.contains("light") || lowercasedTag.contains("warm") {
            return "sun.max"
        }
        if lowercasedTag.contains("portrait") {
            return "person"
        }
        if lowercasedTag.contains("motion") || lowercasedTag.contains("wide") {
            return "figure.walk"
        }
        return "sparkles"
    }
}

struct CarouselDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 4.5) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? AppPalette.paperBright.opacity(0.98) : AppPalette.paperBright.opacity(0.58))
                    .frame(width: index == activeIndex ? 5.2 : 4.4, height: index == activeIndex ? 5.2 : 4.4)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.30), in: Capsule())
    }
}

struct PortfolioActionButton: View {
    let icon: String
    let value: String?
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                if let value {
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(AppPalette.ivory.opacity(0.88))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PortfolioMiniStrip: View {
    let assets: [String]

    var body: some View {
        GeometryReader { proxy in
            let width = (proxy.size.width - 16) / 3
            HStack(spacing: 8) {
                ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: index == 1 ? 132 : 112)
                        .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                                .stroke(AppPalette.paper.opacity(0.55), lineWidth: 1)
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }
}

struct ShotReferenceRow: View {
    let shot: PortfolioShot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(shot.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(shot.title)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .lineLimit(2)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppPalette.gold)
                        }
                    }
                    Label(shot.location, systemImage: "mappin.and.ellipse")
                        .font(AppType.chip)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        .lineLimit(1)
                    Text(shot.gesture)
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.68))
                        .lineLimit(3)
                    TagRow(tags: shot.tags)
                }
            }
            .padding(12)
            .surfaceCard(cornerRadius: AppChrome.radiusSmall)
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? AppPalette.gold : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(shot.title)")
    }
}

struct SubjectCalibrationView: View {
    @Binding var referenceImage: UIImage?

    let profile: SubjectProfile?
    let sessionId: String
    let captureAction: (SubjectProfile) -> Void
    let continueAction: () -> Void
    let backAction: () -> Void

    @State private var isShowingCamera = false
    @State private var isShowingSimulatedCamera = false
    @State private var calibrationResult: PhoneTestSubjectCalibrationResult?

    var body: some View {
        GeometryReader { proxy in
            let hasUploadedSelfie = referenceImage != nil
            let visibleCalibration = calibrationResult ?? profile.map {
                PhoneTestSubjectCalibrationResult(
                    profile: $0,
                    source: "stored_subject_profile",
                    confidenceLabel: "Stored"
                )
            }

            ZStack(alignment: .top) {
                PortfolioDetailBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    SubjectCalibrationTopBar(backAction: backAction)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)

                    VStack(spacing: 11) {
                        Text("Who will be in\nthe photo?")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 38))
                            .foregroundStyle(AppPalette.ivory)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-2)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)

                        Text("Upload one selfie or group selfie so\nBlooming knows who to guide.")
                            .font(.custom("AvenirNext-Regular", size: 14.5))
                            .foregroundStyle(AppPalette.ivory.opacity(0.64))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 22)

                    SubjectSelfieCard(
                        referenceImage: referenceImage,
                        action: openCameraOrDemo
                    )
                    .frame(width: min(proxy.size.width - 62, 320), height: 360)
                    .padding(.top, 20)

                    HStack(spacing: 8) {
                        SubjectStatusChip(title: "selfie\nuploaded", isComplete: hasUploadedSelfie)
                        SubjectStatusChip(title: "face is\nclear", isComplete: visibleCalibration != nil)
                        SubjectStatusChip(title: "ready for\nprocessing", isComplete: visibleCalibration != nil)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 13)

                    Button(action: confirmSelfie) {
                        Text("Confirm Selfie")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 24))
                            .foregroundStyle(hasUploadedSelfie ? AppPalette.buttonText : AppPalette.ivory.opacity(0.42))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(hasUploadedSelfie ? AppPalette.gold : AppPalette.paper.opacity(0.42), in: Capsule())
                            .shadow(color: AppPalette.oliveShadow.opacity(hasUploadedSelfie ? 0.75 : 0.18), radius: 16, y: 7)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasUploadedSelfie)
                    .accessibilityLabel("Confirm Selfie")
                    .padding(.horizontal, 40)
                    .padding(.top, 18)

                    Spacer(minLength: 16)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            PhoneTestCameraView { image in
                handleSubjectSelfieCapture(image)
                isShowingCamera = false
            } cancelAction: {
                isShowingCamera = false
            }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingSimulatedCamera) {
            SubjectSimulatedCameraView {
                referenceImage = UIImage(named: "SubjectSelfieCleanReference") ?? DemoSelfieImage.make()
                if let referenceImage {
                    calibrationResult = PhoneTestSubjectCalibrationResult.fromAdapter(for: referenceImage, sessionId: sessionId)
                }
                isShowingSimulatedCamera = false
            } cancelAction: {
                isShowingSimulatedCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func openCameraOrDemo() {
        #if targetEnvironment(simulator)
        isShowingSimulatedCamera = true
        #else
        isShowingCamera = true
        #endif
    }

    private func handleSubjectSelfieCapture(_ image: UIImage) {
        referenceImage = image
        calibrationResult = PhoneTestSubjectCalibrationResult.fromAdapter(for: image, sessionId: sessionId)
    }

    private func confirmSelfie() {
        guard let referenceImage else { return }
        let result = calibrationResult ?? PhoneTestSubjectCalibrationResult.fromAdapter(for: referenceImage, sessionId: sessionId)
        calibrationResult = result
        captureAction(result.profile)
        continueAction()
    }
}

struct SubjectCalibrationTopBar: View {
    let backAction: () -> Void

    var body: some View {
        ZStack {
            PortfolioFeedWordmark()
                .frame(maxWidth: .infinity, alignment: .center)

            PortfolioFeedBackButton(action: backAction)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SubjectSimulatedCameraView: View {
    let captureAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = max(proxy.safeAreaInsets.bottom, 18)

            ZStack {
                Color.black.ignoresSafeArea()

                Image("SubjectSelfieCleanReference")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay(.black.opacity(0.18))
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("Subject selfie")
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)

                    Spacer()

                    VStack(spacing: 16) {
                        Text("Fit everyone’s face inside the frame.")
                            .font(.custom("AvenirNext-Regular", size: 14))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.36), in: Capsule())

                        Button(action: captureAction) {
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.94), lineWidth: 4)
                                    .frame(width: 76, height: 76)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 60, height: 60)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Capture subject selfie")
                    }
                    .frame(width: proxy.size.width, alignment: .center)
                    .padding(.bottom, safeBottom + 22)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                VStack {
                    HStack {
                        Button(action: cancelAction) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.62), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close camera")

                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 70)

                    Spacer()
                }
            }
        }
    }
}

struct SubjectSelfieCard: View {
    let referenceImage: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 17) {
                ZStack(alignment: .bottom) {
                    ZStack {
                        if let referenceImage {
                            Image(uiImage: referenceImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image("SubjectSelfieCleanReference")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(height: 252)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(AppPalette.hairline.opacity(0.86), lineWidth: 1)
                    }

                    if referenceImage != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Selfie captured")
                                .font(.custom("AvenirNext-DemiBold", size: 10.5))
                                .kerning(1.6)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(AppPalette.buttonText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(AppPalette.gold, in: Capsule())
                        .padding(.bottom, 12)
                    }

                }
                .padding(.top, 22)
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.gold)
                        .frame(width: 26)

                    Text("Good lighting and clear faces help Blooming guide you better.")
                        .font(.custom("AvenirNext-Regular", size: 10.8))
                        .foregroundStyle(AppPalette.ivory.opacity(0.65))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .lineSpacing(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(AppPalette.hairline.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [AppPalette.paperBright, AppPalette.paper.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppPalette.paper.opacity(0.92), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 16, y: 7)
            .shadow(color: AppPalette.oliveShadow.opacity(0.35), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(referenceImage == nil ? "Upload a selfie" : "Retake selfie")
    }
}

struct CameraOverlayButton: View {
    var body: some View {
        Image(systemName: "camera")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(AppPalette.gold)
            .frame(width: 67, height: 67)
            .background(AppPalette.paperBright, in: Circle())
            .overlay {
                Circle()
                    .stroke(AppPalette.hairline.opacity(0.66), lineWidth: 1)
            }
            .overlay {
                Image(systemName: "viewfinder")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppPalette.gold.opacity(0.80))
            }
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }
}

struct SubjectStatusChip: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isComplete ? AppPalette.gold : AppPalette.ivory.opacity(0.34))

            Text(title)
                .font(.custom("AvenirNext-Regular", size: 9.4))
                .foregroundStyle(AppPalette.ivory.opacity(isComplete ? 0.72 : 0.42))
                .lineLimit(2)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(AppPalette.paper.opacity(isComplete ? 0.72 : 0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.hairline.opacity(0.72), lineWidth: 1)
        }
    }
}

struct PlainEditorialBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppPalette.ivory)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

enum DemoSelfieImage {
    static func make() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 720, height: 940), format: format)

        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: 720, height: 940)
            UIColor(red: 0.72, green: 0.82, blue: 0.84, alpha: 1).setFill()
            context.fill(rect)

            UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 164, y: 148, width: 392, height: 392)).fill()

            UIColor(red: 0.22, green: 0.21, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 244, y: 284, width: 32, height: 38)).fill()
            UIBezierPath(ovalIn: CGRect(x: 444, y: 284, width: 32, height: 38)).fill()

            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 294, y: 390))
            smile.addCurve(to: CGPoint(x: 426, y: 390), controlPoint1: CGPoint(x: 326, y: 438), controlPoint2: CGPoint(x: 394, y: 438))
            smile.lineWidth = 12
            UIColor(red: 0.42, green: 0.46, blue: 0.32, alpha: 1).setStroke()
            smile.stroke()

            UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 122, y: 570, width: 476, height: 430), cornerRadius: 238).fill()

            UIColor(red: 0.42, green: 0.46, blue: 0.32, alpha: 1).setStroke()
            let framePath = UIBezierPath(roundedRect: CGRect(x: 36, y: 36, width: 648, height: 868), cornerRadius: 42)
            framePath.lineWidth = 10
            framePath.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                .foregroundColor: UIColor(red: 0.22, green: 0.21, blue: 0.18, alpha: 0.58),
                .paragraphStyle: paragraph
            ]
            "Demo selfie".draw(in: CGRect(x: 0, y: 802, width: 720, height: 50), withAttributes: attributes)
        }
    }
}

struct SceneChoiceView: View {
    let scanAction: () -> Void
    let currentAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PortfolioDetailBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    SubjectCalibrationTopBar(backAction: backAction)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Find the shot")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 40))
                            .foregroundStyle(AppPalette.ivory)
                        Text("Let Blooming scout nearby options, or\nanalyze a scene you already like.")
                            .font(.custom("AvenirNext-Regular", size: 15))
                            .foregroundStyle(AppPalette.ivory.opacity(0.72))
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 34)
                    .padding(.top, 48)

                    VStack(spacing: 14) {
                        SceneOptionPanel(
                            title: "Scan Surroundings",
                            subtitle: "Best when you are unsure where to stand. The app returns the strongest nearby scene.",
                            icon: "viewfinder",
                            badge: "Recommended",
                            action: scanAction
                        )
                        SceneOptionPanel(
                            title: "Use Current Scene",
                            subtitle: "Best when you already found a wall, archway, tower view, or pocket of light.",
                            icon: "photo",
                            badge: "Fast",
                            action: currentAction
                        )
                    }
                    .frame(width: min(proxy.size.width - 40, 340))
                    .padding(.top, 44)

                    Spacer(minLength: 18)
                }
            }
        }
    }
}

struct ScanSurroundingsView: View {
    let candidate: SceneCandidate
    @Binding var uploadStatus: SceneUploadStatus
    let captureAction: (UIImage) -> Void
    let continueAction: (Bool) -> Void
    let backAction: () -> Void
    @State private var isShowingScanCamera = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width - 32, 336)

            ZStack(alignment: .top) {
                PortfolioDetailBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    SubjectCalibrationTopBar(backAction: backAction)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        Text("Scan surroundings")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 40))
                            .foregroundStyle(AppPalette.ivory)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text("Hold your phone upright,\nthen slowly turn once.")
                            .font(.custom("AvenirNext-Regular", size: 16))
                            .foregroundStyle(AppPalette.ivory.opacity(0.74))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 14)

                        ScanInstructionPill()
                            .padding(.top, 28)

                        ScanCaptureFrame(
                            assetName: candidate.assetName,
                            isReady: uploadStatus.isReady
                        )
                        .frame(width: contentWidth, height: min(proxy.size.height * 0.36, 292))
                        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .onTapGesture {
                            isShowingScanCamera = true
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(uploadStatus.isReady ? "Retake surroundings scan" : "Open camera to scan surroundings")
                        .padding(.top, 26)

                        ScanVideoStatusCard(status: uploadStatus)
                            .frame(width: contentWidth)
                            .padding(.top, 14)

                        if uploadStatus.isReady {
                            Button {
                                continueAction(false)
                            } label: {
                                ScanUploadButtonLabel(status: .ready)
                                    .frame(width: contentWidth)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 18)
                        } else if uploadStatus.isFailed {
                            Button {
                                continueAction(true)
                            } label: {
                                ScanUploadButtonLabel(status: uploadStatus)
                                    .frame(width: contentWidth)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 18)
                        } else {
                            ScanUploadButtonLabel(status: .empty)
                                .frame(width: contentWidth)
                                .padding(.top, 18)
                        }
                    }
                    .padding(.top, 36)

                    Spacer(minLength: 12)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingScanCamera) {
            #if targetEnvironment(simulator)
            SimulatedScanCameraView(
                assetName: candidate.assetName,
                finishAction: {
                    uploadStatus = .ready
                    isShowingScanCamera = false
                },
                cancelAction: {
                    isShowingScanCamera = false
                }
            )
            #else
            PhoneTestCameraView(
                title: "Surroundings Scan",
                permissionPrompt: "Camera access is needed to capture the surrounding scene.",
                runningPrompt: "Slowly turn once, then capture the best frame",
                captureAccessibilityLabel: "Capture surroundings scan frame",
                preferredPosition: .back
            ) { image in
                captureAction(image)
                isShowingScanCamera = false
            } cancelAction: {
                isShowingScanCamera = false
            }
            .ignoresSafeArea()
            #endif
        }
    }
}

struct ScanInstructionPill: View {
    @State private var drift = false

    var body: some View {
        HStack(spacing: 10) {
            Image("ScanSprig")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppPalette.gold.opacity(0.9))
                .frame(width: 54, height: 38)
                .rotationEffect(.degrees(drift ? 1.6 : -1.6))
                .offset(y: drift ? -0.5 : 0.5)
            Text("Turn once, slowly")
                .font(.custom("AvenirNext-Regular", size: 16.5))
                .foregroundStyle(AppPalette.gold)
        }
        .padding(.leading, 18)
        .padding(.trailing, 22)
        .frame(height: 46)
        .background(
            AppPalette.paperBright.opacity(0.92),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(AppPalette.hairline.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 14, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct SlowScanPhoneIcon: View {
    let color: Color
    var lineWidth: CGFloat = 4
    var animate: Bool = false

    @State private var sway = false

    var body: some View {
        Image("SlowScanReferenceIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .rotationEffect(.degrees(animate && sway ? 2 : animate ? -2 : 0))
            .onAppear {
                guard animate else { return }
                withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                    sway = true
                }
            }
    }
}

struct ScanCaptureFrame: View {
    let assetName: String
    let isReady: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if isReady {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(.black.opacity(0.12))
                        .transition(.opacity)
                } else {
                    LinearGradient(
                        colors: [
                            AppPalette.paperBright.opacity(0.96),
                            AppPalette.powderBlue.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    VStack(spacing: 15) {
                        SlowScanPhoneIcon(color: AppPalette.gold.opacity(0.86), lineWidth: 3.8, animate: true)
                            .frame(width: 158, height: 100)
                        Text("tap to begin\nslow 360 scan")
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .kerning(1.8)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppPalette.gold.opacity(0.76))
                    }
                }

                CameraGuideOverlay(
                    strokeColor: isReady ? AppPalette.paper.opacity(0.78) : AppPalette.gold.opacity(0.76),
                    edgeInset: 0.08,
                    horizontalLength: 0.12,
                    verticalLength: 0.10
                )
                .padding(10)

                if isReady {
                    VStack(spacing: 10) {
                        SlowScanPhoneIcon(color: AppPalette.paper.opacity(0.96), lineWidth: 4.2)
                            .frame(width: 198, height: 124)
                        Text("slow 360 scan")
                            .font(.custom("AvenirNext-Regular", size: 17))
                            .foregroundStyle(AppPalette.paper)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.paper.opacity(0.72), lineWidth: 1.1)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 9)
    }
}

struct ScanVideoStatusCard: View {
    let status: SceneUploadStatus

    private var isReady: Bool { status.isReady }

    private var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    private var title: String {
        switch status {
        case .ready:
            return "Video ready to upload"
        case .failed:
            return "Video not ready, please retry"
        case .empty:
            return "Video scan not captured"
        }
    }

    private var subtitle: String {
        switch status {
        case .ready:
            return "Blooming will calculate light, depth, and standing position."
        case .failed(let reason):
            return reason.message
        case .empty:
            return "Capture a slow scan first so Blooming can find the strongest scene."
        }
    }

    private var iconName: String {
        switch status {
        case .ready:
            return "checkmark"
        case .failed:
            return "xmark"
        case .empty:
            return "video"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: isReady || isFailed ? 27 : 22, weight: .medium))
                .foregroundStyle(isReady || isFailed ? AppPalette.paper : AppPalette.gold.opacity(0.52))
                .frame(width: 48, height: 48)
                .background(
                    isReady ? AppPalette.gold : isFailed ? Color(red: 0.62, green: 0.30, blue: 0.26) : AppPalette.gold.opacity(0.10),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 24))
                    .foregroundStyle(AppPalette.ivory.opacity(isReady || isFailed ? 1 : 0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(subtitle)
                    .font(.custom("AvenirNext-Regular", size: 12.4))
                    .foregroundStyle(AppPalette.ivory.opacity(isReady || isFailed ? 0.72 : 0.44))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.paperBright.opacity(isReady || isFailed ? 0.96 : 0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((isFailed ? Color(red: 0.62, green: 0.30, blue: 0.26).opacity(0.38) : AppPalette.hairline.opacity(isReady ? 1 : 0.42)), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isReady || isFailed ? 0.06 : 0.025), radius: 12, y: 6)
    }
}

struct ScanUploadButtonLabel: View {
    let status: SceneUploadStatus

    private var isReady: Bool { status.isReady }
    private var isFailed: Bool { status.isFailed }

    private var title: String {
        isFailed ? "Upload Scan Anyway" : "Confirm and Upload Scan"
    }

    private var iconName: String {
        isFailed ? "exclamationmark.triangle" : "icloud.and.arrow.up"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .medium))
            Text(title)
                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
        }
        .foregroundStyle(AppPalette.buttonText.opacity(isReady || isFailed ? 1 : 0.78))
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            AppPalette.gold.opacity(isReady ? 1 : isFailed ? 0.90 : 0.62),
            in: Capsule()
        )
        .overlay {
            if isFailed {
                Capsule()
                    .stroke(Color(red: 0.62, green: 0.30, blue: 0.26).opacity(0.28), lineWidth: 1)
            }
        }
        .shadow(color: AppPalette.oliveShadow.opacity(isReady || isFailed ? 1 : 0.5), radius: 13, y: 7)
    }
}

struct SimulatedScanCameraView: View {
    let assetName: String
    let finishAction: () -> Void
    let cancelAction: () -> Void

    @State private var sweep = false

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = max(proxy.safeAreaInsets.bottom, 16)
            let guideWidth = proxy.size.width - 76
            let guideHeight = min(proxy.size.height * 0.50, 500)
            let guideTop = proxy.size.height * 0.27
            let guideCenterY = guideTop + guideHeight / 2
            let instructionY = guideTop + guideHeight + 46
            let buttonWidth = min(proxy.size.width - 48, 352)
            let buttonCenterY = proxy.size.height - safeBottom - 33

            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(.black.opacity(0.34))
                    .ignoresSafeArea()

                CameraGuideOverlay()
                    .frame(width: guideWidth, height: guideHeight)
                    .position(x: proxy.size.width / 2, y: guideCenterY)

                SlowScanPhoneIcon(color: AppPalette.paper.opacity(0.96), lineWidth: 5, animate: true)
                    .frame(width: 190, height: 118)
                    .rotationEffect(.degrees(sweep ? 5 : -5))
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: sweep)
                    .position(x: proxy.size.width / 2, y: guideCenterY)

                Text("Turn once, slowly")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 32))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                    .position(x: proxy.size.width / 2, y: instructionY)

                Button(action: finishAction) {
                    ZStack {
                        Capsule()
                            .fill(AppPalette.paperBright)
                            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                        Text("Finish Scan")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 24))
                            .foregroundStyle(AppPalette.ivory)
                    }
                    .frame(width: buttonWidth, height: 58)
                }
                .buttonStyle(.plain)
                .position(x: proxy.size.width / 2, y: buttonCenterY)

                VStack(spacing: 0) {
                    HStack {
                        Button(action: cancelAction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.black.opacity(0.42), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("slow 360 scan")
                            .font(.custom("AvenirNext-DemiBold", size: 12))
                            .kerning(2.2)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.82))

                        Spacer()

                        Color.clear.frame(width: 42, height: 42)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 70)

                    Spacer()
                }
            }
        }
        .onAppear { sweep = true }
    }
}

struct CurrentSceneView: View {
    let candidate: SceneCandidate
    let capturedImage: UIImage?
    let analysisResult: PhoneTestSceneInputAnalysisResult?
    @Binding var uploadStatus: SceneUploadStatus
    let captureAction: (UIImage) -> Void
    let continueAction: (Bool) -> Void
    let backAction: () -> Void
    @State private var isShowingSceneCamera = false
    @State private var canConfirmUpload = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width - 44, 342)
            let captureHeight = min(max(proxy.size.height * 0.50, 392), 480)
            let canContinue = uploadStatus.isReady && (canConfirmUpload || analysisResult != nil)

            ZStack(alignment: .top) {
                PortfolioDetailBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    SubjectCalibrationTopBar(backAction: backAction)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Current scene")
                                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 37))
                                    .foregroundStyle(AppPalette.ivory)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)

                                Text("Take one photo of the scene\nyou already like.")
                                    .font(.custom("AvenirNext-Regular", size: 14.5))
                                    .foregroundStyle(AppPalette.ivory.opacity(0.74))
                                    .lineSpacing(3)
                            }
                            .frame(width: contentWidth, alignment: .leading)
                            .padding(.top, 22)

                            Button {
                                isShowingSceneCamera = true
                            } label: {
                                SceneCameraCaptureCard(
                                    assetName: candidate.assetName,
                                    capturedImage: capturedImage,
                                    mode: uploadStatus.isReady ? "PHOTO READY" : "OPEN CAMERA",
                                    title: uploadStatus.isReady ? "Scene photo preview" : "Tap to take a scene photo",
                                    subtitle: uploadStatus.isReady ? "" : "Take one steady frame.",
                                    icon: uploadStatus.isReady ? "checkmark" : "camera.fill",
                                    showGuides: true
                                )
                            }
                            .frame(width: contentWidth, height: captureHeight)
                            .buttonStyle(.plain)
                            .accessibilityLabel(uploadStatus.isReady ? "Retake current scene photo" : "Open camera to take current scene photo")
                            .padding(.top, 24)

                            ScenePhotoStatusCard(status: uploadStatus)
                                .frame(width: contentWidth)
                                .padding(.top, 12)

                            if canContinue {
                                Button {
                                    continueAction(false)
                                } label: {
                                    SceneConfirmUploadButtonLabel(status: .ready)
                                        .frame(width: contentWidth)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 15)
                            } else if uploadStatus.isFailed {
                            Button {
                                continueAction(true)
                            } label: {
                                    SceneConfirmUploadButtonLabel(status: uploadStatus)
                                        .frame(width: contentWidth)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 15)
                            } else {
                                SceneConfirmUploadButtonLabel(status: uploadStatus)
                                    .frame(width: contentWidth)
                                    .padding(.top, 15)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingSceneCamera) {
            #if targetEnvironment(simulator)
            SimulatedScenePhotoCameraView(
                assetName: candidate.assetName,
                finishAction: {
                    let image = UIImage(named: candidate.assetName) ?? DemoSelfieImage.make()
                    captureAction(image)
                    canConfirmUpload = false
                    isShowingSceneCamera = false
                    Task {
                        try? await Task.sleep(nanoseconds: 650_000_000)
                        canConfirmUpload = true
                    }
                },
                cancelAction: {
                    isShowingSceneCamera = false
                }
            )
            #else
            PhoneTestCameraView(
                title: "Scene Photo",
                permissionPrompt: "Camera access is needed to capture the current scene.",
                runningPrompt: "Frame the place you want to use",
                captureAccessibilityLabel: "Capture scene photo",
                preferredPosition: .back
            ) { image in
                captureAction(image)
                canConfirmUpload = false
                isShowingSceneCamera = false
                Task {
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    canConfirmUpload = true
                }
            } cancelAction: {
                isShowingSceneCamera = false
            }
            .ignoresSafeArea()
            #endif
        }
    }
}

enum SceneCaptureGuideMode {
    case scan
    case photo
}

struct SceneCaptureGuide: View {
    let title: String
    let subtitle: String
    let mode: SceneCaptureGuideMode

    @State private var animate = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppPalette.gold)
                    .frame(width: 46, height: 46)

                if mode == .scan {
                    Circle()
                        .trim(from: 0.08, to: 0.86)
                        .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(animate ? 360 : 0))
                    Image(systemName: "iphone")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ivory)
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AppPalette.paperBright, lineWidth: 2)
                        .frame(width: 29, height: 23)
                    Image(systemName: "mountain.2")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppPalette.paperBright)
                        .scaleEffect(animate ? 1.08 : 0.94)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: mode == .scan ? 2.4 : 1.25).repeatForever(autoreverses: mode == .photo)) {
                    animate = true
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21))
                    .foregroundStyle(AppPalette.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.custom("AvenirNext-Regular", size: 12.8))
                    .foregroundStyle(AppPalette.ivory.opacity(0.78))
                    .lineSpacing(1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 14, y: 8)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SceneCameraCaptureCard: View {
    let assetName: String
    let capturedImage: UIImage?
    let mode: String
    let title: String
    let subtitle: String
    let icon: String
    let showGuides: Bool

    var body: some View {
        GeometryReader { proxy in
            let isReady = mode == "PHOTO READY"

            ZStack {
                if isReady {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .overlay(.black.opacity(showGuides ? 0.10 : 0.18))
                    } else {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .overlay(.black.opacity(showGuides ? 0.10 : 0.18))
                    }
                } else {
                    LinearGradient(
                        colors: [
                            AppPalette.paperBright.opacity(0.74),
                            AppPalette.powderBlue.opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppPalette.gold.opacity(0.54), style: StrokeStyle(lineWidth: 2.1, dash: [7, 7]))
                                .frame(width: min(proxy.size.width * 0.46, 148), height: min(proxy.size.height * 0.36, 144))
                            Image(systemName: "photo")
                                .font(.system(size: 33, weight: .light))
                                .foregroundStyle(AppPalette.gold.opacity(0.48))
                        }
                    }
                    .offset(y: -10)
                }

                if showGuides {
                    CameraGuideOverlay(strokeColor: isReady ? AppPalette.paper.opacity(0.88) : AppPalette.gold.opacity(0.62), edgeInset: 0.09, horizontalLength: 0.11, verticalLength: 0.075)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 30)

                    if isReady {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppPalette.paper.opacity(0.86), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                            .frame(width: min(proxy.size.width * 0.48, 154), height: min(proxy.size.height * 0.52, 178))
                            .offset(y: -14)
                    }
                }

                VStack {
                    Spacer()
                    if isReady {
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppPalette.paperBright)
                                .frame(width: 24, height: 24)
                                .background(AppPalette.gold, in: Circle())
                            Text("photo ready")
                                .font(.custom("AvenirNext-DemiBold", size: 12))
                                .kerning(3)
                                .textCase(.uppercase)
                                .foregroundStyle(AppPalette.gold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppPalette.paperBright.opacity(0.94), in: Capsule())
                        .padding(.bottom, 10)
                    }

                    Text(title)
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 23))
                        .foregroundStyle(isReady ? AppPalette.paperBright : AppPalette.gold.opacity(0.74))
                        .shadow(color: .black.opacity(isReady ? 0.22 : 0.02), radius: 7, y: 3)
                        .padding(.bottom, 13)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.paper.opacity(0.82), lineWidth: 1.2)
        }
        .shadow(color: .black.opacity(0.075), radius: 18, y: 10)
    }
}

struct CameraGuideOverlay: View {
    var strokeColor: Color = AppPalette.paper.opacity(0.68)
    var edgeInset: CGFloat = 0.18
    var horizontalLength: CGFloat = 0.12
    var verticalLength: CGFloat = 0.10

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let left = width * edgeInset
            let right = width * (1 - edgeInset)
            let top = height * edgeInset
            let bottom = height * (1 - edgeInset)
            let horizontal = width * horizontalLength
            let vertical = height * verticalLength

            Path { path in
                path.move(to: CGPoint(x: left, y: top + vertical))
                path.addLine(to: CGPoint(x: left, y: top))
                path.addLine(to: CGPoint(x: left + horizontal, y: top))
                path.move(to: CGPoint(x: right, y: top + vertical))
                path.addLine(to: CGPoint(x: right, y: top))
                path.addLine(to: CGPoint(x: right - horizontal, y: top))
                path.move(to: CGPoint(x: left, y: bottom - vertical))
                path.addLine(to: CGPoint(x: left, y: bottom))
                path.addLine(to: CGPoint(x: left + horizontal, y: bottom))
                path.move(to: CGPoint(x: right, y: bottom - vertical))
                path.addLine(to: CGPoint(x: right, y: bottom))
                path.addLine(to: CGPoint(x: right - horizontal, y: bottom))
            }
            .stroke(strokeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

struct ScenePhotoStatusCard: View {
    let status: SceneUploadStatus

    private var isReady: Bool { status.isReady }

    private var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    private var title: String {
        switch status {
        case .ready:
            return "Scene ready to upload"
        case .failed:
            return "Photo not ready, please retry"
        case .empty:
            return "Scene photo not captured"
        }
    }

    private var subtitle: String {
        switch status {
        case .ready:
            return "Blooming will calculate the best standing point from this photo."
        case .failed(let reason):
            return reason.message
        case .empty:
            return "Tap the scene frame first so Blooming can analyze the place you chose."
        }
    }

    private var iconName: String {
        switch status {
        case .ready:
            return "checkmark"
        case .failed:
            return "xmark"
        case .empty:
            return "photo"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: isReady || isFailed ? 24 : 19, weight: .medium))
                .foregroundStyle(isReady || isFailed ? AppPalette.paper : AppPalette.gold.opacity(0.52))
                .frame(width: 46, height: 46)
                .background(
                    isReady ? AppPalette.gold : isFailed ? Color(red: 0.62, green: 0.30, blue: 0.26) : AppPalette.gold.opacity(0.10),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21))
                    .foregroundStyle(AppPalette.ivory.opacity(isReady || isFailed ? 1 : 0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(subtitle)
                    .font(.custom("AvenirNext-Regular", size: 12.8))
                    .foregroundStyle(AppPalette.ivory.opacity(isReady || isFailed ? 0.72 : 0.44))
                    .lineSpacing(1)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 11)
        .frame(minHeight: 72)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.paperBright.opacity(isReady || isFailed ? 0.96 : 0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((isFailed ? Color(red: 0.62, green: 0.30, blue: 0.26).opacity(0.38) : AppPalette.hairline.opacity(isReady ? 1 : 0.42)), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isReady || isFailed ? 0.06 : 0.025), radius: 12, y: 6)
    }
}

struct SceneInputAnalysisResultCard: View {
    let result: PhoneTestSceneInputAnalysisResult

    private var qualitySummary: String {
        let context = result.sceneInputQualityContext
        return "\(context.sceneInputMode.rawValue), \(context.sceneInputStatus.rawValue), suboptimal=\(context.allowsSuboptimalSceneInput ? "true" : "false")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: result.canGenerateScenePlan ? "checkmark.seal" : "exclamationmark.triangle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.paper)
                    .frame(width: 34, height: 34)
                    .background(AppPalette.gold, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scene input analysis")
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21))
                        .foregroundStyle(AppPalette.ivory)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(result.sourceLabel)
                        .font(.custom("AvenirNext-DemiBold", size: 10.5))
                        .kerning(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                SceneInputAnalysisRow(label: "sceneInputId", value: result.sceneInputId)
                SceneInputAnalysisRow(label: "sceneInputAttemptId", value: result.sceneInputAttemptId)
                SceneInputAnalysisRow(label: "scenePhotoId", value: result.scenePhotoId ?? "none")
                SceneInputAnalysisRow(label: "sceneAnalysisId", value: result.sceneAnalysisId)
                SceneInputAnalysisRow(label: "sceneInputStatus", value: result.sceneInputStatus.rawValue)
                SceneInputAnalysisRow(label: "sceneInputQualityContext", value: qualitySummary)
                SceneInputAnalysisRow(label: "analysisSource", value: result.analysisSource.rawValue)
                SceneInputAnalysisRow(label: "sourceLabel", value: result.sourceLabel)
                SceneInputAnalysisRow(label: "scenePlanRequest", value: result.scenePlanRequest == nil ? "not created" : "ready")
                if let failureReason = result.sceneInputFailureReason {
                    SceneInputAnalysisRow(label: "failureReason", value: failureReason.code)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppPalette.paperBright.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 12, y: 6)
    }
}

struct SceneInputAnalysisRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("AvenirNext-DemiBold", size: 10))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.ivory.opacity(0.52))
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AppPalette.ivory.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SceneConfirmUploadButtonLabel: View {
    let status: SceneUploadStatus

    private var isReady: Bool { status.isReady }
    private var isFailed: Bool { status.isFailed }

    private var title: String {
        isFailed ? "Upload Photo Anyway" : "Confirm Scene Upload"
    }

    private var iconName: String {
        isFailed ? "exclamationmark.triangle" : "icloud.and.arrow.up"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
            Text(title)
                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21))
        }
        .foregroundStyle(AppPalette.buttonText.opacity(isReady || isFailed ? 1 : 0.78))
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            AppPalette.gold.opacity(isReady ? 1 : isFailed ? 0.90 : 0.62),
            in: Capsule()
        )
        .overlay {
            if isFailed {
                Capsule()
                    .stroke(Color(red: 0.62, green: 0.30, blue: 0.26).opacity(0.28), lineWidth: 1)
            }
        }
        .shadow(color: AppPalette.oliveShadow.opacity(isReady || isFailed ? 1 : 0.5), radius: 13, y: 7)
    }
}

struct SimulatedScenePhotoCameraView: View {
    let assetName: String
    let finishAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(.black.opacity(0.22))

            CameraGuideOverlay(strokeColor: .white.opacity(0.86), edgeInset: 0.08, horizontalLength: 0.12, verticalLength: 0.10)
                .padding(34)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.78), style: StrokeStyle(lineWidth: 2.2, dash: [8, 7]))
                .frame(width: 172, height: 206)
                .offset(y: -18)

            VStack(spacing: 0) {
                HStack {
                    Button(action: cancelAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.42), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("frame current scene")
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .kerning(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.82))

                    Spacer()

                    Color.clear.frame(width: 42, height: 42)
                }
                .padding(.horizontal, 22)
                .padding(.top, 70)

                Spacer()

                VStack(spacing: 18) {
                    Text("Leave space for people")
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 32))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)

                    Button(action: finishAction) {
                        ZStack {
                            Circle()
                                .fill(AppPalette.paperBright)
                                .frame(width: 78, height: 78)
                                .shadow(color: .black.opacity(0.20), radius: 16, y: 8)
                            Circle()
                                .stroke(AppPalette.gold.opacity(0.82), lineWidth: 4)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Take scene photo")
                }
                .padding(.bottom, 104)
            }
        }
    }
}

struct SceneCalculatingView: View {
    let inputMethod: SceneInputMethod
    let candidate: SceneCandidate
    let portfolioTitle: String
    let portfolioAuthor: String
    let analysisState: SceneRuntimeSceneAnalysisDisplayState?
    let allowsSuboptimalInput: Bool
    let runSceneAnalysis: () async throws -> SceneRuntimeModels.GenerateScenePlanResponse
    let backAction: () -> Void
    let failureAction: (SceneUploadFailureReason) -> Void
    let continueAction: (SceneRuntimeModels.GenerateScenePlanResponse) -> Void

    @State private var progress: CGFloat = 0.78
    @State private var didFinish = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width - 44, 324)
            let shouldAutoContinue = !ProcessInfo.processInfo.arguments.contains("--debug-scene-analysis")
            let shouldFailAnalysis = ProcessInfo.processInfo.arguments.contains("--debug-scene-analysis-failed")
            let displayState = analysisState ?? .pending(portfolioTitle: portfolioTitle)

            ZStack(alignment: .top) {
                PortfolioDetailBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    SubjectCalibrationTopBar(backAction: backAction)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            VStack(spacing: 8) {
                                Text(displayState.title)
                                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 30))
                                    .foregroundStyle(AppPalette.ivory)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)

                                Text(displayState.subtitle)
                                    .font(.custom("AvenirNext-Regular", size: 13.2))
                                    .foregroundStyle(AppPalette.ivory.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.top, 18)

                            SceneAnalysisProgressRing(progress: progress)
                                .frame(width: 160, height: 160)
                                .padding(.top, 4)

                            SceneScanPreview(assetName: candidate.assetName)
                                .frame(width: contentWidth, height: 126)
                                .padding(.top, 4)

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(Array(displayState.metrics.enumerated()), id: \.offset) { _, metric in
                                    SceneAnalysisMetric(icon: metric.icon, label: metric.label, value: metric.value)
                                }
                            }
                            .frame(width: contentWidth)
                            .padding(.top, 2)

                            SceneRecipeSummaryRow(
                                assetName: candidate.assetName,
                                portfolioTitle: portfolioTitle,
                                portfolioAuthor: portfolioAuthor
                            )
                                .frame(width: contentWidth)
                                .padding(.top, 2)

                            SceneCalculatingButton()
                                .frame(width: contentWidth)
                                .padding(.top, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)
                    }
                }
            }
            .task {
                guard !didFinish else { return }
                didFinish = true
                withAnimation(.easeInOut(duration: 1.25)) {
                    progress = 0.88
                }
                guard shouldAutoContinue else { return }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                guard !Task.isCancelled else { return }
                if shouldFailAnalysis && !allowsSuboptimalInput {
                    failureAction(inputMethod == .scanSurroundings ? .scanTooFastOrBlurry : .overexposed)
                    return
                }
                do {
                    let scenePlan = try await runSceneAnalysis()
                    continueAction(scenePlan)
                } catch {
                    failureAction(inputMethod == .scanSurroundings ? .uploadFailed : .photoUnavailable)
                }
            }
        }
    }
}

struct SceneAnalysisProgressRing: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppPalette.paperBright.opacity(0.84), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AppPalette.gold)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .offset(x: 10, y: -8)
                    }
                Text("\(Int(progress * 100))%")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 42))
                    .foregroundStyle(AppPalette.gold)
                Text("Analyzing scene...")
                    .font(.custom("AvenirNext-Regular", size: 11.8))
                    .foregroundStyle(AppPalette.ivory.opacity(0.68))
            }
        }
    }
}

struct SceneScanPreview: View {
    let assetName: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(.black.opacity(0.06))

                HStack(spacing: 8) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 12, weight: .medium))
                    Text("Scan preview")
                        .font(.custom("AvenirNext-Regular", size: 12))
                }
                .foregroundStyle(AppPalette.ivory)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(AppPalette.paperBright.opacity(0.92), in: Capsule())
                .padding(10)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppPalette.paper.opacity(0.86), lineWidth: 2)
                    .frame(width: proxy.size.width * 0.38, height: proxy.size.height * 0.54)
                    .position(x: proxy.size.width * 0.60, y: proxy.size.height * 0.66)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.paper.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.09), radius: 14, y: 8)
        }
    }
}

struct SceneAnalysisMetric: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(AppPalette.gold)
                .frame(width: 42, height: 42)
                .background(AppPalette.graphite.opacity(0.35), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.custom("AvenirNext-Regular", size: 9.6))
                    .foregroundStyle(AppPalette.ivory.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(value)
                    .font(.custom("AvenirNext-Regular", size: 14.2))
                    .foregroundStyle(AppPalette.ivory)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(AppPalette.paperBright.opacity(0.94), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(AppPalette.hairline.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 10, y: 5)
    }
}

struct SceneRecipeSummaryRow: View {
    let assetName: String
    let portfolioTitle: String
    let portfolioAuthor: String

    var body: some View {
        HStack(spacing: 12) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(portfolioTitle)
                    .font(.custom("AvenirNext-Regular", size: 12.8))
                    .foregroundStyle(AppPalette.ivory)
                    .lineLimit(1)
                Text("by \(portfolioAuthor)")
                    .font(.custom("AvenirNext-Regular", size: 10.5))
                    .foregroundStyle(AppPalette.ivory.opacity(0.56))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppPalette.ivory.opacity(0.52))
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(AppPalette.paperBright.opacity(0.94), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(AppPalette.hairline.opacity(0.55), lineWidth: 1)
        }
    }
}

struct SceneCalculatingButton: View {
    @State private var spin = false

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .medium))
                .rotationEffect(.degrees(spin ? 18 : -18))
            Text("Calculating")
                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21))
        }
        .foregroundStyle(AppPalette.gold.opacity(0.86))
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(AppPalette.graphite.opacity(0.55), in: Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                spin = true
            }
        }
    }
}

struct LiveCoachingView: View {
    let candidate: SceneCandidate
    let state: SceneRuntimeLiveCoachUIState
    let scenePlan: SceneRuntimeModels.GenerateScenePlanResponse?
    let scenePlanOutput: PhoneTestScenePlanOutput?
    let liveReadinessOutput: PhoneTestLiveReadinessOutput?
    let canOpenFinalShooting: Bool
    let runReadiness: () -> Void
    let captureAction: () -> Void
    let backAction: () -> Void

    @StateObject private var speechCoach = LiveCoachingSpeechCoach()

    private var isReady: Bool {
        state.isReadyToCapture
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(candidate.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.12), .black.opacity(0.02), .black.opacity(0.52)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipped()
                    .ignoresSafeArea()

                LiveCameraGrid()
                    .ignoresSafeArea()

                LiveSubjectOverlay()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Button(action: backAction) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .background(.black.opacity(0.46), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")

                        Spacer()

                        Spacer()

                        LiveCoachingBadge(readiness: state.readiness)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 22)

                    Spacer()
                }

                VStack {
                    Spacer()
                    HStack {
                        LiveCueStack(cues: displayCues, isReady: isReady)
                            .frame(width: 160)
                            .padding(.leading, 12)
                        Spacer()
                    }
                    .padding(.bottom, 246)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 14) {
                        ForEach(Array(state.settingBadges.prefix(3).enumerated()), id: \.offset) { _, badge in
                            LiveSettingBadge(icon: badge.icon, title: badge.title, status: badge.status)
                        }
                    }
                    .padding(.bottom, 128)
                }

                VStack {
                    Spacer()
                    LiveCameraControlTray(
                        isReady: isReady,
                        canProceed: canOpenFinalShooting,
                        checkAction: runReadiness,
                        captureAction: captureAction,
                        retakeAction: backAction
                    )
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .task {
            speechCoach.start(prompts: spokenCoachingPrompts)
        }
        .onChange(of: spokenPromptSignature) { _, _ in
            speechCoach.start(prompts: spokenCoachingPrompts)
        }
        .onDisappear {
            speechCoach.stop()
        }
    }

    private var displayCues: [SceneRuntimeModels.CoachingCue] {
        if isGraduationSingleSubjectDemo {
            return GraduationSingleSubjectDemoGuidance.cues
        }
        return state.displayCues
    }

    private var spokenCoachingPrompts: [String] {
        displayCues.map { spokenSentence($0.message) }
    }

    private var spokenPromptSignature: String {
        spokenCoachingPrompts.joined(separator: "|")
    }

    private var isGraduationSingleSubjectDemo: Bool {
        let styleProfileId = scenePlan?.styleProfileId ?? scenePlanOutput?.scenePlan.styleProfileId ?? ""
        return styleProfileId.lowercased().contains("graduation")
    }

    private func spokenSentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        let sentence = first.uppercased() + trimmed.dropFirst()
        return sentence.hasSuffix(".") || sentence.hasSuffix("!") || sentence.hasSuffix("?")
            ? sentence
            : sentence + "."
    }
}

struct ScenePlanOutputSummaryCard: View {
    let output: PhoneTestScenePlanOutput
    let liveReadinessOutput: PhoneTestLiveReadinessOutput?

    private var framingSummary: String {
        "\(output.roughFraming.style), \(output.roughFraming.safetyMargin), \(output.roughFraming.orientation)"
    }

    private var fallbackSummary: String {
        if let lowConfidenceRationale = output.lowConfidenceRationale {
            return lowConfidenceRationale
        }
        if let fallback = output.fallback {
            return "\(fallback.type): \(fallback.message)"
        }
        return output.sourceLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "map")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.paper)
                    .frame(width: 30, height: 30)
                    .background(AppPalette.gold, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scene plan")
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 20))
                        .foregroundStyle(AppPalette.ivory)
                    Text(output.cameraSettingsApplicationStage)
                        .font(.custom("AvenirNext-DemiBold", size: 9.8))
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.ivory.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
            }

            SceneInputAnalysisRow(label: "scenePlanId", value: output.scenePlanId)
            SceneInputAnalysisRow(label: "standPoint", value: output.standPoint.label)
            SceneInputAnalysisRow(label: "subjectPosition", value: "\(output.subjectPosition.zone), \(output.subjectPosition.distanceCue)")
            SceneInputAnalysisRow(label: "operatorPosition", value: output.operatorPosition.framingCue)
            SceneInputAnalysisRow(label: "facingDirection", value: output.facingDirection.subjectCue)
            SceneInputAnalysisRow(label: "roughFraming", value: framingSummary)
            SceneInputAnalysisRow(label: "coachingCues", value: "\(output.coachingCues.count)")
            SceneInputAnalysisRow(label: "initialCameraRecommendation", value: output.initialCameraSettingsRecommendation.recommendationId)
            SceneInputAnalysisRow(label: "runtimeAffordances", value: "\(output.runtimeAffordanceSignals.count)")
            SceneInputAnalysisRow(label: "sourceOrFallback", value: fallbackSummary)
            if let liveReadinessOutput {
                SceneInputAnalysisRow(label: "liveReadinessSource", value: liveReadinessOutput.sourceLabel)
                SceneInputAnalysisRow(label: "cameraSettingsStage", value: liveReadinessOutput.cameraSettingsApplicationStage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.50), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.gold.opacity(0.38), lineWidth: 1)
        }
    }
}

struct FinalShootingCameraStep: View {
    let candidate: SceneCandidate
    let scenePlan: SceneRuntimeModels.GenerateScenePlanResponse?
    let scenePlanOutput: PhoneTestScenePlanOutput?
    let liveCoachState: SceneRuntimeLiveCoachUIState
    let runReadiness: () -> Void
    let captureAction: (UIImage) -> Void
    let backAction: () -> Void

    var body: some View {
        #if targetEnvironment(simulator)
        SimulatedScenePhotoCameraView(
            assetName: candidate.assetName,
            finishAction: {
                let image = UIImage(named: candidate.assetName) ?? DemoSelfieImage.make()
                captureAction(image)
            },
            cancelAction: backAction
        )
        .overlay(alignment: .bottom) {
            finalShootingLabel
                .padding(.bottom, 28)
        }
        #else
        PhoneTestCameraView(
            title: "Final Photo",
            permissionPrompt: "Camera access is needed to capture the final photo.",
            runningPrompt: scenePlanOutput?.operatorPosition.framingCue ?? "Frame the final photo",
            spokenPrompts: spokenCoachingPrompts,
            guidanceOverlay: cameraGuidanceOverlay,
            captureAccessibilityLabel: "Capture final photo",
            preferredPosition: .back,
            demoFallbackImage: UIImage(named: candidate.assetName) ?? DemoSelfieImage.make(),
            captureAction: captureAction,
            cancelAction: backAction
        )
        .ignoresSafeArea()
        #endif
    }

    private var finalShootingLabel: some View {
        Text("Final photo")
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .kerning(2.0)
            .textCase(.uppercase)
            .foregroundStyle(AppPalette.paper)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.black.opacity(0.48), in: Capsule())
    }

    private var cameraGuidanceOverlay: PhoneTestCameraGuidanceOverlay {
        PhoneTestCameraGuidanceOverlay(
            readiness: liveCoachState.readiness,
            displayCues: displayCues,
            settingBadges: liveCoachState.settingBadges,
            standPointTitle: standPointTitle,
            guidePlacement: guidePlacement,
            subjectCue: scenePlan?.subjectPosition.distanceCue ?? scenePlanOutput?.subjectPosition.distanceCue,
            operatorCue: scenePlan?.operatorPosition.framingCue ?? scenePlanOutput?.operatorPosition.framingCue,
            cameraRecommendation: scenePlan?.initialCameraSettingsRecommendation ?? scenePlanOutput?.initialCameraSettingsRecommendation,
            checkAction: runReadiness,
            retakeAction: backAction
        )
    }

    private var displayCues: [SceneRuntimeModels.CoachingCue] {
        if isGraduationSingleSubjectDemo {
            return GraduationSingleSubjectDemoGuidance.cues
        }
        return liveCoachState.displayCues
    }

    private var guidePlacement: PhoneTestCameraGuidePlacement {
        let zone = (scenePlan?.subjectPosition.zone ?? scenePlanOutput?.subjectPosition.zone ?? "").lowercased()
        if isGraduationSingleSubjectDemo || zone.contains("graduation_single") {
            return .graduationSingleSubject
        }
        if zone.contains("sit") || zone.contains("bench") || zone.contains("seated") {
            return .seatedSubject
        }
        return .environmentalStanding
    }

    private var standPointTitle: String {
        if isGraduationSingleSubjectDemo {
            return "Stand here"
        }
        let rawTitle = scenePlan?.standPoint.label ?? scenePlanOutput?.standPoint.label ?? defaultStandPointTitle
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultStandPointTitle : trimmed
    }

    private var defaultStandPointTitle: String {
        guidePlacement == .seatedSubject ? "Sit here" : "Stand here"
    }

    private var isGraduationSingleSubjectDemo: Bool {
        let styleProfileId = scenePlan?.styleProfileId ?? scenePlanOutput?.scenePlan.styleProfileId ?? ""
        return styleProfileId.lowercased().contains("graduation")
    }

    private var spokenCoachingPrompts: [String] {
        displayCues.map { spokenSentence($0.message) }
    }

    private func spokenSentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        let sentence = first.uppercased() + trimmed.dropFirst()
        return sentence.hasSuffix(".") || sentence.hasSuffix("!") || sentence.hasSuffix("?")
            ? sentence
            : sentence + "."
    }
}

enum GraduationSingleSubjectDemoGuidance {
    static let cues: [SceneRuntimeModels.CoachingCue] = [
        SceneRuntimeModels.CoachingCue(target: "subject", message: "Smile softly and look here."),
        SceneRuntimeModels.CoachingCue(target: "subject", message: "Take one small step back."),
        SceneRuntimeModels.CoachingCue(target: "subject", message: "Turn shoulders toward the light.")
    ]

}

struct LiveCameraGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                path.move(to: CGPoint(x: width * 0.32, y: 0))
                path.addLine(to: CGPoint(x: width * 0.32, y: height))
                path.move(to: CGPoint(x: width * 0.68, y: 0))
                path.addLine(to: CGPoint(x: width * 0.68, y: height))
                path.move(to: CGPoint(x: 0, y: height * 0.34))
                path.addLine(to: CGPoint(x: width, y: height * 0.34))
                path.move(to: CGPoint(x: 0, y: height * 0.63))
                path.addLine(to: CGPoint(x: width, y: height * 0.63))
            }
            .stroke(.white.opacity(0.48), lineWidth: 1)
        }
    }
}

struct LiveSubjectOverlay: View {
    private let guideColor = Color(red: 0.980, green: 0.835, blue: 0.260)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(guideColor.opacity(0.92), lineWidth: 2.4)
                    .frame(width: width * 0.62, height: height * 0.47)
                    .position(x: width * 0.62, y: height * 0.58)

                Text("Stand here")
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .foregroundStyle(AppPalette.ivory)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(guideColor.opacity(0.86), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppPalette.paper.opacity(0.48), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    .position(x: width * 0.72, y: height * 0.26)

                HStack(spacing: 7) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 34, weight: .bold))
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(guideColor.opacity(0.94))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                .position(x: width * 0.68, y: height * 0.46)
            }
        }
    }
}

struct LiveCoachingBadge: View {
    let readiness: SceneRuntimeModels.Readiness

    private var isReady: Bool {
        readiness == .ready || readiness == .bestEffort
    }

    private var title: String {
        switch readiness {
        case .ready:
            return "Ready"
        case .bestEffort:
            return "Best effort"
        case .almostReady:
            return "Almost"
        case .blocked:
            return "Blocked"
        case .scanning:
            return "Checking"
        case .coaching:
            return "Coaching"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isReady ? "checkmark" : "sparkles")
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 15))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .frame(height: 44)
        .background(AppPalette.gold.opacity(0.82), in: Capsule())
        .overlay {
            Capsule().stroke(AppPalette.paper.opacity(0.24), lineWidth: 1)
        }
    }
}

struct LiveCueStack: View {
    let cues: [SceneRuntimeModels.CoachingCue]
    let isReady: Bool

    private var rows: [(String, String, Bool)] {
        let runtimeRows = cues.prefix(4).map { cue -> (String, String, Bool) in
            (icon(for: cue), wrapped(cue.message), !isReady)
        }
        if runtimeRows.isEmpty {
            return [("checkmark", isReady ? "Hold. Ready." : "Run check", isReady)]
        }
        return runtimeRows
    }

    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    Image(systemName: row.0)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppPalette.gold)
                        .frame(width: 24)
                    Text(row.1)
                        .font(.custom("AvenirNext-DemiBold", size: 12.6))
                        .lineSpacing(3)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .foregroundStyle(AppPalette.paper)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(height: row.2 ? 64 : 58)
                .background(.black.opacity(row.2 ? 0.58 : 0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(row.2 ? AppPalette.gold.opacity(0.78) : .white.opacity(0.05), lineWidth: row.2 ? 1.5 : 1)
                }
            }
        }
    }

    private func icon(for cue: SceneRuntimeModels.CoachingCue) -> String {
        let message = cue.message.lowercased()
        if message.contains("light") || message.contains("brighter") {
            return "sun.max"
        }
        if message.contains("step") || message.contains("back") || message.contains("closer") {
            return "shoeprints.fill"
        }
        if message.contains("hold") || message.contains("steady") {
            return "checkmark"
        }
        if cue.target.lowercased().contains("subject") {
            return "figure.walk"
        }
        return "viewfinder"
    }

    private func wrapped(_ message: String) -> String {
        let words = message.split(separator: " ")
        guard words.count > 3 else { return message }
        return words.prefix(3).joined(separator: " ") + "\n" + words.dropFirst(3).prefix(4).joined(separator: " ")
    }
}

struct LiveSettingBadge: View {
    let icon: String
    let title: String
    let status: SceneRuntimeModels.CameraCapabilityStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppPalette.gold)
            Text(title)
                .font(.custom("AvenirNext-Regular", size: 13.5))
                .foregroundStyle(AppPalette.paper)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.black.opacity(0.45), in: Capsule())
        .overlay {
            Capsule().stroke(borderColor.opacity(0.66), lineWidth: 1)
        }
    }

    private var borderColor: Color {
        switch status {
        case .applied:
            return AppPalette.gold
        case .adjusted, .pending:
            return AppPalette.paper
        case .unavailable, .needsOperatorAdjustment:
            return Color.white
        }
    }
}

struct LiveCameraControlTray: View {
    let isReady: Bool
    let canProceed: Bool
    let checkAction: () -> Void
    let captureAction: () -> Void
    let retakeAction: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Button(action: checkAction) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 31, weight: .medium))
                        .frame(width: 62, height: 62)
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay { Circle().stroke(AppPalette.paper.opacity(0.20), lineWidth: 1) }
                    Text("Check")
                        .font(.custom("AvenirNext-Regular", size: 17))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Run readiness check")

            Spacer()

            Button(action: captureAction) {
                ZStack {
                    Circle()
                        .stroke(AppPalette.paper, lineWidth: 6)
                        .frame(width: 86, height: 86)
                    Circle()
                        .stroke(.black.opacity(0.74), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(AppPalette.gold.opacity(isReady ? 1 : canProceed ? 0.72 : 0.38))
                        .frame(width: 62, height: 62)
                }
            }
            .disabled(!canProceed)
            .buttonStyle(.plain)
            .accessibilityLabel(isReady ? "Open final shooting camera" : "Open final shooting camera with fallback readiness")

            Spacer()

            Button(action: retakeAction) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 27, weight: .regular))
                        .frame(width: 62, height: 62)
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay { Circle().stroke(AppPalette.paper.opacity(0.20), lineWidth: 1) }
                    Text("Retake")
                        .font(.custom("AvenirNext-Regular", size: 17))
                }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(AppPalette.paper)
        .padding(.horizontal, 36)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct FinalMomentMissingStateView: View {
    let title: String
    let actionTitle: String
    let backAction: () -> Void
    let action: () -> Void

    var body: some View {
        ZStack {
            PortfolioDetailBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                BloomingCenteredTopBar(backAction: backAction)
                    .padding(.horizontal, 20)

                Spacer()

                Text(title)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 31))
                    .foregroundStyle(AppPalette.ivory)

                Button(actionTitle, action: action)
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .foregroundStyle(AppPalette.paperBright)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(AppPalette.gold, in: Capsule())

                Spacer()
            }
            .padding(.vertical, 18)
        }
    }
}

struct PreviewKeeperView: View {
    let autoCullResult: FinalMomentAutoCullResult
    @Binding var selectedKeeperFrameIds: Set<String>
    let displayAssetName: (FinalMomentAssetRef) -> String
    let backAction: () -> Void
    let saveAction: () -> Void
    @State private var previewIndex: Int?

    private var acceptedFrames: [FinalMomentAcceptedFrame] {
        autoCullResult.acceptedFrames
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppPalette.paperBright
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    BloomingCenteredTopBar(backAction: backAction)
                        .padding(.horizontal, -4)
                        .padding(.top, 2)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select moments")
                                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 39))
                                .foregroundStyle(AppPalette.ivory)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Text("Choose the photos you want\nBlooming to fine tune.")
                                .font(.custom("AvenirNext-Regular", size: 15))
                                .foregroundStyle(AppPalette.ivory.opacity(0.72))
                                .lineSpacing(3)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 26) {
                            Text("\(selectedKeeperFrameIds.count) selected")
                                .font(.custom("AvenirNext-DemiBold", size: 13.5))
                                .foregroundStyle(AppPalette.gold)

                            Button(selectedKeeperFrameIds.count == acceptedFrames.count ? "Deselect All" : "Select All") {
                                if selectedKeeperFrameIds.count == acceptedFrames.count {
                                    selectedKeeperFrameIds.removeAll()
                                } else {
                                    selectedKeeperFrameIds = Set(acceptedFrames.map(\.frameId))
                                }
                            }
                            .font(.custom("AvenirNext-Regular", size: 14.5))
                            .foregroundStyle(AppPalette.ivory.opacity(0.74))
                        }
                        .padding(.top, -10)
                    }
                    .padding(.top, 16)

                    CapturedPhotoGrid(
                        frames: acceptedFrames,
                        selectedKeeperFrameIds: $selectedKeeperFrameIds,
                        displayAssetName: displayAssetName,
                        openAction: { index in
                            previewIndex = index
                        }
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 112)
            }

            VStack(spacing: 0) {
                Button(action: saveAction) {
                    Text("Fine Tune Selected (\(selectedKeeperFrameIds.count))")
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 21))
                        .foregroundStyle(AppPalette.paperBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppPalette.gold, in: Capsule())
                    .shadow(color: AppPalette.oliveShadow.opacity(0.34), radius: 12, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(selectedKeeperFrameIds.isEmpty)
                .opacity(selectedKeeperFrameIds.isEmpty ? 0.48 : 1)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(AppPalette.paperBright)
            }
            .ignoresSafeArea(edges: .bottom)

            if let previewIndex {
                KeeperPhotoPreviewOverlay(
                    frames: acceptedFrames,
                    selectedKeeperFrameIds: $selectedKeeperFrameIds,
                    displayAssetName: displayAssetName,
                    initialIndex: previewIndex,
                    closeAction: {
                        self.previewIndex = nil
                    }
                )
                .transition(.opacity)
                .zIndex(30)
            }
        }
    }
}

struct FineTuneReviewView: View {
    private static let launchArguments = ProcessInfo.processInfo.arguments

    let fineTuneResult: FinalMomentFineTuneResult
    @Binding var fineTuneDecisions: [String: FinalMomentSelectedOutput]
    let displayAssetName: (FinalMomentAssetRef) -> String
    let isSaved: Bool
    let viewProfileAction: () -> Void
    let takeMoreAction: () -> Void
    let backAction: () -> Void
    let saveAction: () -> Void

    @State private var activePreviewIndex: Int? = Self.launchArguments.contains("--debug-fine-tune-preview") ? 0 : nil

    private var selectedItems: [FinalMomentFineTuneItem] {
        fineTuneResult.items
    }

    private var chosenCount: Int {
        selectedItems.filter { fineTuneDecisions[$0.frameId] != nil }.count
    }

    private var isReadyToSave: Bool {
        !isSaved && chosenCount > 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PortfolioDetailBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 13) {
                    BloomingCenteredTopBar(backAction: backAction)
                        .padding(.horizontal, -4)
                        .padding(.top, 2)

                    VStack(spacing: 8) {
                        Text("AI fine tune")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 30))
                            .foregroundStyle(AppPalette.ivory)
                        Text("Choose the tuned version or\nkeep the original for each photo.")
                            .font(.custom("AvenirNext-Regular", size: 13.8))
                            .foregroundStyle(AppPalette.ivory.opacity(0.82))
                            .lineSpacing(3)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppPalette.paperBright)
                                .frame(width: 27, height: 27)
                                .background(AppPalette.gold, in: Circle())
                            Text("\(chosenCount) of \(selectedItems.count) chosen")
                                .font(.custom("AvenirNext-DemiBold", size: 14.5))
                                .foregroundStyle(AppPalette.ivory)
                        }
                        Spacer()
                        Button("Accept All") {
                            for item in selectedItems {
                                fineTuneDecisions[item.frameId] = .edited
                            }
                        }
                        .font(.custom("AvenirNext-DemiBold", size: 13.8))
                        .foregroundStyle(AppPalette.gold)
                        .disabled(isSaved || selectedItems.isEmpty)
                        .opacity(isSaved || selectedItems.isEmpty ? 0.46 : 1)
                    }
                    .padding(.top, 0)

                    VStack(spacing: 12) {
                        ForEach(Array(selectedItems.enumerated()), id: \.element.id) { index, item in
                            FineTunePhotoCard(
                                originalAssetName: displayAssetName(item.originalAssetRef),
                                croppedAssetName: displayAssetName(item.croppedAssetRef),
                                editedAssetName: displayAssetName(item.editedAssetRef),
                                cropLabel: item.recommendedCropId.replacingOccurrences(of: "_", with: " "),
                                presetApplied: fineTuneResult.presetApplied.replacingOccurrences(of: "_", with: " "),
                                decision: fineTuneDecisions[item.frameId],
                                previewAction: {
                                    activePreviewIndex = index
                                },
                                acceptFineTuneAction: {
                                    fineTuneDecisions[item.frameId] = .edited
                                },
                                keepOriginalAction: {
                                    fineTuneDecisions[item.frameId] = .croppedOriginal
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, isSaved ? 40 : 112)
            }

            if isSaved {
                EmptyView()
            } else {
                VStack(spacing: 0) {
                    Button(action: saveAction) {
                        Text("Save (\(chosenCount))")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                            .foregroundStyle(AppPalette.paperBright)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppPalette.gold, in: Capsule())
                            .shadow(color: AppPalette.oliveShadow.opacity(0.34), radius: 12, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isReadyToSave)
                    .opacity(isReadyToSave ? 1 : 0.48)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .background(AppPalette.paperBright)
                }
                .ignoresSafeArea(edges: .bottom)
            }

            if let activePreviewIndex {
                FineTuneBeforeAfterPreviewOverlay(
                    items: selectedItems,
                    displayAssetName: displayAssetName,
                    initialIndex: activePreviewIndex,
                    closeAction: {
                        self.activePreviewIndex = nil
                    }
                )
                .transition(.opacity)
                .zIndex(30)
            }
        }
    }
}

struct CapturedPhotoGrid: View {
    let frames: [FinalMomentAcceptedFrame]
    @Binding var selectedKeeperFrameIds: Set<String>
    let displayAssetName: (FinalMomentAssetRef) -> String
    let openAction: (Int) -> Void

    private let spacing: CGFloat = 8
    private let tileHeight: CGFloat = 184

    var body: some View {
        GeometryReader { proxy in
            let tileWidth = (proxy.size.width - spacing) / 2
            let rows = stride(from: 0, to: frames.count, by: 2).map { $0 }

            VStack(spacing: spacing) {
                ForEach(rows, id: \.self) { rowStart in
                    HStack(spacing: spacing) {
                        ForEach(rowStart..<min(rowStart + 2, frames.count), id: \.self) { index in
                            let frame = frames[index]
                            CapturedPhotoTile(
                                assetName: displayAssetName(frame.assetRef),
                                index: index,
                                isSelected: selectedKeeperFrameIds.contains(frame.frameId)
                            ) {
                                openAction(index)
                            }
                            .frame(width: tileWidth, height: tileHeight)
                        }

                        if rowStart + 1 >= frames.count {
                            Color.clear
                                .frame(width: tileWidth, height: tileHeight)
                        }
                    }
                }
            }
        }
        .frame(height: gridHeight)
    }

    private var gridHeight: CGFloat {
        let rowCount = CGFloat((frames.count + 1) / 2)
        return rowCount * tileHeight + max(0, rowCount - 1) * spacing
    }
}

struct CapturedPhotoTile: View {
    let assetName: String
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                GeometryReader { proxy in
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(isSelected ? AppPalette.gold : AppPalette.hairline, lineWidth: isSelected ? 2 : 1)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppPalette.paperBright)
                        .frame(width: 36, height: 36)
                        .background(AppPalette.gold, in: Circle())
                        .overlay {
                            Circle().stroke(AppPalette.paperBright, lineWidth: 1.4)
                        }
                        .padding(9)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Deselect captured photo \(index + 1)" : "Select captured photo \(index + 1)")
    }
}

struct KeeperPhotoPreviewOverlay: View {
    let frames: [FinalMomentAcceptedFrame]
    @Binding var selectedKeeperFrameIds: Set<String>
    let displayAssetName: (FinalMomentAssetRef) -> String
    let closeAction: () -> Void
    @State private var activeIndex: Int

    init(
        frames: [FinalMomentAcceptedFrame],
        selectedKeeperFrameIds: Binding<Set<String>>,
        displayAssetName: @escaping (FinalMomentAssetRef) -> String,
        initialIndex: Int,
        closeAction: @escaping () -> Void
    ) {
        self.frames = frames
        self._selectedKeeperFrameIds = selectedKeeperFrameIds
        self.displayAssetName = displayAssetName
        self.closeAction = closeAction
        self._activeIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture {
                    closeAction()
                }

            VStack(spacing: 18) {
                HStack {
                    Button("Select All") {
                        selectedKeeperFrameIds = Set(frames.map(\.frameId))
                    }
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(AppPalette.paperBright)

                    Spacer()

                    Text("\(selectedKeeperFrameIds.count) selected")
                        .font(.custom("AvenirNext-DemiBold", size: 13))
                        .foregroundStyle(AppPalette.paperBright.opacity(0.72))

                    Button(action: closeAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.ivory)
                            .frame(width: 34, height: 34)
                            .background(AppPalette.paperBright.opacity(0.92), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close photo preview")
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                TabView(selection: $activeIndex) {
                    ForEach(frames.indices, id: \.self) { index in
                        let frame = frames[index]
                        ZStack(alignment: .topTrailing) {
                            Image(displayAssetName(frame.assetRef))
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .padding(.horizontal, 18)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            Button {
                                if selectedKeeperFrameIds.contains(frame.frameId) {
                                    selectedKeeperFrameIds.remove(frame.frameId)
                                } else {
                                    selectedKeeperFrameIds.insert(frame.frameId)
                                }
                            } label: {
                                Image(systemName: selectedKeeperFrameIds.contains(frame.frameId) ? "checkmark" : "plus")
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundStyle(AppPalette.paperBright)
                                    .frame(width: 50, height: 50)
                                    .background(AppPalette.gold, in: Circle())
                                    .overlay {
                                        Circle().stroke(AppPalette.paperBright, lineWidth: 1.3)
                                    }
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 26)
                            .padding(.top, 12)
                            .accessibilityLabel(selectedKeeperFrameIds.contains(frame.frameId) ? "Deselect photo" : "Select photo")
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(maxHeight: .infinity)
            }
        }
    }
}

struct FineTunePhotoCard: View {
    let originalAssetName: String
    let croppedAssetName: String
    let editedAssetName: String
    let cropLabel: String
    let presetApplied: String
    let decision: FinalMomentSelectedOutput?
    let previewAction: () -> Void
    let acceptFineTuneAction: () -> Void
    let keepOriginalAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: previewAction) {
                BeforeAfterView(
                    originalAssetName: croppedAssetName.isEmpty ? originalAssetName : croppedAssetName,
                    editedAssetName: editedAssetName
                )
                .frame(height: 214)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open before and after preview")

            HStack(spacing: 8) {
                Label(presetApplied, systemImage: "camera.filters")
                Text(cropLabel)
            }
            .font(.custom("AvenirNext-Regular", size: 11.5))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .foregroundStyle(AppPalette.ivory.opacity(0.58))

            HStack(spacing: 9) {
                FineTuneChoiceButton(
                    title: "Accept Fine Tune",
                    icon: "wand.and.stars",
                    isSelected: decision == .edited,
                    action: acceptFineTuneAction
                )
                FineTuneChoiceButton(
                    title: "Keep Original",
                    icon: "photo",
                    isSelected: decision == .croppedOriginal,
                    action: keepOriginalAction
                )
            }
        }
        .padding(9)
        .background(AppPalette.paperBright.opacity(0.96), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(decision == nil ? AppPalette.hairline : AppPalette.gold.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 10, y: 5)
    }
}

struct FineTuneBeforeAfterPreviewOverlay: View {
    let items: [FinalMomentFineTuneItem]
    let displayAssetName: (FinalMomentAssetRef) -> String
    let closeAction: () -> Void
    @State private var activeIndex: Int

    init(
        items: [FinalMomentFineTuneItem],
        displayAssetName: @escaping (FinalMomentAssetRef) -> String,
        initialIndex: Int,
        closeAction: @escaping () -> Void
    ) {
        self.items = items
        self.displayAssetName = displayAssetName
        self.closeAction = closeAction
        _activeIndex = State(initialValue: min(max(initialIndex, 0), max(items.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.90)
                .ignoresSafeArea()
                .onTapGesture {
                    closeAction()
                }

            VStack(spacing: 16) {
                HStack {
                    Text("Before / After")
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 28))
                        .foregroundStyle(AppPalette.paperBright)

                    Spacer()

                    Button(action: closeAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.ivory)
                            .frame(width: 36, height: 36)
                            .background(AppPalette.paperBright.opacity(0.94), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close before after preview")
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                TabView(selection: $activeIndex) {
                    ForEach(items.indices, id: \.self) { index in
                        FineTuneBeforeAfterPreviewPage(
                            beforeAssetName: beforeAssetName(for: items[index]),
                            afterAssetName: displayAssetName(items[index].editedAssetRef)
                        )
                        .padding(.horizontal, 16)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                FineTunePreviewDots(count: items.count, activeIndex: activeIndex)
                    .padding(.bottom, 24)
            }
        }
    }

    private func beforeAssetName(for item: FinalMomentFineTuneItem) -> String {
        let croppedAssetName = displayAssetName(item.croppedAssetRef)
        return croppedAssetName.isEmpty ? displayAssetName(item.originalAssetRef) : croppedAssetName
    }
}

struct FineTuneBeforeAfterPreviewPage: View {
    let beforeAssetName: String
    let afterAssetName: String

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                FineTunePreviewImagePanel(
                    title: "Before",
                    assetName: beforeAssetName,
                    badgeFill: .black.opacity(0.52)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                FineTunePreviewImagePanel(
                    title: "After",
                    assetName: afterAssetName,
                    badgeFill: AppPalette.gold.opacity(0.88)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Swipe to compare the next photo")
                .font(.custom("AvenirNext-DemiBold", size: 12.5))
                .foregroundStyle(AppPalette.paperBright.opacity(0.62))
                .kerning(0.4)
        }
    }
}

struct FineTunePreviewImagePanel: View {
    let title: String
    let assetName: String
    let badgeFill: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.paperBright.opacity(0.08))

            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)

            Text(title)
                .fineTuneImageBadge(fill: badgeFill, foreground: AppPalette.paperBright)
                .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.paperBright.opacity(0.18), lineWidth: 1)
        }
    }
}

struct FineTunePreviewDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? AppPalette.paperBright : AppPalette.paperBright.opacity(0.34))
                    .frame(width: index == activeIndex ? 7 : 6, height: index == activeIndex ? 7 : 6)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.black.opacity(0.28), in: Capsule())
        .opacity(count > 1 ? 1 : 0)
    }
}

struct FineTuneChoiceButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : icon)
                .font(.custom("AvenirNext-DemiBold", size: 12.5))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(isSelected ? AppPalette.gold : AppPalette.paperBright, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? .clear : AppPalette.hairline, lineWidth: 1)
                }
                .foregroundStyle(isSelected ? AppPalette.paperBright : AppPalette.ivory.opacity(0.82))
        }
        .buttonStyle(.plain)
    }
}

struct CommentSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let portfolio: CuratedPortfolio
    let avatarAsset: String
    let postAction: (String, CuratedPortfolio) -> Void

    @State private var commentText = ""
    @State private var displayedComments: [PortfolioComment]

    private let reactions = ["❤️", "🙌", "🔥", "👏", "😍", "🤩", "😮", "😂"]

    init(
        portfolio: CuratedPortfolio,
        avatarAsset: String,
        comments: [PortfolioComment],
        postAction: @escaping (String, CuratedPortfolio) -> Void
    ) {
        self.portfolio = portfolio
        self.avatarAsset = avatarAsset
        self.postAction = postAction
        _displayedComments = State(initialValue: comments)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Text("COMMENTS")
                    .font(.system(size: 15, weight: .heavy, design: .default))
                    .kerning(0.8)
                    .padding(.top, 18)

                if displayedComments.isEmpty {
                    VStack(spacing: 8) {
                        Text("Be the first to comment")
                            .font(.system(size: 20, weight: .semibold, design: .default))
                            .foregroundStyle(AppPalette.ivory.opacity(0.62))
                        Text(portfolio.author)
                            .font(AppType.caption)
                            .foregroundStyle(AppPalette.gold)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(displayedComments) { comment in
                                PortfolioCommentRow(comment: comment)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                    }
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        ForEach(reactions, id: \.self) { reaction in
                            Button {
                                commentText += reaction
                            } label: {
                                Text(reaction)
                                    .font(.system(size: 30))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add reaction")
                        }
                    }
                    .padding(.horizontal, 24)
                }

                HStack(spacing: 12) {
                    PhotographerAvatar(assetName: avatarAsset, name: "You")
                        .frame(width: 42, height: 42)

                    TextField("Add a comment", text: $commentText)
                        .font(.system(size: 17, weight: .medium, design: .default))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(AppPalette.panelStrong.opacity(0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onSubmit(postComment)

                    if !commentText.isEmpty {
                        Button(action: postComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(AppPalette.gold)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Post comment")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
            .background(AppPalette.paperBright)
        }
        .background(AppPalette.paperBright)
    }

    private func postComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let comment = PortfolioComment(
            userName: "You",
            avatarAsset: avatarAsset,
            text: trimmedText,
            timestamp: Date()
        )
        displayedComments.append(comment)
        postAction(trimmedText, portfolio)
        commentText = ""
    }
}

struct PortfolioCommentRow: View {
    let comment: PortfolioComment

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PhotographerAvatar(assetName: comment.avatarAsset, name: comment.userName)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(comment.userName)
                        .font(.system(size: 14.5, weight: .semibold, design: .default))
                        .foregroundStyle(AppPalette.ivory.opacity(0.86))
                    Text(Self.timeFormatter.string(from: comment.timestamp))
                        .font(.system(size: 12.5, weight: .medium, design: .default))
                        .foregroundStyle(AppPalette.ivory.opacity(0.46))
                }

                Text(comment.text)
                    .font(.system(size: 15.2, weight: .regular, design: .default))
                    .foregroundStyle(AppPalette.ivory.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

struct BookmarkSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let portfolio: CuratedPortfolio
    @Binding var folders: [BookmarkFolder]
    let saveAction: (CuratedPortfolio, String?) -> Void

    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                saveAction(portfolio, nil)
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    BookmarkPreviewImage(assets: portfolio.assets)
                        .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(portfolio.title)
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 24))
                            .lineLimit(2)
                        Text("Saved")
                            .font(AppType.body)
                            .foregroundStyle(AppPalette.ivory.opacity(0.58))
                    }

                    Spacer()

                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppPalette.ivory)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save \(portfolio.title) to all saved")
            .padding(.top, 22)

            Divider()
                .overlay(AppPalette.hairline)

            VStack(alignment: .leading, spacing: 10) {
                if !folders.isEmpty {
                    Text("Choose a folder")
                        .font(AppType.eyebrow)
                        .kerning(2.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.gold)

                    VStack(spacing: 8) {
                        ForEach(folders) { folder in
                            Button {
                                saveAction(portfolio, folder.id)
                                dismiss()
                            } label: {
                                BookmarkFolderChoiceRow(
                                    title: folder.name,
                                    portfolioCount: folder.portfolioIds.count,
                                    icon: "folder"
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Save to \(folder.name)")
                        }
                    }
                }

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isCreatingFolder = true
                    }
                } label: {
                    BookmarkFolderChoiceRow(title: "New Folder", portfolioCount: nil, icon: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create new folder")

                if isCreatingFolder {
                    HStack(spacing: 10) {
                        TextField("Folder name", text: $newFolderName)
                            .font(AppType.body)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(AppPalette.panelStrong.opacity(0.55), in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))

                        Button("Save") {
                            let folderName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !folderName.isEmpty {
                                let folder = BookmarkFolder(
                                    id: folderName
                                        .lowercased()
                                        .replacingOccurrences(of: " ", with: "_") + "_\(folders.count)",
                                    name: folderName,
                                    portfolioIds: [portfolio.id]
                                )
                                folders.append(folder)
                                saveAction(portfolio, folder.id)
                            } else {
                                saveAction(portfolio, nil)
                            }
                            dismiss()
                        }
                        .font(AppType.chip)
                        .foregroundStyle(AppPalette.buttonText)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(AppPalette.gold, in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(AppPalette.paperBright)
    }
}

struct BookmarkFolderChoiceRow: View {
    let title: String
    let portfolioCount: Int?
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppPalette.ivory)
                .frame(width: 58, height: 48)
                .background(AppPalette.panelStrong.opacity(0.72), in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppType.profileItemTitle)
                    .foregroundStyle(AppPalette.ivory)
                if let portfolioCount {
                    Text("\(portfolioCount) saved")
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.56))
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct BookmarkPreviewImage: View {
    let assets: [String]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(assets.prefix(4).enumerated()), id: \.offset) { index, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width / 2, height: proxy.size.height / 2)
                        .clipped()
                        .position(
                            x: index.isMultiple(of: 2) ? proxy.size.width * 0.25 : proxy.size.width * 0.75,
                            y: index < 2 ? proxy.size.height * 0.25 : proxy.size.height * 0.75
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                    .stroke(AppPalette.hairline, lineWidth: 1)
            }
        }
    }
}

struct MomentsSavedOverlay: View {
    let savedCount: Int
    let savedAssets: [String]
    let viewProfileAction: () -> Void
    let takeMoreAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Saved state is intentionally modal: users choose one of the two actions.
                }

            MomentsSavedSheetView(
                savedCount: savedCount,
                savedAssets: savedAssets,
                viewProfileAction: viewProfileAction,
                takeMoreAction: takeMoreAction,
                dismissAction: dismissAction
            )
            .frame(maxWidth: .infinity)
            .frame(height: 452)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 18, y: -3)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: 54, height: 4)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .ignoresSafeArea()
    }
}

struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}

struct MomentsSavedSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let savedCount: Int
    let savedAssets: [String]
    let viewProfileAction: () -> Void
    let takeMoreAction: () -> Void
    let dismissAction: () -> Void

    private var previewAssets: [String] {
        Array((savedAssets.isEmpty ? ["ArchesWalk", "HooverTower", "StripedLight"] : savedAssets).prefix(3))
    }

    var body: some View {
        VStack(spacing: 17) {
            ZStack(alignment: .bottomTrailing) {
                Image("ScanSprig")
                    .resizable()
                    .scaledToFit()
                    .opacity(0.46)
                    .frame(width: 76, height: 50)
                    .rotationEffect(.degrees(-3))
                    .offset(x: 43, y: 12)

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppPalette.paperBright)
                    .frame(width: 56, height: 56)
                    .background(AppPalette.gold, in: Circle())
                    .shadow(color: AppPalette.oliveShadow.opacity(0.32), radius: 10, y: 5)
            }
            .padding(.top, 34)

            VStack(spacing: 8) {
                Text("Saved to\nMy Blooming Moments")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 30))
                    .foregroundStyle(AppPalette.ivory)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(savedCount) photos are ready in your Profile.")
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundStyle(AppPalette.ivory.opacity(0.62))
            }

            HStack(spacing: 10) {
                ForEach(Array(previewAssets.enumerated()), id: \.offset) { _, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(AppPalette.paperBright, lineWidth: 1)
                        }
                }
            }
            .padding(.top, 2)

            VStack(spacing: 12) {
                Button {
                    dismiss()
                    dismissAction()
                    viewProfileAction()
                } label: {
                    Label("View My Blooming Moments", systemImage: "person")
                        .font(.custom("AvenirNext-DemiBold", size: 15.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppPalette.gold, in: Capsule())
                        .foregroundStyle(AppPalette.paperBright)
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    dismissAction()
                    takeMoreAction()
                } label: {
                    Label("Take More Photos", systemImage: "camera")
                        .font(.custom("AvenirNext-DemiBold", size: 15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppPalette.paperBright, in: Capsule())
                        .overlay { Capsule().stroke(AppPalette.hairline, lineWidth: 1) }
                        .foregroundStyle(AppPalette.ivory)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
            .padding(.horizontal, 26)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.paperBright)
    }
}

struct InviteView: View {
    @State private var isShowingInviteLink = false
    private let inviteURL = "blooming.app/invite/ann-kai"

    var body: some View {
        ZStack {
            PortfolioDetailBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    BloomingCenteredTopBar()
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Invite")
                            .font(.custom("BodoniSvtyTwoITCTT-Book", size: 48))
                            .foregroundStyle(AppPalette.ivory)
                        Text("Bring someone into the shoot so you\ncan plan, pose, and save the moment\ntogether.")
                            .font(.custom("AvenirNext-Regular", size: 14.2))
                            .foregroundStyle(AppPalette.ivory.opacity(0.82))
                            .lineSpacing(3)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 14) {
                        ZStack(alignment: .top) {
                            VStack(spacing: 14) {
                                Image("HooverTower")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 118)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        AppPalette.paperBright.opacity(0.16),
                                                        AppPalette.paperBright.opacity(0)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    }
                                    .padding(.horizontal, 48)
                                    .padding(.top, 78)

                                Text("Share your blooming moments")
                                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 25))
                                    .foregroundStyle(AppPalette.ivory)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)

                                Text("Send an invite link to a friend or partner.\nYou can plan, pose, and save the moments together.")
                                    .font(.custom("AvenirNext-Regular", size: 13.6))
                                    .foregroundStyle(AppPalette.ivory.opacity(0.72))
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.86)

                                Button {
                                    isShowingInviteLink = true
                                } label: {
                                    Label("Send Invite", systemImage: "person.badge.plus")
                                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                                        .foregroundStyle(AppPalette.paperBright)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(AppPalette.gold, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 20)
                            }
                            .background(AppPalette.paperBright.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(AppPalette.hairline, lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.055), radius: 14, y: 8)

                            ZStack {
                                Circle()
                                    .fill(AppPalette.paperBright)
                                    .frame(width: 86, height: 86)
                                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(AppPalette.gold)
                                Image("ScanSprig")
                                    .resizable()
                                    .scaledToFit()
                                    .opacity(0.34)
                                    .frame(width: 64, height: 36)
                                    .rotationEffect(.degrees(18))
                                    .offset(x: 38, y: -20)
                            }
                            .padding(.top, 38)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 104)
            }

            if isShowingInviteLink {
                InviteLinkOverlay(
                    inviteURL: inviteURL,
                    closeAction: {
                        isShowingInviteLink = false
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
    }
}

struct InviteLinkOverlay: View {
    let inviteURL: String
    let closeAction: () -> Void
    @State private var hasCopied = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    closeAction()
                }

            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    Image("ScanSprig")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.48)
                        .frame(width: 40, height: 24)
                    Text("Your invite link")
                        .font(.custom("BodoniSvtyTwoITCTT-Book", size: 24))
                        .foregroundStyle(AppPalette.gold)
                    Image("ScanSprig")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.48)
                        .frame(width: 40, height: 24)
                        .scaleEffect(x: -1, y: 1)
                }

                HStack(spacing: 14) {
                    Image(systemName: "link")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppPalette.gold)
                        .frame(width: 48, height: 48)
                        .background(AppPalette.paper.opacity(0.72), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(inviteURL)
                            .font(.custom("AvenirNext-Regular", size: 16))
                            .foregroundStyle(AppPalette.ivory)
                            .lineLimit(2)
                        Text("Anyone with the link can join your shoot.")
                            .font(.custom("AvenirNext-Regular", size: 12))
                            .foregroundStyle(AppPalette.ivory.opacity(0.64))
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = inviteURL
                        hasCopied = true
                    } label: {
                        Image(systemName: hasCopied ? "checkmark" : "square.on.square")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(AppPalette.gold)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hasCopied ? "Invite link copied" : "Copy invite link")
                }
                .padding(18)
                .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.hairline, lineWidth: 1)
                }
            }
            .padding(22)
            .background(AppPalette.paperBright.opacity(0.98), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .padding(.horizontal, 24)
        }
    }
}

struct InviteAvatar: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: 76, height: 76)
            .clipShape(Circle())
            .overlay { Circle().stroke(AppPalette.paperBright, lineWidth: 3) }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ProfileView: View {
    let savedPortfolios: [CuratedPortfolio]
    @Binding var bookmarkFolders: [BookmarkFolder]
    @Binding var savedMoments: [SavedBloomingMoment]
    let avatarAsset: String
    let deleteFolderAction: (BookmarkFolder) -> Void
    let removeSavedPortfolioAction: (CuratedPortfolio) -> Void
    let sessionBackAction: (() -> Void)?
    let openPortfolioAction: (CuratedPortfolio) -> Void
    @State private var activeProfileSheet: ProfileSheet?
    @State private var swipedFolderId: String?

    private var momentGroups: [(sceneTitle: String, moments: [SavedBloomingMoment])] {
        Dictionary(grouping: savedMoments, by: \.sceneTitle)
            .map { (sceneTitle: $0.key, moments: $0.value) }
            .sorted { $0.sceneTitle < $1.sceneTitle }
    }

    var body: some View {
        ZStack {
            PortfolioDetailBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    BloomingCenteredTopBar(backAction: sessionBackAction)
                        .padding(.top, -6)

                    HStack(spacing: 14) {
                        Image(avatarAsset)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(AppPalette.paperBright, lineWidth: 2) }
                            .shadow(color: .black.opacity(0.07), radius: 8, y: 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ann Li")
                                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                                .foregroundStyle(AppPalette.ivory)
                            Text("Treasured moments,\ncampus light, saved recipes")
                                .font(.custom("AvenirNext-Regular", size: 10.2))
                                .foregroundStyle(AppPalette.ivory.opacity(0.72))
                                .lineSpacing(0.4)
                        }
                    }
                    .padding(.top, 4)

                    ProfileSavedMomentsPanel(
                        momentGroups: momentGroups,
                        openAllAction: {
                            activeProfileSheet = .moments(
                                title: momentGroups.first?.sceneTitle ?? "Graduation"
                            )
                        },
                        openMomentAction: { _, moments, index in
                            activeProfileSheet = .image(moments: moments, initialIndex: index)
                        }
                    )
                        .padding(.top, 6)

                    ProfileFavoritePortfolioPanel(
                        portfolios: displayedPortfolios,
                        openAllAction: {
                            activeProfileSheet = .portfolios
                        },
                        openPortfolioAction: { portfolio in
                            activeProfileSheet = nil
                            openPortfolioAction(portfolio)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 84)
            }

            if case .portfolios = activeProfileSheet {
                ProfileDismissBackdrop {
                    activeProfileSheet = nil
                }
                .transition(.opacity)
                .zIndex(10)

                ProfilePortfolioFolderOverlay(
                    portfolios: displayedPortfolios,
                    folders: $bookmarkFolders,
                    removeSavedPortfolioAction: removeSavedPortfolioAction,
                    openPortfolioAction: { portfolio in
                        activeProfileSheet = nil
                        openPortfolioAction(portfolio)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(11)
            }
        }
        .sheet(item: modalSheetBinding) { sheet in
            switch sheet {
            case .moments(let title):
                ProfileMomentsFolderView(
                    title: title,
                    moments: momentsForProfileSheet(title),
                    deleteMomentsAction: removeSavedMoments,
                    openMomentAction: { moments, index in
                        activeProfileSheet = .image(moments: moments, initialIndex: index)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .portfolios:
                EmptyView()
            case .image(let moments, let initialIndex):
                ProfileImagePreviewView(moments: moments, initialIndex: initialIndex)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var displayMoments: [SavedBloomingMoment] {
        if let moments = momentGroups.first?.moments, !moments.isEmpty {
            return moments
        }
        return []
    }

    private var displayedPortfolios: [CuratedPortfolio] {
        savedPortfolios
    }

    private var modalSheetBinding: Binding<ProfileSheet?> {
        Binding(
            get: {
                if case .portfolios = activeProfileSheet {
                    return nil
                }
                return activeProfileSheet
            },
            set: { newValue in
                activeProfileSheet = newValue
            }
        )
    }

    private func portfolios(in folder: BookmarkFolder) -> [CuratedPortfolio] {
        savedPortfolios.filter { folder.portfolioIds.contains($0.id) }
    }

    private func momentsForProfileSheet(_ title: String) -> [SavedBloomingMoment] {
        savedMoments.filter { $0.sceneTitle == title }
    }

    private func removeSavedMoments(_ ids: Set<UUID>) {
        savedMoments.removeAll { ids.contains($0.id) }
    }
}

enum ProfileSheet: Identifiable {
    case moments(title: String)
    case portfolios
    case image(moments: [SavedBloomingMoment], initialIndex: Int)

    var id: String {
        switch self {
        case .moments(let title):
            return "moments-\(title)"
        case .portfolios:
            return "portfolios"
        case .image(let moments, let initialIndex):
            let groupId = moments.map(\.assetName).joined(separator: "-")
            return "image-\(groupId)-\(initialIndex)"
        }
    }
}

struct ProfileSavedMomentsPanel: View {
    let momentGroups: [(sceneTitle: String, moments: [SavedBloomingMoment])]
    let openAllAction: () -> Void
    let openMomentAction: (SavedBloomingMoment, [SavedBloomingMoment], Int) -> Void

    static let fallbackMoments = [
        SavedBloomingMoment(sceneTitle: "Graduation", assetName: "HooverTower", isFineTuned: true),
        SavedBloomingMoment(sceneTitle: "Graduation", assetName: "ArchesWalk", isFineTuned: true),
        SavedBloomingMoment(sceneTitle: "Graduation", assetName: "StripedLight", isFineTuned: true),
        SavedBloomingMoment(sceneTitle: "Graduation", assetName: "HooverTower", isFineTuned: false),
        SavedBloomingMoment(sceneTitle: "Graduation", assetName: "ArchesWalk", isFineTuned: true),
        SavedBloomingMoment(sceneTitle: "Graduation", assetName: "StripedLight", isFineTuned: true)
    ]

    private var displayTitle: String {
        momentGroups.first?.sceneTitle ?? "Graduation"
    }

    private var displayMoments: [SavedBloomingMoment] {
        if let moments = momentGroups.first?.moments, !moments.isEmpty {
            return Array(moments.prefix(6))
        }
        return []
    }

    private var carouselMoments: [SavedBloomingMoment] {
        if let moments = momentGroups.first?.moments, !moments.isEmpty {
            return moments
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Blooming Moments")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                    .foregroundStyle(AppPalette.ivory)
                Spacer()
                Button(action: openAllAction) {
                    HStack(spacing: 6) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                    }
                    .font(.custom("AvenirNext-Regular", size: 11.5))
                    .foregroundStyle(AppPalette.ivory.opacity(0.72))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppPalette.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayTitle)
                        .font(.custom("AvenirNext-DemiBold", size: 14.5))
                        .foregroundStyle(AppPalette.gold)
                    Text("\(displayMoments.count) moment\(displayMoments.count == 1 ? "" : "s")")
                        .font(.custom("AvenirNext-Regular", size: 10.5))
                        .foregroundStyle(AppPalette.ivory.opacity(0.64))
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("Saved")
                    Image(systemName: "bookmark")
                }
                .font(.custom("AvenirNext-Regular", size: 10.5))
                .foregroundStyle(AppPalette.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppPalette.paper.opacity(0.62), in: Capsule())
                .overlay { Capsule().stroke(AppPalette.hairline, lineWidth: 1) }
            }

            if displayMoments.isEmpty {
                EmptyProfileState(
                    icon: "photo.on.rectangle",
                    title: "No saved moments yet",
                    subtitle: "Fine tune and save photos to keep them here."
                )
                .padding(12)
                .background(AppPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else {
                ProfileMomentsGrid(moments: displayMoments) { moment, _, index in
                    openMomentAction(moment, carouselMoments, index)
                }
            }
        }
        .padding(12)
        .background(AppPalette.paperBright.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 10, y: 5)
    }
}

struct ProfileMomentsGrid: View {
    let moments: [SavedBloomingMoment]
    let openMomentAction: (SavedBloomingMoment, [SavedBloomingMoment], Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 7
            let cellWidth = max(76, (proxy.size.width - spacing * 2) / 3)
            let cellHeight: CGFloat = 86

            VStack(spacing: spacing) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { column in
                            let index = row * 3 + column
                            if moments.indices.contains(index) {
                                Button {
                                    openMomentAction(moments[index], moments, index)
                                } label: {
                                    MomentThumbnail(moment: moments[index])
                                        .frame(width: cellWidth, height: cellHeight)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 179)
    }
}

struct ProfileFavoritePortfolioPanel: View {
    let portfolios: [CuratedPortfolio]
    let openAllAction: () -> Void
    let openPortfolioAction: (CuratedPortfolio) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Favorite Curated Portfolios")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                    .foregroundStyle(AppPalette.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                Spacer()
                Button(action: openAllAction) {
                    HStack(spacing: 6) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                    }
                    .font(.custom("AvenirNext-Regular", size: 11.5))
                    .foregroundStyle(AppPalette.ivory.opacity(0.70))
                }
                .buttonStyle(.plain)
            }

            if let portfolio = portfolios.first {
                Button {
                    openPortfolioAction(portfolio)
                } label: {
                    HStack(spacing: 12) {
                        BookmarkPreviewImage(assets: portfolio.assets)
                            .frame(width: 112, height: 56)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(portfolio.title)
                                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 16))
                                .foregroundStyle(AppPalette.ivory)
                                .lineLimit(2)
                            HStack(spacing: 7) {
                                PhotographerAvatar(assetName: portfolio.avatarAsset, name: portfolio.author)
                                    .frame(width: 20, height: 20)
                                Text("by \(portfolio.author)")
                                    .font(.custom("AvenirNext-Regular", size: 10.8))
                                    .foregroundStyle(AppPalette.gold)
                            }
                        }
                        Spacer()
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.gold)
                    }
                }
                .buttonStyle(.plain)
            } else {
                EmptyProfileState(
                    icon: "bookmark",
                    title: "No saved portfolios yet",
                    subtitle: "Save a photographer portfolio to keep it here."
                )
                .padding(12)
                .background(AppPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            Rectangle()
                .fill(AppPalette.hairline.opacity(0.65))
                .frame(height: 1)
                .overlay {
                    Rectangle()
                        .stroke(AppPalette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
                }

            HStack(spacing: 10) {
                Spacer()
                Text("Curated taste. AI guidance. Your moment.")
                    .font(.custom("AvenirNext-Regular", size: 10.4))
                    .foregroundStyle(AppPalette.ivory.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image("ScanSprig")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppPalette.gold.opacity(0.72))
                    .frame(width: 46, height: 24)
                Spacer()
            }
        }
        .padding(12)
        .background(AppPalette.paperBright.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
    }
}

struct ProfileBookmarkFolderGroup: View {
    let title: String
    let portfolios: [CuratedPortfolio]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(AppType.profileItemTitle)
                Spacer()
                Text("\(portfolios.count)")
                    .font(AppType.chip)
                    .foregroundStyle(AppPalette.gold)
            }

            if portfolios.isEmpty {
                Text("No saved portfolios in this folder yet.")
                    .font(AppType.caption)
                    .foregroundStyle(AppPalette.ivory.opacity(0.54))
            } else {
                VStack(spacing: 10) {
                    ForEach(portfolios) { portfolio in
                        SavedPortfolioRow(portfolio: portfolio)
                    }
                }
            }
        }
    }
}

struct ProfileFolderSelection: Identifiable {
    let id = UUID()
    let title: String
    let portfolios: [CuratedPortfolio]
}

struct ProfileMomentsFolderView: View {
    let title: String
    let moments: [SavedBloomingMoment]
    let deleteMomentsAction: (Set<UUID>) -> Void
    let openMomentAction: ([SavedBloomingMoment], Int) -> Void
    @State private var isEditing = false
    @State private var selectedMomentIds: Set<UUID> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 28))
                    .foregroundStyle(AppPalette.ivory)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    withAnimation(.snappy(duration: 0.18)) {
                        isEditing.toggle()
                        selectedMomentIds.removeAll()
                    }
                }
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundStyle(AppPalette.gold)
                .disabled(moments.isEmpty)
            }
            .padding(.top, 20)

            Text("\(moments.count) blooming moment\(moments.count == 1 ? "" : "s")")
                .font(.custom("AvenirNext-Regular", size: 13))
                .foregroundStyle(AppPalette.ivory.opacity(0.58))

            if moments.isEmpty {
                EmptyProfileState(
                    icon: "photo.on.rectangle",
                    title: "No saved moments yet",
                    subtitle: "Fine tune and save photos to keep them here."
                )
                .padding(14)
                .background(AppPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ScrollView(showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: 9) {
                        ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                            Button {
                                if isEditing {
                                    toggleSelection(for: moment)
                                } else {
                                    openMomentAction(moments, index)
                                }
                            } label: {
                                EditableMomentThumbnail(
                                    moment: moment,
                                    isEditing: isEditing,
                                    isSelected: selectedMomentIds.contains(moment.id)
                                )
                                .aspectRatio(0.72, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isEditing ? "Select saved moment \(index + 1)" : "Open saved moment \(index + 1)")
                        }
                    }
                    .padding(.bottom, isEditing ? 94 : 28)
                }
            }

            if isEditing {
                Button {
                    let idsToDelete = selectedMomentIds
                    guard !idsToDelete.isEmpty else { return }
                    withAnimation(.snappy(duration: 0.2)) {
                        deleteMomentsAction(idsToDelete)
                        selectedMomentIds.removeAll()
                        if moments.count == idsToDelete.count {
                            isEditing = false
                        }
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "trash")
                        Text(selectedMomentIds.isEmpty ? "Select photos to delete" : "Delete Selected")
                    }
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(selectedMomentIds.isEmpty ? AppPalette.ivory.opacity(0.48) : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(selectedMomentIds.isEmpty ? AppPalette.paper.opacity(0.68) : Color.red.opacity(0.90), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedMomentIds.isEmpty)
            }
        }
        .padding(.horizontal, 22)
        .background(AppPalette.paperBright)
        .onChange(of: moments.map(\.id)) { _, ids in
            selectedMomentIds = selectedMomentIds.intersection(Set(ids))
            if ids.isEmpty {
                isEditing = false
            }
        }
    }

    private func toggleSelection(for moment: SavedBloomingMoment) {
        if selectedMomentIds.contains(moment.id) {
            selectedMomentIds.remove(moment.id)
        } else {
            selectedMomentIds.insert(moment.id)
        }
    }
}

struct EditableMomentThumbnail: View {
    let moment: SavedBloomingMoment
    let isEditing: Bool
    let isSelected: Bool

    var body: some View {
        MomentThumbnail(moment: moment)
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.red.opacity(0.95) : AppPalette.paperBright.opacity(0.88))
                        .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                        .padding(7)
                }
            }
            .overlay {
                if isEditing && isSelected {
                    RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                        .stroke(Color.red.opacity(0.92), lineWidth: 3)
                }
            }
            .opacity(isEditing && !isSelected ? 0.72 : 1)
    }
}

struct ProfilePortfolioFolderView: View {
    let portfolios: [CuratedPortfolio]
    @Binding var folders: [BookmarkFolder]
    let removeSavedPortfolioAction: (CuratedPortfolio) -> Void
    let openPortfolioAction: (CuratedPortfolio) -> Void

    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Favorite Curated Portfolios")
                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 28))
                .foregroundStyle(AppPalette.ivory)
                .padding(.top, 20)

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    ProfilePortfolioFolderBlock(
                        title: "All Saved",
                        portfolios: portfolios,
                        deletePortfolioAction: removeSavedPortfolioAction,
                        openPortfolioAction: openPortfolioAction
                    )

                    if !folders.isEmpty {
                        ForEach(folders) { folder in
                            ProfilePortfolioFolderBlock(
                                title: folder.name,
                                portfolios: portfolios.filter { folder.portfolioIds.contains($0.id) },
                                deletePortfolioAction: { portfolio in
                                    if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                                        folders[index].portfolioIds.remove(portfolio.id)
                                    }
                                },
                                openPortfolioAction: openPortfolioAction
                            )
                        }
                    }

                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            isCreatingFolder = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(AppPalette.gold.opacity(0.12), in: Circle())
                            Text("New Folder")
                                .font(.custom("AvenirNext-Regular", size: 14))
                            Spacer()
                        }
                        .foregroundStyle(AppPalette.gold)
                        .padding(12)
                        .background(AppPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if isCreatingFolder {
                        HStack(spacing: 10) {
                            TextField("Folder name", text: $newFolderName)
                                .font(.custom("AvenirNext-Regular", size: 14))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .background(AppPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Button("Save") {
                                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                folders.append(BookmarkFolder(
                                    id: trimmed.lowercased().replacingOccurrences(of: " ", with: "_") + "_\(folders.count + 1)",
                                    name: trimmed,
                                    portfolioIds: []
                                ))
                                newFolderName = ""
                                isCreatingFolder = false
                            }
                            .font(.custom("AvenirNext-DemiBold", size: 13))
                            .foregroundStyle(AppPalette.paperBright)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(AppPalette.gold, in: Capsule())
                        }
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .padding(.horizontal, 22)
        .background(AppPalette.paperBright)
    }
}

struct ProfileDismissBackdrop: View {
    let dismissAction: () -> Void

    var body: some View {
        Button(action: dismissAction) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss portfolio folder")
    }
}

struct ProfilePortfolioFolderOverlay: View {
    let portfolios: [CuratedPortfolio]
    @Binding var folders: [BookmarkFolder]
    let removeSavedPortfolioAction: (CuratedPortfolio) -> Void
    let openPortfolioAction: (CuratedPortfolio) -> Void

    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                Capsule()
                    .fill(AppPalette.ivory.opacity(0.20))
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("Favorite Curated Portfolios")
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 28))
                    .foregroundStyle(AppPalette.ivory)

                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        ProfilePortfolioFolderBlock(
                            title: "All Saved",
                            portfolios: portfolios,
                            deletePortfolioAction: removeSavedPortfolioAction,
                            openPortfolioAction: openPortfolioAction
                        )

                        if !folders.isEmpty {
                            ForEach(folders) { folder in
                                ProfilePortfolioFolderBlock(
                                    title: folder.name,
                                    portfolios: portfolios.filter { folder.portfolioIds.contains($0.id) },
                                    deletePortfolioAction: { portfolio in
                                        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                                            folders[index].portfolioIds.remove(portfolio.id)
                                        }
                                    },
                                    openPortfolioAction: openPortfolioAction
                                )
                            }
                        }

                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                isCreatingFolder = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .background(AppPalette.gold.opacity(0.12), in: Circle())
                                Text("New Folder")
                                    .font(.custom("AvenirNext-Regular", size: 14))
                                Spacer()
                            }
                            .foregroundStyle(AppPalette.gold)
                            .padding(12)
                            .background(AppPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if isCreatingFolder {
                            HStack(spacing: 10) {
                                TextField("Folder name", text: $newFolderName)
                                    .font(.custom("AvenirNext-Regular", size: 14))
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .frame(height: 44)
                                    .background(AppPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Button("Save") {
                                    let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    folders.append(BookmarkFolder(
                                        id: trimmed.lowercased().replacingOccurrences(of: " ", with: "_") + "_\(folders.count + 1)",
                                        name: trimmed,
                                        portfolioIds: []
                                    ))
                                    newFolderName = ""
                                    isCreatingFolder = false
                                }
                                .font(.custom("AvenirNext-DemiBold", size: 13))
                                .foregroundStyle(AppPalette.paperBright)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(AppPalette.gold, in: Capsule())
                            }
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .padding(.horizontal, 22)
            .frame(maxHeight: 650)
            .background(AppPalette.paperBright, in: UnevenRoundedRectangle(topLeadingRadius: 34, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 34, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 24, y: -8)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct ProfilePortfolioFolderBlock: View {
    let title: String
    let portfolios: [CuratedPortfolio]
    let deletePortfolioAction: (CuratedPortfolio) -> Void
    let openPortfolioAction: (CuratedPortfolio) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 22))
                    .foregroundStyle(AppPalette.ivory)
                Spacer()
                Text("\(portfolios.count)")
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(AppPalette.gold)
            }

            if portfolios.isEmpty {
                EmptyProfileState(
                    icon: "bookmark",
                    title: "No saved portfolios yet",
                    subtitle: "Save a photographer portfolio to keep it here."
                )
                .padding(12)
                .background(AppPalette.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(portfolios) { portfolio in
                        ProfilePortfolioFolderRow(
                            portfolio: portfolio,
                            deletePortfolioAction: deletePortfolioAction,
                            openPortfolioAction: openPortfolioAction
                        )
                    }
                }
            }
        }
    }
}

struct ProfilePortfolioFolderRow: View {
    let portfolio: CuratedPortfolio
    let deletePortfolioAction: (CuratedPortfolio) -> Void
    let openPortfolioAction: (CuratedPortfolio) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isDeleteRevealed = false

    private let revealWidth: CGFloat = 74

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.snappy(duration: 0.2)) {
                    deletePortfolioAction(portfolio)
                    isDeleteRevealed = false
                    dragOffset = 0
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: revealWidth, height: 90)
                    .background(Color.red.opacity(0.88), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(deleteRevealProgress)
            .allowsHitTesting(isDeleteRevealed)
            .accessibilityLabel("Remove \(portfolio.title)")
            .zIndex(2)

            HStack(spacing: 12) {
                Button {
                    openPortfolioAction(portfolio)
                } label: {
                    HStack(spacing: 12) {
                        BookmarkPreviewImage(assets: portfolio.assets)
                            .frame(width: 70, height: 70)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(portfolio.title)
                                .font(AppType.profileItemTitle)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(portfolio.author)
                                .font(AppType.caption)
                                .foregroundStyle(AppPalette.gold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: 210, alignment: .leading)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(portfolio.title)")

                Spacer(minLength: 8)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.ivory.opacity(0.66))
                    .allowsHitTesting(false)

                Button {
                    openPortfolioAction(portfolio)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                        .frame(width: 34, height: 34)
                        .background(AppPalette.paperBright.opacity(0.74), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(portfolio.title)")
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(AppPalette.paper.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .offset(x: rowOffset)
            .gesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        let baseOffset = isDeleteRevealed ? -revealWidth : 0
                        dragOffset = min(0, max(-revealWidth, baseOffset + value.translation.width))
                    }
                    .onEnded { value in
                        let shouldReveal = dragOffset < -revealWidth * 0.45 || value.predictedEndTranslation.width < -revealWidth
                        withAnimation(.snappy(duration: 0.2)) {
                            isDeleteRevealed = shouldReveal
                            dragOffset = 0
                        }
                    }
            )
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .clipped()
    }

    private var rowOffset: CGFloat {
        dragOffset == 0 ? (isDeleteRevealed ? -revealWidth : 0) : dragOffset
    }

    private var deleteRevealProgress: Double {
        min(1, Double(abs(rowOffset) / revealWidth))
    }
}

struct ProfilePortfolioPreviewView: View {
    let portfolio: CuratedPortfolio

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(portfolio.title)
                .font(.custom("BodoniSvtyTwoITCTT-Book", size: 28))
                .foregroundStyle(AppPalette.ivory)
                .lineLimit(2)
                .padding(.top, 20)
            Text("by \(portfolio.author)")
                .font(.custom("AvenirNext-Regular", size: 13.5))
                .foregroundStyle(AppPalette.gold)

            ScrollView(showsIndicators: true) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(portfolio.assets, id: \.self) { asset in
                        Image(asset)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .padding(.horizontal, 22)
        .background(AppPalette.paperBright)
    }
}

struct ProfileImagePreviewView: View {
    let moments: [SavedBloomingMoment]
    @State private var activeIndex: Int

    init(moments: [SavedBloomingMoment], initialIndex: Int) {
        self.moments = moments.isEmpty ? ProfileSavedMomentsPanel.fallbackMoments : moments
        let boundedIndex = min(max(initialIndex, 0), max(self.moments.count - 1, 0))
        _activeIndex = State(initialValue: boundedIndex)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AppPalette.paperBright.ignoresSafeArea()

            TabView(selection: $activeIndex) {
                ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                    Image(moment.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 14)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(alignment: .leading, spacing: 7) {
                if moments.count > 1 {
                    ProfilePreviewPageDots(
                        count: min(moments.count, 6),
                        activeIndex: visibleDotIndex
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }

                Text(activeMoment.sceneTitle)
                    .font(.custom("BodoniSvtyTwoITCTT-Book", size: 26))
                    .foregroundStyle(AppPalette.ivory)
                if moments.count > 1 {
                    Text("\(activeIndex + 1) of \(moments.count)")
                        .font(.custom("AvenirNext-Regular", size: 12))
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
    }

    private var activeMoment: SavedBloomingMoment {
        moments[min(max(activeIndex, 0), moments.count - 1)]
    }

    private var visibleDotIndex: Int {
        let dotCount = min(moments.count, 6)
        guard dotCount > 1, moments.count > 1 else { return 0 }
        if moments.count <= dotCount {
            return min(activeIndex, dotCount - 1)
        }
        let progress = Double(activeIndex) / Double(moments.count - 1)
        return min(dotCount - 1, max(0, Int((progress * Double(dotCount - 1)).rounded())))
    }
}

struct ProfilePreviewPageDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? AppPalette.ivory.opacity(0.82) : AppPalette.ivory.opacity(0.22))
                    .frame(width: index == activeIndex ? 6 : 5, height: index == activeIndex ? 6 : 5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppPalette.paper.opacity(0.74), in: Capsule())
    }
}

struct ProfileBookmarkFolderRow: View {
    let title: String
    let portfolios: [CuratedPortfolio]
    let canDelete: Bool
    let isDeleteRevealed: Bool
    let openAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 70)
                        .background(Color.red.opacity(0.86), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(title)")
            }

            Button(action: openAction) {
                HStack(spacing: 12) {
                    BookmarkPreviewImage(assets: previewAssets)
                        .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppType.profileItemTitle)
                            .lineLimit(1)
                        Text("\(portfolios.count) saved portfolio\(portfolios.count == 1 ? "" : "s")")
                            .font(AppType.caption)
                            .foregroundStyle(AppPalette.ivory.opacity(0.56))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.ivory.opacity(0.34))
                }
                .padding(10)
                .background(AppPalette.paper.opacity(0.86), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                        .stroke(AppPalette.hairline, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .offset(x: isDeleteRevealed ? -74 : 0)
        }
        .clipped()
    }

    private var previewAssets: [String] {
        portfolios.first?.assets ?? ["HooverTower", "ArchesWalk", "StripedLight"]
    }
}

struct ProfileFolderDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let folder: ProfileFolderSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.title)
                        .font(AppType.profileName)
                    Text("\(folder.portfolios.count) saved portfolio\(folder.portfolios.count == 1 ? "" : "s")")
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.ivory)
                        .frame(width: 32, height: 32)
                        .background(AppPalette.panelStrong.opacity(0.56), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close folder")
            }
            .padding(.top, 20)

            if folder.portfolios.isEmpty {
                EmptyProfileState(
                    icon: "bookmark",
                    title: "No saved portfolios in this folder",
                    subtitle: "Use the bookmark button on a portfolio to save it here."
                )
                .padding(.top, 10)
            } else {
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 12) {
                        ForEach(folder.portfolios) { portfolio in
                            SavedPortfolioRow(portfolio: portfolio)
                                .padding(10)
                                .background(AppPalette.paper.opacity(0.80), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                        }
                    }
                    .padding(.bottom, 24)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .background(AppPalette.paperBright)
    }
}

struct ProfileMomentSceneGroup: View {
    let sceneTitle: String
    let moments: [SavedBloomingMoment]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(sceneTitle)
                    .font(AppType.profileItemTitle)
                Spacer()
                Text("\(moments.count)")
                    .font(AppType.chip)
                    .foregroundStyle(AppPalette.gold)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(moments.prefix(9)) { moment in
                    MomentThumbnail(moment: moment)
                }
            }
        }
    }
}

struct MomentThumbnail: View {
    let moment: SavedBloomingMoment

    var body: some View {
        GeometryReader { proxy in
            Image(moment.assetName)
                .resizable()
                .scaledToFill()
                .saturation(moment.isFineTuned ? 1.06 : 1)
                .contrast(moment.isFineTuned ? 1.10 : 1)
                .brightness(moment.isFineTuned ? 0.025 : 0)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                        .stroke(AppPalette.hairline, lineWidth: 1)
                }
        }
    }
}

struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppType.profileSection)

            content
        }
        .padding(16)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
    }
}

struct SavedPortfolioRow: View {
    let portfolio: CuratedPortfolio

    var body: some View {
        HStack(spacing: 12) {
            BookmarkPreviewImage(assets: portfolio.assets)
                .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(portfolio.title)
                    .font(AppType.profileItemTitle)
                    .lineLimit(2)
                Text(portfolio.author)
                    .font(AppType.caption)
                    .foregroundStyle(AppPalette.gold)
            }

            Spacer()

            Image(systemName: "bookmark.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppPalette.ivory.opacity(0.72))
        }
    }
}

struct EmptyProfileState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(AppPalette.panelStrong.opacity(0.56), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppType.profileItemTitle)
                Text(subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(AppPalette.ivory.opacity(0.56))
            }
        }
    }
}

struct AppBottomNavigationBar: View {
    @Binding var activeTab: AppTab
    let avatarAsset: String
    let homeAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            bottomItem(title: "Home", icon: "house.fill", tab: .home, action: homeAction)
            bottomItem(title: "Invite", icon: "sparkles", tab: .invite) {
                activeTab = .invite
            }
            profileItem
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 0)
        .offset(y: 10)
        .background(AppPalette.paperBright.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppPalette.hairline)
                .frame(height: 1)
        }
    }

    private func bottomItem(title: String, icon: String, tab: AppTab, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .semibold))
                    .frame(height: 26)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .default))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(activeTab == tab ? AppPalette.ivory : AppPalette.ivory.opacity(0.44))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var profileItem: some View {
        Button {
            activeTab = .profile
        } label: {
            VStack(spacing: 4) {
                Image(avatarAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(red: 0.920, green: 0.280, blue: 0.330))
                            .frame(width: 7, height: 7)
                            .offset(x: 1, y: -1)
                    }
                Text("Profile")
                    .font(.system(size: 12, weight: .semibold, design: .default))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(activeTab == .profile ? AppPalette.ivory : AppPalette.ivory.opacity(0.44))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }
}

struct ScreenScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    let backAction: () -> Void
    private let content: () -> Content
    private let footer: () -> Footer

    init(
        title: String,
        subtitle: String,
        backAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backAction = backAction
        self.content = content
        self.footer = footer
    }

    init(
        title: String,
        subtitle: String,
        backAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) where Footer == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.backAction = backAction
        self.content = content
        self.footer = { EmptyView() }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(AppPalette.panelStrong, in: Circle())
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppType.screenTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                Text(subtitle)
                    .font(AppType.body)
                    .foregroundStyle(AppPalette.ivory.opacity(0.68))
                    .lineSpacing(3)
            }

            content()
        }
    }

    @ViewBuilder
    var body: some View {
        if Footer.self == EmptyView.self {
            ScrollPage {
                pageContent
            }
        } else {
            FixedFooterPage {
                pageContent
            } footer: {
                footer()
            }
        }
    }
}

struct ScrollPage<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView(showsIndicators: true) {
            content()
                .padding(20)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FixedFooterPage<Content: View, Footer: View>: View {
    private let content: () -> Content
    private let footer: () -> Footer

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                content()
                    .padding(20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FooterBar {
                footer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FooterBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(AppPalette.ink.opacity(0.98))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppPalette.hairline)
                    .frame(height: 1)
            }
    }
}

struct MoodStrip: View {
    let assets: [String]

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(82, (proxy.size.width - 20) / 3)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: index == 1 ? 220 : 180)
                        .clipShape(RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                                .stroke(AppPalette.ivory.opacity(index == 1 ? 0.2 : 0.1), lineWidth: 1)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text(index == 0 ? "scale" : index == 1 ? "motion" : "light")
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(8)
                        }
                }
            }
        }
        .frame(height: 220)
    }
}

struct TagRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(AppType.chip)
                        .foregroundStyle(AppPalette.ivory.opacity(0.84))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppPalette.ivory.opacity(0.08), in: Capsule())
                }
            }
        }
    }
}

struct WrapChips: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Label(item, systemImage: "checkmark")
                        .font(AppType.chip)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppPalette.ivory.opacity(0.08), in: Capsule())
                }
            }
        }
    }
}

struct MetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .default))
            Text(label)
                .font(AppType.micro)
                .foregroundStyle(AppPalette.ivory.opacity(0.56))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SceneOptionPanel: View {
    let title: String
    let subtitle: String
    let icon: String
    let badge: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppPalette.buttonText)
                        .frame(width: 46, height: 46)
                        .background(AppPalette.gold, in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                    Spacer()
                    Text(badge.uppercased())
                        .font(AppType.micro)
                        .kerning(2.0)
                        .foregroundStyle(AppPalette.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppPalette.graphite.opacity(0.55), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(AppType.cardTitle)
                    Text(subtitle)
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.64))
                        .lineSpacing(2)
                }

                HStack(spacing: 6) {
                    Text("SELECT")
                        .font(AppType.micro)
                        .kerning(2.4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppPalette.gold)
            }
            .padding(18)
            .surfaceCard()
        }
        .buttonStyle(.plain)
    }
}

struct CameraMockView: View {
    let assetName: String
    let mode: String
    let showGuides: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        LinearGradient(
                            colors: [
                                .black.opacity(0.38),
                                .black.opacity(0.08),
                                .black.opacity(0.36)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipped()

                if showGuides {
                    GuideOverlay()
                }

                if !showGuides {
                    VStack {
                        HStack {
                            Text(mode)
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.52), in: Capsule())
                            Spacer()
                            Label("Light right", systemImage: "sun.max.fill")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.52), in: Capsule())
                        }
                        Spacer()
                    }
                    .foregroundStyle(AppPalette.paper)
                    .padding(14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                    .stroke(AppPalette.ivory.opacity(0.14), lineWidth: 1)
            }
        }
    }
}

struct GuideOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width / 3, y: 0))
                    path.addLine(to: CGPoint(x: width / 3, y: height))
                    path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                    path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                    path.move(to: CGPoint(x: 0, y: height / 3))
                    path.addLine(to: CGPoint(x: width, y: height / 3))
                    path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                    path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
                }
                .stroke(AppPalette.ivory.opacity(0.28), lineWidth: 1)

                RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                    .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                    .frame(width: width * 0.44, height: height * 0.32)
                    .position(x: width * 0.52, y: height * 0.58)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.down")
                    Text("subjects")
                }
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppPalette.gold, in: Capsule())
                .foregroundStyle(AppPalette.ink)
                .position(x: width * 0.52, y: height * 0.39)
            }
        }
    }
}

struct FrameRail: View {
    var body: some View {
        GeometryReader { proxy in
            let itemWidth = max(64, (proxy.size.width - 24) / 4)
            HStack(spacing: 8) {
                ForEach(Array(["HooverTower", "ArchesWalk", "StripedLight", "ArchesWalk"].enumerated()), id: \.offset) { _, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: itemWidth, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                                .stroke(AppPalette.ivory.opacity(0.12), lineWidth: 1)
                        }
                }
            }
        }
        .frame(height: 68)
    }
}

struct AnalysisGrid: View {
    let items: [(String, String, Int)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                    Text(item.0)
                            .font(AppType.micro)
                            .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        Spacer()
                        Text("\(item.2)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(AppPalette.gold)
                    }
                    Text(item.1)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                }
                .padding(14)
                .surfaceCard(cornerRadius: AppChrome.radiusSmall)
            }
        }
    }
}

struct OptimalSceneCard: View {
    let candidate: SceneCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optimal place")
                        .font(AppType.micro)
                        .kerning(2.0)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.gold)
                    Text(candidate.title)
                        .font(AppType.cardTitle)
                }
                Spacer()
                Text("\(candidate.score)")
                    .font(.system(size: 24, weight: .regular, design: .serif))
            }

            SceneAnalysisImage(assetName: candidate.assetName)
                .frame(height: 220)

            Text(candidate.reason)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.ivory.opacity(0.68))
        }
        .padding(16)
        .surfaceCard()
    }
}

struct SceneAnalysisImage: View {
    let assetName: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay(.black.opacity(0.18))
                    .clipped()

                let width = proxy.size.width
                let height = proxy.size.height
                RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                    .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
                    .frame(width: width * 0.42, height: height * 0.32)
                    .position(x: width * 0.52, y: height * 0.62)

                VStack(spacing: 5) {
                    Image(systemName: "figure.stand")
                    Text("stand here")
                }
                .font(.system(size: 11, weight: .heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppPalette.gold, in: Capsule())
                .foregroundStyle(AppPalette.ink)
                .position(x: width * 0.52, y: height * 0.42)

                VStack(spacing: 5) {
                    Image(systemName: "camera.fill")
                    Text("camera")
                }
                .font(.system(size: 11, weight: .heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.black.opacity(0.62), in: Capsule())
                .foregroundStyle(AppPalette.paper)
                .position(x: width * 0.20, y: height * 0.84)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.24, y: height * 0.80))
                    path.addLine(to: CGPoint(x: width * 0.46, y: height * 0.63))
                }
                .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
            }
            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                    .stroke(AppPalette.ivory.opacity(0.14), lineWidth: 1)
            }
        }
    }
}

struct ReadinessCapsule: View {
    let isReady: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isReady ? AppPalette.gold : AppPalette.ivory.opacity(0.42))
                .frame(width: 9, height: 9)
            Text(isReady ? "Ready" : "Coaching")
                .font(.system(size: 13, weight: .heavy))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.black.opacity(0.48), in: Capsule())
        .foregroundStyle(AppPalette.paper)
    }
}

struct CueStack: View {
    let cues: [CoachingCue]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(cues) { cue in
                HStack(spacing: 10) {
                    Image(systemName: icon(for: cue.status))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(color(for: cue.status))
                        .frame(width: 20)
                    Text(cue.title)
                        .font(.system(size: 15, weight: cue.status == .active ? .heavy : .semibold))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(background(for: cue.status), in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
            }
        }
    }

    private func icon(for status: CueStatus) -> String {
        switch status {
        case .pending:
            return "circle"
        case .active:
            return "arrow.right.circle.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    private func color(for status: CueStatus) -> Color {
        switch status {
        case .pending:
            return AppPalette.ivory.opacity(0.42)
        case .active, .complete:
            return AppPalette.gold
        }
    }

    private func background(for status: CueStatus) -> Color {
        switch status {
        case .pending:
            return AppPalette.panel.opacity(0.66)
        case .active:
            return AppPalette.gold.opacity(0.14)
        case .complete:
            return AppPalette.panel.opacity(0.84)
        }
    }
}

struct BeforeAfterView: View {
    let originalAssetName: String
    let editedAssetName: String

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = proxy.size.width / 2
            ZStack {
                HStack(spacing: 0) {
                    Image(originalAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: panelWidth, height: proxy.size.height)
                        .saturation(0.78)
                        .contrast(0.92)
                        .overlay(.black.opacity(0.18))
                        .clipped()
                    Image(editedAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: panelWidth, height: proxy.size.height)
                        .saturation(1.08)
                        .contrast(1.13)
                        .brightness(0.035)
                        .clipped()
                }

                Rectangle()
                    .fill(AppPalette.paperBright.opacity(0.92))
                    .frame(width: 1.4)

                VStack {
                    HStack {
                        Text("Before")
                            .fineTuneImageBadge(fill: .black.opacity(0.46), foreground: AppPalette.paperBright)
                        Spacer()
                        Text("After")
                            .fineTuneImageBadge(fill: AppPalette.gold.opacity(0.86), foreground: AppPalette.paperBright)
                    }
                    .padding(10)
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }
}

struct KeeperCardRow: View {
    let assets: [String]
    @Binding var selectedKeepers: Set<Int>

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(92, (proxy.size.width - 20) / 3)
            HStack(spacing: 10) {
                ForEach(assets.indices, id: \.self) { index in
                    KeeperCard(
                        assetName: assets[index],
                        index: index,
                        isSelected: selectedKeepers.contains(index)
                    ) {
                        if selectedKeepers.contains(index) {
                            selectedKeepers.remove(index)
                        } else {
                            selectedKeepers.insert(index)
                        }
                    }
                    .frame(width: cardWidth)
                }
            }
        }
        .frame(height: 144)
    }
}

struct KeeperCard: View {
    let assetName: String
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 112)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isSelected ? AppPalette.gold : AppPalette.paper.opacity(0.9))
                            .padding(8)
                    }
                HStack(spacing: 7) {
                    Image(systemName: "heart")
                    Image(systemName: "bubble.right")
                    Image(systemName: "paperplane")
                    Spacer()
                    Image(systemName: "bookmark")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(AppPalette.paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                    .stroke(isSelected ? AppPalette.gold : AppPalette.hairline, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AppWordmark: View {
    var body: some View {
        BloomingWordmark()
    }
}

struct BloomingWordmark: View {
    var body: some View {
        Image("BloomingLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 64, alignment: .leading)
            .accessibilityLabel("Blooming")
    }
}

struct BloomingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppPalette.ivory)
                .frame(width: 44, height: 44)
                .background(AppPalette.paper, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppPalette.hairline, lineWidth: 1)
                }
                .shadow(color: AppPalette.oliveShadow, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct PortfolioFeedBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ivory)
                .frame(width: 44, height: 44)
                .background(AppPalette.paper, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppPalette.hairline.opacity(0.86), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.045), radius: 8, y: 3)
                .shadow(color: AppPalette.oliveShadow.opacity(0.38), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct PortfolioFeedIconButton: View {
    let icon: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ivory)
                .frame(width: 44, height: 44)
                .background(AppPalette.paper, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppPalette.hairline.opacity(0.86), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.045), radius: 8, y: 3)
                .shadow(color: AppPalette.oliveShadow.opacity(0.38), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct BloomingSprig: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 3))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 5, y: rect.minY + 3),
            control1: CGPoint(x: rect.midX * 0.68, y: rect.midY + 6),
            control2: CGPoint(x: rect.midX * 1.08, y: rect.midY - 8)
        )

        let leaves = [
            (0.34, -0.18, -34.0),
            (0.53, 0.10, 34.0),
            (0.70, -0.23, -38.0),
            (0.84, 0.05, 30.0)
        ]

        for leaf in leaves {
            let center = CGPoint(x: rect.minX + rect.width * leaf.0, y: rect.midY + rect.height * leaf.1)
            let leafSize = CGSize(width: rect.width * 0.12, height: rect.height * 0.30)
            var leafPath = Path(ellipseIn: CGRect(
                x: center.x - leafSize.width / 2,
                y: center.y - leafSize.height / 2,
                width: leafSize.width,
                height: leafSize.height
            ))
            leafPath = leafPath.applying(CGAffineTransform(translationX: -center.x, y: -center.y))
            leafPath = leafPath.applying(CGAffineTransform(rotationAngle: CGFloat(leaf.2 * .pi / 180)))
            leafPath = leafPath.applying(CGAffineTransform(translationX: center.x, y: center.y))
            path.addPath(leafPath)
        }

        return path
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title.uppercased())
                    .kerning(3.0)
            }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .default))
            .padding(.vertical, 16)
            .background(
                isEnabled ? AppPalette.gold : AppPalette.ivory.opacity(0.13),
                in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
            )
            .foregroundStyle(isEnabled ? AppPalette.buttonText : AppPalette.ivory.opacity(0.52))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

extension String {
    var firstName: String {
        split(separator: " ").first.map(String.init) ?? self
    }
}

extension View {
    func fineTuneImageBadge(fill: Color, foreground: Color) -> some View {
        self
            .font(.custom("AvenirNext-DemiBold", size: 13))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(fill, in: Capsule())
    }

    func buttonStyleLabel() -> some View {
        self
            .font(.system(size: 13, weight: .semibold, design: .default))
            .kerning(1.8)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(AppPalette.gold.opacity(0.92), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
            .foregroundStyle(AppPalette.buttonText)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .default))
            .kerning(1.4)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(AppPalette.panel.opacity(configuration.isPressed ? 0.70 : 1), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
            .foregroundStyle(AppPalette.ivory)
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                    .stroke(AppPalette.gold.opacity(0.28), lineWidth: 1)
            }
    }
}

struct SecondaryTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .default))
            .kerning(1.6)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppPalette.panel.opacity(configuration.isPressed ? 0.76 : 1), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
            .foregroundStyle(AppPalette.ivory)
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                    .stroke(AppPalette.hairline, lineWidth: 1)
            }
    }
}

struct StatusBadge: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .kerning(1.2)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

struct SurfaceCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(AppPalette.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppPalette.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }
}

extension View {
    func surfaceCard(cornerRadius: CGFloat = AppChrome.radius) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius))
    }
}

struct MemoryBackdrop: View {
    var body: some View {
        AppPalette.ink
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppPalette.backdropMid)
                    .frame(height: 178)
                    .ignoresSafeArea()
            }
    }
}

struct PortfolioFeedBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("PortfolioFeedBackdrop")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

struct PortfolioDetailBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("PortfolioDetailBackdrop")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

struct BloomingHomeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AppPalette.powderBlue
                    .frame(width: proxy.size.width, height: proxy.size.height)

                Image("PortfolioDetailBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .clear, location: 0.46),
                        .init(color: AppPalette.paperBright.opacity(0.42), location: 0.72),
                        .init(color: AppPalette.paperBright.opacity(0.96), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

struct BloomingWelcomeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                AppPalette.airBlue

                Image("BloomingHeaderBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(0.72)
                    .clipped()

                LinearGradient(
                    colors: [
                        AppPalette.airBlue.opacity(0.34),
                        AppPalette.panel.opacity(0.28),
                        AppPalette.airBlue.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                SoftBreezeLines()
                    .stroke(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                    .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.32)
                    .offset(x: -10, y: proxy.size.height * 0.08)

                WelcomeFlowerTrace()
                    .stroke(Color.white.opacity(0.44), style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                    .frame(width: 156, height: 230)
                    .padding(.top, proxy.size.height * 0.10)
                    .padding(.trailing, -8)
            }
        }
    }
}

struct WelcomeFlowerTrace: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x: (CGFloat) -> CGFloat = { rect.minX + rect.width * $0 }
        let y: (CGFloat) -> CGFloat = { rect.minY + rect.height * $0 }

        path.move(to: CGPoint(x: x(0.55), y: y(0.98)))
        path.addCurve(
            to: CGPoint(x: x(0.54), y: y(0.24)),
            control1: CGPoint(x: x(0.42), y: y(0.76)),
            control2: CGPoint(x: x(0.68), y: y(0.46))
        )
        path.move(to: CGPoint(x: x(0.54), y: y(0.53)))
        path.addCurve(
            to: CGPoint(x: x(0.24), y: y(0.36)),
            control1: CGPoint(x: x(0.43), y: y(0.48)),
            control2: CGPoint(x: x(0.33), y: y(0.42))
        )
        path.move(to: CGPoint(x: x(0.58), y: y(0.43)))
        path.addCurve(
            to: CGPoint(x: x(0.86), y: y(0.28)),
            control1: CGPoint(x: x(0.68), y: y(0.38)),
            control2: CGPoint(x: x(0.76), y: y(0.31))
        )
        path.move(to: CGPoint(x: x(0.48), y: y(0.72)))
        path.addCurve(
            to: CGPoint(x: x(0.20), y: y(0.66)),
            control1: CGPoint(x: x(0.40), y: y(0.69)),
            control2: CGPoint(x: x(0.30), y: y(0.66))
        )

        addPetalCluster(to: &path, center: CGPoint(x: x(0.20), y: y(0.34)), radius: rect.width * 0.10)
        addPetalCluster(to: &path, center: CGPoint(x: x(0.88), y: y(0.27)), radius: rect.width * 0.09)
        addPetalCluster(to: &path, center: CGPoint(x: x(0.18), y: y(0.66)), radius: rect.width * 0.08)

        return path
    }

    private func addPetalCluster(to path: inout Path, center: CGPoint, radius: CGFloat) {
        for index in 0..<5 {
            let angle = CGFloat(index) * (.pi * 2 / 5)
            let petalCenter = CGPoint(
                x: center.x + cos(angle) * radius * 0.56,
                y: center.y + sin(angle) * radius * 0.42
            )
            path.addEllipse(in: CGRect(
                x: petalCenter.x - radius * 0.36,
                y: petalCenter.y - radius * 0.24,
                width: radius * 0.72,
                height: radius * 0.48
            ))
        }
        path.addEllipse(in: CGRect(
            x: center.x - radius * 0.14,
            y: center.y - radius * 0.14,
            width: radius * 0.28,
            height: radius * 0.28
        ))
    }
}

struct SoftBreezeLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.58, 0.10, 0.92, 0.04),
            (0.62, 0.20, 1.02, 0.16),
            (0.08, 0.36, 0.44, 0.31),
            (0.55, 0.52, 0.98, 0.42)
        ]

        for line in lines {
            path.move(to: CGPoint(x: rect.width * line.0, y: rect.height * line.1))
            path.addCurve(
                to: CGPoint(x: rect.width * line.2, y: rect.height * line.3),
                control1: CGPoint(x: rect.width * (line.0 + 0.12), y: rect.height * (line.1 - 0.08)),
                control2: CGPoint(x: rect.width * (line.2 - 0.18), y: rect.height * (line.3 + 0.10))
            )
        }

        return path
    }
}

enum AppType {
    static let welcomeHero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 56)
    static let homeHero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 46)
    static let wordmark = Font.custom("SnellRoundhand", size: 25)
    static let hero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 38)
    static let screenTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 34)
    static let sectionTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 27)
    static let cardTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 27)
    static let sceneTitle = Font.custom("BodoniSvtyTwoSCITCTT-Book", size: 31)
    static let portfolioHero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 40)
    static let portfolioName = Font.custom("BodoniSvtyTwoITCTT-Book", size: 32)
    static let adoptionTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 32)
    static let ctaSerif = Font.custom("BodoniSvtyTwoITCTT-Book", size: 26)
    static let eyebrow = Font.custom("AvenirNext-DemiBold", size: 11)
    static let body = Font.custom("AvenirNext-Regular", size: 15)
    static let caption = Font.custom("AvenirNext-Regular", size: 13)
    static let chip = Font.custom("AvenirNext-DemiBold", size: 12)
    static let micro = Font.custom("AvenirNext-DemiBold", size: 10)
    static let profileName = Font.custom("AvenirNext-DemiBold", size: 24)
    static let profileSection = Font.custom("AvenirNext-DemiBold", size: 16)
    static let profileItemTitle = Font.custom("AvenirNext-DemiBold", size: 15)
}

enum AppChrome {
    static let radiusSmall: CGFloat = 8
    static let radius: CGFloat = 13
    static let radiusLarge: CGFloat = 18
}

enum AppPalette {
    static let ink = Color(red: 0.955, green: 0.946, blue: 0.926)
    static let powderBlueHighlight = Color(red: 0.925, green: 0.953, blue: 0.969)
    static let powderBlue = Color(red: 0.894, green: 0.922, blue: 0.945)
    static let powderBlueShadow = Color(red: 0.878, green: 0.910, blue: 0.941)
    static let airBlue = Color(red: 0.820, green: 0.902, blue: 0.930)
    static let backdropMid = Color(red: 0.675, green: 0.775, blue: 0.805)
    static let mistBlue = Color(red: 0.610, green: 0.720, blue: 0.765)
    static let graphite = Color(red: 0.878, green: 0.858, blue: 0.820)
    static let panel = Color(red: 0.982, green: 0.972, blue: 0.952)
    static let panelStrong = Color(red: 0.910, green: 0.898, blue: 0.866)
    static let paper = Color(red: 0.992, green: 0.986, blue: 0.972)
    static let paperBright = Color(red: 0.998, green: 0.995, blue: 0.986)
    static let cameraPanel = Color(red: 0.982, green: 0.972, blue: 0.952).opacity(0.92)
    static let ivory = Color(red: 0.210, green: 0.216, blue: 0.195)
    static let gold = Color(red: 0.420, green: 0.462, blue: 0.320)
    static let oliveShadow = Color(red: 0.420, green: 0.462, blue: 0.320).opacity(0.14)
    static let buttonText = Color(red: 0.992, green: 0.986, blue: 0.972)
    static let hairline = Color.black.opacity(0.10)
}
