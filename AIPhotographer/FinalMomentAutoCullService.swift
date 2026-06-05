import Foundation

struct FinalMomentAutoCullServiceRequest: Codable, Equatable {
    let autoCullResultId: String
    let captureResult: FinalMomentCaptureResult
    let frameAssessmentInputs: [FinalMomentFrameAssessmentInput]
}

enum FinalMomentAutoCullServiceError: Error, Equatable, LocalizedError {
    case missingAssessmentInput(frameId: String)
    case duplicateAssessmentInput(frameId: String)
    case protectedSubjectSetMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .missingAssessmentInput(let frameId):
            return "Missing post-capture assessment input for frame: \(frameId)."
        case .duplicateAssessmentInput(let frameId):
            return "Duplicate post-capture assessment input for frame: \(frameId)."
        case .protectedSubjectSetMismatch(let expected, let actual):
            return "Auto-cull protected subject set mismatch. Expected \(expected), got \(actual)."
        }
    }
}

final class FinalMomentAutoCullService {
    private let assessmentAdapter: any FinalMomentPostCaptureAssessmentAdapter
    private let repository: (any FinalMomentRepository)?

    init(
        assessmentAdapter: any FinalMomentPostCaptureAssessmentAdapter = FinalMomentLocalTestAssessmentAdapter(),
        repository: (any FinalMomentRepository)? = nil
    ) {
        self.assessmentAdapter = assessmentAdapter
        self.repository = repository
    }

    func autoCull(_ request: FinalMomentAutoCullServiceRequest) throws -> FinalMomentAutoCullResult {
        let captureResult = request.captureResult
        let inputsByFrameId = try keyedAssessmentInputs(request.frameAssessmentInputs)
        var acceptedFrames: [FinalMomentAcceptedFrame] = []
        var rejectedFrames: [FinalMomentRejectedFrame] = []
        var rejectionReasons: [String: [FinalMomentRejectionReason]] = [:]
        var frameProvenance: [FinalMomentAutoCullFrameProvenance] = []

        for frame in captureResult.frames {
            guard let input = inputsByFrameId[frame.frameId] else {
                throw FinalMomentAutoCullServiceError.missingAssessmentInput(frameId: frame.frameId)
            }

            let assessment = assessmentAdapter.assessFrame(input)
            let protectedSubjectChecks = makeProtectedSubjectChecks(
                input: input,
                assessment: assessment
            )
            let provenance = FinalMomentAutoCullFrameProvenance(
                frameId: frame.frameId,
                cameraSettingsUsedId: input.cameraSettingsUsed.settingsId,
                cameraStatusEvidence: assessment.cameraStatusEvidence.map(\.provenanceNote),
                assessmentConfidence: assessment.confidence,
                assessmentProvenanceNotes: assessment.provenanceNotes
            )
            frameProvenance.append(provenance)

            if assessment.passesCapturePrerequisites {
                acceptedFrames.append(FinalMomentAcceptedFrame(
                    frameId: frame.frameId,
                    assetRef: frame.assetRef,
                    qualityScore: assessment.confidence,
                    expressionScore: expressionScore(from: input),
                    protectedSubjectChecks: protectedSubjectChecks
                ))
            } else {
                let reasons = rejectionReasonsFromAssessment(assessment)
                rejectionReasons[frame.frameId] = reasons
                rejectedFrames.append(FinalMomentRejectedFrame(
                    frameId: frame.frameId,
                    assetRef: frame.assetRef,
                    reasons: reasons,
                    protectedSubjectChecks: protectedSubjectChecks
                ))
            }
        }

        let result = FinalMomentAutoCullResult(
            autoCullResultId: request.autoCullResultId,
            captureResultId: captureResult.captureResultId,
            acceptedFrames: acceptedFrames,
            rejectedFrames: rejectedFrames,
            rejectionReasons: rejectionReasons,
            allFramesRejected: acceptedFrames.isEmpty,
            cameraSettingsUsed: captureResult.cameraSettingsUsed,
            frameProvenance: frameProvenance
        )

        _ = try repository?.upsertAutoCullResultRef(FinalMomentAutoCullResultRefRecord(
            autoCullResultId: result.autoCullResultId,
            captureResultId: result.captureResultId,
            acceptedFrameIds: result.acceptedFrames.map(\.frameId),
            rejectedFrameIds: result.rejectedFrames.map(\.frameId),
            rejectionReasonsByFrame: result.rejectionReasons
        ))

        return result
    }

    func autoCull(
        _ request: FinalMomentAutoCullRequest,
        captureResult: FinalMomentCaptureResult,
        frameAssessmentInputs: [FinalMomentFrameAssessmentInput]
    ) throws -> FinalMomentAutoCullResult {
        guard request.protectedSubjectSetId == captureResult.protectedSubjectSetId else {
            throw FinalMomentAutoCullServiceError.protectedSubjectSetMismatch(
                expected: captureResult.protectedSubjectSetId,
                actual: request.protectedSubjectSetId
            )
        }

        return try autoCull(FinalMomentAutoCullServiceRequest(
            autoCullResultId: "auto_cull_\(captureResult.captureResultId)",
            captureResult: captureResult,
            frameAssessmentInputs: frameAssessmentInputs
        ))
    }

    private func keyedAssessmentInputs(
        _ inputs: [FinalMomentFrameAssessmentInput]
    ) throws -> [String: FinalMomentFrameAssessmentInput] {
        var keyed: [String: FinalMomentFrameAssessmentInput] = [:]
        for input in inputs {
            guard keyed[input.frameId] == nil else {
                throw FinalMomentAutoCullServiceError.duplicateAssessmentInput(frameId: input.frameId)
            }
            keyed[input.frameId] = input
        }
        return keyed
    }

    private func makeProtectedSubjectChecks(
        input: FinalMomentFrameAssessmentInput,
        assessment: FinalMomentFrameAssessment
    ) -> [FinalMomentProtectedSubjectCheck] {
        let assessmentsBySubjectId = Dictionary(uniqueKeysWithValues: assessment.protectedSubjectAssessments.map {
            ($0.subjectId, $0)
        })

        return input.protectedSubjectObservations.map { observation in
            let subjectAssessment = assessmentsBySubjectId[observation.subjectId]
            let faceLightQuality = (subjectAssessment?.faceLightUsable ?? false)
                ? "usable"
                : "unusable"
            let cropProtectionStatus: String
            if observation.protectedSubjectInFrame == false {
                cropProtectionStatus = "protected_subject_missing"
            } else if subjectAssessment?.cropHeadroomPreserved == true {
                cropProtectionStatus = "protectable"
            } else {
                cropProtectionStatus = "unsafe_too_tight"
            }

            return FinalMomentProtectedSubjectCheck(
                frameId: input.frameId,
                subjectId: observation.subjectId,
                eyesOpen: subjectAssessment?.eyesOpen ?? observation.eyesOpen,
                faceSharpness: observation.faceSharpness,
                faceExposure: observation.faceExposure,
                focusUsable: subjectAssessment?.focusUsable ?? false,
                faceExposureUsable: subjectAssessment?.faceExposureUsable ?? false,
                faceLightQuality: faceLightQuality,
                expressionNaturalness: observation.expressionNaturalness,
                interactionPresent: subjectAssessment?.interactionPresent ?? false,
                cropProtectionStatus: cropProtectionStatus,
                protectedSubjectInFrame: subjectAssessment?.protectedSubjectInFrame ?? observation.protectedSubjectInFrame
            )
        }
    }

    private func expressionScore(from input: FinalMomentFrameAssessmentInput) -> Double {
        guard input.protectedSubjectObservations.isEmpty == false else { return 0.0 }
        let total = input.protectedSubjectObservations.map(\.expressionNaturalness).reduce(0.0, +)
        return total / Double(input.protectedSubjectObservations.count)
    }

    private func rejectionReasonsFromAssessment(
        _ assessment: FinalMomentFrameAssessment
    ) -> [FinalMomentRejectionReason] {
        var reasons: [FinalMomentRejectionReason] = []
        for failure in assessment.nonRecoverableFailures {
            switch failure {
            case .missedFocus:
                appendUnique(.protectedSubjectFocusFailed, to: &reasons)
            case .closedEyes:
                appendUnique(.protectedSubjectClosedEyes, to: &reasons)
            case .faceBlur:
                appendUnique(.protectedSubjectFaceBlur, to: &reasons)
            case .unusableFaceLight:
                appendUnique(.protectedSubjectFaceLightUnusable, to: &reasons)
            case .underExposedFace, .overExposedFace:
                appendUnique(.protectedSubjectFaceExposureUnusable, to: &reasons)
            case .deadExpression:
                appendUnique(.deadOrStiffExpression, to: &reasons)
            case .absentInteraction:
                appendUnique(.missingRequiredInteraction, to: &reasons)
            case .tooTightCapture:
                appendUnique(.cropHeadroomNotPreserved, to: &reasons)
            case .protectedSubjectMissing:
                appendUnique(.protectedSubjectMissing, to: &reasons)
            case .missingAsset, .unreadableMetadata:
                appendUnique(.assetUnreadable, to: &reasons)
            case .corruptAsset:
                appendUnique(.burstFrameCorrupt, to: &reasons)
            }
        }

        if reasons.isEmpty && assessment.passesCapturePrerequisites == false {
            appendUnique(.assetUnreadable, to: &reasons)
        }
        return reasons
    }

    private func appendUnique(
        _ reason: FinalMomentRejectionReason,
        to reasons: inout [FinalMomentRejectionReason]
    ) {
        if reasons.contains(reason) == false {
            reasons.append(reason)
        }
    }
}
