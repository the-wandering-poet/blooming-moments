import Foundation

enum FinalMomentLocalTestPipelineError: Error, Equatable {
    case missingCaptureResult
    case missingAutoCullResult
    case missingKeeperSelection
    case missingCropGenerationResult
    case missingFineTuneResult
    case protectedSubjectSetMismatch
}

final class FinalMomentLocalTestPipelineFacade {
    private let store: FinalMomentLocalTestStore
    private var captureResult: FinalMomentCaptureResult?
    private var frameAssessmentInputs: [FinalMomentFrameAssessmentInput] = []
    private var protectedSubjectGeometry: [FinalMomentProtectedSubjectCropGeometry] = []
    private var autoCullResult: FinalMomentAutoCullResult?
    private var keeperSelection: FinalMomentKeeperSelection?
    private var cropGenerationResult: FinalMomentCropGenerationResult?
    private var fineTuneResult: FinalMomentFineTuneResult?

    init(store: FinalMomentLocalTestStore = FinalMomentLocalTestStore()) {
        self.store = store
    }

    func recordCaptureResult(request: FinalMomentCaptureRequest) throws -> FinalMomentCaptureResult {
        let captureResultId = "capture_result_\(Self.sanitized(request.runtimeHandoff.scenePlanId))"
        let frames = (1...3).map { index in
            FinalMomentFrame(
                frameId: "frame_local_test_\(captureResultId)_\(index)",
                assetRef: Self.asset(
                    "asset_local_test_\(captureResultId)_\(index)",
                    role: .original,
                    width: 3024,
                    height: 4032
                ),
                timestamp: "2026-06-04T16:00:0\(index)Z",
                burstIndex: index,
                cameraSettingsUsed: request.runtimeHandoff.cameraSettingsUsed
            )
        }

        let assessment = FinalMomentProfessionalHappyMomentAssessment(
            protectedSubjectFocusUsable: request.runtimeHandoff.capturedAffordanceMetadata.protectedSubjectFocusReady,
            protectedSubjectFaceLightUsable: request.runtimeHandoff.capturedAffordanceMetadata.faceExposureUsable,
            naturalExpressionOrInteractionPresent: request.runtimeHandoff.capturedAffordanceMetadata.naturalExpressionOrInteractionObserved,
            cropHeadroomPreserved: request.runtimeHandoff.capturedAffordanceMetadata.cropHeadroomPreserved,
            capturedAffordances: request.runtimeHandoff.runtimeAffordanceSignals,
            weakOrMissingPrerequisites: request.runtimeHandoff.capturedAffordanceMetadata.cropHeadroomPreserved ? [] : ["crop_headroom"]
        )
        let intentSnapshot = FinalMomentCameraSettingsIntentSnapshot(
            styleProfileId: request.runtimeHandoff.styleProfileId,
            styleProfileVersion: request.runtimeHandoff.styleProfileVersion,
            nativeCameraParameterIntentVersion: request.runtimeHandoff.nativeCameraParameterIntentVersion,
            initialCameraSettingsRecommendationId: request.runtimeHandoff.initialCameraSettingsRecommendation.recommendationId,
            dynamicCameraSettingsAdjustmentId: request.runtimeHandoff.dynamicCameraSettingsAdjustmentId
        )

        let result = FinalMomentCaptureResult(
            captureResultId: captureResultId,
            sessionId: request.context.sessionId,
            scenarioId: request.context.scenarioId,
            sceneTitle: request.context.sceneTitle,
            sourcePortfolioId: request.context.sourcePortfolioId,
            scenePlanId: request.runtimeHandoff.scenePlanId,
            styleProfileId: request.runtimeHandoff.styleProfileId,
            protectedSubjectSetId: request.runtimeHandoff.protectedSubjectSetId,
            sceneInputQualityContext: request.runtimeHandoff.sceneInputQualityContext,
            initialCameraSettingsRecommendation: request.runtimeHandoff.initialCameraSettingsRecommendation,
            cameraSettingsUsed: request.runtimeHandoff.cameraSettingsUsed,
            runtimeAffordanceSignals: request.runtimeHandoff.runtimeAffordanceSignals,
            postCapturePrerequisites: request.runtimeHandoff.postCapturePrerequisites,
            capturedAffordanceMetadata: request.runtimeHandoff.capturedAffordanceMetadata,
            professionalHappyMomentAssessment: assessment,
            cameraSettingsIntentSnapshot: intentSnapshot,
            assetProvenance: frames.map {
                FinalMomentAssetProvenance(
                    frameId: $0.frameId,
                    originalAssetRef: $0.assetRef,
                    cameraSettingsUsedId: request.runtimeHandoff.cameraSettingsUsed.settingsId,
                    captureResultId: captureResultId
                )
            },
            frames: frames
        )

        try persistCaptureAssets(result)
        captureResult = result
        frameAssessmentInputs = Self.assessmentInputs(for: result)
        protectedSubjectGeometry = Self.safeGeometry(frameIds: result.frames.map(\.frameId))
        autoCullResult = nil
        keeperSelection = nil
        cropGenerationResult = nil
        fineTuneResult = nil
        return result
    }

    func autoCullFrames(_ request: FinalMomentAutoCullRequest) throws -> FinalMomentAutoCullResult {
        guard let captureResult else { throw FinalMomentLocalTestPipelineError.missingCaptureResult }
        guard request.protectedSubjectSetId == captureResult.protectedSubjectSetId else {
            throw FinalMomentLocalTestPipelineError.protectedSubjectSetMismatch
        }
        let result = try FinalMomentAutoCullService(repository: store).autoCull(
            FinalMomentAutoCullServiceRequest(
                autoCullResultId: "auto_cull_\(captureResult.captureResultId)",
                captureResult: captureResult,
                frameAssessmentInputs: frameAssessmentInputs
            )
        )
        autoCullResult = result
        return result
    }

    func createKeeperSelection(_ request: FinalMomentKeeperSelectionRequest) throws -> FinalMomentKeeperSelection {
        guard let autoCullResult, let captureResult else {
            throw FinalMomentLocalTestPipelineError.missingAutoCullResult
        }
        let result = try FinalMomentKeeperSelectionService(
            repository: store,
            assetRepository: store
        ).createKeeperSelection(FinalMomentKeeperSelectionServiceRequest(
            keeperSelectionId: "keeper_selection_\(captureResult.captureResultId)",
            request: request,
            autoCullResult: autoCullResult,
            captureResultId: captureResult.captureResultId,
            protectedSubjectSetId: captureResult.protectedSubjectSetId,
            captureSessionIsActive: true
        ))
        keeperSelection = result
        return result
    }

    func generateInternalCrops(_ request: FinalMomentCropGenerationRequest) throws -> FinalMomentCropGenerationResult {
        guard let keeperSelection else { throw FinalMomentLocalTestPipelineError.missingKeeperSelection }
        guard let autoCullResult else { throw FinalMomentLocalTestPipelineError.missingAutoCullResult }
        let result = try FinalMomentCropService(
            repository: store,
            assetRepository: store
        ).generateInternalCrops(FinalMomentCropServiceRequest(
            cropGenerationResultId: "crop_generation_\(keeperSelection.captureResultId)",
            request: request,
            keeperSelection: keeperSelection,
            acceptedFrames: autoCullResult.acceptedFrames,
            protectedSubjectGeometry: protectedSubjectGeometry
        ))
        cropGenerationResult = result
        return result
    }

    func prepareFineTuneReview(_ request: FinalMomentFineTuneRequest) throws -> FinalMomentFineTuneResult {
        guard let captureResult else { throw FinalMomentLocalTestPipelineError.missingCaptureResult }
        guard let keeperSelection else { throw FinalMomentLocalTestPipelineError.missingKeeperSelection }
        guard let cropGenerationResult else {
            throw FinalMomentLocalTestPipelineError.missingCropGenerationResult
        }
        let cropDecisions = try cropGenerationResult.recommendedCropByFrame.values.sorted().map {
            try store.loadCropDecisionRef(cropDecisionId: $0)
        }
        let result = try FinalMomentFineTuneService(
            repository: store,
            assetRepository: store
        ).prepareFineTuneReview(FinalMomentFineTuneServiceRequest(
            fineTuneResultId: "fine_tune_\(captureResult.captureResultId)",
            request: request,
            keeperSelection: keeperSelection,
            cropGenerationResult: cropGenerationResult,
            originalFrames: captureResult.frames,
            cropDecisions: cropDecisions,
            preset: Self.localTestPreset(),
            requestedEnhancements: captureResult.capturedAffordanceMetadata.postCaptureFineTuneEligible,
            nonRecoverableFailuresByFrame: [:]
        ))
        fineTuneResult = result
        return result
    }

    func saveMoment(_ request: FinalMomentSaveRequest) throws -> FinalMomentSaveResult {
        guard let captureResult else { throw FinalMomentLocalTestPipelineError.missingCaptureResult }
        guard let keeperSelection else { throw FinalMomentLocalTestPipelineError.missingKeeperSelection }
        guard let cropGenerationResult else {
            throw FinalMomentLocalTestPipelineError.missingCropGenerationResult
        }
        guard let fineTuneResult else { throw FinalMomentLocalTestPipelineError.missingFineTuneResult }
        return try FinalMomentSaveService(
            repository: store,
            assetRepository: store
        ).saveMoment(FinalMomentSaveServiceRequest(
            saveRequest: request,
            captureResult: captureResult,
            autoCullResultId: keeperSelection.autoCullResultId,
            keeperSelection: keeperSelection,
            cropGenerationResult: cropGenerationResult,
            fineTuneResult: fineTuneResult,
            profileSchemaVersion: captureResult.cameraSettingsIntentSnapshot.nativeCameraParameterIntentVersion,
            resumeCaptureContextAvailable: true,
            createdAt: "2026-06-04T16:10:00Z"
        ))
    }

    func getProfileState() throws -> FinalMomentProfileState {
        try FinalMomentSaveService(repository: store, assetRepository: store).getProfileState()
    }

    static func convert(
        sceneRuntimeHandoff: SceneRuntimeModels.BeforeCaptureFinalMomentHandoff,
        styleProfileVersion: String
    ) -> FinalMomentRuntimeCaptureHandoff {
        let recommendation = convert(sceneRuntimeHandoff.initialCameraSettingsRecommendation)
        let cameraSettings = convert(
            sceneRuntimeHandoff.cameraSettingsUsed,
            recommendationId: recommendation.recommendationId
        )
        let signals = sceneRuntimeHandoff.runtimeAffordanceSignals.map { convert($0.type) }
        let eligible = sceneRuntimeHandoff.postCapturePrerequisites.canFineTuneLater?.map { $0.rawValue } ?? [
            "portfolio_color_tone",
            "crop_composition",
            "light_shadow_contrast",
            "background_readability"
        ]
        let metadata = sceneRuntimeHandoff.capturedAffordanceMetadata

        return FinalMomentRuntimeCaptureHandoff(
            scenePlanId: sceneRuntimeHandoff.scenePlanId,
            styleProfileId: sceneRuntimeHandoff.styleProfileId,
            protectedSubjectSetId: sceneRuntimeHandoff.protectedSubjectSetId,
            styleProfileVersion: styleProfileVersion,
            profileSchemaVersion: "2026-06-04",
            nativeCameraParameterIntentVersion: "native_camera_intent_\(sceneRuntimeHandoff.styleProfileId)",
            sceneInputQualityContext: FinalMomentSceneInputQualityContext(
                sceneInputStatus: sceneRuntimeHandoff.sceneInputQualityContext.sceneInputStatus.rawValue,
                allowsSuboptimalSceneInput: sceneRuntimeHandoff.sceneInputQualityContext.allowsSuboptimalSceneInput,
                sceneInputFailureReason: sceneRuntimeHandoff.sceneInputQualityContext.sceneInputFailureReason?.code
            ),
            initialCameraSettingsRecommendation: recommendation,
            dynamicCameraSettingsAdjustmentId: sceneRuntimeHandoff.cameraSettingsUsed.settingsId
                .replacingOccurrences(of: "camera_settings_used", with: "dynamic_camera_adjustment"),
            cameraSettingsUsed: cameraSettings,
            runtimeAffordanceSignals: signals,
            postCapturePrerequisites: FinalMomentPostCapturePrerequisites(
                mustCaptureCorrectly: sceneRuntimeHandoff.postCapturePrerequisites.mustCaptureCorrectly.map(\.rawValue),
                protectedSubjectFocusRequired: sceneRuntimeHandoff.postCapturePrerequisites.mustCaptureCorrectly.contains(.protectedSubjectFocus),
                usableFaceLightRequired: sceneRuntimeHandoff.postCapturePrerequisites.mustCaptureCorrectly.contains(.usableFaceLight),
                naturalExpressionOrInteractionRequired: sceneRuntimeHandoff.postCapturePrerequisites.mustCaptureCorrectly.contains(.naturalExpressionOrInteraction),
                cropHeadroomRequired: sceneRuntimeHandoff.postCapturePrerequisites.mustCaptureCorrectly.contains(.cropHeadroom)
            ),
            capturedAffordanceMetadata: FinalMomentCapturedAffordanceMetadata(
                protectedSubjectFocusReady: metadata.protectedSubjectFocusReady,
                faceExposureUsable: metadata.faceExposureUsable,
                rimHairEdgeLightPreserved: metadata.rimHairEdgeLightPreserved ?? signals.contains(.rimHairEdgeLight),
                projectedShadowPatternPreserved: signals.contains(.projectedShadowPattern),
                architecturalAnchorPreserved: signals.contains(.architecturalAnchor) || signals.contains(.classicLocationAnchor),
                naturalExpressionOrInteractionObserved: metadata.naturalExpressionOrInteractionObserved,
                cropHeadroomPreserved: metadata.cropHeadroomPreserved,
                postCaptureFineTuneEligible: eligible
            )
        )
    }

    static func localTestRuntimeHandoff(
        styleProfileId: String,
        styleProfileVersion: String,
        protectedSubjectCount: Int
    ) -> FinalMomentRuntimeCaptureHandoff {
        let sceneRuntimeHandoff = LocalTestScenePlanProvider.beforeCaptureHandoff(
            styleProfileId: styleProfileId,
            protectedSubjectSetId: "protected_subject_set_local_test_\(protectedSubjectCount)"
        )
        return convert(
            sceneRuntimeHandoff: sceneRuntimeHandoff,
            styleProfileVersion: styleProfileVersion
        )
    }

    private func persistCaptureAssets(_ captureResult: FinalMomentCaptureResult) throws {
        for frame in captureResult.frames {
            _ = try store.upsertAsset(FinalMomentAssetRecord(
                assetRef: frame.assetRef,
                sourceStage: "capture_original",
                captureResultId: captureResult.captureResultId,
                frameId: frame.frameId,
                isReadable: true,
                contentFingerprint: "\(captureResult.captureResultId)_\(frame.frameId)"
            ))
            _ = try store.upsertCaptureAsset(FinalMomentCaptureAssetRecord(
                recordId: "\(captureResult.captureResultId)_\(frame.frameId)",
                captureResultId: captureResult.captureResultId,
                frameId: frame.frameId,
                originalAssetRef: frame.assetRef,
                styleProfileId: captureResult.styleProfileId,
                styleProfileVersion: captureResult.cameraSettingsIntentSnapshot.styleProfileVersion,
                scenePlanId: captureResult.scenePlanId,
                protectedSubjectSetId: captureResult.protectedSubjectSetId,
                runtimeAffordanceSignals: captureResult.runtimeAffordanceSignals,
                capturedAffordanceMetadata: captureResult.capturedAffordanceMetadata,
                cameraSettingsUsed: captureResult.cameraSettingsUsed
            ))
        }
    }

    private static func assessmentInputs(for capture: FinalMomentCaptureResult) -> [FinalMomentFrameAssessmentInput] {
        capture.frames.map { frame in
            FinalMomentFrameAssessmentInput(
                frameId: frame.frameId,
                assetRef: frame.assetRef,
                assetIsReadable: true,
                metadataIsReadable: true,
                protectedSubjectObservations: [
                    frame.burstIndex == 2 ? closedEyesObservation() : goodObservation()
                ],
                cameraSettingsUsed: capture.cameraSettingsUsed,
                runtimeAffordanceSignals: capture.runtimeAffordanceSignals,
                capturedAffordanceMetadata: capture.capturedAffordanceMetadata,
                postCapturePrerequisites: capture.postCapturePrerequisites
            )
        }
    }

    private static func goodObservation() -> FinalMomentProtectedSubjectObservation {
        FinalMomentProtectedSubjectObservation(
            subjectId: "subject_local_test_1",
            protectedSubjectInFrame: true,
            eyesOpen: true,
            faceSharpness: 0.86,
            faceExposure: 0.72,
            faceLightUsability: 0.82,
            expressionNaturalness: 0.84,
            interactionPresence: 0.78,
            cropHeadroom: 0.74
        )
    }

    private static func closedEyesObservation() -> FinalMomentProtectedSubjectObservation {
        FinalMomentProtectedSubjectObservation(
            subjectId: "subject_local_test_1",
            protectedSubjectInFrame: true,
            eyesOpen: false,
            faceSharpness: 0.82,
            faceExposure: 0.70,
            faceLightUsability: 0.78,
            expressionNaturalness: 0.82,
            interactionPresence: 0.74,
            cropHeadroom: 0.70
        )
    }

    private static func safeGeometry(frameIds: [String]) -> [FinalMomentProtectedSubjectCropGeometry] {
        frameIds.map {
            FinalMomentProtectedSubjectCropGeometry(
                frameId: $0,
                subjectId: "subject_local_test_1",
                protectedBounds: FinalMomentNormalizedRect(x: 0.40, y: 0.30, w: 0.20, h: 0.32),
                minimumSafePadding: 0.05
            )
        }
    }

    private static func localTestPreset() -> FinalMomentPublishedPreset {
        FinalMomentPublishedPreset(
            presetId: "preset_local_test_warm_editorial",
            lutAssetId: "lut_local_test_warm_editorial_v1",
            isAvailable: true,
            supportedEditSignals: [
                "portfolio_color_tone",
                "light_shadow_contrast",
                "crop_composition",
                "local_crispness",
                "local_softness",
                "background_readability_or_subject_separation",
                "background_readability",
                "subject_separation",
                "rim_light_emphasis",
                "shadow_pattern_emphasis"
            ]
        )
    }

    private static func convert(
        _ recommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation
    ) -> FinalMomentInitialCameraSettingsRecommendation {
        FinalMomentInitialCameraSettingsRecommendation(
            recommendationId: recommendation.recommendationId,
            focus: FinalMomentFocusRecommendation(
                target: recommendation.focus.target,
                mode: recommendation.focus.mode,
                priority: recommendation.focus.priority ?? "protected_subjects"
            ),
            exposure: FinalMomentExposureRecommendation(
                meteringTarget: recommendation.exposure.meteringTarget,
                bias: recommendation.exposure.bias ?? 0,
                protectHighlights: recommendation.exposure.protectHighlights ?? true,
                avoidFaceClipping: recommendation.exposure.avoidFaceClipping ?? true
            ),
            whiteBalance: FinalMomentWhiteBalanceRecommendation(
                mode: recommendation.whiteBalance.mode,
                lockWhenReady: recommendation.whiteBalance.lockWhenReady ?? true
            ),
            depth: FinalMomentDepthRecommendation(
                mode: recommendation.depth?.mode ?? "environmental_depth",
                portraitBlurStrength: recommendation.depth?.portraitBlurStrength ?? 0.2,
                keepArchitecturalAnchorReadable: recommendation.depth?.keepArchitecturalAnchorReadable ?? true
            ),
            framing: FinalMomentFramingRecommendation(
                shootWide: recommendation.framing?.shootWide ?? true,
                safetyMargin: recommendation.framing?.safetyMargin ?? "high",
                orientation: recommendation.framing?.orientation ?? "vertical",
                compositionTarget: recommendation.framing?.compositionTarget ?? "wide_environmental"
            ),
            colorAndTonePreview: FinalMomentColorAndTonePreview(
                contrast: recommendation.colorAndTonePreview?.contrast ?? "medium",
                saturation: recommendation.colorAndTonePreview?.saturation ?? "slightly_warm",
                highlightRecovery: recommendation.colorAndTonePreview?.highlightRecovery ?? "moderate"
            ),
            capture: FinalMomentCaptureRecommendation(
                burstCount: recommendation.capture?.burstCount ?? 3,
                highestPracticalResolution: recommendation.capture?.highestPracticalResolution ?? true,
                photoQualityPrioritization: recommendation.capture?.photoQualityPrioritization ?? "quality",
                flashMode: recommendation.flashLowLight?.flashMode ?? "off_unless_recovery_needed"
            )
        )
    }

    private static func convert(
        _ settings: SceneRuntimeModels.CameraSettingsUsed,
        recommendationId: String
    ) -> FinalMomentCameraSettingsUsed {
        FinalMomentCameraSettingsUsed(
            settingsId: settings.settingsId,
            appliedRecommendationId: recommendationId,
            dynamicCameraSettingsAdjustmentId: settings.settingsId.replacingOccurrences(
                of: "camera_settings_used",
                with: "dynamic_camera_adjustment"
            ),
            focusModeUsed: settings.focusModeUsed ?? "continuous_then_lock_when_ready",
            exposureBiasUsed: settings.exposureBiasUsed ?? 0,
            whiteBalanceModeUsed: settings.whiteBalanceModeUsed ?? "auto_then_lock_when_ready",
            depthModeUsed: settings.depthModeUsed ?? "environmental_depth",
            zoomLensModeUsed: settings.lensUsed ?? "wide",
            burstCountRequested: settings.burstCountRequested ?? 3,
            burstCountCaptured: settings.burstCountCaptured ?? 3,
            highestPracticalResolutionUsed: settings.highestPracticalResolutionUsed ?? true,
            focus: actual(settings.focusStatus, requested: "protected_subject_focus", applied: settings.focusModeUsed),
            exposure: actual(settings.exposureStatus, requested: "protected_subject_face_metering", applied: "\(settings.exposureBiasUsed ?? 0)"),
            whiteBalance: actual(settings.whiteBalanceStatus, requested: "warm_lock_when_ready", applied: settings.whiteBalanceModeUsed),
            depthPortrait: actual(settings.depthStatus, requested: "environmental_depth", applied: settings.depthModeUsed),
            zoomLens: actual(settings.zoomLensStatus, requested: "wide_lens_crop_headroom", applied: settings.lensUsed),
            framing: actual(
                settings.zoomLensStatus,
                requested: "wide_environmental",
                applied: settings.zoomFactorUsed.map { String($0) }
            ),
            captureQuality: actual(.applied, requested: "quality_high_resolution", applied: settings.photoQualityPrioritizationUsed),
            flashLowLightPolicy: actual(.applied, requested: "natural_light_first", applied: settings.flashModeUsed),
            capabilityStatus: [
                "focus": convert(settings.focusStatus),
                "exposure": convert(settings.exposureStatus),
                "whiteBalance": convert(settings.whiteBalanceStatus),
                "depthPortrait": convert(settings.depthStatus),
                "zoomLens": convert(settings.zoomLensStatus)
            ],
            capabilityGaps: settings.capabilityGaps
        )
    }

    private static func actual(
        _ status: SceneRuntimeModels.CameraCapabilityStatus,
        requested: String,
        applied: String?
    ) -> FinalMomentCameraSettingActual {
        FinalMomentCameraSettingActual(
            status: convert(status),
            requested: requested,
            applied: applied ?? "not_recorded",
            reason: status == .applied ? nil : "scene_runtime_reported_\(status.rawValue)"
        )
    }

    private static func convert(_ status: SceneRuntimeModels.CameraCapabilityStatus) -> FinalMomentCapabilityStatus {
        switch status {
        case .applied:
            return .applied
        case .adjusted:
            return .adjusted
        case .unavailable:
            return .unavailable
        case .needsOperatorAdjustment:
            return .needsOperatorAdjustment
        case .pending:
            return .notRequested
        }
    }

    private static func convert(_ signal: SceneRuntimeModels.RuntimeAffordanceSignalType) -> FinalMomentRuntimeAffordanceSignal {
        switch signal {
        case .softFrontLight:
            return .softFrontLight
        case .softSideLight:
            return .softSideLight
        case .rimHairEdgeLight:
            return .rimHairEdgeLight
        case .projectedShadowPattern:
            return .projectedShadowPattern
        case .dramaticSideLightUsable:
            return .dramaticSideLightUsable
        case .classicLocationAnchor:
            return .classicLocationAnchor
        case .openSpaceAnchor:
            return .openSpaceAnchor
        case .architecturalAnchor:
            return .architecturalAnchor
        case .cropHeadroomAvailable:
            return .cropHeadroomAvailable
        case .naturalMotionOpportunity:
            return .naturalMotionOpportunity
        case .relationshipInteractionOpportunity:
            return .relationshipInteractionOpportunity
        case .focusDepthOpportunity:
            return .focusDepthOpportunity
        }
    }

    private static func asset(
        _ id: String,
        role: FinalMomentAssetRole,
        width: Int,
        height: Int
    ) -> FinalMomentAssetRef {
        FinalMomentAssetRef(
            assetId: id,
            uri: "local-test-final-moment://\(id)",
            role: role,
            width: width,
            height: height,
            mimeType: "image/jpeg"
        )
    }

    private static func sanitized(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber || character == "_" ? character : "_"
        }.reduce(into: "") { $0.append($1) }
    }
}

private extension LocalTestScenePlanProvider {
    static func beforeCaptureHandoff(
        styleProfileId: String,
        protectedSubjectSetId: String
    ) -> SceneRuntimeModels.BeforeCaptureFinalMomentHandoff {
        let sceneInputQualityContext = SceneRuntimeModels.SceneInputQualityContext(
                sceneInputMode: .singlePhoto,
                sceneInputStatus: .accepted,
                allowsSuboptimalSceneInput: false,
                sceneInputFailureReason: nil,
                qualitySignals: .empty
            )
        let runtimeSignals = [
            localTestSignal(.softSideLight),
            localTestSignal(.rimHairEdgeLight),
            localTestSignal(.cropHeadroomAvailable),
            localTestSignal(.naturalMotionOpportunity),
            localTestSignal(.relationshipInteractionOpportunity),
            localTestSignal(.focusDepthOpportunity),
            localTestSignal(.architecturalAnchor)
        ]
        let postCapturePrerequisites = SceneRuntimeModels.PostCapturePrerequisites(
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
            statusAtCapture: [
                "protected_subject_focus": "strong",
                "usable_face_light": "strong",
                "natural_expression_or_interaction": "strong",
                "crop_headroom": "strong"
            ]
        )
        let scenePlanId = "scene_plan_local_test_direct_capture"
        let recommendation = localTestCameraRecommendation(scenePlanId: scenePlanId)
        let adjustment = SceneRuntimeModels.DynamicCameraSettingsAdjustment(
            focus: localTestAdjustment(.applied, value: "continuous_then_lock_when_ready", mode: "continuous_then_lock_when_ready"),
            exposure: localTestAdjustment(.applied, value: "protected_faces_-0.2", meteringTarget: "protected_subject_faces", bias: -0.2),
            whiteBalance: localTestAdjustment(.applied, value: "auto_then_lock_when_ready", mode: "auto_then_lock_when_ready", temperatureBias: "warm"),
            zoomLens: localTestAdjustment(.applied, value: "wide_1x", lensUsed: "wide", zoomFactor: 1.0),
            depth: localTestAdjustment(.applied, value: "environmental_depth", mode: "environmental_depth", portraitBlurStrength: 0.2),
            framing: localTestAdjustment(.applied, value: "wide_environmental", cue: "preserve_crop_headroom", shootWide: true),
            capture: localTestAdjustment(.applied, value: "quality_burst", burstCount: 3, highestPracticalResolution: true, photoQualityPrioritization: "quality"),
            flashLowLight: localTestAdjustment(.applied, value: "natural_light_first", flashMode: "off_unless_recovery_needed"),
            capabilityStatus: [
                "focus": .applied,
                "exposure": .applied,
                "whiteBalance": .applied,
                "zoomLens": .applied,
                "depth": .applied,
                "framing": .applied,
                "capture": .applied,
                "flashLowLight": .applied
            ]
        )
        let liveResponse = SceneRuntimeModels.EvaluateLiveFrameReadinessResponse(
            scenePlanId: scenePlanId,
            readiness: .ready,
            score: 0.91,
            blockingIssues: [],
            cues: [SceneRuntimeModels.CoachingCue(target: "operator", message: "Hold steady and capture now.")],
            dynamicCameraSettingsAdjustment: adjustment,
            capturedAffordanceMetadata: SceneRuntimeModels.CapturedAffordanceMetadata(
                protectedSubjectFocusReady: true,
                faceExposureUsable: true,
                rimHairEdgeLightPreserved: true,
                naturalExpressionOrInteractionObserved: true,
                cropHeadroomPreserved: true,
                postCaptureFineTuneEligible: postCapturePrerequisites.canFineTuneLater ?? [],
                weakPrerequisites: nil
            ),
            postCapturePrerequisiteStatus: postCapturePrerequisites.statusAtCapture ?? [:],
            cameraSettingsUsed: nil,
            canCaptureBestEffort: false,
            persistenceWriteIntent: ["local_test_live_readiness"]
        )
        let scenePlan = SceneRuntimeModels.GenerateScenePlanResponse(
            scenePlanId: scenePlanId,
            sceneAnalysisId: "scene_analysis_local_test_direct_capture",
            styleProfileId: styleProfileId,
            protectedSubjectSetId: protectedSubjectSetId,
            sceneInputQualityContext: sceneInputQualityContext,
            sceneMatchType: .styleSynthesis,
            professionalHappyMomentAssessment: SceneRuntimeModels.ProfessionalHappyMomentAssessment(
                faceLightUsable: true,
                naturalExpressionOpportunity: true,
                relationshipInteractionOpportunity: true,
                protectedSubjectFocusFeasible: true,
                cropHeadroomFeasible: true,
                unrecoverableRisks: nil
            ),
            runtimeAffordanceSignals: runtimeSignals,
            postCapturePrerequisites: postCapturePrerequisites,
            postCaptureFineTuneSignals: postCapturePrerequisites.canFineTuneLater ?? [],
            standPoint: SceneRuntimeModels.LabeledDescription(
                label: "Local-test capture point",
                description: "Contract-backed direct capture fixture."
            ),
            subjectPosition: SceneRuntimeModels.SubjectPosition(
                zone: "open_light_edge",
                distanceCue: "stand where faces stay bright"
            ),
            operatorPosition: SceneRuntimeModels.OperatorPosition(
                distanceCue: "step back for crop headroom",
                heightCue: "hold the phone around chest height",
                framingCue: "keep protected subjects and the anchor inside the guide"
            ),
            facingDirection: SceneRuntimeModels.FacingDirection(
                subjectCue: "turn gently toward the softer side light",
                operatorCue: "face the phone toward the subjects and anchor"
            ),
            roughFraming: SceneRuntimeModels.RoughFraming(
                style: "wide_environmental",
                safetyMargin: "high",
                orientation: "vertical"
            ),
            coachingCues: [],
            initialCameraSettingsRecommendation: recommendation,
            fallback: nil,
            persistenceWriteIntent: ["local_test_scene_plan"]
        )
        return SceneRuntimeModels.BeforeCaptureFinalMomentHandoff(
            scenePlanId: scenePlan.scenePlanId,
            styleProfileId: styleProfileId,
            protectedSubjectSetId: protectedSubjectSetId,
            sceneInputQualityContext: scenePlan.sceneInputQualityContext,
            initialCameraSettingsRecommendation: scenePlan.initialCameraSettingsRecommendation,
            runtimeAffordanceSignals: scenePlan.runtimeAffordanceSignals,
            postCapturePrerequisites: scenePlan.postCapturePrerequisites,
            capturedAffordanceMetadata: liveResponse.capturedAffordanceMetadata,
            cameraSettingsUsed: SceneRuntimeCaptureSettingsFinalizer.cameraSettingsUsed(
                scenePlan: scenePlan,
                liveResponse: liveResponse
            ),
            persistenceWriteIntent: ["local_test_final_moment_handoff"]
        )
    }

    static func localTestSignal(
        _ type: SceneRuntimeModels.RuntimeAffordanceSignalType
    ) -> SceneRuntimeModels.RuntimeAffordanceSignal {
        SceneRuntimeModels.RuntimeAffordanceSignal(
            type: type,
            confidence: 0.86,
            recommendedUse: "preserve_during_live_capture",
            evidence: "local_test_scene_runtime_provider"
        )
    }

    static func localTestCameraRecommendation(
        scenePlanId: String
    ) -> SceneRuntimeModels.InitialCameraSettingsRecommendation {
        SceneRuntimeModels.InitialCameraSettingsRecommendation(
            recommendationId: "camera_rec_\(scenePlanId)",
            sourceNativeCameraParameterIntentId: "style_profile_runtime.local_test.native_camera_intent",
            focus: SceneRuntimeModels.FocusRecommendation(
                target: "all_protected_subjects",
                mode: "continuous_then_lock_when_ready",
                priority: "faces_and_bodies",
                focusPointStrategy: "protected_subject_face_group"
            ),
            exposure: SceneRuntimeModels.ExposureRecommendation(
                meteringTarget: "protected_subject_faces",
                bias: -0.2,
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
                maxDigitalZoomFactor: 2.0,
                allowUltraWideIfOperatorTooClose: true,
                avoidLensSwitchDuringCapture: true
            ),
            depth: SceneRuntimeModels.DepthRecommendation(
                mode: "environmental_depth",
                portraitBlurStrength: 0.2,
                keepArchitecturalAnchorReadable: true,
                depthDataDeliveryPreferred: true,
                portraitEffectsMattePreferred: true
            ),
            framing: SceneRuntimeModels.FramingRecommendation(
                shootWide: true,
                safetyMargin: "high",
                orientation: "vertical",
                compositionTarget: "wide_environmental"
            ),
            colorAndTonePreview: SceneRuntimeModels.ColorAndTonePreview(
                contrast: "medium",
                saturation: "slightly_warm",
                highlightRecovery: "moderate"
            ),
            capture: SceneRuntimeModels.CaptureRecommendation(
                burstCount: 3,
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

    static func localTestAdjustment(
        _ status: SceneRuntimeModels.CameraCapabilityStatus,
        value: String?,
        mode: String? = nil,
        meteringTarget: String? = nil,
        bias: Double? = nil,
        temperatureBias: String? = nil,
        portraitBlurStrength: Double? = nil,
        lensUsed: String? = nil,
        zoomFactor: Double? = nil,
        cue: String? = nil,
        shootWide: Bool? = nil,
        burstCount: Int? = nil,
        highestPracticalResolution: Bool? = nil,
        photoQualityPrioritization: String? = nil,
        flashMode: String? = nil
    ) -> SceneRuntimeModels.CameraAdjustment {
        SceneRuntimeModels.CameraAdjustment(
            status: status,
            value: value,
            reason: nil,
            capabilityGap: nil,
            lockedOn: nil,
            adjustment: nil,
            meteringTarget: meteringTarget,
            bias: bias,
            mode: mode,
            temperatureBias: temperatureBias,
            portraitBlurStrength: portraitBlurStrength,
            depthDataDelivery: nil,
            portraitEffectsMatteDelivery: nil,
            lensUsed: lensUsed,
            zoomFactor: zoomFactor,
            cue: cue,
            shootWide: shootWide,
            burstCount: burstCount,
            highestPracticalResolution: highestPracticalResolution,
            photoQualityPrioritization: photoQualityPrioritization,
            captureResponsiveness: nil,
            flashMode: flashMode,
            torchMode: nil
        )
    }
}
