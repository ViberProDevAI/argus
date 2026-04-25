import Foundation
import Combine

// MARK: - BIST Data Service
// Sorumluluk: BIST hisselerinin fiyat ve grafik verilerini Yahoo Finance'den çekmek.
// API Key gerektirmez (Public Endpoint).

class BistDataService: ObservableObject {
    static let shared = BistDataService()
    
    private let session = URLSession.shared
    private let baseUrl = "https://query1.finance.yahoo.com/v8/finance/chart/"
    
    // Sembol Örneği: "THYAO.IS"
    
    // MARK: - Fetch Quote (Anlık Fiyat)
    // Aslında "1 günlük" grafik isteyip son fiyatı alarak anlık fiyat gibi davranacağız.
    func fetchQuote(symbol: String) async throws -> BistTicker {
        // Yahoo'da BIST hisseleri .IS ile biter (örn: THYAO.IS)
        let formattedSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol.uppercased() : "\(symbol.uppercased()).IS"
        let urlString = "\(baseUrl)\(formattedSymbol)?interval=1d&range=1d"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // Yahoo bazen User-Agent bekler
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let yahooResponse = try decoder.decode(BistYahooChartResponse.self, from: data)
        
        guard let result = yahooResponse.chart.result?.first,
              let meta = result.meta as BistYahooMetaInfo?,
              let currentPrice = meta.regularMarketPrice,
              let prevClose = meta.previousClose else {
            throw URLError(.cannotParseResponse)
        }
        
        // Hesaplamalar
        let change = currentPrice - prevClose
        let changePercent = (change / prevClose) * 100
        
        // Model Oluştur
        let shortSym = formattedSymbol.replacingOccurrences(of: ".IS", with: "")
        
        return BistTicker(
            symbol: formattedSymbol,
            shortSymbol: shortSym,
            companyName: nil, // İsim detayını şimdilik boş geçiyoruz (Opsiyonel: başka endpointten alınabilir)
            price: currentPrice,
            change: change,
            changePercent: changePercent,
            volume: nil,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Fetch History (Grafik Verisi)
    func fetchHistory(symbol: String, interval: String = "15m", range: String = "5d") async throws -> [BistCandle] {
        let formattedSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol.uppercased() : "\(symbol.uppercased()).IS"
        let urlString = "\(baseUrl)\(formattedSymbol)?interval=\(interval)&range=\(range)"
        
        guard let url = URL(string: urlString) else {
            throw BistDataError.invalidURL(urlString)
        }
        
        let (data, _) = try await session.data(for: URLRequest(url: url))
        let yahooResponse = try JSONDecoder().decode(BistYahooChartResponse.self, from: data)
        
        guard let result = yahooResponse.chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators?.quote?.first,
              let opens = quote.open,
              let highs = quote.high,
              let lows = quote.low,
              let closes = quote.close,
              let volumes = quote.volume else {
            return []
        }
        
        var candles: [BistCandle] = []
        
        for i in 0..<timestamps.count {
            if let o = opens[i], let h = highs[i], let l = lows[i], let c = closes[i], let v = volumes[i] {
                let currentTimestamp = timestamps[i]
                let date = Date(timeIntervalSince1970: currentTimestamp)
                
                // Hatalı veya null verileri atla
                if o == 0 || c == 0 { continue }
                
                candles.append(BistCandle(
                    date: date,
                    open: o,
                    high: h,
                    low: l,
                    close: c,
                    volume: v
                ))
            }
        }
        
        return candles
    }
    
    // MARK: - Debug Helper
    func testConnection(symbol: String = "THYAO") async {
        do {
            let ticker = try await fetchQuote(symbol: symbol)
            print("🇹🇷 BIST BAĞLANTISI BAŞARILI!")
            print("📍 Hisse: \(ticker.shortSymbol)")
            print("💰 Fiyat: \(ticker.price) TRY")
            print("📈 Değişim: %\(String(format: "%.2f", ticker.changePercent))")
        } catch {
            print("❌ BIST BAĞLANTISI BAŞARISIZ: \(error.localizedDescription)")
        }
    }
}

// MARK: - BIST Data Errors
enum BistDataError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case noData
    case parseFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Geçersiz URL: \(url)"
        case .invalidResponse: return "Sunucu yanıtı geçersiz"
        case .noData: return "Veri bulunamadı"
        case .parseFailed: return "Veri işlenemedi"
        }
    }
}
