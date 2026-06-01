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
    case momentsSaved(Int)

    var id: String {
        switch self {
        case .comments(let portfolio):
            return "comments-\(portfolio.id)"
        case .bookmark(let portfolio):
            return "bookmark-\(portfolio.id)"
        case .momentsSaved(let count):
            return "moments-saved-\(count)"
        }
    }
}

enum SceneInputMethod: String {
    case scanSurroundings = "Scan surroundings"
    case currentScene = "Current scene"
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
    let photographerBio: String
    let locationSummary: String
    let styleSummary: String
    let assets: [String]
    let tags: [String]
    let shots: [PortfolioShot]
}

struct PortfolioShot: Identifiable {
    let id: String
    let assetName: String
    let title: String
    let location: String
    let gesture: String
    let tags: [String]
}

struct SubjectProfile {
    let count: Int
    let readinessNotes: [String]
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

struct CaptureSessionResult {
    let finishingLook: String
    let candidateAssets: [String]
}

struct SavedBloomingMoment: Identifiable {
    let id = UUID()
    let sceneTitle: String
    let assetName: String
    let isFineTuned: Bool
}

struct ContentView: View {
    private let scenarios = AppContent.scenarios

    @State private var step: AppStep = .welcome
    @State private var selectedScenarioIndex = 0
    @State private var selectedPortfolioIndex = 0
    @State private var selectedShotIndex = 1
    @State private var subjectProfile: SubjectProfile?
    @State private var sceneInputMethod: SceneInputMethod = .scanSurroundings
    @State private var sceneCandidate = SceneCandidate(
        title: "South arcade, late side light",
        reason: "Clean background, side light, enough depth.",
        score: 91,
        assetName: "ArchesWalk"
    )
    @State private var subjectReferenceImage: UIImage?
    @State private var isReadyToCapture = false
    @State private var selectedKeepers: Set<Int> = [0]
    @State private var fineTuneDecisions: [Int: Bool] = [:]
    @State private var hasSavedFineTuneSelection = false
    @State private var activeTab: AppTab = .home
    @State private var activeSheet: AppSheet?
    @State private var savedPortfolioIds: Set<String> = []
    @State private var savedMoments: [SavedBloomingMoment] = []

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

    private var captureResult: CaptureSessionResult {
        CaptureSessionResult(
            finishingLook: "AI Fine Tune",
            candidateAssets: Array((selectedPortfolio.assets + selectedPortfolio.shots.map(\.assetName)).prefix(6))
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
            case .welcome, .scenarioSelect, .liveCoach:
                return false
            default:
                return true
            }
        }
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
                            step = .welcome
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(step == .welcome)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .comments(let portfolio):
                CommentSheetView(portfolio: portfolio, avatarAsset: "HooverTower")
                    .presentationDetents([.fraction(0.58), .large])
                    .presentationDragIndicator(.visible)
            case .bookmark(let portfolio):
                BookmarkSheetView(
                    portfolio: portfolio,
                    saveAction: { savedPortfolioIds.insert($0.id) }
                )
                .presentationDetents([.fraction(0.48), .medium])
                .presentationDragIndicator(.visible)
            case .momentsSaved(let count):
                MomentsSavedSheetView(
                    savedCount: count,
                    viewProfileAction: {
                        activeSheet = nil
                        resetCaptureState(clearSubject: true)
                        activeTab = .profile
                        step = .scenarioSelect
                    },
                    takeMoreAction: {
                        activeSheet = nil
                        resetCaptureState(clearSubject: false)
                        activeTab = .home
                        step = .sceneChoice
                    }
                )
                .presentationDetents([.fraction(0.36), .medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func resetCaptureState(clearSubject: Bool) {
        selectedKeepers = []
        fineTuneDecisions = [:]
        hasSavedFineTuneSelection = false
        isReadyToCapture = false
        if clearSubject {
            subjectProfile = nil
            subjectReferenceImage = nil
        }
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
                savedMoments: savedMoments,
                avatarAsset: "HooverTower"
            )
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
                selectedScenarioIndex: $selectedScenarioIndex
            ) {
                selectedPortfolioIndex = 0
                selectedShotIndex = 0
                step = .portfolioList
            }
        case .portfolioList:
            PortfolioListView(
                scenario: selectedScenario,
                selectedPortfolioIndex: $selectedPortfolioIndex,
                openAction: { index in
                    selectedPortfolioIndex = index
                    selectedShotIndex = 0
                    step = .portfolioDetail
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
                continueAction: {
                    sceneCandidate = SceneCandidate(
                        title: selectedShot.location,
                        reason: "Selected from \(selectedPortfolio.author)'s curated portfolio.",
                        score: 88,
                        assetName: selectedShot.assetName
                    )
                    step = .subjectCalibration
                },
                backAction: {
                    step = .portfolioList
                }
            )
        case .subjectCalibration:
            SubjectCalibrationView(
                referenceImage: $subjectReferenceImage,
                profile: subjectProfile
            ) {
                subjectProfile = SubjectProfile(
                    count: 2,
                    readinessNotes: ["selfie uploaded", "faces visible", "ready for pose matching"]
                )
            } continueAction: {
                step = .sceneChoice
            } backAction: {
                step = .portfolioDetail
            }
        case .sceneChoice:
            SceneChoiceView(
                scanAction: {
                    sceneInputMethod = .scanSurroundings
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
            ScanSurroundingsView(candidate: sceneCandidate) {
                step = .sceneCalculating
            } backAction: {
                step = .sceneChoice
            }
        case .currentScene:
            CurrentSceneView(candidate: sceneCandidate) {
                step = .sceneCalculating
            } backAction: {
                step = .sceneChoice
            }
        case .sceneCalculating:
            SceneCalculatingView(inputMethod: sceneInputMethod) {
                isReadyToCapture = false
                step = .liveCoach
            }
        case .liveCoach:
            LiveCoachingView(
                candidate: sceneCandidate,
                isReady: isReadyToCapture,
                runReadiness: {
                    isReadyToCapture = true
                },
                captureAction: {
                    selectedKeepers = Set(captureResult.candidateAssets.indices)
                    fineTuneDecisions = [:]
                    hasSavedFineTuneSelection = false
                    step = .preview
                },
                backAction: {
                    isReadyToCapture = false
                    step = sceneInputMethod == .scanSurroundings ? .scanSurroundings : .currentScene
                }
            )
        case .preview:
            PreviewKeeperView(
                result: captureResult,
                selectedKeepers: $selectedKeepers,
                saveAction: {
                    fineTuneDecisions = [:]
                    hasSavedFineTuneSelection = false
                    step = .saved
                }
            )
        case .saved:
            FineTuneReviewView(
                result: captureResult,
                selectedKeepers: selectedKeepers,
                fineTuneDecisions: $fineTuneDecisions,
                isSaved: hasSavedFineTuneSelection,
                saveAction: {
                    guard !hasSavedFineTuneSelection else { return }
                    let savedSelection = selectedKeepers.sorted().compactMap { index -> SavedBloomingMoment? in
                        guard captureResult.candidateAssets.indices.contains(index) else { return nil }
                        return SavedBloomingMoment(
                            sceneTitle: selectedScenario.title,
                            assetName: captureResult.candidateAssets[index],
                            isFineTuned: fineTuneDecisions[index] ?? false
                        )
                    }
                    savedMoments = Array((savedSelection + savedMoments).prefix(30))
                    hasSavedFineTuneSelection = true
                    isReadyToCapture = false
                    activeSheet = .momentsSaved(savedSelection.count)
                }
            )
        }
    }
}

struct AppContent {
    static let graduationPortfolio = CuratedPortfolio(
        id: "campus_editorial_graduation",
        title: "Campus Editorial Graduation",
        author: "Ann Li",
        photographerBio: "Ann builds campus stories around landmark scale, soft movement, and graphic pockets of light. Her graduation work feels editorial without losing the warmth of the people in the frame.",
        locationSummary: "Hoover Tower, sandstone arches, warm indoor light",
        styleSummary: "Landmark scale, motion blur, dramatic striped light",
        assets: ["HooverTower", "ArchesWalk", "StripedLight"],
        tags: ["landmark", "motion", "dramatic light"],
        shots: [
            PortfolioShot(
                id: "tower-scale",
                assetName: "HooverTower",
                title: "Tiny Beneath The Tower",
                location: "Hoover Tower lawn",
                gesture: "Sit low in the foreground, lean in, let the landmark dominate.",
                tags: ["scale", "landmark", "soft grass"]
            ),
            PortfolioShot(
                id: "arcade-motion",
                assetName: "ArchesWalk",
                title: "Walkaway Through Arches",
                location: "Main Quad arcade",
                gesture: "Hold hands and walk away slowly as the camera follows behind.",
                tags: ["motion", "arches", "gold light"]
            ),
            PortfolioShot(
                id: "striped-light",
                assetName: "StripedLight",
                title: "Striped Light Conversation",
                location: "Warm interior with louver light",
                gesture: "Stand inside the light, face each other, laugh mid-conversation.",
                tags: ["light pattern", "warm", "intimate"]
            )
        ]
    )

    static let softPortraitPortfolio = CuratedPortfolio(
        id: "soft_campus_portrait",
        title: "Soft Campus Portraits",
        author: "Maya Chen",
        photographerBio: "Maya focuses on calm portrait direction, clean backgrounds, and gentle expression. Her sets are tuned for people who want a flattering, natural image language.",
        locationSummary: "Open lawn, tower edges, shaded paths",
        styleSummary: "Clean portraits, soft greens, calm expressions",
        assets: ["HooverTower", "StripedLight", "ArchesWalk"],
        tags: ["portrait", "soft light", "clean"],
        shots: [
            PortfolioShot(id: "portrait-lawn", assetName: "HooverTower", title: "Lawn Portrait", location: "Open campus lawn", gesture: "Stand tall, angle shoulders, look slightly past camera.", tags: ["portrait", "green", "classic"]),
            PortfolioShot(id: "portrait-light", assetName: "StripedLight", title: "Window Glow", location: "Quiet window light", gesture: "Turn chin toward light, hands relaxed.", tags: ["soft", "window", "solo"]),
            PortfolioShot(id: "portrait-arches", assetName: "ArchesWalk", title: "Framed Walk", location: "Shaded arch path", gesture: "Walk toward camera with a small smile.", tags: ["walking", "frame", "simple"])
        ]
    )

    static let cinematicCampusPortfolio = CuratedPortfolio(
        id: "cinematic_campus_story",
        title: "Cinematic Campus Story",
        author: "Leo Park",
        photographerBio: "Leo treats the campus like a film location, looking for depth, backlight, and quiet movement. His portfolio favors wide frames with a sense of story.",
        locationSummary: "Long corridors, backlight, layered architecture",
        styleSummary: "Wide frames, shadow depth, story-first movement",
        assets: ["ArchesWalk", "HooverTower", "StripedLight"],
        tags: ["cinematic", "wide", "story"],
        shots: [
            PortfolioShot(id: "cinema-arches", assetName: "ArchesWalk", title: "Long Arcade", location: "Deep arch corridor", gesture: "Walk slowly, do not look back.", tags: ["wide", "motion", "depth"]),
            PortfolioShot(id: "cinema-tower", assetName: "HooverTower", title: "Campus Scale", location: "Landmark view", gesture: "Stay small in frame, interact naturally.", tags: ["scale", "campus", "quiet"]),
            PortfolioShot(id: "cinema-light", assetName: "StripedLight", title: "Light Scene", location: "Graphic light wall", gesture: "Step into the brightest stripe and pause.", tags: ["shadow", "graphic", "warm"])
        ]
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
            portfolios: [softPortraitPortfolio, graduationPortfolio, cinematicCampusPortfolio]
        ),
        PhotoScenario(
            id: "anniversary",
            title: "Anniversary",
            subtitle: "Couple-led stories with intimate gestures, soft light, and place-based memories.",
            heroAsset: "AnniversaryScenePoster",
            tags: ["couple", "memory", "soft"],
            portfolios: [cinematicCampusPortfolio, graduationPortfolio, softPortraitPortfolio]
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
    let continueAction: () -> Void

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    BloomingWordmark()

                    Text("What’s blooming now?")
                        .font(AppType.homeHero)
                        .foregroundStyle(AppPalette.ivory)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("Select your themed scene")
                        .font(AppType.micro)
                        .kerning(4.0)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                }
                .padding(.top, 10)
                .padding(.horizontal, 18)

                VStack(spacing: 12) {
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
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .background(BloomingHomeBackdrop().ignoresSafeArea())
    }
}

struct PortfolioListView: View {
    let scenario: PhotoScenario
    @Binding var selectedPortfolioIndex: Int
    let openAction: (Int) -> Void
    let commentAction: (CuratedPortfolio) -> Void
    let bookmarkAction: (CuratedPortfolio) -> Void
    let backAction: () -> Void

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    BloomingBackButton(action: backAction)
                    Spacer()
                }
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text(scenario.title)
                        .font(AppType.hero)
                        .foregroundStyle(AppPalette.ivory)
                    Text("Choose a photographer whose eye matches the moment.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                        .lineSpacing(3)
                }

                LazyVStack(spacing: 14) {
                    ForEach(Array(scenario.portfolios.enumerated()), id: \.element.id) { index, portfolio in
                        PhotographerPortfolioCard(
                            portfolio: portfolio,
                            avatarAsset: avatarAsset(for: index),
                            likeCount: likeCount(for: index),
                            isSelected: selectedPortfolioIndex == index,
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
            }
            .padding(20)
            .padding(.bottom, 52)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .background(MemoryBackdrop())
    }

    private func avatarAsset(for index: Int) -> String {
        let avatars = ["StripedLight", "HooverTower", "ArchesWalk"]
        return avatars[index % avatars.count]
    }

    private func likeCount(for index: Int) -> Int {
        [64, 42, 87][index % 3]
    }
}

struct PortfolioDetailView: View {
    let portfolio: CuratedPortfolio
    let continueAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    BloomingBackButton(action: backAction)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)

                PhotographerProfileHeader(portfolio: portfolio)
                    .padding(.horizontal, 20)

                PortfolioMasonryGrid(shots: portfolio.shots)
                    .padding(.horizontal, 12)

                PrimaryButton(title: "Choose This Curated Portfolio", icon: "camera.viewfinder", action: continueAction)
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
            }
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MemoryBackdrop())
    }
}

struct PhotographerProfileHeader: View {
    let portfolio: CuratedPortfolio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                PhotographerAvatar(assetName: portfolio.assets.first ?? "HooverTower", name: portfolio.author)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
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
                        PortfolioMasonryPhotoTile(
                            shot: item.element,
                            index: item.offset
                        )
                        .frame(width: columnWidth, height: tileHeight(for: item.element, columnWidth: columnWidth))
                    }
                }

                VStack(spacing: 10) {
                    ForEach(rightColumnShots, id: \.element.id) { item in
                        PortfolioMasonryPhotoTile(
                            shot: item.element,
                            index: item.offset
                        )
                        .frame(width: columnWidth, height: tileHeight(for: item.element, columnWidth: columnWidth))
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

    var body: some View {
        GeometryReader { proxy in
            Image(shot.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppPalette.hairline, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.055), radius: 12, y: 6)
                .accessibilityLabel("Portfolio photo \(index + 1), \(shot.title)")
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
        case "anniversary":
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
        case "anniversary":
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
                    .fill(AppPalette.paper.opacity(kind == "anniversary" ? 0.10 : 0.72))
                    .frame(width: width * 0.78, height: height * 0.82)
                    .offset(x: width * 0.05, y: height * 0.04)

                Circle()
                    .fill(accent.opacity(kind == "wedding" ? 0.22 : 0.28))
                    .frame(width: width * 0.48, height: width * 0.48)
                    .position(x: width * 0.70, y: height * 0.22)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppPalette.paper.opacity(kind == "anniversary" ? 0.92 : 0.96))
                    .frame(width: width * 0.58, height: height * 0.72)
                    .position(x: width * 0.45, y: height * 0.52)
                    .shadow(color: .black.opacity(0.07), radius: 18, y: 8)

                sceneMotif(width: width, height: height)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(kind == "anniversary" ? AppPalette.paper.opacity(0.72) : AppPalette.gold.opacity(0.78))
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
        case "anniversary":
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
    let isSelected: Bool
    let commentAction: () -> Void
    let bookmarkAction: () -> Void
    let openAction: () -> Void

    @State private var isLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: openAction) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 10) {
                        PhotographerAvatar(assetName: avatarAsset, name: portfolio.author)
                            .frame(width: 36, height: 36)

                        Text(portfolio.author)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundStyle(AppPalette.ivory)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppPalette.ivory.opacity(0.42))
                    }

                    PortfolioPhotoCarousel(assets: carouselAssets)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(portfolio.author)'s portfolio")

            HStack(spacing: 22) {
                PortfolioActionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    value: "\(isLiked ? likeCount + 1 : likeCount)",
                    accessibilityLabel: "Like \(portfolio.author)'s portfolio"
                ) {
                    isLiked.toggle()
                }
                PortfolioActionButton(
                    icon: "bubble.right",
                    value: nil,
                    accessibilityLabel: "Comment on \(portfolio.author)'s portfolio",
                    action: commentAction
                )
                Spacer()
                PortfolioActionButton(
                    icon: "bookmark",
                    value: nil,
                    accessibilityLabel: "Bookmark \(portfolio.author)'s portfolio",
                    action: bookmarkAction
                )
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                .stroke(isSelected ? AppPalette.gold.opacity(0.5) : AppPalette.hairline, lineWidth: isSelected ? 1.5 : 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 12, y: 6)
    }

    private var carouselAssets: [String] {
        Array((portfolio.assets + portfolio.shots.map(\.assetName)).prefix(6))
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
                .overlay(alignment: .bottomTrailing) {
                    Text(initials)
                        .font(.system(size: max(7, proxy.size.width * 0.19), weight: .heavy))
                        .foregroundStyle(AppPalette.buttonText)
                        .frame(width: proxy.size.width * 0.38, height: proxy.size.width * 0.38)
                        .background(AppPalette.gold, in: Circle())
                }
        }
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }
    private var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}

struct PortfolioPhotoCarousel: View {
    let assets: [String]
    @State private var visiblePhotoIndex: Int? = 0

    var body: some View {
        VStack(spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                        Image(asset)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 116)
                            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                                    .stroke(AppPalette.hairline, lineWidth: 1)
                            }
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.trailing, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visiblePhotoIndex)

            CarouselDots(count: min(assets.count, 6), activeIndex: visiblePhotoIndex ?? 0)
        }
    }
}

struct CarouselDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? AppPalette.ivory.opacity(0.72) : AppPalette.ivory.opacity(0.20))
                    .frame(width: index == activeIndex ? 6 : 5, height: index == activeIndex ? 6 : 5)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AppPalette.ink.opacity(0.06), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct PortfolioActionButton: View {
    let icon: String
    let value: String?
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
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
    let captureAction: () -> Void
    let continueAction: () -> Void
    let backAction: () -> Void

    @State private var isShowingCamera = false

    var body: some View {
        ScreenScaffold(
            title: "Who will be in the photo?",
            subtitle: "Upload one selfie or group selfie so the app knows who to guide. You will confirm it before moving on.",
            backAction: backAction
        ) {
            VStack(spacing: 14) {
                Button {
                    openCameraOrDemo()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                            .fill(AppPalette.mistBlue.opacity(0.52))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                                    .stroke(AppPalette.hairline, lineWidth: 1)
                            }

                        if let referenceImage {
                            Image(uiImage: referenceImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 232, height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                                        .stroke(AppPalette.paperBright, lineWidth: 2)
                                }
                                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                        } else {
                            RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                                .fill(AppPalette.paperBright)
                                .frame(width: 232, height: 300)
                                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)

                            VStack(spacing: 18) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 52, weight: .medium))
                                    .foregroundStyle(AppPalette.gold)

                                Text("SELFIE")
                                    .font(AppType.micro)
                                    .kerning(2.4)
                                    .foregroundStyle(AppPalette.ivory.opacity(0.56))
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if referenceImage != nil {
                            Text("Tap photo to retake")
                                .font(AppType.caption)
                                .foregroundStyle(AppPalette.ivory.opacity(0.62))
                                .padding(.bottom, 18)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 386)
                .accessibilityLabel(referenceImage == nil ? "Upload a selfie" : "Retake selfie")
            }
        } footer: {
            PrimaryButton(
                title: "Confirm Selfie",
                icon: "checkmark.seal.fill",
                action: confirmSelfie
            )
            .disabled(referenceImage == nil)
            .opacity(referenceImage == nil ? 0.45 : 1)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            SubjectCameraPicker(image: $referenceImage)
                .ignoresSafeArea()
        }
    }

    private func openCameraOrDemo() {
        #if targetEnvironment(simulator)
        referenceImage = DemoSelfieImage.make()
        #else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingCamera = true
        } else {
            referenceImage = DemoSelfieImage.make()
        }
        #endif
    }

    private func confirmSelfie() {
        guard referenceImage != nil else { return }
        captureAction()
        continueAction()
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

struct SubjectCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: SubjectCameraPicker

        init(_ parent: SubjectCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct SceneChoiceView: View {
    let scanAction: () -> Void
    let currentAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        ScreenScaffold(
            title: "Find the shot",
            subtitle: "Let the app scout nearby options, or analyze a scene you already like.",
            backAction: backAction
        ) {
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
        }
    }
}

struct ScanSurroundingsView: View {
    let candidate: SceneCandidate
    let continueAction: () -> Void
    let backAction: () -> Void
    @State private var hasCapturedScan = false

    var body: some View {
        ScreenScaffold(
            title: "Scan surroundings",
            subtitle: "Open camera, hold your phone upright, then slowly turn once so Blooming can see the surrounding space.",
            backAction: backAction
        ) {
            VStack(spacing: 16) {
                SceneCaptureGuide(
                    title: "Turn once, slowly",
                    subtitle: "Keep the phone level and pan across the full area. Blooming will pick the best standing spot from the uploaded scan.",
                    mode: .scan
                )
                .frame(height: 100)
                .zIndex(1)

                Button {
                    hasCapturedScan = true
                } label: {
                    SceneCameraCaptureCard(
                        assetName: candidate.assetName,
                        mode: hasCapturedScan ? "SCAN READY" : "OPEN CAMERA",
                        title: hasCapturedScan ? "360 scan preview" : "Tap to scan your surroundings",
                        subtitle: hasCapturedScan ? "Review this video scan, then confirm upload." : "Camera opens here. Pan slowly in one smooth circle.",
                        icon: hasCapturedScan ? "checkmark.seal.fill" : "video.fill",
                        showGuides: !hasCapturedScan
                    )
                    .frame(height: 236)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasCapturedScan ? "Retake surroundings scan" : "Open camera to scan surroundings")

                if hasCapturedScan {
                    UploadedSceneSummary(
                        title: "Video ready to upload",
                        subtitle: "Blooming will calculate light, background, depth, clutter, and where people should stand."
                    )
                } else {
                    Text("After the scan, you will come back here to confirm the upload.")
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } footer: {
            PrimaryButton(
                title: hasCapturedScan ? "Confirm and Upload Scan" : "Open Camera to Scan",
                icon: hasCapturedScan ? "icloud.and.arrow.up.fill" : "video.fill",
                action: hasCapturedScan ? continueAction : { hasCapturedScan = true }
            )
        }
    }
}

struct CurrentSceneView: View {
    let candidate: SceneCandidate
    let continueAction: () -> Void
    let backAction: () -> Void
    @State private var hasCapturedPhoto = false

    var body: some View {
        ScreenScaffold(
            title: "Current scene",
            subtitle: "Take one photo of the scene you already like. Blooming will calculate the best subject position from that frame.",
            backAction: backAction
        ) {
            VStack(spacing: 16) {
                SceneCaptureGuide(
                    title: "Frame the scene",
                    subtitle: "Point at the wall, archway, landmark, or pocket of light you want to use. Leave enough space for people.",
                    mode: .photo
                )
                .frame(height: 100)
                .zIndex(1)

                Button {
                    hasCapturedPhoto = true
                } label: {
                    SceneCameraCaptureCard(
                        assetName: candidate.assetName,
                        mode: hasCapturedPhoto ? "PHOTO READY" : "OPEN CAMERA",
                        title: hasCapturedPhoto ? "Scene photo preview" : "Tap to take a scene photo",
                        subtitle: hasCapturedPhoto ? "Review this scene photo, then confirm upload." : "Camera opens here. Take one steady frame.",
                        icon: hasCapturedPhoto ? "checkmark.seal.fill" : "camera.fill",
                        showGuides: !hasCapturedPhoto
                    )
                    .frame(height: 268)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasCapturedPhoto ? "Retake current scene photo" : "Open camera to take current scene photo")

                if hasCapturedPhoto {
                    UploadedSceneSummary(
                        title: "Scene ready to upload",
                        subtitle: "Blooming will calculate the best standing point and coaching frame from this photo."
                    )
                } else {
                    Text("After the photo, you will come back here to confirm the upload.")
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } footer: {
            PrimaryButton(
                title: hasCapturedPhoto ? "Confirm Scene Upload" : "Take Scene Photo",
                icon: hasCapturedPhoto ? "icloud.and.arrow.up.fill" : "camera.fill",
                action: hasCapturedPhoto ? continueAction : { hasCapturedPhoto = true }
            )
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
                    .fill(AppPalette.paperBright)
                    .frame(width: 58, height: 58)

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
                        .stroke(AppPalette.gold, lineWidth: 2)
                        .frame(width: 38, height: 28)
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ivory)
                        .scaleEffect(animate ? 1.08 : 0.94)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: mode == .scan ? 2.4 : 1.25).repeatForever(autoreverses: mode == .photo)) {
                    animate = true
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppType.sectionTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(AppPalette.ivory.opacity(0.68))
                    .lineSpacing(2)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SceneCameraCaptureCard: View {
    let assetName: String
    let mode: String
    let title: String
    let subtitle: String
    let icon: String
    let showGuides: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(.black.opacity(0.18))

            if showGuides {
                CameraGuideOverlay()
                    .padding(18)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(mode)
                    .font(AppType.micro)
                    .kerning(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.paper.opacity(0.78))

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(AppType.cardTitle)
                            .foregroundStyle(AppPalette.paper)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                        Text(subtitle)
                            .font(AppType.caption)
                            .foregroundStyle(AppPalette.paper.opacity(0.76))
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppPalette.paper)
                        .frame(width: 48, height: 48)
                        .background(.black.opacity(0.34), in: Circle())
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

struct CameraGuideOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            Path { path in
                path.move(to: CGPoint(x: width * 0.18, y: height * 0.28))
                path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.18))
                path.addLine(to: CGPoint(x: width * 0.30, y: height * 0.18))
                path.move(to: CGPoint(x: width * 0.82, y: height * 0.28))
                path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.18))
                path.addLine(to: CGPoint(x: width * 0.70, y: height * 0.18))
                path.move(to: CGPoint(x: width * 0.18, y: height * 0.72))
                path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.82))
                path.addLine(to: CGPoint(x: width * 0.30, y: height * 0.82))
                path.move(to: CGPoint(x: width * 0.82, y: height * 0.72))
                path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.82))
                path.addLine(to: CGPoint(x: width * 0.70, y: height * 0.82))
            }
            .stroke(AppPalette.paper.opacity(0.68), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

struct UploadedSceneSummary: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppPalette.gold)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                Text(subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(AppPalette.ivory.opacity(0.62))
                    .lineSpacing(2)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                .stroke(AppPalette.hairline, lineWidth: 1)
        }
    }
}

struct SceneCalculatingView: View {
    let inputMethod: SceneInputMethod
    let continueAction: () -> Void

    @State private var progress: CGFloat = 0.18
    @State private var didFinish = false

    var body: some View {
        FixedFooterPage {
            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                        .fill(AppPalette.mistBlue.opacity(0.44))
                        .frame(height: 360)

                    VStack(spacing: 22) {
                        ZStack {
                            Circle()
                                .stroke(AppPalette.paper.opacity(0.70), lineWidth: 12)
                                .frame(width: 164, height: 164)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 164, height: 164)
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "sparkles")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(AppPalette.ivory)
                        }

                        Text(inputMethod == .scanSurroundings ? "Reading your surroundings" : "Reading your scene")
                            .font(AppType.cardTitle)
                    }
                }

                VStack(spacing: 8) {
                    Text("Blooming is calculating")
                        .font(AppType.screenTitle)
                    Text("Finding light direction, background clutter, depth, and the best place for your subjects to stand.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .task {
                guard !didFinish else { return }
                didFinish = true
                withAnimation(.easeInOut(duration: 1.35)) {
                    progress = 0.86
                }
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                guard !Task.isCancelled else { return }
                continueAction()
            }
        } footer: {
            Button("Calculating") {}
                .buttonStyle(SecondaryTextButtonStyle())
                .disabled(true)
                .opacity(0.62)
        }
    }
}

struct LiveCoachingView: View {
    let candidate: SceneCandidate
    let isReady: Bool
    let runReadiness: () -> Void
    let captureAction: () -> Void
    let backAction: () -> Void

    private var cues: [CoachingCue] {
        [
            CoachingCue(title: "Step back two steps", status: isReady ? .complete : .active),
            CoachingCue(title: "Move subjects left", status: isReady ? .complete : .pending),
            CoachingCue(title: "Turn faces toward the light", status: isReady ? .complete : .pending),
            CoachingCue(title: isReady ? "Hold. Ready." : "Hold pose when framed", status: isReady ? .active : .pending)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraMockView(assetName: candidate.assetName, mode: isReady ? "READY" : "LIVE COACH", showGuides: true)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppPalette.paper)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.42), in: Circle())
                    }
                    Spacer()
                    ReadinessCapsule(isReady: isReady)
                }
                .padding(.horizontal, 18)
                .padding(.top, 58)

                Spacer()

                VStack(spacing: 14) {
                    if isReady {
                        HStack(spacing: 8) {
                            StatusBadge(title: "AE locked", icon: "dial.low.fill", color: AppPalette.gold)
                            StatusBadge(title: "Focus", icon: "scope", color: AppPalette.gold)
                            StatusBadge(title: "HL safe", icon: "sun.min.fill", color: AppPalette.gold)
                        }
                    }

                    CueStack(cues: cues)

                    HStack(spacing: 24) {
                        Button(action: runReadiness) {
                            Label(isReady ? "Ready" : "Check", systemImage: "wand.and.stars")
                                .font(.system(size: 14, weight: .heavy))
                                .frame(width: 82, height: 58)
                                .background(AppPalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                        }
                        .accessibilityLabel("Run readiness check")

                        Button(action: captureAction) {
                            ZStack {
                                Circle()
                                    .stroke(AppPalette.ivory, lineWidth: 4)
                                    .frame(width: 82, height: 82)
                                Circle()
                                    .fill(isReady ? AppPalette.gold : AppPalette.ivory.opacity(0.34))
                                    .frame(width: 62, height: 62)
                            }
                        }
                        .disabled(!isReady)
                        .accessibilityLabel(isReady ? "Capture photo" : "Capture disabled until ready")

                        Button(action: backAction) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 22, weight: .bold))
                                .frame(width: 58, height: 58)
                                .background(AppPalette.panel.opacity(0.92), in: Circle())
                        }
                        .accessibilityLabel("Choose another scene")
                    }
                }
                .padding(16)
                .background(AppPalette.cameraPanel, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                        .stroke(AppPalette.ivory.opacity(0.12), lineWidth: 1)
                }
                .padding(14)
            }
            .foregroundStyle(AppPalette.ivory)
        }
    }
}

struct PreviewKeeperView: View {
    let result: CaptureSessionResult
    @Binding var selectedKeepers: Set<Int>
    let saveAction: () -> Void

    var body: some View {
        FixedFooterPage {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select moments")
                        .font(AppType.screenTitle)
                    Text("Choose the photos you want Blooming to fine tune.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                        .lineSpacing(3)
                }
                .padding(.top, 24)

                HStack {
                    Text("\(selectedKeepers.count) selected")
                        .font(AppType.chip)
                        .foregroundStyle(AppPalette.gold)
                    Spacer()
                    Button(selectedKeepers.count == result.candidateAssets.count ? "Deselect All" : "Select All") {
                        if selectedKeepers.count == result.candidateAssets.count {
                            selectedKeepers.removeAll()
                        } else {
                            selectedKeepers = Set(result.candidateAssets.indices)
                        }
                    }
                    .font(AppType.chip)
                    .foregroundStyle(AppPalette.ivory)
                }

                CapturedPhotoGrid(
                    assets: result.candidateAssets,
                    selectedKeepers: $selectedKeepers
                )

            }
        } footer: {
            PrimaryButton(title: "Fine Tune Selected", icon: "wand.and.stars", action: saveAction)
                .disabled(selectedKeepers.isEmpty)
                .opacity(selectedKeepers.isEmpty ? 0.48 : 1)
        }
    }
}

struct FineTuneReviewView: View {
    let result: CaptureSessionResult
    let selectedKeepers: Set<Int>
    @Binding var fineTuneDecisions: [Int: Bool]
    let isSaved: Bool
    let saveAction: () -> Void

    private var selectedItems: [(index: Int, asset: String)] {
        selectedKeepers
            .sorted()
            .compactMap { index in
                guard result.candidateAssets.indices.contains(index) else { return nil }
                return (index, result.candidateAssets[index])
            }
    }

    private var chosenCount: Int {
        selectedItems.filter { fineTuneDecisions[$0.index] != nil }.count
    }

    private var isReadyToSave: Bool {
        !isSaved && !selectedItems.isEmpty && selectedItems.allSatisfy { fineTuneDecisions[$0.index] != nil }
    }

    var body: some View {
        FixedFooterPage {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI fine tune")
                        .font(AppType.screenTitle)
                    Text("Choose the tuned version or keep the original for each photo.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                        .lineSpacing(3)
                }
                .padding(.top, 24)

                HStack {
                    Text("\(chosenCount) of \(selectedItems.count) chosen")
                        .font(AppType.chip)
                        .foregroundStyle(AppPalette.gold)
                    Spacer()
                    Button("Accept All") {
                        for item in selectedItems {
                            fineTuneDecisions[item.index] = true
                        }
                    }
                    .font(AppType.chip)
                    .foregroundStyle(AppPalette.ivory)
                    .disabled(isSaved || selectedItems.isEmpty)
                    .opacity(isSaved || selectedItems.isEmpty ? 0.46 : 1)
                }

                VStack(spacing: 16) {
                    ForEach(selectedItems, id: \.index) { item in
                        FineTunePhotoCard(
                            assetName: item.asset,
                            decision: fineTuneDecisions[item.index],
                            acceptFineTuneAction: {
                                fineTuneDecisions[item.index] = true
                            },
                            keepOriginalAction: {
                                fineTuneDecisions[item.index] = false
                            }
                        )
                    }
                }
            }
        } footer: {
            VStack(spacing: 8) {
                PrimaryButton(title: "Save", icon: "square.and.arrow.down.fill", action: saveAction)
                    .disabled(!isReadyToSave)
                    .opacity(isReadyToSave ? 1 : 0.48)
                Text(isSaved ? "Saved in your Profile under My Blooming Moments." : "You can see them in your Profile under My Blooming Moments.")
                    .font(AppType.caption)
                    .foregroundStyle(AppPalette.ivory.opacity(0.56))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct CapturedPhotoGrid: View {
    let assets: [String]
    @Binding var selectedKeepers: Set<Int>

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(assets.indices, id: \.self) { index in
                CapturedPhotoTile(
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
            }
        }
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
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 184)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                            .stroke(isSelected ? AppPalette.gold : AppPalette.hairline, lineWidth: isSelected ? 2 : 1)
                    }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? AppPalette.gold : AppPalette.paperBright)
                    .padding(9)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Deselect captured photo \(index + 1)" : "Select captured photo \(index + 1)")
    }
}

struct FineTunePhotoCard: View {
    let assetName: String
    let decision: Bool?
    let acceptFineTuneAction: () -> Void
    let keepOriginalAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BeforeAfterView(assetName: assetName)
                .frame(height: 230)

            HStack(spacing: 8) {
                FineTuneChoiceButton(
                    title: "Accept Fine Tune",
                    icon: "wand.and.stars",
                    isSelected: decision == true,
                    action: acceptFineTuneAction
                )
                FineTuneChoiceButton(
                    title: "Keep Original",
                    icon: "photo",
                    isSelected: decision == false,
                    action: keepOriginalAction
                )
            }
        }
        .padding(12)
        .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                .stroke(decision == nil ? AppPalette.hairline : AppPalette.gold.opacity(0.42), lineWidth: 1)
        }
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
                .font(AppType.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(isSelected ? AppPalette.gold : AppPalette.panelStrong.opacity(0.72), in: Capsule())
                .foregroundStyle(isSelected ? AppPalette.buttonText : AppPalette.ivory)
        }
        .buttonStyle(.plain)
    }
}

struct CommentSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let portfolio: CuratedPortfolio
    let avatarAsset: String

    @State private var commentText = ""

    private let reactions = ["❤️", "🙌", "🔥", "👏", "😍", "🤩", "😮", "😂"]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Text("COMMENTS")
                    .font(.system(size: 15, weight: .heavy, design: .default))
                    .kerning(0.8)
                    .padding(.top, 18)

                VStack(spacing: 8) {
                    Text("Be the first to comment")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundStyle(AppPalette.ivory.opacity(0.62))
                    Text(portfolio.author)
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.gold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 24)

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

                    if !commentText.isEmpty {
                        Button {
                            commentText = ""
                            dismiss()
                        } label: {
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
}

struct BookmarkSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let portfolio: CuratedPortfolio
    let saveAction: (CuratedPortfolio) -> Void

    @State private var folders: [String] = []
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button {
                saveAction(portfolio)
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    BookmarkPreviewImage(assets: portfolio.assets)
                        .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(portfolio.title)
                            .font(.system(size: 19, weight: .heavy, design: .default))
                            .lineLimit(2)
                        Text("Saved")
                            .font(.system(size: 18, weight: .medium, design: .default))
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

            VStack(alignment: .leading, spacing: 14) {
                Button {
                    isCreatingFolder = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "plus")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(AppPalette.ivory)
                            .frame(width: 92, height: 74)
                            .background(AppPalette.panelStrong, in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))

                        Text("New Folder")
                            .font(.system(size: 20, weight: .heavy, design: .default))
                            .foregroundStyle(AppPalette.ivory)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create new folder")

                if isCreatingFolder {
                    HStack(spacing: 10) {
                        TextField("Folder name", text: $newFolderName)
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(AppPalette.panelStrong.opacity(0.55), in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))

                        Button("Save") {
                            let folderName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !folderName.isEmpty {
                                folders.append(folderName)
                            }
                            saveAction(portfolio)
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .heavy, design: .default))
                        .foregroundStyle(AppPalette.buttonText)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(AppPalette.gold, in: RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
                    }
                }

                if folders.isEmpty && !isCreatingFolder {
                    Text("Create your first folder, or tap the saved portfolio above to keep it in All Saved.")
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.ivory.opacity(0.58))
                        .lineSpacing(3)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(AppPalette.paperBright)
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

struct MomentsSavedSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let savedCount: Int
    let viewProfileAction: () -> Void
    let takeMoreAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(AppPalette.hairline)
                .frame(width: 54, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Saved to My Blooming Moments")
                    .font(AppType.profileName)
                    .foregroundStyle(AppPalette.ivory)
                Text("\(savedCount) photos are ready in your Profile.")
                    .font(AppType.body)
                    .foregroundStyle(AppPalette.ivory.opacity(0.62))
            }

            VStack(spacing: 10) {
                Button {
                    dismiss()
                    viewProfileAction()
                } label: {
                    Label("View My Blooming Moments", systemImage: "person.crop.circle")
                        .font(AppType.profileSection)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppPalette.gold, in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                        .foregroundStyle(AppPalette.buttonText)
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    takeMoreAction()
                } label: {
                    Label("Take More Photos", systemImage: "camera.fill")
                        .font(AppType.profileSection)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppPalette.panelStrong.opacity(0.72), in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                        .foregroundStyle(AppPalette.ivory)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .background(AppPalette.paperBright)
    }
}

struct InviteView: View {
    @State private var isShowingShareSheet = false

    var body: some View {
        ScrollPage {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite")
                        .font(AppType.hero)
                    Text("Bring someone into the shoot so you can plan, pose, and save the moment together.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                        .lineSpacing(3)
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        PhotographerAvatar(assetName: "ArchesWalk", name: "Guest")
                            .frame(width: 54, height: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share your blooming moments")
                                .font(AppType.profileSection)
                            Text("Send an invite link to friends, loved ones, or anyone you want to keep close to the memory.")
                                .font(AppType.caption)
                                .foregroundStyle(AppPalette.ivory.opacity(0.60))
                        }
                    }

                    PrimaryButton(title: "Send Invite", icon: "person.badge.plus") {
                        isShowingShareSheet = true
                    }
                }
                .padding(18)
                .background(AppPalette.paperBright, in: RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                        .stroke(AppPalette.hairline, lineWidth: 1)
                }
            }
        }
        .background(AppPalette.ink.ignoresSafeArea())
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: [
                "Share your blooming moments with friends on AI Photographer.",
                URL(string: "https://aiphotographer.local/invite/blooming-moments")!
            ])
            .presentationDetents([.medium, .large])
        }
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
    let savedMoments: [SavedBloomingMoment]
    let avatarAsset: String

    private var momentGroups: [(sceneTitle: String, moments: [SavedBloomingMoment])] {
        Dictionary(grouping: savedMoments, by: \.sceneTitle)
            .map { (sceneTitle: $0.key, moments: $0.value) }
            .sorted { $0.sceneTitle < $1.sceneTitle }
    }

    var body: some View {
        ScrollPage {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    PhotographerAvatar(assetName: avatarAsset, name: "Ann Li")
                        .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ann Li")
                            .font(AppType.profileName)
                        Text("Treasured moments, campus light, saved recipes")
                            .font(AppType.caption)
                            .foregroundStyle(AppPalette.ivory.opacity(0.60))
                    }
                }
                .padding(.top, 22)

                ProfileSection(title: "My Blooming Moments") {
                    if momentGroups.isEmpty {
                        EmptyProfileState(
                            icon: "photo.on.rectangle",
                            title: "No blooming moments yet",
                            subtitle: "Saved fine-tuned photos will appear here by themed scene."
                        )
                    } else {
                        VStack(spacing: 16) {
                            ForEach(momentGroups, id: \.sceneTitle) { group in
                                ProfileMomentSceneGroup(
                                    sceneTitle: group.sceneTitle,
                                    moments: group.moments
                                )
                            }
                        }
                    }
                }

                ProfileSection(title: "Favorite Curated Portfolios") {
                    if savedPortfolios.isEmpty {
                        EmptyProfileState(
                            icon: "bookmark",
                            title: "No favorite portfolios yet",
                            subtitle: "Bookmark a photographer's portfolio to keep it here."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(savedPortfolios) { portfolio in
                                SavedPortfolioRow(portfolio: portfolio)
                            }
                        }
                    }
                }
            }
        }
        .background(AppPalette.ink.ignoresSafeArea())
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
        Image(moment.assetName)
            .resizable()
            .scaledToFill()
            .saturation(moment.isFineTuned ? 1.06 : 1)
            .contrast(moment.isFineTuned ? 1.10 : 1)
            .brightness(moment.isFineTuned ? 0.025 : 0)
            .frame(height: 108)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppChrome.radiusSmall, style: .continuous)
                    .stroke(AppPalette.hairline, lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if moment.isFineTuned {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppPalette.buttonText)
                        .padding(5)
                        .background(AppPalette.gold, in: Circle())
                        .padding(6)
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
        .padding(.top, 10)
        .padding(.bottom, 12)
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
    let assetName: String

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = proxy.size.width / 2
            HStack(spacing: 0) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: panelWidth, height: proxy.size.height)
                    .overlay(.black.opacity(0.24))
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text("before")
                            .font(.system(size: 11, weight: .heavy))
                            .padding(8)
                    }
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: panelWidth, height: proxy.size.height)
                    .saturation(1.06)
                    .contrast(1.12)
                    .brightness(0.03)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text("after")
                            .font(.system(size: 11, weight: .heavy))
                            .padding(8)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous))
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
                .frame(width: 46, height: 46)
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

extension View {
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

struct BloomingHomeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let headerHeight = min(350, proxy.size.height * 0.40)

            ZStack(alignment: .top) {
                AppPalette.ink

                Image("BloomingHeaderBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: headerHeight)
                    .clipped()

                Rectangle()
                    .fill(AppPalette.ink)
                    .frame(height: proxy.size.height * 0.66)
                    .offset(y: headerHeight)
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
    static let welcomeHero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 42)
    static let homeHero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 36)
    static let wordmark = Font.custom("SnellRoundhand", size: 25)
    static let hero = Font.custom("BodoniSvtyTwoITCTT-Book", size: 38)
    static let screenTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 34)
    static let sectionTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 27)
    static let cardTitle = Font.custom("BodoniSvtyTwoITCTT-Book", size: 27)
    static let sceneTitle = Font.custom("BodoniSvtyTwoSCITCTT-Book", size: 31)
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
