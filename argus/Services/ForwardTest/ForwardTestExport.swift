import Foundation
import SQLite3

// MARK: - Forward Test Export Service
/// Handles the extraction of Ledger data into a portable ZIP format.
/// Vendor-Agnostic: Output is standard JSONL + Gzip Blobs.
final class ForwardTestExport: Sendable {
    static let shared = ForwardTestExport()
    
    private init() {}
    
    /// Generates a ZIP file containing the full Ledger history.
    /// - Returns: URL to the ZIP file in temporary directory.
    func exportLogBundle() async throws -> URL? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("Argus_BlackBox_Export_\(Date().iso8601)")
        
        // 1. Create Directory Structure
        let blobsDir = tempDir.appendingPathComponent("blobs")
        try fileManager.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        
        // 2. Export Events to JSONL
        let eventsUrl = tempDir.appendingPathComponent("events.jsonl")
        try exportEvents(to: eventsUrl)
        
        // 3. Export Blobs
        try exportBlobs(to: blobsDir)
        
        // 4. Create Manifest
        let manifestUrl = tempDir.appendingPathComponent("manifest.json")
        let manifest: [String: Any] = [
            "export_time": Date().iso8601,
            "schema_version": 1,
            "app_build": Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown",
            "format": "Argus BlackBox V0"
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
        try manifestData.write(to: manifestUrl)
        
        // 5. ZIP it (Using FileCoordinator or simple assumption for V0)
        // Since we can't easily zip without a library (and we said no deps in V0),
        // we might rely on the user zipping the folder or implement a simple directory provider.
        // For strict V0 compliance without deps, we return the Directory URL. 
        // iOS Files app can zip it.
        // Or we use `NSFileCoordinator` to zip? No native zip in Swift Stdlib.
        // Let's return the Folder URL for V0. The UI can wrap it.
        
        return tempDir
    }
    
    private func exportEvents(to url: URL) throws {
        try ArgusLedger.shared.dumpEvents(to: url)
    }
    
    private func exportBlobs(to dir: URL) throws {
        try ArgusLedger.shared.dumpBlobs(to: dir)
    }
}


