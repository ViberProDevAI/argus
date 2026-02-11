import Foundation

// MARK: - Alkindus Sync Retry Queue
/// Stores failed RAG sync operations for retry.
/// Actor-based thread-safe implementation with persistence.

actor AlkindusSyncRetryQueue {
    static let shared = AlkindusSyncRetryQueue()

    // MARK: - Data Model

    struct FailedSync: Codable, Identifiable {
        let id: UUID
        let namespace: String
        let documentId: String
        let text: String
        let metadata: [String: String]
        let failedAt: Date
        var retryCount: Int
    }

    // MARK: - Properties

    private var queue: [FailedSync] = []
    private let maxRetries = 3

    // Fix #1: Safe file path with guard let instead of force-unwrap
    private let queuePath: URL? = {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent("alkindus_sync_retry_queue.json")
    }()

    // Fix #2: Lazy loading instead of Task in init
    private var hasLoaded = false

    // Fix #5: Guard against concurrent processRetryQueue calls
    private var isProcessing = false

    // MARK: - Initialization

    // Fix #2: Removed Task from init - using lazy loading instead
    init() {
        // No async work in init
    }

    // Fix #2: Ensure queue is loaded before any operation
    private func ensureLoaded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadFromDisk()
    }

    // MARK: - Public Methods

    /// Add a failed sync to the retry queue
    func enqueue(_ sync: FailedSync) async {
        await ensureLoaded()
        queue.append(sync)
        await saveToDisk()
        print("Warning: Alkindus RAG: Sync added to queue (\(queue.count) pending)")
    }

    /// Process all queued syncs with retry logic
    func processRetryQueue() async {
        // Fix #5: Guard against concurrent calls
        guard !isProcessing else {
            print("Info: Alkindus RAG: Retry queue already being processed, skipping")
            return
        }
        isProcessing = true
        defer { isProcessing = false }

        await ensureLoaded()
        guard !queue.isEmpty else { return }

        print("Info: Alkindus RAG: Processing retry queue (\(queue.count) pending)")

        var successfulIndices: Set<Int> = []

        // Fix #4: Use indexed loop for proper mutation
        for i in queue.indices {
            // Fix #6: Exponential backoff between retries
            if queue[i].retryCount > 0 {
                let backoffSeconds = pow(2.0, Double(queue[i].retryCount))
                try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
            }

            do {
                try await AlkindusRAGEngine.shared.upsertDocument(
                    namespace: queue[i].namespace,
                    id: queue[i].documentId,
                    text: queue[i].text,
                    metadata: queue[i].metadata
                )
                print("Success: Alkindus RAG: Retry successful - \(queue[i].documentId)")
                successfulIndices.insert(i)
            } catch {
                // Fix #4: Mutate array element directly via index
                queue[i].retryCount += 1
                if queue[i].retryCount >= maxRetries {
                    print("Error: Alkindus RAG: Max retries exceeded, removing - \(queue[i].documentId)")
                    successfulIndices.insert(i) // Remove from queue
                } else {
                    print("Warning: Alkindus RAG: Retry \(queue[i].retryCount)/\(maxRetries) - \(queue[i].documentId)")
                }
            }
        }

        // Remove successful and max-retried items (iterate in reverse to maintain indices)
        for i in successfulIndices.sorted().reversed() {
            queue.remove(at: i)
        }

        await saveToDisk()

        if queue.isEmpty {
            print("Success: Alkindus RAG: Retry queue fully processed")
        } else {
            print("Warning: Alkindus RAG: \(queue.count) syncs still pending")
        }
    }

    /// Get current queue count
    func queueCount() async -> Int {
        await ensureLoaded()
        return queue.count
    }

    /// Check if queue has pending items
    func hasPendingItems() async -> Bool {
        await ensureLoaded()
        return !queue.isEmpty
    }

    // MARK: - Persistence

    // Fix #3: Proper error handling with logging for unavailable path
    private func saveToDisk() async {
        guard let path = queuePath else {
            print("Error: AlkindusSyncRetryQueue: Cannot save - path unavailable")
            return
        }

        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: path)
        } catch {
            print("Error: Alkindus RAG: Failed to save retry queue: \(error)")
        }
    }

    // Fix #3: Proper error handling with logging for unavailable path
    private func loadFromDisk() async {
        guard let path = queuePath else {
            print("Error: AlkindusSyncRetryQueue: Cannot load - path unavailable")
            return
        }

        guard FileManager.default.fileExists(atPath: path.path) else { return }

        do {
            let data = try Data(contentsOf: path)
            queue = try JSONDecoder().decode([FailedSync].self, from: data)
            if !queue.isEmpty {
                print("Info: Alkindus RAG: Loaded \(queue.count) pending syncs from disk")
            }
        } catch {
            print("Error: Alkindus RAG: Failed to load retry queue: \(error)")
        }
    }
}
