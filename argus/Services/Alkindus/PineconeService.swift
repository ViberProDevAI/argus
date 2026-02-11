import Foundation

// MARK: - Pinecone Service
/// Pinecone Vector Database API client for RAG system.

@MainActor
final class PineconeService {
    static let shared = PineconeService()
    
    // Pinecone serverless endpoint
    private let baseURL = "https://alkindus-8mzyr4k.svc.aped-4627-b74a.pinecone.io"
    private let indexName = "alkindus"
    
    private init() {}
    
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
    
    // MARK: - API Methods
    
    /// Upsert vectors to Pinecone
    func upsert(vectors: [Vector], namespace: String = "default") async throws -> Int {
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

enum PineconeError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    
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
        }
    }
}
