import Foundation

// MARK: - Chart Pattern Engine
/// Uses Gemini AI to detect chart patterns from candle data
@MainActor
final class ChartPatternEngine {
    static let shared = ChartPatternEngine()
    
    private var geminiKey: String {
        APIKeyStore.shared.geminiApiKey
    }
    
    private let modelCandidates = [
        "gemini-1.5-pro",
        "gemini-1.0-pro"
    ]
    
    // Rate limiting (15 RPM for free tier = 4 sec interval)
    private var lastRequestTime: Date?
    private let minInterval: TimeInterval = 10.0 // Increased to 10 sec for safety
    
    // CACHING - Aynı sembol için tekrar istek gitmemesi için
    private var cache: [String: (result: ChartPatternAnalysisResult, timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 600 // 10 dakika cache
    
    private init() {}
    
    // MARK: - Public API
    
    /// Analyze candles for chart patterns
    func analyzePatterns(symbol: String, candles: [Candle]) async -> ChartPatternAnalysisResult {
        // CACHE CHECK - Önce cache'e bak
        if let cached = cache[symbol], Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            // print("📦 ChartPattern Cache Hit: \(symbol)")
            return cached.result
        }
        
        // Rate limit check
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minInterval {
                try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
        
        guard candles.count >= 30 else {
            return ChartPatternAnalysisResult(symbol: symbol, patterns: [], error: "Yetersiz veri (min 30 mum)")
        }
        
        // Convert candles to analysis-friendly text
        let candleText = formatCandlesForAnalysis(candles.suffix(60))
        
        // Build prompt
        let prompt = buildPatternPrompt(symbol: symbol, candleData: candleText)
        
        do {
            let response = try await callGemini(prompt: prompt)
            let result = parsePatternResponse(symbol: symbol, response: response)
            // CACHE SAVE - Başarılı sonucu cache'e kaydet
            cache[symbol] = (result: result, timestamp: Date())
            return result
        } catch {
            print("❌ ChartPatternEngine: \(error)")
            return ChartPatternAnalysisResult(symbol: symbol, patterns: [], error: error.localizedDescription)
        }
    }
    
    // MARK: - Candle Formatting
    
    private func formatCandlesForAnalysis(_ candles: ArraySlice<Candle>) -> String {
        var lines: [String] = []
        var prevClose: Double?
        
        // Calculate swing points
        let highs = candles.map { $0.high }
        let lows = candles.map { $0.low }
        let avgRange = zip(highs, lows).map { $0 - $1 }.reduce(0, +) / Double(candles.count)
        
        for (index, candle) in candles.enumerated() {
            let change = prevClose.map { ((candle.close - $0) / $0) * 100 } ?? 0
            let bodySize = abs(candle.close - candle.open)
            let upperWick = candle.high - max(candle.open, candle.close)
            let lowerWick = min(candle.open, candle.close) - candle.low
            
            // Candle type
            var candleType = "NÖTR"
            if candle.close > candle.open {
                candleType = bodySize > avgRange * 0.7 ? "GÜÇLÜ_YEŞİL" : "YEŞİL"
            } else if candle.close < candle.open {
                candleType = bodySize > avgRange * 0.7 ? "GÜÇLÜ_KIRMIZI" : "KIRMIZI"
            }
            
            // Special patterns
            if upperWick > bodySize * 2 && lowerWick < bodySize * 0.5 {
                candleType += "_ÜST_FİTİL"
            } else if lowerWick > bodySize * 2 && upperWick < bodySize * 0.5 {
                candleType += "_ALT_FİTİL"
            }
            
            lines.append("[\(index+1)] H:\(String(format: "%.2f", candle.high)) L:\(String(format: "%.2f", candle.low)) C:\(String(format: "%.2f", candle.close)) (\(String(format: "%+.1f", change))%) [\(candleType)]")
            
            prevClose = candle.close
        }
        
        // Add summary stats
        let recentHigh = highs.max() ?? 0
        let recentLow = lows.min() ?? 0
        let currentPrice = candles.last?.close ?? 0
        let priceRange = recentHigh - recentLow
        let positionInRange = priceRange > 0 ? (currentPrice - recentLow) / priceRange * 100 : 50
        
        let summary = """
        
        ÖZET:
        - Dönem Yüksek: \(String(format: "%.2f", recentHigh))
        - Dönem Düşük: \(String(format: "%.2f", recentLow))
        - Mevcut Fiyat: \(String(format: "%.2f", currentPrice))
        - Range İçi Pozisyon: %\(String(format: "%.0f", positionInRange))
        """
        
        return lines.joined(separator: "\n") + summary
    }
    
    // MARK: - Prompt Building
    
    private func buildPatternPrompt(symbol: String, candleData: String) -> String {
        return """
        Sen bir teknik analiz uzmanısın. Aşağıdaki \(symbol) hissesinin mum verilerini analiz et ve SADECE gördüğün formasyonları bildir.
        
        MUM VERİLERİ (En eski → En yeni):
        \(candleData)
        
        ARANAN FORMASYONLAR:
        1. Double Top (Çift Tepe)
        2. Double Bottom (Çift Dip)
        3. Head & Shoulders (Omuz Baş Omuz)
        4. Inverse Head & Shoulders (Ters OBO)
        5. Ascending Triangle (Yükselen Üçgen)
        6. Descending Triangle (Alçalan Üçgen)
        7. Symmetrical Triangle (Simetrik Üçgen)
        8. Bull Flag (Boğa Bayrağı)
        9. Bear Flag (Ayı Bayrağı)
        10. Cup & Handle (Fincan Kulp)
        11. Wedge (Kama - Rising/Falling)
        
        KURALLAR:
        - Sadece NET gördüğün formasyonları bildir
        - Emin değilsen "patterns_detected" boş array olsun
        - Her formasyon için confidence 0.0-1.0 arası ver
        - stage: "forming" (oluşuyor), "complete" (tamamlandı), "breakout" (kırılım)
        
        JSON formatında döndür:
        {
          "patterns_detected": [
            {
              "name": "Formasyon adı",
              "name_tr": "Türkçe adı",
              "type": "reversal" veya "continuation",
              "bias": "bullish" veya "bearish",
              "confidence": 0.85,
              "stage": "forming",
              "notes": "Kısa açıklama"
            }
          ],
          "overall_trend": "uptrend" veya "downtrend" veya "sideways",
          "key_levels": {
            "resistance": [seviye1, seviye2],
            "support": [seviye1, seviye2]
          }
        }
        """
    }
    
    // MARK: - Gemini API Call
    
    private func callGemini(prompt: String) async throws -> String {
        guard !geminiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 1024
            ]
        ]
        var lastError: Error?
        for version in ["v1beta", "v1"] {
            for model in modelCandidates {
                guard let url = URL(string: "https://generativelanguage.googleapis.com/\(version)/models/\(model):generateContent?key=\(geminiKey)") else { continue }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    struct GeminiResponse: Codable {
                        struct Candidate: Codable {
                            struct Content: Codable {
                                struct Part: Codable {
                                    let text: String?
                                }
                                let parts: [Part]
                            }
                            let content: Content
                        }
                        let candidates: [Candidate]?
                    }
                    
                    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    return geminiResponse.candidates?.first?.content.parts.first?.text ?? ""
                }
                
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
                print("❌ ChartPatternEngine Gemini Error (\(statusCode)) [\(version)/\(model)]: \(errorText)")
                lastError = NSError(domain: "ChartPatternEngine", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API error: \(statusCode)"])
            }
        }
        
        if let lastError {
            throw lastError
        }
        throw URLError(.badServerResponse)
    }
    
    // MARK: - Response Parsing
    
    private func parsePatternResponse(symbol: String, response: String) -> ChartPatternAnalysisResult {
        // Clean JSON
        var str = response
        if str.contains("```json") { str = str.replacingOccurrences(of: "```json", with: "") }
        if str.contains("```") { str = str.replacingOccurrences(of: "```", with: "") }
        
        if let startIndex = str.firstIndex(of: "{"),
           let endIndex = str.lastIndex(of: "}") {
            if startIndex <= endIndex {
                str = String(str[startIndex...endIndex])
            }
        }
        
        guard let jsonData = str.data(using: .utf8) else {
            return ChartPatternAnalysisResult(symbol: symbol, patterns: [], error: "JSON parse hatası")
        }
        
        do {
            let parsed = try JSONDecoder().decode(PatternResponseDTO.self, from: jsonData)
            
            let patterns = parsed.patterns_detected.map { dto in
                DetectedChartPattern(
                    name: dto.name,
                    nameTR: dto.name_tr,
                    type: dto.type == "reversal" ? .reversal : .continuation,
                    bias: dto.bias == "bullish" ? .bullish : .bearish,
                    confidence: dto.confidence,
                    stage: ChartPatternStage(rawValue: dto.stage) ?? .forming,
                    notes: dto.notes
                )
            }
            
            return ChartPatternAnalysisResult(
                symbol: symbol,
                patterns: patterns,
                overallTrend: parsed.overall_trend,
                resistance: parsed.key_levels?.resistance ?? [],
                support: parsed.key_levels?.support ?? [],
                error: nil
            )
        } catch {
            print("❌ ChartPatternEngine Parse: \(error)")
            return ChartPatternAnalysisResult(symbol: symbol, patterns: [], error: "Parse hatası: \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

struct ChartPatternAnalysisResult: Sendable {
    let symbol: String
    let patterns: [DetectedChartPattern]
    var overallTrend: String?
    var resistance: [Double] = []
    var support: [Double] = []
    var error: String?
    
    var hasPatterns: Bool { !patterns.isEmpty }
    var highConfidencePatterns: [DetectedChartPattern] {
        patterns.filter { $0.confidence >= 0.7 }
    }
}

struct DetectedChartPattern: Sendable, Identifiable {
    let id = UUID()
    let name: String
    let nameTR: String
    let type: ChartPatternType
    let bias: ChartPatternBias
    let confidence: Double
    let stage: ChartPatternStage
    let notes: String?
    
    var emoji: String {
        switch bias {
        case .bullish: return "🐂"
        case .bearish: return "🐻"
        }
    }
}

enum ChartPatternType: String, Sendable {
    case reversal
    case continuation
}

enum ChartPatternBias: String, Sendable {
    case bullish
    case bearish
}

enum ChartPatternStage: String, Sendable {
    case forming
    case complete
    case breakout
}

// MARK: - DTO for JSON Parsing

private struct PatternResponseDTO: Codable, Sendable {
    let patterns_detected: [PatternDTO]
    let overall_trend: String?
    let key_levels: KeyLevelsDTO?
}

private struct PatternDTO: Codable, Sendable {
    let name: String
    let name_tr: String
    let type: String
    let bias: String
    let confidence: Double
    let stage: String
    let notes: String?
}

private struct KeyLevelsDTO: Codable, Sendable {
    let resistance: [Double]?
    let support: [Double]?
}
