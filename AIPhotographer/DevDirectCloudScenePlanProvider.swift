import Foundation

enum DevDirectCloudScenePlanError: Error, LocalizedError {
    case noCloudCredentials
    case sceneInputRecordMissing(String)
    case invalidResponse(String)
    case allProvidersFailed([String])

    var errorDescription: String? {
        switch self {
        case .noCloudCredentials:
            return "No DigitalOcean or Gemini API key was found in the Xcode Run environment."
        case let .sceneInputRecordMissing(sceneAnalysisId):
            return "No scene input record was found for \(sceneAnalysisId)."
        case let .invalidResponse(message):
            return message
        case let .allProvidersFailed(errors):
            return "All cloud providers failed: \(errors.joined(separator: " | "))"
        }
    }
}

struct DevDirectCloudScenePlanProvider: ScenePlanGenerationProvider {
    let repository: SceneRuntimeRepository
    let environment: [String: String]
    let session: URLSession

    init(
        repository: SceneRuntimeRepository,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        session: URLSession = .shared
    ) {
        self.repository = repository
        self.environment = environment
        self.session = session
    }

    static func isConfigured(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        hasValue(environment["DIGITALOCEAN_MODEL_ACCESS_KEY"]) || hasValue(environment["GEMINI_API_KEY"])
    }

    func generateScenePlan(
        _ request: SceneRuntimeModels.GenerateScenePlanRequest,
        schemaVersion: String
    ) async throws -> SceneRuntimeModels.GenerateScenePlanResponse {
        try SceneRuntimeServiceSchema.validate(schemaVersion, operation: .generateScenePlan)
        try SceneRuntimeRequestValidator.validate(request)

        guard Self.isConfigured(environment: environment) else {
            throw DevDirectCloudScenePlanError.noCloudCredentials
        }
        let sceneInput = try await sceneInputRecord(for: request)
        let prompt = Self.prompt(request: request, sceneInput: sceneInput)
        var failures: [String] = []

        if let digitalOceanKey = nonEmpty(environment["DIGITALOCEAN_MODEL_ACCESS_KEY"]) {
            do {
                let router = nonEmpty(environment["DIGITALOCEAN_ROUTER_OVERRIDE"]) ?? "router:general"
                let baseURL = nonEmpty(environment["DIGITALOCEAN_INFERENCE_BASE_URL"]) ?? "https://inference.do-ai.run/v1"
                let content = try await requestOpenAICompatibleChatCompletion(
                    baseURL: baseURL,
                    bearerToken: digitalOceanKey,
                    model: router,
                    prompt: prompt
                )
                return try Self.scenePlan(
                    from: content,
                    request: request,
                    provider: "digitalocean_inference_router",
                    modelId: router,
                    evidence: sceneInput.mediaRefs.joined(separator: ", ")
                )
            } catch {
                failures.append("DigitalOcean: \(error.localizedDescription)")
            }
        }

        if let geminiKey = nonEmpty(environment["GEMINI_API_KEY"]) {
            let models = Self.geminiModels(environment: environment)
            for model in models {
                do {
                    let content = try await requestGeminiGenerateContent(
                        apiKey: geminiKey,
                        model: model,
                        prompt: prompt
                    )
                    return try Self.scenePlan(
                        from: content,
                        request: request,
                        provider: "gemini",
                        modelId: model,
                        evidence: sceneInput.mediaRefs.joined(separator: ", ")
                    )
                } catch {
                    failures.append("Gemini \(model): \(error.localizedDescription)")
                }
            }
        }

        throw DevDirectCloudScenePlanError.allProvidersFailed(failures)
    }

    private func sceneInputRecord(
        for request: SceneRuntimeModels.GenerateScenePlanRequest
    ) async throws -> SceneInputIngestionRecord {
        let attemptId = request.sceneAnalysisId.replacingOccurrences(of: "scene_analysis_", with: "")
        if let record = await repository.sceneInputRecord(attemptId: attemptId) {
            return record
        }
        if let record = await repository.sceneInputRecords().first(where: { $0.sceneAnalysisId == request.sceneAnalysisId }) {
            return record
        }
        throw DevDirectCloudScenePlanError.sceneInputRecordMissing(request.sceneAnalysisId)
    }
}

private extension DevDirectCloudScenePlanProvider {
    struct OpenAIChatRequest: Encodable {
        let model: String
        let messages: [OpenAIChatMessage]
        let temperature: Double
        let responseFormat: OpenAIResponseFormat

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case responseFormat = "response_format"
        }
    }

    struct OpenAIChatMessage: Encodable {
        let role: String
        let content: String
    }

    struct OpenAIResponseFormat: Encodable {
        let type: String
    }

    struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    struct GeminiRequest: Encodable {
        struct Content: Encodable {
            struct Part: Encodable {
                let text: String
            }

            let parts: [Part]
        }

        let contents: [Content]
    }

    struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }

                let parts: [Part]
            }

            let content: Content
        }

        let candidates: [Candidate]?
    }

    struct CloudScenePlanPayload: Decodable {
        struct Cue: Decodable {
            let target: String
            let message: String
        }

        struct Camera: Decodable {
            let exposureBias: Double?
            let whiteBalanceTemperatureBias: String?
            let preferredLens: String?
            let targetZoomFactor: Double?
            let depthMode: String?
            let portraitBlurStrength: Double?
            let burstCount: Int?
            let shootWide: Bool?
            let orientation: String?
        }

        let standPointLabel: String
        let standPointDescription: String
        let subjectZone: String
        let subjectDistanceCue: String
        let operatorDistanceCue: String
        let operatorHeightCue: String
        let operatorFramingCue: String
        let subjectFacingCue: String
        let operatorFacingCue: String
        let roughFramingStyle: String
        let roughFramingSafetyMargin: String
        let roughFramingOrientation: String
        let coachingCues: [Cue]
        let affordances: [String]
        let fineTuneSignals: [String]
        let camera: Camera?
        let confidence: Double?
    }

    func requestOpenAICompatibleChatCompletion(
        baseURL: String,
        bearerToken: String,
        model: String,
        prompt: String
    ) async throws -> String {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmedBaseURL)/chat/completions") else {
            throw DevDirectCloudScenePlanError.invalidResponse("Invalid DigitalOcean base URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIChatMessage(
                    role: "system",
                    content: "You are Blooming Moments scene-planning backend. Return only strict JSON matching the requested schema."
                ),
                OpenAIChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.2,
            responseFormat: OpenAIResponseFormat(type: "json_object")
        ))

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw DevDirectCloudScenePlanError.invalidResponse("DigitalOcean response had no message content.")
        }
        return content
    }

    func requestGeminiGenerateContent(
        apiKey: String,
        model: String,
        prompt: String
    ) async throws -> String {
        let escapedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent?key=\(apiKey)") else {
            throw DevDirectCloudScenePlanError.invalidResponse("Invalid Gemini URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GeminiRequest(contents: [
            GeminiRequest.Content(parts: [
                GeminiRequest.Content.Part(
                    text: "Return only strict JSON matching the requested schema.\n\n\(prompt)"
                )
            ])
        ]))

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let text = decoded.candidates?.first?.content.parts.compactMap(\.text).joined(separator: "\n")
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DevDirectCloudScenePlanError.invalidResponse("Gemini response had no text content.")
        }
        return text
    }

    func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DevDirectCloudScenePlanError.invalidResponse("Cloud provider returned a non-HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw DevDirectCloudScenePlanError.invalidResponse("HTTP \(http.statusCode): \(body.prefix(500))")
        }
    }

    static func prompt(
        request: SceneRuntimeModels.GenerateScenePlanRequest,
        sceneInput: SceneInputIngestionRecord
    ) -> String {
        """
        Create a scene plan for Blooming Moments.

        Inputs:
        - styleProfileId: \(request.styleProfileId)
        - protectedSubjectSetId: \(request.protectedSubjectSetId)
        - sceneInputMode: \(sceneInput.sceneInputMode.rawValue)
        - mediaRefs: \(sceneInput.mediaRefs.joined(separator: ", "))
        - sceneInputStatus: \(request.sceneInputQualityContext.sceneInputStatus.rawValue)
        - qualitySignals: \(qualitySignalsDescription(request.sceneInputQualityContext.qualitySignals))

        Product logic:
        - Prefer subject placement based on usable face light first, gesture second.
        - Give concrete but safe guidance for where subjects should stand/sit/lean/move.
        - Keep portfolio style as a tendency, not an exact copied shot.
        - Return camera intent in iPhone-friendly terms: focus on protected subjects, exposure bias, white balance, lens/zoom, depth, burst, framing.
        - This is a dev-direct phone-test path. If image bytes are not available, reason from the scene/media ref labels and quality signals, and be explicit but practical.

        Return only JSON with this exact shape:
        {
          "standPointLabel": "short label",
          "standPointDescription": "where the subject should go and why",
          "subjectZone": "stable snake_case zone",
          "subjectDistanceCue": "subject distance/placement cue",
          "operatorDistanceCue": "operator distance cue",
          "operatorHeightCue": "operator height cue",
          "operatorFramingCue": "operator framing cue",
          "subjectFacingCue": "subject/body/pose cue",
          "operatorFacingCue": "where phone should face",
          "roughFramingStyle": "wide_environmental|medium_portrait|close_detail",
          "roughFramingSafetyMargin": "low|medium|high",
          "roughFramingOrientation": "vertical|horizontal",
          "coachingCues": [
            {"target": "operator", "message": "short cue"},
            {"target": "subjects", "message": "short cue"}
          ],
          "affordances": ["soft_side_light", "architectural_anchor", "crop_headroom_available"],
          "fineTuneSignals": ["portfolio_color_tone", "crop_composition"],
          "camera": {
            "exposureBias": -0.2,
            "whiteBalanceTemperatureBias": "warm",
            "preferredLens": "wide",
            "targetZoomFactor": 1.0,
            "depthMode": "environmental_depth",
            "portraitBlurStrength": 0.2,
            "burstCount": 8,
            "shootWide": true,
            "orientation": "vertical"
          },
          "confidence": 0.0
        }
        """
    }

    static func scenePlan(
        from content: String,
        request: SceneRuntimeModels.GenerateScenePlanRequest,
        provider: String,
        modelId: String,
        evidence: String
    ) throws -> SceneRuntimeModels.GenerateScenePlanResponse {
        let data = try strictJSONData(from: content)
        let payload = try JSONDecoder().decode(CloudScenePlanPayload.self, from: data)
        let affordances = payload.affordances
            .compactMap(SceneRuntimeModels.RuntimeAffordanceSignalType.init(rawValue:))
        let fineTuneSignals = payload.fineTuneSignals
            .compactMap(SceneRuntimeModels.PostCaptureFineTuneSignal.init(rawValue:))
        let camera = payload.camera
        let scenePlanId = "scene_plan_\(request.sceneAnalysisId.replacingOccurrences(of: "scene_analysis_", with: ""))"
        let providerEvidence = "\(provider):\(modelId); \(evidence)"
        let confidence = max(0, min(1, payload.confidence ?? 0.72))

        return SceneRuntimeModels.GenerateScenePlanResponse(
            scenePlanId: scenePlanId,
            sceneAnalysisId: request.sceneAnalysisId,
            styleProfileId: request.styleProfileId,
            protectedSubjectSetId: request.protectedSubjectSetId,
            sceneInputQualityContext: request.sceneInputQualityContext,
            sceneMatchType: request.sceneInputQualityContext.allowsSuboptimalSceneInput ? .bestEffortFallback : .styleSynthesis,
            professionalHappyMomentAssessment: SceneRuntimeModels.ProfessionalHappyMomentAssessment(
                faceLightUsable: true,
                naturalExpressionOpportunity: true,
                relationshipInteractionOpportunity: true,
                protectedSubjectFocusFeasible: true,
                cropHeadroomFeasible: true,
                unrecoverableRisks: nil
            ),
            runtimeAffordanceSignals: (affordances.isEmpty ? defaultAffordances() : affordances).map {
                SceneRuntimeModels.RuntimeAffordanceSignal(
                    type: $0,
                    confidence: confidence,
                    recommendedUse: "protect_during_phone_test_capture",
                    evidence: providerEvidence
                )
            },
            postCapturePrerequisites: postCapturePrerequisites(
                fineTuneSignals: fineTuneSignals
            ),
            postCaptureFineTuneSignals: fineTuneSignals.isEmpty ? defaultFineTuneSignals() : fineTuneSignals,
            standPoint: SceneRuntimeModels.LabeledDescription(
                label: payload.standPointLabel,
                description: payload.standPointDescription
            ),
            subjectPosition: SceneRuntimeModels.SubjectPosition(
                zone: payload.subjectZone,
                distanceCue: payload.subjectDistanceCue
            ),
            operatorPosition: SceneRuntimeModels.OperatorPosition(
                distanceCue: payload.operatorDistanceCue,
                heightCue: payload.operatorHeightCue,
                framingCue: payload.operatorFramingCue
            ),
            facingDirection: SceneRuntimeModels.FacingDirection(
                subjectCue: payload.subjectFacingCue,
                operatorCue: payload.operatorFacingCue
            ),
            roughFraming: SceneRuntimeModels.RoughFraming(
                style: payload.roughFramingStyle,
                safetyMargin: payload.roughFramingSafetyMargin,
                orientation: payload.roughFramingOrientation
            ),
            coachingCues: cloudSourceCue(provider: provider, modelId: modelId) + payload.coachingCues.prefix(4).map {
                SceneRuntimeModels.CoachingCue(target: $0.target, message: $0.message)
            },
            initialCameraSettingsRecommendation: cameraRecommendation(
                scenePlanId: scenePlanId,
                provider: provider,
                modelId: modelId,
                camera: camera,
                framingStyle: payload.roughFramingStyle,
                orientation: payload.roughFramingOrientation
            ),
            fallback: nil,
            persistenceWriteIntent: ["sceneAnalysis", "scenePlan", "initialCameraSettingsRecommendation", "runtimeAffordanceMetadata"]
        )
    }

    static func strictJSONData(from content: String) throws -> Data {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }
        guard
            let start = trimmed.firstIndex(of: "{"),
            let end = trimmed.lastIndex(of: "}")
        else {
            throw DevDirectCloudScenePlanError.invalidResponse("Cloud response did not contain a JSON object.")
        }
        let json = String(trimmed[start...end])
        guard let data = json.data(using: .utf8) else {
            throw DevDirectCloudScenePlanError.invalidResponse("Cloud response JSON was not UTF-8.")
        }
        _ = try JSONSerialization.jsonObject(with: data)
        return data
    }

    static func cameraRecommendation(
        scenePlanId: String,
        provider: String,
        modelId: String,
        camera: CloudScenePlanPayload.Camera?,
        framingStyle: String,
        orientation: String
    ) -> SceneRuntimeModels.InitialCameraSettingsRecommendation {
        SceneRuntimeModels.InitialCameraSettingsRecommendation(
            recommendationId: "camera_rec_\(scenePlanId.replacingOccurrences(of: "scene_plan_", with: ""))",
            sourceNativeCameraParameterIntentId: "dev_direct_cloud.\(provider).\(modelId)",
            focus: SceneRuntimeModels.FocusRecommendation(
                target: "all_protected_subjects",
                mode: "continuous_then_lock_when_ready",
                priority: "faces_and_bodies",
                focusPointStrategy: "protected_subject_face_group"
            ),
            exposure: SceneRuntimeModels.ExposureRecommendation(
                meteringTarget: "protected_subject_faces",
                bias: camera?.exposureBias ?? -0.15,
                protectHighlights: true,
                avoidFaceClipping: true,
                avoidFaceShadowCrush: true
            ),
            whiteBalance: SceneRuntimeModels.WhiteBalanceRecommendation(
                mode: "auto_then_lock_when_ready",
                lockWhenReady: true,
                temperatureBias: camera?.whiteBalanceTemperatureBias ?? "warm",
                tintBias: "neutral"
            ),
            zoomLens: SceneRuntimeModels.ZoomLensRecommendation(
                preferredLens: camera?.preferredLens ?? "wide",
                targetZoomFactor: camera?.targetZoomFactor ?? 1.0,
                maxDigitalZoomFactor: 2.0,
                allowUltraWideIfOperatorTooClose: true,
                avoidLensSwitchDuringCapture: true
            ),
            depth: SceneRuntimeModels.DepthRecommendation(
                mode: camera?.depthMode ?? "environmental_depth",
                portraitBlurStrength: camera?.portraitBlurStrength ?? 0.2,
                keepArchitecturalAnchorReadable: true,
                depthDataDeliveryPreferred: true,
                portraitEffectsMattePreferred: true
            ),
            framing: SceneRuntimeModels.FramingRecommendation(
                shootWide: camera?.shootWide ?? true,
                safetyMargin: "high",
                orientation: camera?.orientation ?? orientation,
                compositionTarget: framingStyle
            ),
            colorAndTonePreview: SceneRuntimeModels.ColorAndTonePreview(
                contrast: "medium_high",
                saturation: "neutral_warm",
                highlightRecovery: "moderate"
            ),
            capture: SceneRuntimeModels.CaptureRecommendation(
                burstCount: camera?.burstCount ?? 8,
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
                statusValues: [.applied, .adjusted, .unavailable, .needsOperatorAdjustment]
            )
        )
    }

    static func postCapturePrerequisites(
        fineTuneSignals: [SceneRuntimeModels.PostCaptureFineTuneSignal]
    ) -> SceneRuntimeModels.PostCapturePrerequisites {
        SceneRuntimeModels.PostCapturePrerequisites(
            mustCaptureCorrectly: [
                .protectedSubjectsVisible,
                .protectedSubjectFocus,
                .usableFaceLight,
                .naturalExpressionOrInteraction,
                .cropHeadroom
            ],
            canFineTuneLater: fineTuneSignals.isEmpty ? defaultFineTuneSignals() : fineTuneSignals,
            statusAtCapture: nil
        )
    }

    static func defaultAffordances() -> [SceneRuntimeModels.RuntimeAffordanceSignalType] {
        [
            .softSideLight,
            .architecturalAnchor,
            .cropHeadroomAvailable,
            .naturalMotionOpportunity,
            .relationshipInteractionOpportunity
        ]
    }

    static func defaultFineTuneSignals() -> [SceneRuntimeModels.PostCaptureFineTuneSignal] {
        [.portfolioColorTone, .cropComposition, .lightShadowContrast]
    }

    static func cloudSourceCue(provider: String, modelId: String) -> [SceneRuntimeModels.CoachingCue] {
        [
            SceneRuntimeModels.CoachingCue(
                target: "operator",
                message: "Cloud scene plan: \(provider) / \(modelId)."
            )
        ]
    }

    static func geminiModels(environment: [String: String]) -> [String] {
        if let override = nonEmpty(environment["GEMINI_MODEL_OVERRIDE"]) {
            return [override]
        }
        return [
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite"
        ]
    }

    static func qualitySignalsDescription(_ signals: SceneRuntimeModels.SceneInputQualitySignals?) -> String {
        guard let signals else {
            return "none"
        }
        return "tooDark=\(signals.tooDark), overexposed=\(signals.overexposed), motionBlur=\(signals.motionBlur), scanTooShort=\(signals.scanTooShort), noUsefulCompositionSpace=\(signals.noUsefulCompositionSpace), uploadFailed=\(signals.uploadFailed ?? false)"
    }

    static func hasValue(_ value: String?) -> Bool {
        nonEmpty(value) != nil
    }

    static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func nonEmpty(_ value: String?) -> String? {
        Self.nonEmpty(value)
    }
}
