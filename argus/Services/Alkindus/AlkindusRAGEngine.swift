import Foundation

// MARK: - Alkindus RAG Engine
/// Retrieval-Augmented Generation engine for Alkindus learning system.
/// Syncs learning data to Pinecone and enables semantic search.

@MainActor
final class AlkindusRAGEngine {
    static let shared = AlkindusRAGEngine()
    
    private let pinecone = PineconeService.shared
    private let embedding = GeminiEmbeddingService.shared
    
    // Namespaces
    private let indicatorNamespace = "indicators"
    private let patternNamespace = "patterns"
    private let decisionNamespace = "decisions"
    private let symbolNamespace = "symbols"
    private let chironNamespace = "chiron"
    
    // Trade Brain 3.0 Namespaces
    static let eventNamespace = "market_events"
    static let regimeNamespace = "regime_memory"
    static let horizonNamespace = "horizon_decisions"
    static let contradictionNamespace = "contradictions"
    static let calibrationNamespace = "confidence_calibration"
    
    private init() {}
    
    // MARK: - Data Models
    
    struct RAGDocument {
        let id: String
        let content: String
        let metadata: [String: String]
    }
    
    struct RAGSearchResult {
        let id: String
        let content: String
        let score: Float
        let metadata: [String: String]
    }
    
    // MARK: - Trade Brain 3.0 Data Models
    
    struct CalibratedConfidence: Codable {
        let raw: Double
        let calibrated: Double
        let bucket: String
        let historicalWinRate: Double
        let sampleSize: Int
    }
    
    // MARK: - Sync Methods
    
    /// Sync indicator learning to vector DB
    func syncIndicatorLearning(
        indicator: String,
        symbol: String,
        condition: String,
        wasSuccess: Bool,
        gain: Double
    ) async {
        let text = """
        İndikatör: \(indicator)
        Sembol: \(symbol)
        Koşul: \(condition)
        Sonuç: \(wasSuccess ? "Başarılı" : "Başarısız")
        Kazanç: %\(String(format: "%.2f", gain))
        """
        
        let id = "\(indicator)_\(symbol)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "indicator",
                "indicator": indicator,
                "symbol": symbol,
                "success": wasSuccess ? "true" : "false",
                "gain": String(format: "%.2f", gain)
            ],
            namespace: indicatorNamespace
        )
    }
    
    /// Sync pattern learning to vector DB
    func syncPatternLearning(
        pattern: String,
        symbol: String,
        wasSuccess: Bool,
        gain: Double,
        holdingDays: Double
    ) async {
        let text = """
        Formasyon: \(pattern)
        Sembol: \(symbol)
        Sonuç: \(wasSuccess ? "Başarılı" : "Başarısız")
        Kazanç: %\(String(format: "%.2f", gain))
        Tutma süresi: \(Int(holdingDays)) gün
        """
        
        let id = "\(pattern)_\(symbol)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "pattern",
                "pattern": pattern,
                "symbol": symbol,
                "success": wasSuccess ? "true" : "false",
                "gain": String(format: "%.2f", gain),
                "holdingDays": String(Int(holdingDays))
            ],
            namespace: patternNamespace
        )
    }
    
    /// Sync decision event to vector DB
    func syncDecision(
        symbol: String,
        action: String,
        confidence: Double,
        reasoning: String,
        outcome: String?
    ) async {
        var text = """
        Karar: \(action) \(symbol)
        Güven: %\(Int(confidence * 100))
        Gerekçe: \(reasoning)
        """
        
        if let outcome = outcome {
            text += "\nSonuç: \(outcome)"
        }
        
        let id = "decision_\(symbol)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "decision",
                "symbol": symbol,
                "action": action,
                "confidence": String(format: "%.2f", confidence)
            ],
            namespace: decisionNamespace
        )
    }
    
    /// Sync Chiron trade outcome to vector DB
    func syncChironTrade(
        id: String,
        symbol: String,
        engine: String,
        entryPrice: Double,
        exitPrice: Double,
        pnlPercent: Double,
        holdingDays: Int,
        orionScore: Double?,
        atlasScore: Double?,
        regime: String?
    ) async {
        let text = """
        Trade: \(symbol) | Engine: \(engine)
        Entry: \(String(format: "%.2f", entryPrice)) → Exit: \(String(format: "%.2f", exitPrice))
        PnL: \(String(format: "%.2f", pnlPercent))% | Duration: \(holdingDays) gün
        Orion: \(orionScore.map { String(format: "%.1f", $0) } ?? "N/A")
        Atlas: \(atlasScore.map { String(format: "%.1f", $0) } ?? "N/A")
        Rejim: \(regime ?? "Bilinmiyor")
        """
        
        let vectorId = "chiron_trade_\(id)"
        
        await upsertDocument(
            id: vectorId,
            content: text,
            metadata: [
                "type": "chiron_trade",
                "symbol": symbol,
                "engine": engine,
                "pnl": String(format: "%.2f", pnlPercent),
                "result": pnlPercent > 0 ? "win" : "loss"
            ],
            namespace: chironNamespace
        )
        
        print("🧠 Chiron RAG: Trade synced for \(symbol)")
    }
    
    /// Sync Chiron learning event to vector DB
    func syncChironLearning(
        symbol: String,
        engine: String,
        reasoning: String,
        confidence: Double
    ) async {
        let text = """
        Öğrenme: \(symbol) | Engine: \(engine)
        Gerekçe: \(reasoning)
        Güven: \(String(format: "%.0f", confidence * 100))%
        """
        
        let id = "chiron_learning_\(symbol)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "chiron_learning",
                "symbol": symbol,
                "engine": engine,
                "confidence": String(format: "%.2f", confidence)
            ],
            namespace: chironNamespace
        )
    }
    
    // MARK: - Query Methods
    
    /// Search for similar experiences
    func search(query: String, namespace: String? = nil, topK: Int = 5) async -> [RAGSearchResult] {
        do {
            // Get embedding for query
            let queryVector = try await embedding.embed(text: query)
            
            // Search in specified namespace or all
            let ns = namespace ?? "default"
            let matches = try await pinecone.query(vector: queryVector, topK: topK, namespace: ns)
            
            return matches.map { match in
                RAGSearchResult(
                    id: match.id,
                    content: match.metadata?["content"] ?? "",
                    score: match.score,
                    metadata: match.metadata ?? [:]
                )
            }
        } catch {
            print("❌ RAG search error: \(error)")
            return []
        }
    }
    
    /// Search for indicator experiences
    func searchIndicatorExperiences(indicator: String, symbol: String) async -> [RAGSearchResult] {
        let query = "\(indicator) indikatörü \(symbol) hissesinde nasıl performans gösterdi?"
        return await search(query: query, namespace: indicatorNamespace, topK: 10)
    }
    
    /// Search for pattern experiences
    func searchPatternExperiences(pattern: String, symbol: String) async -> [RAGSearchResult] {
        let query = "\(pattern) formasyonu \(symbol) hissesinde işe yaradı mı?"
        return await search(query: query, namespace: patternNamespace, topK: 10)
    }
    
    /// Search for decision history
    func searchDecisionHistory(symbol: String, context: String) async -> [RAGSearchResult] {
        let query = "\(symbol) hissesi için geçmiş kararlar: \(context)"
        return await search(query: query, namespace: decisionNamespace, topK: 10)
    }
    
    /// Get contextual advice based on historical data
    func getContextualAdvice(symbol: String, currentSituation: String) async -> String {
        let results = await search(query: "\(symbol): \(currentSituation)", topK: 5)
        
        if results.isEmpty {
            return "Bu durum için yeterli geçmiş veri yok."
        }
        
        let insights = results.prefix(3).map { result in
            "• \(result.content) (Benzerlik: %\(Int(result.score * 100)))"
        }.joined(separator: "\n")
        
        return """
        Geçmiş Deneyimler:
        \(insights)
        """
    }
    
    // MARK: - Trade Brain 3.0 Sync Methods
    
    /// Sync event outcome to vector DB
    func syncEventOutcome(
        eventType: String,
        symbol: String,
        context: String,
        outcome: String,
        priceImpact: Double
    ) async {
        let text = """
        Olay: \(eventType) - \(symbol)
        Bağlam: \(context)
        Sonuç: \(outcome), Etki: \(String(format: "%.2f", priceImpact))%
        """
        
        let id = "event_\(eventType)_\(symbol)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "event",
                "event_type": eventType,
                "symbol": symbol,
                "outcome": outcome,
                "impact": String(format: "%.2f", priceImpact)
            ],
            namespace: Self.eventNamespace
        )
    }
    
    /// Sync regime performance to vector DB
    func syncRegimePerformance(
        regime: String,
        vixBucket: String,
        avgReturn: Double,
        winRate: Double,
        sampleSize: Int
    ) async {
        let text = """
        Rejim: \(regime)
        VIX Aralığı: \(vixBucket)
        Ortalama Getiri: \(String(format: "%.2f", avgReturn))%
        Başarı Oranı: \(String(format: "%.0f", winRate * 100))%
        Örnek Sayısı: \(sampleSize)
        """
        
        let id = "regime_\(regime)_\(vixBucket)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "regime",
                "regime": regime,
                "vix_bucket": vixBucket,
                "win_rate": String(format: "%.2f", winRate),
                "sample_size": "\(sampleSize)"
            ],
            namespace: Self.regimeNamespace
        )
    }
    
    /// Sync horizon decision outcome to vector DB
    func syncHorizonOutcome(
        symbol: String,
        timeframe: String,
        action: String,
        confidence: Double,
        outcome: String,
        pnlPercent: Double
    ) async {
        let text = """
        Sembol: \(symbol)
        Zaman Dilimi: \(timeframe)
        Karar: \(action) - Güven: \(String(format: "%.0f", confidence * 100))%
        Sonuç: \(outcome) - PnL: \(String(format: "%.2f", pnlPercent))%
        """
        
        let id = "horizon_\(symbol)_\(timeframe)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "horizon",
                "symbol": symbol,
                "timeframe": timeframe,
                "action": action,
                "outcome": outcome,
                "pnl": String(format: "%.2f", pnlPercent)
            ],
            namespace: Self.horizonNamespace
        )
    }
    
    /// Sync contradiction record to vector DB
    func syncContradiction(
        symbol: String,
        module1: String,
        stance1: String,
        module2: String,
        stance2: String,
        finalDecision: String,
        outcome: String,
        pnlPercent: Double
    ) async {
        let text = """
        Çelişki: \(symbol)
        \(module1): \(stance1) vs \(module2): \(stance2)
        Nihai Karar: \(finalDecision)
        Sonuç: \(outcome) - PnL: \(String(format: "%.2f", pnlPercent))%
        """
        
        let id = "contradiction_\(symbol)_\(module1)_\(module2)_\(Date().timeIntervalSince1970)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "contradiction",
                "symbol": symbol,
                "module1": module1,
                "module2": module2,
                "outcome": outcome,
                "pnl": String(format: "%.2f", pnlPercent)
            ],
            namespace: Self.contradictionNamespace
        )
    }
    
    /// Sync calibration bucket to vector DB
    func syncCalibrationBucket(
        bucket: String,
        actualWinRate: Double,
        sampleSize: Int
    ) async {
        let text = """
        Confidence Aralığı: \(bucket)
        Gerçek Başarı: \(String(format: "%.0f", actualWinRate * 100))%
        Örnek Sayısı: \(sampleSize)
        """
        
        let id = "calib_\(bucket)"
        
        await upsertDocument(
            id: id,
            content: text,
            metadata: [
                "type": "calibration",
                "bucket": bucket,
                "actual_win_rate": String(format: "%.2f", actualWinRate),
                "sample_size": "\(sampleSize)"
            ],
            namespace: Self.calibrationNamespace
        )
    }
    
    // MARK: - Trade Brain 3.0 Query Methods
    
    /// Search for similar event outcomes
    func searchEventExperiences(eventType: String, context: String) async -> [RAGSearchResult] {
        let query = "Olay: \(eventType), Bağlam: \(context)"
        return await search(query: query, namespace: Self.eventNamespace, topK: 5)
    }
    
    /// Search for regime history
    func searchRegimeHistory(regime: String, vixBucket: String) async -> [RAGSearchResult] {
        let query = "Rejim: \(regime), VIX: \(vixBucket)"
        return await search(query: query, namespace: Self.regimeNamespace, topK: 3)
    }
    
    /// Search for horizon decision history
    func searchHorizonHistory(symbol: String, timeframe: String) async -> [RAGSearchResult] {
        let query = "\(symbol) \(timeframe) karar geçmişi"
        return await search(query: query, namespace: Self.horizonNamespace, topK: 5)
    }
    
    /// Search for contradiction patterns
    func searchContradictionPatterns(module1: String, module2: String) async -> [RAGSearchResult] {
        let query = "\(module1) vs \(module2) çelişkisi"
        return await search(query: query, namespace: Self.contradictionNamespace, topK: 10)
    }
    
    /// Get calibration for confidence bucket
    func getCalibrationForBucket(_ bucket: String) async -> CalibratedConfidence? {
        let results = await search(query: "Calibration bucket \(bucket)", namespace: Self.calibrationNamespace, topK: 1)
        
        guard let result = results.first,
              let winRateStr = result.metadata["actual_win_rate"],
              let sampleStr = result.metadata["sample_size"],
              let winRate = Double(winRateStr),
              let sampleSize = Int(sampleStr),
              let rawRange = parseBucketRange(bucket) else {
            return nil
        }
        
        return CalibratedConfidence(
            raw: (rawRange.lowerBound + rawRange.upperBound) / 2,
            calibrated: winRate,
            bucket: bucket,
            historicalWinRate: winRate,
            sampleSize: sampleSize
        )
    }
    
    private func parseBucketRange(_ bucket: String) -> ClosedRange<Double>? {
        let parts = bucket.split(separator: "-")
        guard parts.count == 2,
              let lower = Double(parts[0]),
              let upper = Double(parts[1]) else { return nil }
        return lower...upper
    }
    
    // MARK: - Private Helpers

    private func upsertDocument(id: String, content: String, metadata: [String: String], namespace: String) async {
        do {
            try await upsertDocument(namespace: namespace, id: id, text: content, metadata: metadata)
        } catch {
            print("❌ RAG upsert error: \(error)")

            // Enqueue for retry
            let failedSync = AlkindusSyncRetryQueue.FailedSync(
                id: UUID(),
                namespace: namespace,
                documentId: id,
                text: content,
                metadata: metadata,
                failedAt: Date(),
                retryCount: 0
            )
            await AlkindusSyncRetryQueue.shared.enqueue(failedSync)
        }
    }

    // MARK: - Public Upsert (for retry queue)

    /// Public upsert method for retry queue access
    /// - Throws: Error if embedding or Pinecone upsert fails
    func upsertDocument(namespace: String, id: String, text: String, metadata: [String: String]) async throws {
        // Get embedding
        let values = try await embedding.embed(text: text)

        // Add content to metadata for retrieval
        var enrichedMetadata = metadata
        enrichedMetadata["content"] = text
        enrichedMetadata["timestamp"] = ISO8601DateFormatter().string(from: Date())

        // Upsert to Pinecone
        let vector = PineconeService.Vector(
            id: id,
            values: values,
            metadata: enrichedMetadata
        )

        let count = try await pinecone.upsert(vectors: [vector], namespace: namespace)
        print("✅ RAG: Upserted \(count) vector(s) to \(namespace)")
    }
    
    // MARK: - Bulk Sync
    
    /// Sync all existing Alkindus data to vector DB
    func syncAllExistingData() async {
        print("🔄 RAG: Starting bulk sync...")
        
        // This would read from existing JSON files and sync to Pinecone
        // For now, we'll just log that it needs to be implemented per data source
        
        print("ℹ️ RAG: Bulk sync should be triggered after learning data is generated")
    }
    
    // MARK: - Stats
    
    struct RAGStats {
        var indicatorCount: Int = 0
        var patternCount: Int = 0
        var decisionCount: Int = 0
        var lastSync: Date?
    }
    
    func getStats() async -> RAGStats {
        // In production, this would query Pinecone for namespace stats
        return RAGStats(lastSync: Date())
    }
}
