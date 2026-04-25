import Foundation

// MARK: - Pinecone Service
/// Pinecone Vector Database API client for RAG system.
///
/// Multi-tenant not: Aboneler kendi Pinecone hesaplarını açıp kendi index'lerini
/// kuruyorlar (test-embedding-004 → 768 boyut). Dolayısıyla hem API key hem de
/// serverless endpoint URL'i Secrets.xcconfig üzerinden okunur. Hardcode'lu URL
/// geçmişte buradaydı (`alkindus-8mzyr4k...`) — geliştirici hesabıma bağımlıydı,
/// başkası çalıştıramıyordu. Şimdi `PINECONE_BASE_URL` boşsa servis `.notConfigured`
/// döner, RAG engine graceful degrade eder (sync sessizce atlanır, search boş döner,
/// uygulamanın geri kalanı normal çalışır).

@MainActor
final class PineconeService {
    static let shared = PineconeService()

    /// Serverless Pinecone endpoint URL'i. Secrets.xcconfig → Info.plist → burası.
    /// Boşsa `isConfigured` false olur, tüm çağrılar `.notConfigured` fırlatır.
    /// Örnek format: `https://<index>-<project>.svc.<region>.pinecone.io`
    private var baseURL: String { Secrets.pineconeBaseURL }

    /// Beklenen vektör boyutu. `text-embedding-004` modeli her zaman 768-dim
    /// üretir (`GeminiEmbeddingService`). Index farklı boyutta kurulduysa
    /// upsert request'i Pinecone tarafında 400 ile reddedilir; o noktaya
    /// kadar olan tüm "kuyruk akıyor" sinyalleri yanıltıcı olur. Bu yüzden
    /// ilk network çağrısında `validateIndexDimension()` ile fail-fast.
    static let expectedDimension = 768

    /// `validateIndexDimension()` cache'i. Pinecone serverless index'leri
    /// kullanım ömrü boyunca dimension'ını değiştirmez (sabit boyutlu
    /// kuruluyor); o yüzden tek bir başarılı doğrulama yeterli, sonraki
    /// çağrılar bunu okur. Hata cache'lenir ki ilk hatadan sonra her upsert
    /// aynı describe_index_stats çağrısını tekrar yapmasın.
    private var dimensionValidation: Result<Int, PineconeError>?

    private init() {}

    /// RAG sistemi şu an kullanılabilir mi? Key + URL + parse edilebilir URL şartlarını tarar.
    /// AlkindusRAGEngine bu bayrağı bütün sync/search girişlerinde gate olarak kullanır.
    var isConfigured: Bool {
        guard let apiKey = APIKeyStore.getDirectKey(for: .pinecone),
              !apiKey.isEmpty else {
            return false
        }
        let url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return false }
        return URL(string: url) != nil
    }

    /// Neden yapılandırılmamış? Kullanıcıya / teşhis paneline insan diliyle açıklar.
    /// Nil döndüğünde `isConfigured == true` demektir.
    var configurationFailureReason: String? {
        if APIKeyStore.getDirectKey(for: .pinecone)?.isEmpty ?? true {
            return "PINECONE_KEY Secrets.xcconfig'de boş."
        }
        let url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty {
            return "PINECONE_BASE_URL Secrets.xcconfig'de boş."
        }
        if URL(string: url) == nil {
            return "PINECONE_BASE_URL geçersiz format. Örnek: https://<index>-<project>.svc.<region>.pinecone.io"
        }
        return nil
    }
    
    // MARK: - Models
    
    struct Vector: Codable {
        let id: String
        let values: [Float]
        var metadata: [String: String]?
    }
    
    struct UpsertRequest: Codable {
        let vectors: [Vector]
        let namespace: String?
    }
    
    struct UpsertResponse: Codable {
        let upsertedCount: Int?
    }
    
    struct QueryRequest: Codable {
        let vector: [Float]
        let topK: Int
        let includeMetadata: Bool
        let namespace: String?
    }
    
    struct QueryResponse: Codable {
        let matches: [Match]?
        
        struct Match: Codable {
            let id: String
            let score: Float
            let metadata: [String: String]?
        }
    }
    
    struct DeleteRequest: Codable {
        let ids: [String]?
        let deleteAll: Bool?
        let namespace: String?
    }

    /// Pinecone `/describe_index_stats` yanıtı. `dimension` döndüren minimal
    /// alt küme; `namespaces` / `totalVectorCount` gerekirse genişletilebilir.
    struct IndexStats: Codable {
        let dimension: Int?
        let totalVectorCount: Int?
    }

    // MARK: - API Methods

    /// Pinecone index'in metadata'sını alır. Tek başına çağrı maliyeti düşük
    /// (DB read yok); bu yüzden dimension doğrulaması için kullanılır.
    func describeIndexStats() async throws -> IndexStats {
        struct EmptyBody: Codable {}
        return try await post(endpoint: "/describe_index_stats", body: EmptyBody())
    }

    /// Index dimension'ı `expectedDimension` (768) ile uyuşuyor mu?
    /// İlk başarılı çağrı cache'lenir; sonraki çağrılar network'e dönmez.
    /// Mismatch durumunda `.dimensionMismatch` fırlatılır ki kullanıcı
    /// "ilk upsert 400 aldı, neden?" sürprizini değil "index'iniz 768 değil
    /// 1024 kurulmuş, yeniden oluşturun" mesajını alsın.
    ///
    /// Cache politikası: sadece dimension'a dair sonuçlar (`.success`,
    /// `.dimensionUnknown`, `.dimensionMismatch`) cache'lenir. Network
    /// hataları (auth, timeout, 5xx) propagate eder ama cache'lenmez ki
    /// kullanıcı key'i veya bağlantıyı düzelttiğinde retry başarılı olsun.
    @discardableResult
    func validateIndexDimension(expected: Int = PineconeService.expectedDimension) async throws -> Int {
        if let cached = dimensionValidation {
            return try cached.get()
        }

        let stats = try await describeIndexStats()

        guard let actual = stats.dimension else {
            let error = PineconeError.dimensionUnknown
            dimensionValidation = .failure(error)
            throw error
        }
        guard actual == expected else {
            let error = PineconeError.dimensionMismatch(expected: expected, actual: actual)
            dimensionValidation = .failure(error)
            throw error
        }
        dimensionValidation = .success(actual)
        return actual
    }

    /// Test/diagnostic için cache'i sıfırlar (örn. kullanıcı Secrets.xcconfig'i
    /// güncelleyip yeniden bağlandığında).
    func resetDimensionValidationCache() {
        dimensionValidation = nil
    }

    /// Upsert vectors to Pinecone
    func upsert(vectors: [Vector], namespace: String = "default") async throws -> Int {
        try await validateIndexDimension()
        let request = UpsertRequest(vectors: vectors, namespace: namespace)
        let response: UpsertResponse = try await post(endpoint: "/vectors/upsert", body: request)
        return response.upsertedCount ?? 0
    }
    
    /// Query similar vectors
    func query(vector: [Float], topK: Int = 5, namespace: String = "default") async throws -> [QueryResponse.Match] {
        let request = QueryRequest(vector: vector, topK: topK, includeMetadata: true, namespace: namespace)
        let response: QueryResponse = try await post(endpoint: "/query", body: request)
        return response.matches ?? []
    }
    
    /// Delete vectors by IDs
    func delete(ids: [String], namespace: String = "default") async throws {
        let request = DeleteRequest(ids: ids, deleteAll: false, namespace: namespace)
        let _: [String: String] = try await post(endpoint: "/vectors/delete", body: request)
    }
    
    /// Delete all vectors in namespace
    func deleteAll(namespace: String = "default") async throws {
        let request = DeleteRequest(ids: nil, deleteAll: true, namespace: namespace)
        let _: [String: String] = try await post(endpoint: "/vectors/delete", body: request)
    }
    
    // MARK: - Network Layer
    
    private func post<T: Encodable, R: Decodable>(endpoint: String, body: T) async throws -> R {
        // Guard 1: Yapılandırma eksikliği. `isConfigured` false ise kullanıcı
        // Pinecone hesabını Secrets.xcconfig'e eklememiş demektir. Sessiz üretim
        // hatalarına neden olmasın diye burada net bir `.notConfigured` fırlat —
        // caller (AlkindusRAGEngine) bunu yakalayıp UI'a disabled state gösterir.
        guard isConfigured else {
            throw PineconeError.notConfigured(configurationFailureReason ?? "Pinecone yapılandırması eksik.")
        }

        guard let apiKey = APIKeyStore.getDirectKey(for: .pinecone) else {
            throw PineconeError.missingAPIKey
        }

        guard let url = URL(string: baseURL + endpoint) else {
            throw PineconeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PineconeError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            ServiceHealthMonitor.shared.reportSuccess(provider: .pinecone)
            return try JSONDecoder().decode(R.self, from: data)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            ServiceHealthMonitor.shared.reportError(provider: .pinecone, error: PineconeError.apiError(httpResponse.statusCode, errorMessage))
            throw PineconeError.apiError(httpResponse.statusCode, errorMessage)
        }
    }
}

// MARK: - Errors

enum PineconeError: Error, LocalizedError, Equatable {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    /// Kullanıcı Pinecone hesabı/endpoint'i Secrets'e eklememiş. Uygulamanın
    /// kendi açığı değil, RAG öğrenme opsiyonel. Engine bunu yakalayınca
    /// işlemi sessizce atlar, "RAG devre dışı" bilgisini UI'a iletir.
    case notConfigured(String)
    /// Index `dimension` Pinecone'dan dönmedi. API yanıtı eksik; muhtemelen
    /// describe_index_stats yetkisi yok ya da serverless variant farklı
    /// shape döndürüyor. Operasyonel bir sürpriz, kullanıcıya bildir.
    case dimensionUnknown
    /// Index `dimension` beklenen `expected` değerinden farklı. README Adım
    /// 5'in en yaygın kurulum hatası: kullanıcı 1024/1536 kurmuş.
    /// `text-embedding-004` 768 üretir, mismatch durumunda upsert 400 alır.
    case dimensionMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Pinecone API key bulunamadı"
        case .invalidURL:
            return "Geçersiz URL"
        case .invalidResponse:
            return "Geçersiz yanıt"
        case .apiError(let code, let message):
            return "Pinecone hatası (\(code)): \(message)"
        case .notConfigured(let reason):
            return "Pinecone yapılandırılmamış: \(reason)"
        case .dimensionUnknown:
            return "Pinecone index dimension'ı okunamadı. describe_index_stats yanıtı eksik veya yetki yok."
        case .dimensionMismatch(let expected, let actual):
            return "Pinecone index dimension'ı \(actual), beklenen \(expected). text-embedding-004 modeli \(expected)-dim üretir; index'i bu boyutta yeniden oluşturmalısın (README Adım 5)."
        }
    }
}
