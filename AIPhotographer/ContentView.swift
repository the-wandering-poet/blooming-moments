import SwiftUI

enum AppStep {
    case styleSelect
    case subjectCalibration
    case sceneChoice
    case scanSurroundings
    case currentScene
    case liveCoach
    case captureProcessing
    case preview
    case saved
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

struct KeeperSignal {
    let styleId: String
    let recipeAuthor: String
    let sceneInputMethod: SceneInputMethod
    let savedPhotoCount: Int
}

struct ContentView: View {
    private let style = PhotographyStyle(
        id: "campus_editorial_graduation",
        title: "Campus Editorial Graduation",
        author: "Ann Li",
        assets: ["HooverTower", "ArchesWalk", "StripedLight"],
        tags: ["landmark", "motion", "dramatic light"]
    )

    @State private var step: AppStep = .styleSelect
    @State private var subjectProfile: SubjectProfile?
    @State private var sceneInputMethod: SceneInputMethod = .scanSurroundings
    @State private var sceneCandidate = SceneCandidate(
        title: "South arcade, late side light",
        reason: "Clean background, side light, enough depth.",
        score: 91,
        assetName: "ArchesWalk"
    )
    @State private var isReadyToCapture = false
    @State private var selectedKeepers: Set<Int> = [0]
    @State private var feedbackPositive: Bool?

    private let captureResult = CaptureSessionResult(
        finishingLook: "Editorial Warm Contrast",
        candidateAssets: ["HooverTower", "ArchesWalk", "StripedLight"]
    )

    var body: some View {
        ZStack {
            MemoryBackdrop()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(AppPalette.ivory)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: step)
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .styleSelect:
            StyleSelectView(style: style) {
                step = .subjectCalibration
            }
        case .subjectCalibration:
            SubjectCalibrationView(profile: subjectProfile) {
                subjectProfile = SubjectProfile(
                    count: 2,
                    readinessNotes: ["faces found", "full body optional", "matching skin highlights"]
                )
            } continueAction: {
                step = .sceneChoice
            } backAction: {
                step = .styleSelect
            }
        case .sceneChoice:
            SceneChoiceView(
                scanAction: {
                    sceneInputMethod = .scanSurroundings
                    sceneCandidate = SceneCandidate(
                        title: "South arcade, late side light",
                        reason: "Clean background, side light, enough depth.",
                        score: 91,
                        assetName: "ArchesWalk"
                    )
                    step = .scanSurroundings
                },
                currentAction: {
                    sceneInputMethod = .currentScene
                    sceneCandidate = SceneCandidate(
                        title: "Library wall, stripe light",
                        reason: "Strong directional light with a quiet background.",
                        score: 84,
                        assetName: "StripedLight"
                    )
                    step = .currentScene
                },
                backAction: {
                    step = .subjectCalibration
                }
            )
        case .scanSurroundings:
            ScanSurroundingsView(candidate: sceneCandidate) {
                step = .liveCoach
            } backAction: {
                step = .sceneChoice
            }
        case .currentScene:
            CurrentSceneView(candidate: sceneCandidate) {
                step = .liveCoach
            } backAction: {
                step = .sceneChoice
            }
        case .liveCoach:
            LiveCoachingView(
                candidate: sceneCandidate,
                isReady: isReadyToCapture,
                runReadiness: {
                    isReadyToCapture = true
                },
                captureAction: {
                    step = .captureProcessing
                },
                backAction: {
                    isReadyToCapture = false
                    step = sceneInputMethod == .scanSurroundings ? .scanSurroundings : .currentScene
                }
            )
        case .captureProcessing:
            CaptureProcessingView {
                step = .preview
            }
        case .preview:
            PreviewKeeperView(
                result: captureResult,
                selectedKeepers: $selectedKeepers,
                saveAction: {
                    step = .saved
                },
                retakeAction: {
                    isReadyToCapture = false
                    step = .liveCoach
                },
                rescoutAction: {
                    isReadyToCapture = false
                    step = .sceneChoice
                }
            )
        case .saved:
            SavedFeedbackView(
                signal: KeeperSignal(
                    styleId: style.id,
                    recipeAuthor: style.author,
                    sceneInputMethod: sceneInputMethod,
                    savedPhotoCount: selectedKeepers.count
                ),
                feedbackPositive: $feedbackPositive,
                doneAction: {
                    feedbackPositive = nil
                    selectedKeepers = [0]
                    isReadyToCapture = false
                    step = .styleSelect
                }
            )
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

struct SubjectCalibrationView: View {
    let profile: SubjectProfile?
    let captureAction: () -> Void
    let continueAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        ScreenScaffold(
            title: "Subject reference",
            subtitle: "Capture everyone once so the app can judge scale, pose readiness, and faces during the shoot.",
            backAction: backAction
        ) {
            VStack(spacing: 18) {
                Button(action: captureAction) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                            .fill(AppPalette.mistBlue.opacity(0.52))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                                    .stroke(AppPalette.hairline, lineWidth: 1)
                            }
                        VStack(spacing: 18) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                                    .fill(AppPalette.paper)
                                    .frame(width: 132, height: 162)
                                    .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
                                VStack(spacing: 12) {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .stroke(AppPalette.ivory.opacity(0.36), lineWidth: 1)
                                            .frame(width: 11, height: 11)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(AppPalette.ivory.opacity(0.12))
                                            .frame(width: 48, height: 4)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)

                                    Image(systemName: profile == nil ? "person.crop.rectangle.stack" : "checkmark.seal.fill")
                                        .font(.system(size: 42, weight: .semibold))
                                        .foregroundStyle(profile == nil ? AppPalette.ivory.opacity(0.50) : AppPalette.gold)

                                    Text(profile == nil ? "REFERENCE" : "READY")
                                        .font(AppType.micro)
                                        .kerning(2.4)
                                        .foregroundStyle(AppPalette.gold)
                                }
                                .frame(width: 132, height: 162)
                            }
                            Text(profile == nil ? "Add subject reference" : "Subjects detected")
                                .font(AppType.sectionTitle)
                            Text(profile == nil ? "The app uses this to judge pose readiness and composition scale during the shoot." : "Two people are ready for framing, light, and pose cues.")
                                .font(AppType.body)
                                .foregroundStyle(AppPalette.ivory.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal)
                            Label(profile == nil ? "Capture Subject Photo" : "Retake Reference", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .buttonStyleLabel()
                        }
                        .padding(24)
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 360)
                .accessibilityLabel(profile == nil ? "Capture subject reference" : "Retake subject reference")

                if let profile {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("\(profile.count) subjects", systemImage: "person.2.fill")
                            Spacer()
                            Text("READY")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(AppPalette.gold)
                        }
                        .font(.system(size: 14, weight: .semibold))

                        WrapChips(items: profile.readinessNotes)
                    }
                    .padding(16)
                    .background(AppPalette.graphite, in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous)
                            .stroke(AppPalette.hairline, lineWidth: 1)
                    }
                }
            }
        } footer: {
            PrimaryButton(
                title: profile == nil ? "Capture Subject Photo" : "Choose Scene",
                icon: profile == nil ? "camera.fill" : "arrow.right",
                action: profile == nil ? captureAction : continueAction
            )
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
    @State private var scanPass = 1

    var body: some View {
        ScreenScaffold(
            title: "Scan surroundings",
            subtitle: "Pan slowly for a few seconds. The prototype simulates scene analysis from your video.",
            backAction: backAction
        ) {
            VStack(spacing: 16) {
                CameraMockView(assetName: "ArchesWalk", mode: "SCANNING", showGuides: false)
                    .frame(height: 270)

                FrameRail()

                Button {
                    scanPass += 1
                } label: {
                    Label(scanPass == 1 ? "Rescan Area" : "Scan Pass \(scanPass)", systemImage: "arrow.triangle.2.circlepath.camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                AnalysisGrid(items: [
                    ("Light", scanPass == 1 ? "side warm" : "clean side", scanPass == 1 ? 91 : 93),
                    ("Depth", "strong", scanPass == 1 ? 86 : 88),
                    ("Clutter", "low", scanPass == 1 ? 78 : 82),
                    ("Landmark", "arches", scanPass == 1 ? 88 : 90)
                ])

                OptimalSceneCard(candidate: candidate)
            }
        } footer: {
            PrimaryButton(title: "Go Shoot Here", icon: "location.fill", action: continueAction)
        }
    }
}

struct CurrentSceneView: View {
    let candidate: SceneCandidate
    let continueAction: () -> Void
    let backAction: () -> Void
    @State private var retakeCount = 0

    var body: some View {
        ScreenScaffold(
            title: "Current scene",
            subtitle: "Analyze this frame and mark where the subjects should stand.",
            backAction: backAction
        ) {
            VStack(spacing: 16) {
                SceneAnalysisImage(assetName: candidate.assetName)
                    .frame(height: 340)

                Button {
                    retakeCount += 1
                } label: {
                    Label(retakeCount == 0 ? "Retake Scene Photo" : "Scene Photo Updated", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                HStack(spacing: 10) {
                    StatusBadge(title: "Shoot here", icon: "checkmark.circle.fill", color: AppPalette.gold)
                    StatusBadge(title: "Face light", icon: "sun.max.fill", color: AppPalette.ivory.opacity(0.86))
                    StatusBadge(title: "Low clutter", icon: "sparkles", color: AppPalette.ivory.opacity(0.86))
                }

                Text(candidate.reason)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppPalette.ivory.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } footer: {
            PrimaryButton(title: "Start Live Coaching", icon: "camera.fill", action: continueAction)
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

struct CaptureProcessingView: View {
    let continueAction: () -> Void

    var body: some View {
        FixedFooterPage {
            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppChrome.radiusLarge, style: .continuous)
                        .fill(AppPalette.mistBlue.opacity(0.52))
                        .frame(height: 360)
                    ZStack {
                        Circle()
                            .stroke(AppPalette.paper.opacity(0.72), lineWidth: 12)
                            .frame(width: 168, height: 168)
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(AppPalette.gold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 168, height: 168)
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(AppPalette.ivory)
                    }
                    .symbolEffect(.pulse)
                }

                VStack(spacing: 8) {
                    Text("Selecting best frame")
                        .font(AppType.screenTitle)
                    Text("Checking faces, gesture, blur, and highlight detail.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.66))
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: "View Best Frames", icon: "photo.stack.fill", action: continueAction)
        }
    }
}

struct PreviewKeeperView: View {
    let result: CaptureSessionResult
    @Binding var selectedKeepers: Set<Int>
    let saveAction: () -> Void
    let retakeAction: () -> Void
    let rescoutAction: () -> Void

    var body: some View {
        FixedFooterPage {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose keepers")
                        .font(AppType.screenTitle)
                    Text(result.finishingLook)
                        .font(AppType.caption)
                        .foregroundStyle(AppPalette.gold)
                }
                .padding(.top, 24)

                BeforeAfterView(assetName: result.candidateAssets[0])
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Best frames")
                        .font(AppType.cardTitle)
                    KeeperCardRow(
                        assets: result.candidateAssets,
                        selectedKeepers: $selectedKeepers
                    )
                }

                HStack(spacing: 10) {
                    Button("Retake", action: retakeAction)
                        .buttonStyle(SecondaryTextButtonStyle())
                    Button("Try Another Scene", action: rescoutAction)
                        .buttonStyle(SecondaryTextButtonStyle())
                }
            }
        } footer: {
            PrimaryButton(title: "Save Selected", icon: "square.and.arrow.down.fill", action: saveAction)
                .disabled(selectedKeepers.isEmpty)
                .opacity(selectedKeepers.isEmpty ? 0.48 : 1)
        }
    }
}

struct SavedFeedbackView: View {
    let signal: KeeperSignal
    @Binding var feedbackPositive: Bool?
    let doneAction: () -> Void

    var body: some View {
        FixedFooterPage {
            VStack(spacing: 22) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 82, weight: .semibold))
                    .foregroundStyle(AppPalette.gold)

                VStack(spacing: 8) {
                    Text("Saved")
                        .font(AppType.hero)
                    Text("Keeper signal logged locally for the recipe.")
                        .font(AppType.body)
                        .foregroundStyle(AppPalette.ivory.opacity(0.68))
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    SignalRow(label: "style id", value: signal.styleId)
                    SignalRow(label: "recipe author", value: signal.recipeAuthor)
                    SignalRow(label: "scene path", value: signal.sceneInputMethod.rawValue)
                    SignalRow(label: "saved count", value: "\(signal.savedPhotoCount)")
                }
                .padding(16)
                .surfaceCard()

                HStack(spacing: 12) {
                    FeedbackButton(icon: "hand.thumbsup.fill", isSelected: feedbackPositive == true) {
                        feedbackPositive = true
                    }
                    FeedbackButton(icon: "hand.thumbsdown.fill", isSelected: feedbackPositive == false) {
                        feedbackPositive = false
                    }
                }
            }
            .padding(.top, 28)
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: "Done", icon: "sparkles", action: doneAction)
        }
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
        HStack(spacing: 8) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 14, weight: .bold))
            Text("AI Photographer")
                .font(.system(size: 15, weight: .heavy, design: .default))
        }
        .foregroundStyle(AppPalette.gold)
        .accessibilityElement(children: .combine)
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

struct SignalRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppType.micro)
                .kerning(1.8)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.ivory.opacity(0.52))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct FeedbackButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .frame(width: 58, height: 52)
                .background(isSelected ? AppPalette.gold : AppPalette.panel, in: RoundedRectangle(cornerRadius: AppChrome.radius, style: .continuous))
                .foregroundStyle(isSelected ? AppPalette.buttonText : AppPalette.ivory)
        }
        .buttonStyle(.plain)
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
                    .frame(height: 320)
                    .ignoresSafeArea()
            }
    }
}

enum AppType {
    static let hero = Font.custom("Didot", size: 36)
    static let screenTitle = Font.custom("Didot", size: 32)
    static let sectionTitle = Font.custom("Didot", size: 26)
    static let cardTitle = Font.custom("Didot", size: 27)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .medium, design: .default)
    static let chip = Font.system(size: 12, weight: .semibold, design: .default)
    static let micro = Font.system(size: 10, weight: .semibold, design: .default)
}

enum AppChrome {
    static let radiusSmall: CGFloat = 8
    static let radius: CGFloat = 13
    static let radiusLarge: CGFloat = 18
}

enum AppPalette {
    static let ink = Color(red: 0.955, green: 0.946, blue: 0.926)
    static let backdropMid = Color(red: 0.640, green: 0.748, blue: 0.790)
    static let mistBlue = Color(red: 0.610, green: 0.720, blue: 0.765)
    static let graphite = Color(red: 0.878, green: 0.858, blue: 0.820)
    static let panel = Color(red: 0.982, green: 0.972, blue: 0.952)
    static let panelStrong = Color(red: 0.910, green: 0.898, blue: 0.866)
    static let paper = Color(red: 0.992, green: 0.986, blue: 0.972)
    static let cameraPanel = Color(red: 0.982, green: 0.972, blue: 0.952).opacity(0.92)
    static let ivory = Color(red: 0.210, green: 0.216, blue: 0.195)
    static let gold = Color(red: 0.420, green: 0.462, blue: 0.320)
    static let buttonText = Color(red: 0.992, green: 0.986, blue: 0.972)
    static let hairline = Color.black.opacity(0.10)
}
