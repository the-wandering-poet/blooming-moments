import Foundation

enum NativeCameraAdapterSchema {
    static let currentVersion = "2026-06-04.native-camera-adapter.v1"
}

enum NativeCameraParameterGroup: String, Codable, Equatable, CaseIterable {
    case focus
    case exposure
    case whiteBalance
    case zoomLens
    case depth
    case framing
    case capture
    case flashLowLight
}

struct NativeCameraAdapterInput: Codable, Equatable {
    let schemaVersion: String
    let scenePlanId: String
    let recommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation
    let nativeCapabilities: SceneRuntimeModels.NativeCameraCapabilities

    init(
        schemaVersion: String = SceneRuntimeServiceSchema.currentVersion,
        scenePlanId: String,
        recommendation: SceneRuntimeModels.InitialCameraSettingsRecommendation,
        nativeCapabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) {
        self.schemaVersion = schemaVersion
        self.scenePlanId = scenePlanId
        self.recommendation = recommendation
        self.nativeCapabilities = nativeCapabilities
    }
}

struct NativeCameraCommand: Codable, Equatable {
    let group: NativeCameraParameterGroup
    let operation: String
    let requestedValue: String?
    let resolvedValue: String?
    let status: SceneRuntimeModels.CameraCapabilityStatus
    let capabilityGap: String?
}

struct NativeCameraAdapterResult: Codable, Equatable {
    let scenePlanId: String
    let recommendationId: String
    let dynamicCameraSettingsAdjustment: SceneRuntimeModels.DynamicCameraSettingsAdjustment
    let commands: [NativeCameraCommand]
    let capabilityGaps: [String]
    let substitutions: [SceneRuntimeModels.CameraSettingSubstitution]
    let operatorCues: [SceneRuntimeModels.CoachingCue]
}

enum NativeCameraAdapterError: Error, Equatable {
    case unsupportedSchemaVersion(String)
    case validationFailed(fieldPath: String, message: String)
}

protocol NativeCameraAdapterBoundary {
    func prepareCameraAdjustment(
        _ input: NativeCameraAdapterInput
    ) throws -> NativeCameraAdapterResult
}

struct AVFoundationNativeCameraAdapter: NativeCameraAdapterBoundary {
    func prepareCameraAdjustment(
        _ input: NativeCameraAdapterInput
    ) throws -> NativeCameraAdapterResult {
        try validate(input)

        let focus = focusAdjustment(input.recommendation.focus, capabilities: input.nativeCapabilities)
        let exposure = exposureAdjustment(input.recommendation.exposure, capabilities: input.nativeCapabilities)
        let whiteBalance = whiteBalanceAdjustment(input.recommendation.whiteBalance, capabilities: input.nativeCapabilities)
        let zoomLens = zoomLensAdjustment(input.recommendation.zoomLens, capabilities: input.nativeCapabilities)
        let depth = depthAdjustment(input.recommendation.depth, capabilities: input.nativeCapabilities)
        let framing = framingAdjustment(input.recommendation.framing, zoomLens: zoomLens.adjustment)
        let capture = captureAdjustment(input.recommendation.capture, capabilities: input.nativeCapabilities)
        let flashLowLight = flashLowLightAdjustment(input.recommendation.flashLowLight, capabilities: input.nativeCapabilities)

        let groups = [
            focus,
            exposure,
            whiteBalance,
            zoomLens,
            depth,
            framing,
            capture,
            flashLowLight
        ]
        let capabilityStatus = Dictionary(
            uniqueKeysWithValues: zip(
                NativeCameraParameterGroup.allCases.map(\.rawValue),
                groups.map(\.adjustment.status)
            )
        )
        let dynamicAdjustment = SceneRuntimeModels.DynamicCameraSettingsAdjustment(
            focus: focus.adjustment,
            exposure: exposure.adjustment,
            whiteBalance: whiteBalance.adjustment,
            zoomLens: zoomLens.adjustment,
            depth: depth.adjustment,
            framing: framing.adjustment,
            capture: capture.adjustment,
            flashLowLight: flashLowLight.adjustment,
            capabilityStatus: capabilityStatus
        )

        return NativeCameraAdapterResult(
            scenePlanId: input.scenePlanId,
            recommendationId: input.recommendation.recommendationId,
            dynamicCameraSettingsAdjustment: dynamicAdjustment,
            commands: groups.flatMap(\.commands),
            capabilityGaps: Array(Set(groups.flatMap(\.capabilityGaps))).sorted(),
            substitutions: groups.flatMap(\.substitutions),
            operatorCues: groups.flatMap(\.operatorCues)
        )
    }

    private func validate(_ input: NativeCameraAdapterInput) throws {
        guard input.schemaVersion == SceneRuntimeServiceSchema.currentVersion else {
            throw NativeCameraAdapterError.unsupportedSchemaVersion(input.schemaVersion)
        }
        try requireNonEmpty(input.scenePlanId, fieldPath: "scenePlanId")
        try requireNonEmpty(input.recommendation.recommendationId, fieldPath: "recommendation.recommendationId")
    }

    private func requireNonEmpty(_ value: String, fieldPath: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NativeCameraAdapterError.validationFailed(
                fieldPath: fieldPath,
                message: "\(fieldPath) must not be empty."
            )
        }
    }

    private func focusAdjustment(
        _ recommendation: SceneRuntimeModels.FocusRecommendation,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        var gaps: [String] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []
        var cues: [SceneRuntimeModels.CoachingCue] = []

        if !capabilities.canLockFocus {
            gaps.append("focus_lock_unavailable")
            return GroupResult(
                adjustment: cameraAdjustment(
                    status: .unavailable,
                    reason: "Focus lock is unavailable on this camera surface.",
                    capabilityGap: "focus_lock_unavailable",
                    lockedOn: nil,
                    adjustment: "Use continuous autofocus only.",
                    cue: "Hold the phone steady with protected subjects centered."
                ),
                commands: [
                    command(.focus, "lock_focus", recommendation.mode, nil, .unavailable, "focus_lock_unavailable")
                ],
                capabilityGaps: gaps,
                substitutions: [
                    substitution("focusLock", requested: true, used: false, status: .unavailable, reason: "Focus lock is unavailable.")
                ],
                operatorCues: [
                    cue("operator", "Hold the phone steady with protected subjects centered.")
                ]
            )
        }

        if capabilities.canSetFocusPoint == false {
            gaps.append("focus_point_unavailable")
            substitutions.append(substitution("focusPoint", requested: true, used: false, status: .needsOperatorAdjustment, reason: "Focus point cannot be set directly."))
            cues.append(cue("operator", "Center the protected subjects in the frame."))
            return GroupResult(
                adjustment: cameraAdjustment(
                    status: .needsOperatorAdjustment,
                    reason: "Focus point control is unavailable.",
                    capabilityGap: "focus_point_unavailable",
                    lockedOn: nil,
                    adjustment: "Use center-weighted continuous autofocus.",
                    cue: "Center the protected subjects in the frame."
                ),
                commands: [
                    command(.focus, "set_focus_point", recommendation.focusPointStrategy, "center_weighted", .needsOperatorAdjustment, "focus_point_unavailable")
                ],
                capabilityGaps: gaps,
                substitutions: substitutions,
                operatorCues: cues
            )
        }

        return GroupResult(
            adjustment: cameraAdjustment(
                status: .applied,
                reason: nil,
                capabilityGap: nil,
                lockedOn: [recommendation.target],
                adjustment: "Focus lock requested for protected subjects.",
                cue: nil
            ),
            commands: [
                command(.focus, "set_focus_point", recommendation.focusPointStrategy, recommendation.focusPointStrategy, .applied, nil),
                command(.focus, "lock_focus", recommendation.mode, recommendation.mode, .applied, nil)
            ],
            capabilityGaps: [],
            substitutions: [],
            operatorCues: []
        )
    }

    private func exposureAdjustment(
        _ recommendation: SceneRuntimeModels.ExposureRecommendation,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        var gaps: [String] = []
        var commands: [NativeCameraCommand] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []

        if capabilities.canSetExposurePoint == false {
            gaps.append("exposure_point_unavailable")
            return GroupResult(
                adjustment: cameraAdjustment(
                    status: .needsOperatorAdjustment,
                    reason: "Exposure point control is unavailable.",
                    capabilityGap: "exposure_point_unavailable",
                    adjustment: "Use automatic exposure and ask for better physical light.",
                    meteringTarget: recommendation.meteringTarget,
                    bias: nil,
                    cue: "Turn protected subjects toward softer light."
                ),
                commands: [
                    command(.exposure, "set_exposure_point", recommendation.meteringTarget, nil, .needsOperatorAdjustment, "exposure_point_unavailable")
                ],
                capabilityGaps: gaps,
                substitutions: [
                    substitution("exposurePoint", requested: true, used: false, status: .needsOperatorAdjustment, reason: "Exposure metering point cannot be set.")
                ],
                operatorCues: [
                    cue("operator", "Turn protected subjects toward softer light.")
                ]
            )
        }

        commands.append(command(.exposure, "set_exposure_point", recommendation.meteringTarget, recommendation.meteringTarget, .applied, nil))
        var status: SceneRuntimeModels.CameraCapabilityStatus = .applied
        var biasUsed = recommendation.bias
        if recommendation.bias != nil && capabilities.canSetExposureBias == false {
            status = .adjusted
            biasUsed = nil
            gaps.append("exposure_bias_unavailable")
            substitutions.append(substitution("exposureBias", requested: true, used: false, status: .adjusted, reason: "Exposure bias is unavailable; face metering remains requested."))
            commands.append(command(.exposure, "set_exposure_bias", recommendation.bias.map { String($0) }, nil, .adjusted, "exposure_bias_unavailable"))
        } else if let bias = recommendation.bias {
            commands.append(command(.exposure, "set_exposure_bias", String(bias), String(bias), .applied, nil))
        }

        return GroupResult(
            adjustment: cameraAdjustment(
                status: status,
                reason: status == .adjusted ? "Exposure bias unavailable; using face metering without bias." : nil,
                capabilityGap: gaps.first,
                adjustment: "Meter protected-subject faces.",
                meteringTarget: recommendation.meteringTarget,
                bias: biasUsed
            ),
            commands: commands,
            capabilityGaps: gaps,
            substitutions: substitutions,
            operatorCues: []
        )
    }

    private func whiteBalanceAdjustment(
        _ recommendation: SceneRuntimeModels.WhiteBalanceRecommendation,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        var gaps: [String] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []
        var commands: [NativeCameraCommand] = []
        var status: SceneRuntimeModels.CameraCapabilityStatus = .applied
        var cueValue: String?

        if recommendation.lockWhenReady == true && capabilities.canLockWhiteBalance == false {
            gaps.append("white_balance_lock_unavailable")
            status = capabilities.canSetWhiteBalanceGains == false ? .needsOperatorAdjustment : .adjusted
            substitutions.append(substitution("whiteBalanceLock", requested: true, used: false, status: status, reason: "White balance lock is unavailable."))
            commands.append(command(.whiteBalance, "lock_white_balance", recommendation.mode, nil, status, "white_balance_lock_unavailable"))
            if status == .needsOperatorAdjustment {
                cueValue = "Move into steadier light before capture."
            }
        }

        if recommendation.temperatureBias != nil && capabilities.canSetWhiteBalanceGains == false {
            if !gaps.contains("white_balance_gains_unavailable") {
                gaps.append("white_balance_gains_unavailable")
            }
            status = status == .needsOperatorAdjustment ? .needsOperatorAdjustment : .adjusted
            substitutions.append(substitution("whiteBalanceGains", requested: true, used: false, status: status, reason: "White balance gains cannot be set."))
            commands.append(command(.whiteBalance, "set_white_balance_gains", recommendation.temperatureBias, nil, status, "white_balance_gains_unavailable"))
            if status == .needsOperatorAdjustment {
                cueValue = "Move into steadier light before capture."
            }
        }

        if commands.isEmpty {
            commands.append(command(.whiteBalance, "set_white_balance", recommendation.mode, recommendation.mode, .applied, nil))
        }

        return GroupResult(
            adjustment: cameraAdjustment(
                status: status,
                reason: gaps.isEmpty ? nil : "White balance capability fallback required.",
                capabilityGap: gaps.first,
                adjustment: status == .applied ? "Lock white balance when face light is ready." : "Use automatic white balance.",
                mode: recommendation.mode,
                temperatureBias: status == .applied ? recommendation.temperatureBias : nil,
                cue: cueValue
            ),
            commands: commands,
            capabilityGaps: gaps,
            substitutions: substitutions,
            operatorCues: cueValue.map { [cue("operator", $0)] } ?? []
        )
    }

    private func zoomLensAdjustment(
        _ recommendation: SceneRuntimeModels.ZoomLensRecommendation?,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        guard let recommendation else {
            return emptyResult(.zoomLens, status: .applied)
        }

        let lenses = capabilities.availableLenses ?? []
        guard !lenses.isEmpty else {
            return GroupResult(
                adjustment: cameraAdjustment(
                    status: .unavailable,
                    reason: "No reported lens capability is available.",
                    capabilityGap: "zoom_lens_unavailable",
                    cue: "Step back to keep subjects and scene anchor in frame."
                ),
                commands: [
                    command(.zoomLens, "select_lens", recommendation.preferredLens, nil, .unavailable, "zoom_lens_unavailable")
                ],
                capabilityGaps: ["zoom_lens_unavailable"],
                substitutions: [
                    substitution("lens", requested: true, used: false, status: .unavailable, reason: "No compatible lens was reported.")
                ],
                operatorCues: [
                    cue("operator", "Step back to keep subjects and scene anchor in frame.")
                ]
            )
        }

        var status: SceneRuntimeModels.CameraCapabilityStatus = .applied
        var gaps: [String] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []
        var commands: [NativeCameraCommand] = []
        var selectedLens = recommendation.preferredLens

        if !lenses.contains(recommendation.preferredLens) {
            selectedLens = closestLens(preferred: recommendation.preferredLens, available: lenses)
            status = .adjusted
            gaps.append("zoom_lens_unavailable")
            substitutions.append(substitution("lens", requested: true, used: true, status: .adjusted, reason: "Preferred lens unavailable; using closest available lens."))
        }
        commands.append(command(.zoomLens, "select_lens", recommendation.preferredLens, selectedLens, status, status == .adjusted ? "zoom_lens_unavailable" : nil))

        let targetZoom = recommendation.targetZoomFactor ?? 1
        let minZoom = capabilities.minZoomFactor ?? 1
        let maxOptical = capabilities.maxOpticalZoomFactor ?? targetZoom
        let maxAcceptable = capabilities.maxAcceptableDigitalZoomFactor ?? maxOptical
        var resolvedZoom = max(minZoom, min(targetZoom, maxAcceptable))
        var cueValue: String?

        if targetZoom > maxAcceptable {
            status = .needsOperatorAdjustment
            gaps.append("digital_zoom_quality_loss")
            resolvedZoom = maxAcceptable
            substitutions.append(substitution("zoomFactor", requested: true, used: true, status: .needsOperatorAdjustment, reason: "Requested zoom exceeds acceptable quality."))
            cueValue = "Step closer instead of relying on heavy digital zoom."
        } else if targetZoom > maxOptical {
            status = status == .needsOperatorAdjustment ? .needsOperatorAdjustment : .adjusted
            gaps.append("digital_zoom_quality_loss")
            substitutions.append(substitution("zoomFactor", requested: true, used: true, status: .adjusted, reason: "Requested zoom exceeds optical range."))
        }
        commands.append(command(.zoomLens, "set_zoom_factor", String(targetZoom), String(resolvedZoom), status, gaps.last))

        return GroupResult(
            adjustment: cameraAdjustment(
                status: status,
                reason: gaps.isEmpty ? nil : "Lens or zoom fallback required.",
                capabilityGap: gaps.first,
                lensUsed: selectedLens,
                zoomFactor: resolvedZoom,
                cue: cueValue
            ),
            commands: commands,
            capabilityGaps: Array(Set(gaps)).sorted(),
            substitutions: substitutions,
            operatorCues: cueValue.map { [cue("operator", $0)] } ?? []
        )
    }

    private func depthAdjustment(
        _ recommendation: SceneRuntimeModels.DepthRecommendation?,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        guard let recommendation else {
            return emptyResult(.depth, status: .applied)
        }

        if recommendation.mode != "standard_photo_depth_optional" && capabilities.canUseDepth == false {
            return GroupResult(
                adjustment: cameraAdjustment(
                    status: .unavailable,
                    reason: "Depth mode is unavailable.",
                    capabilityGap: "depth_mode_unavailable",
                    mode: "standard_photo",
                    depthDataDelivery: false,
                    portraitEffectsMatteDelivery: false
                ),
                commands: [
                    command(.depth, "enable_depth", recommendation.mode, nil, .unavailable, "depth_mode_unavailable")
                ],
                capabilityGaps: ["depth_mode_unavailable"],
                substitutions: [
                    substitution("depthMode", requested: true, used: false, status: .unavailable, reason: "Device does not report depth capability.")
                ],
                operatorCues: []
            )
        }

        var status: SceneRuntimeModels.CameraCapabilityStatus = .applied
        var gaps: [String] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []
        var commands: [NativeCameraCommand] = [
            command(.depth, "enable_depth", recommendation.mode, recommendation.mode, .applied, nil)
        ]
        var depthData = recommendation.depthDataDeliveryPreferred ?? false
        var matte = recommendation.portraitEffectsMattePreferred ?? false
        var cueValue: String?

        if depthData && capabilities.canDeliverDepthData == false {
            status = .adjusted
            depthData = false
            gaps.append("depth_data_unavailable")
            substitutions.append(substitution("depthDataDelivery", requested: true, used: false, status: .adjusted, reason: "Depth data delivery is unavailable."))
            commands.append(command(.depth, "deliver_depth_data", recommendation.depthDataDeliveryPreferred.map { String($0) }, String(depthData), .adjusted, "depth_data_unavailable"))
        } else {
            commands.append(command(.depth, "deliver_depth_data", recommendation.depthDataDeliveryPreferred.map { String($0) }, String(depthData), .applied, nil))
        }
        if matte && capabilities.canDeliverPortraitEffectsMatte == false {
            status = status == .applied ? .adjusted : status
            matte = false
            gaps.append("portrait_effects_matte_unavailable")
            substitutions.append(substitution("portraitEffectsMatte", requested: true, used: false, status: .adjusted, reason: "Portrait effects matte is unavailable."))
            commands.append(command(.depth, "deliver_portrait_effects_matte", recommendation.portraitEffectsMattePreferred.map { String($0) }, String(matte), .adjusted, "portrait_effects_matte_unavailable"))
        } else {
            commands.append(command(.depth, "deliver_portrait_effects_matte", recommendation.portraitEffectsMattePreferred.map { String($0) }, String(matte), .applied, nil))
        }
        if status == .adjusted && recommendation.keepArchitecturalAnchorReadable == true {
            cueValue = "Keep a little more distance between subjects and background."
        }

        return GroupResult(
            adjustment: cameraAdjustment(
                status: status,
                reason: gaps.isEmpty ? nil : "Depth delivery fallback required.",
                capabilityGap: gaps.first,
                mode: recommendation.mode,
                portraitBlurStrength: recommendation.portraitBlurStrength,
                depthDataDelivery: depthData,
                portraitEffectsMatteDelivery: matte,
                cue: cueValue
            ),
            commands: commands,
            capabilityGaps: Array(Set(gaps)).sorted(),
            substitutions: substitutions,
            operatorCues: cueValue.map { [cue("operator", $0)] } ?? []
        )
    }

    private func framingAdjustment(
        _ recommendation: SceneRuntimeModels.FramingRecommendation?,
        zoomLens: SceneRuntimeModels.CameraAdjustment
    ) -> GroupResult {
        guard let recommendation else {
            return emptyResult(.framing, status: .applied)
        }
        if zoomLens.status == .needsOperatorAdjustment {
            return GroupResult(
                adjustment: cameraAdjustment(
                    status: .needsOperatorAdjustment,
                    reason: "Framing needs physical repositioning because zoom/lens could not satisfy the request.",
                    capabilityGap: zoomLens.capabilityGap,
                    cue: "Step closer or back until protected subjects and anchor fit naturally.",
                    shootWide: recommendation.shootWide
                ),
                commands: [
                    command(.framing, "preserve_framing", recommendation.compositionTarget, nil, .needsOperatorAdjustment, zoomLens.capabilityGap)
                ],
                capabilityGaps: [zoomLens.capabilityGap].compactMap { $0 },
                substitutions: [
                    substitution("framingDistance", requested: true, used: false, status: .needsOperatorAdjustment, reason: "Physical repositioning is needed.")
                ],
                operatorCues: [
                    cue("operator", "Step closer or back until protected subjects and anchor fit naturally.")
                ]
            )
        }
        return GroupResult(
            adjustment: cameraAdjustment(
                status: .applied,
                adjustment: recommendation.compositionTarget,
                cue: nil,
                shootWide: recommendation.shootWide
            ),
            commands: [
                command(.framing, "preserve_framing", recommendation.compositionTarget, recommendation.compositionTarget, .applied, nil)
            ],
            capabilityGaps: [],
            substitutions: [],
            operatorCues: []
        )
    }

    private func captureAdjustment(
        _ recommendation: SceneRuntimeModels.CaptureRecommendation?,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        guard let recommendation else {
            return emptyResult(.capture, status: .applied)
        }

        var status: SceneRuntimeModels.CameraCapabilityStatus = .applied
        var gaps: [String] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []
        var commands: [NativeCameraCommand] = []
        var burst = recommendation.burstCount
        var highResolution = recommendation.highestPracticalResolution
        var quality = recommendation.photoQualityPrioritization
        var cueValue: String?

        if quality != nil && capabilities.canSetPhotoQualityPrioritization == false {
            status = .adjusted
            quality = nil
            gaps.append("photo_quality_prioritization_unavailable")
            substitutions.append(substitution("photoQualityPrioritization", requested: true, used: false, status: .adjusted, reason: "Photo quality prioritization is unavailable."))
            commands.append(command(.capture, "configure_capture_quality", recommendation.photoQualityPrioritization, quality, .adjusted, "photo_quality_prioritization_unavailable"))
        } else {
            commands.append(command(.capture, "configure_capture_quality", recommendation.photoQualityPrioritization, quality, .applied, nil))
        }
        if burst != nil && capabilities.canCaptureBurst == false {
            status = status == .applied ? .adjusted : status
            burst = nil
            gaps.append("burst_unavailable")
            substitutions.append(substitution("burst", requested: true, used: false, status: .adjusted, reason: "Burst capture is unavailable."))
            commands.append(command(.capture, "configure_burst", recommendation.burstCount.map { String($0) }, nil, .adjusted, "burst_unavailable"))
        } else {
            commands.append(command(.capture, "configure_burst", recommendation.burstCount.map { String($0) }, burst.map { String($0) }, .applied, nil))
        }
        if highResolution == true && capabilities.canUseHighestPracticalResolution == false {
            status = status == .applied ? .adjusted : status
            highResolution = false
            gaps.append("high_resolution_unavailable")
            substitutions.append(substitution("highestPracticalResolution", requested: true, used: false, status: .adjusted, reason: "Highest practical resolution is unavailable."))
            commands.append(command(.capture, "configure_high_resolution", recommendation.highestPracticalResolution.map { String($0) }, String(false), .adjusted, "high_resolution_unavailable"))
        } else {
            commands.append(command(.capture, "configure_high_resolution", recommendation.highestPracticalResolution.map { String($0) }, highResolution.map { String($0) }, .applied, nil))
        }
        if status == .adjusted && recommendation.captureResponsiveness == "fast" && burst == nil {
            status = .needsOperatorAdjustment
            cueValue = "Hold the phone steady for a single best frame."
        }

        return GroupResult(
            adjustment: cameraAdjustment(
                status: status,
                reason: gaps.isEmpty ? nil : "Capture mode fallback required.",
                capabilityGap: gaps.first,
                cue: cueValue,
                burstCount: burst,
                highestPracticalResolution: highResolution,
                photoQualityPrioritization: quality,
                captureResponsiveness: recommendation.captureResponsiveness
            ),
            commands: commands,
            capabilityGaps: Array(Set(gaps)).sorted(),
            substitutions: substitutions,
            operatorCues: cueValue.map { [cue("operator", $0)] } ?? []
        )
    }

    private func flashLowLightAdjustment(
        _ recommendation: SceneRuntimeModels.FlashLowLightRecommendation?,
        capabilities: SceneRuntimeModels.NativeCameraCapabilities
    ) -> GroupResult {
        guard let recommendation else {
            return emptyResult(.flashLowLight, status: .applied)
        }

        var status: SceneRuntimeModels.CameraCapabilityStatus = .applied
        var gaps: [String] = []
        var substitutions: [SceneRuntimeModels.CameraSettingSubstitution] = []
        var flashMode = recommendation.flashMode
        var torchMode: String? = recommendation.torchAllowed == true ? "recovery_only" : "off"
        var cueValue: String?

        if recommendation.flashMode != nil && capabilities.canControlFlash == false {
            status = .unavailable
            flashMode = nil
            gaps.append("flash_policy_unavailable")
            substitutions.append(substitution("flashPolicy", requested: true, used: false, status: .unavailable, reason: "Flash control is unavailable."))
        }
        if recommendation.torchAllowed == true && capabilities.canUseTorch == false {
            status = status == .unavailable ? .unavailable : .needsOperatorAdjustment
            torchMode = nil
            gaps.append("low_light_recovery_unavailable")
            substitutions.append(substitution("torchRecovery", requested: true, used: false, status: status, reason: "Torch low-light recovery is unavailable."))
            cueValue = "Move toward brighter natural light."
        }

        return GroupResult(
            adjustment: cameraAdjustment(
                status: status,
                reason: gaps.isEmpty ? nil : "Flash or low-light recovery fallback required.",
                capabilityGap: gaps.first,
                cue: cueValue,
                flashMode: flashMode,
                torchMode: torchMode
            ),
            commands: [
                command(.flashLowLight, "configure_flash_low_light", recommendation.flashMode, flashMode, status, gaps.first)
            ],
            capabilityGaps: Array(Set(gaps)).sorted(),
            substitutions: substitutions,
            operatorCues: cueValue.map { [cue("operator", $0)] } ?? []
        )
    }

    private func emptyResult(
        _ group: NativeCameraParameterGroup,
        status: SceneRuntimeModels.CameraCapabilityStatus
    ) -> GroupResult {
        GroupResult(
            adjustment: cameraAdjustment(status: status),
            commands: [
                command(group, "noop", nil, nil, status, nil)
            ],
            capabilityGaps: [],
            substitutions: [],
            operatorCues: []
        )
    }

    private func closestLens(preferred: String, available: [String]) -> String {
        if preferred == "tele", available.contains("wide") {
            return "wide"
        }
        if preferred == "ultra_wide", available.contains("wide") {
            return "wide"
        }
        return available.first ?? preferred
    }

    private func command(
        _ group: NativeCameraParameterGroup,
        _ operation: String,
        _ requestedValue: String?,
        _ resolvedValue: String?,
        _ status: SceneRuntimeModels.CameraCapabilityStatus,
        _ capabilityGap: String?
    ) -> NativeCameraCommand {
        NativeCameraCommand(
            group: group,
            operation: operation,
            requestedValue: requestedValue,
            resolvedValue: resolvedValue,
            status: status,
            capabilityGap: capabilityGap
        )
    }

    private func cue(_ target: String, _ message: String) -> SceneRuntimeModels.CoachingCue {
        SceneRuntimeModels.CoachingCue(target: target, message: message)
    }

    private func substitution(
        _ parameter: String,
        requested: Bool?,
        used: Bool?,
        status: SceneRuntimeModels.CameraCapabilityStatus,
        reason: String
    ) -> SceneRuntimeModels.CameraSettingSubstitution {
        SceneRuntimeModels.CameraSettingSubstitution(
            parameter: parameter,
            requested: requested,
            used: used,
            status: status,
            reason: reason
        )
    }

    private func cameraAdjustment(
        status: SceneRuntimeModels.CameraCapabilityStatus,
        reason: String? = nil,
        capabilityGap: String? = nil,
        lockedOn: [String]? = nil,
        adjustment: String? = nil,
        meteringTarget: String? = nil,
        bias: Double? = nil,
        mode: String? = nil,
        temperatureBias: String? = nil,
        portraitBlurStrength: Double? = nil,
        depthDataDelivery: Bool? = nil,
        portraitEffectsMatteDelivery: Bool? = nil,
        lensUsed: String? = nil,
        zoomFactor: Double? = nil,
        cue: String? = nil,
        shootWide: Bool? = nil,
        burstCount: Int? = nil,
        highestPracticalResolution: Bool? = nil,
        photoQualityPrioritization: String? = nil,
        captureResponsiveness: String? = nil,
        flashMode: String? = nil,
        torchMode: String? = nil
    ) -> SceneRuntimeModels.CameraAdjustment {
        SceneRuntimeModels.CameraAdjustment(
            status: status,
            value: nil,
            reason: reason,
            capabilityGap: capabilityGap,
            lockedOn: lockedOn,
            adjustment: adjustment,
            meteringTarget: meteringTarget,
            bias: bias,
            mode: mode,
            temperatureBias: temperatureBias,
            portraitBlurStrength: portraitBlurStrength,
            depthDataDelivery: depthDataDelivery,
            portraitEffectsMatteDelivery: portraitEffectsMatteDelivery,
            lensUsed: lensUsed,
            zoomFactor: zoomFactor,
            cue: cue,
            shootWide: shootWide,
            burstCount: burstCount,
            highestPracticalResolution: highestPracticalResolution,
            photoQualityPrioritization: photoQualityPrioritization,
            captureResponsiveness: captureResponsiveness,
            flashMode: flashMode,
            torchMode: torchMode
        )
    }
}

private struct GroupResult {
    let adjustment: SceneRuntimeModels.CameraAdjustment
    let commands: [NativeCameraCommand]
    let capabilityGaps: [String]
    let substitutions: [SceneRuntimeModels.CameraSettingSubstitution]
    let operatorCues: [SceneRuntimeModels.CoachingCue]
}
