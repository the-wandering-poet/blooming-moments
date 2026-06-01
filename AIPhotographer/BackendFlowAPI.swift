import Foundation

protocol CaptureGuidanceAPI {
    func createGuidance(request: GuidanceRequest) throws -> GuidanceResponse
    func saveCaptureSession(response: GuidanceResponse, guidedImagePath: String, editedImagePath: String, notes: [String]) throws -> CaptureSessionRecord
}

struct LocalCaptureGuidanceAPI: CaptureGuidanceAPI {
    let backend: GuidedCaptureBackend

    func createGuidance(request: GuidanceRequest) throws -> GuidanceResponse {
        try backend.buildGuidance(request: request)
    }

    func saveCaptureSession(response: GuidanceResponse, guidedImagePath: String, editedImagePath: String, notes: [String]) throws -> CaptureSessionRecord {
        let record = CaptureSessionRecord(
            id: UUID(),
            response: response,
            guidedImagePath: guidedImagePath,
            editedImagePath: editedImagePath,
            notes: notes
        )
        try backend.persistSession(record)
        return record
    }

    static func preview() -> LocalCaptureGuidanceAPI {
        LocalCaptureGuidanceAPI(
            backend: GuidedCaptureBackend.preview(
                persistence: JSONCaptureSessionStore.appSupportStore()
            )
        )
    }
}
