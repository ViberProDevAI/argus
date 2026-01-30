import Foundation

// MARK: - Gemini Embedding Service
/// Converts text to vector embeddings using Gemini's embedding model.

@MainActor
final class GeminiEmbeddingService {
    static let shared = GeminiEmbeddingService()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "models/embedding-001"
    
    private init() {}
    
    // MARK: - Models
    
    struct EmbedRequest: Codable {
        let model: String
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
            
            struct Part: Codable {
                let text: String
            }
        }
    }
    
    struct EmbedResponse: Codable {
        let embedding: Embedding?
        
        struct Embedding: Codable {
            let values: [Float]
        }
    }
    
    struct BatchEmbedRequest: Codable {
        let requests: [EmbedContentRequest]
        
        struct EmbedContentRequest: Codable {
            let model: String
            let content: EmbedRequest.Content
        }
    }
    
    struct BatchEmbedResponse: Codable {
        let embeddings: [EmbedResponse.Embedding]?
    }
    
    // MARK: - API Methods
    
    /// Get embedding for a single text
    func embed(text: String) async throws -> [Float] {
        guard let apiKey = APIKeyStore.getDirectKey(for: .gemini) else {
            throw EmbeddingError.missingAPIKey
        }
        
        let url = URL(string: "\(baseURL)/\(model):embedContent?key=\(apiKey)")!
        
        let request = EmbedRequest(
            model: model,
            content: .init(parts: [.init(text: text)])
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError(errorMessage)
        }
        
        let embedResponse = try JSONDecoder().decode(EmbedResponse.self, from: data)
        
        guard let values = embedResponse.embedding?.values else {
            throw EmbeddingError.noEmbedding
        }
        
        return values
    }
    
    /// Get embeddings for multiple texts (batch)
    func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard let apiKey = APIKeyStore.getDirectKey(for: .gemini) else {
            throw EmbeddingError.missingAPIKey
        }
        
        let url = URL(string: "\(baseURL)/\(model):batchEmbedContents?key=\(apiKey)")!
        
        let requests = texts.map { text in
            BatchEmbedRequest.EmbedContentRequest(
                model: model,
                content: .init(parts: [.init(text: text)])
            )
        }
        
        let batchRequest = BatchEmbedRequest(requests: requests)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(batchRequest)
        urlRequest.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError(errorMessage)
        }
        
        let batchResponse = try JSONDecoder().decode(BatchEmbedResponse.self, from: data)
        
        guard let embeddings = batchResponse.embeddings else {
            throw EmbeddingError.noEmbedding
        }
        
        return embeddings.map { $0.values }
    }
}

// MARK: - Errors

enum EmbeddingError: Error, LocalizedError {
    case missingAPIKey
    case apiError(String)
    case noEmbedding
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key bulunamadı"
        case .apiError(let message):
            return "Embedding hatası: \(message)"
        case .noEmbedding:
            return "Embedding alınamadı"
        }
    }
}
