import Foundation

struct DemoScenarioManifest: Codable {
    let scenario: String
    let originalSceneImagePath: String
    let guidanceJSONPath: String
    let guidedCaptureImagePath: String
    let editedImagePath: String
    let readinessState: String
    let readinessScore: Int
}

struct DemoManifest: Codable {
    let generatedAt: Date
    let portfolioId: String
    let notes: [String]
    let scenarios: [DemoScenarioManifest]
}

enum DemoError: Error {
    case missingArgument(String)
}

enum BackendDemoMain {
    static func run() throws {
        let arguments = CommandLine.arguments
        let scenePath = try argumentValue("--scene", in: arguments)
        let outputPath = try argumentValue("--out", in: arguments)

        let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
        let sessionsURL = outputURL.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)

        let backend = GuidedCaptureBackend.preview(
            persistence: JSONCaptureSessionStore(baseURL: sessionsURL)
        )

        let scenarios: [(SubjectProfileInput, String)] = [
            (
                SubjectProfileInput(
                    scenario: .single,
                    subjectCount: 1,
                    ageMix: "adult",
                    mobilityNotes: ["full standing mobility"]
                ),
                "single-person"
            ),
            (
                SubjectProfileInput(
                    scenario: .family,
                    subjectCount: 4,
                    ageMix: "two adults, two children",
                    mobilityNotes: ["keep children near front edge", "avoid kneeling"]
                ),
                "family-group"
            )
        ]

        var manifestEntries: [DemoScenarioManifest] = []

        for (profile, slug) in scenarios {
            print("Running scenario: \(slug)")
            let scenarioDir = outputURL.appendingPathComponent(slug, isDirectory: true)
            try FileManager.default.createDirectory(at: scenarioDir, withIntermediateDirectories: true)

            let originalSceneTarget = scenarioDir.appendingPathComponent("A-original-scene.jpg")
            try copyReplacingItem(from: URL(fileURLWithPath: scenePath), to: originalSceneTarget)

            let request = GuidanceRequest(
                portfolioId: backend.portfolio.id,
                subjectProfile: profile,
                scene: SceneUpload(
                    id: UUID(),
                    kind: .scenePhoto,
                    localImagePath: originalSceneTarget.path,
                    referenceVideoPath: nil,
                    title: "Stanford sandstone arcade, late afternoon",
                    locationHint: "Stanford campus arcade near Main Quad, warm west light"
                )
            )

            let response = try backend.buildGuidance(request: request)
            let guidanceURL = scenarioDir.appendingPathComponent("guidance-response.json")
            try DemoArtifactStore.saveJSON(response, to: guidanceURL)
            print("Saved guidance: \(guidanceURL.path)")

            let guidedURL = scenarioDir.appendingPathComponent("B-guided-capture.png")
            let editedURL = scenarioDir.appendingPathComponent("C-post-capture-edit.png")

            let session = CaptureSessionRecord(
                id: UUID(),
                response: response,
                guidedImagePath: guidedURL.path,
                editedImagePath: editedURL.path,
                notes: [
                    "A is a generated Stanford-like scene distinct from the bundled portfolio references.",
                    "B is a simulated guided capture overlay artifact.",
                    "C is a real tone/color edit applied to B by the local artifact renderer."
                ]
            )
            try backend.persistSession(session)

            manifestEntries.append(
                DemoScenarioManifest(
                    scenario: slug,
                    originalSceneImagePath: originalSceneTarget.path,
                    guidanceJSONPath: guidanceURL.path,
                    guidedCaptureImagePath: guidedURL.path,
                    editedImagePath: editedURL.path,
                    readinessState: response.readiness.state.rawValue,
                    readinessScore: response.readiness.score
                )
            )
        }

        let manifest = DemoManifest(
            generatedAt: Date(),
            portfolioId: backend.portfolio.id,
            notes: [
                "Original scene is photorealistic generated input A.",
                "Guided capture B is an annotated local simulation, not a person-inserted generation.",
                "Post-capture edit C is a deterministic filter pass applied to B."
            ],
            scenarios: manifestEntries
        )
        try DemoArtifactStore.saveJSON(manifest, to: outputURL.appendingPathComponent("demo-manifest.json"))
        print("Saved manifest.")
    }

    private static func argumentValue(_ flag: String, in arguments: [String]) throws -> String {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            throw DemoError.missingArgument(flag)
        }
        return arguments[index + 1]
    }

    private static func copyReplacingItem(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

try BackendDemoMain.run()
