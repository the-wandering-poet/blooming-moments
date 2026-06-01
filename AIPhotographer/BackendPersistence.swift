import Foundation

struct JSONCaptureSessionStore: CaptureSessionPersisting {
    let baseURL: URL

    static func appSupportStore(folderName: String = "CaptureSessions") -> JSONCaptureSessionStore {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return JSONCaptureSessionStore(baseURL: root.appendingPathComponent(folderName, isDirectory: true))
    }

    func save(_ session: CaptureSessionRecord) throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let url = baseURL.appendingPathComponent("\(session.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(session).write(to: url)
    }
}

enum DemoArtifactStore {
    static func saveJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url)
    }
}
