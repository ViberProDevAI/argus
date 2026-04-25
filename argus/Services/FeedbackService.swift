import Foundation

// MARK: - Feedback Service
/// Kullanici geri bildirimlerini cihazda saklar.
actor FeedbackService {
    static let shared = FeedbackService()

    struct FeedbackEntry: Codable, Identifiable {
        let id: UUID
        let createdAt: Date
        let type: String
        let message: String
        let appVersion: String?
        let buildNumber: String?
    }

    private static let fileName = "argus_feedback.jsonl"

    private init() {}

    func submit(type: String, message: String) async throws {
        let entry = FeedbackEntry(
            id: UUID(),
            createdAt: Date(),
            type: type,
            message: message,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        )

        try await append(entry)
    }

    // MARK: - Persistence

    private func append(_ entry: FeedbackEntry) async throws {
        let url = getDocumentsDirectory().appendingPathComponent(Self.fileName)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        guard let line = String(data: data, encoding: .utf8) else { return }
        let lineWithNewline = line + "\n"

        if FileManager.default.fileExists(atPath: url.path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
            if let lineData = lineWithNewline.data(using: .utf8) {
                fileHandle.write(lineData)
            }
            fileHandle.closeFile()
        } else {
            try lineWithNewline.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private nonisolated func getDocumentsDirectory() -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory
        }
        return url
    }
}
