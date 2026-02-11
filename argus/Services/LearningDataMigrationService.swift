import Foundation

// MARK: - Learning Data Migration Service
// Tüm Chiron + Alkindus öğrenme verilerini tek bir JSON paketine toplar
// Eski uygulamadan (Algo-Trading) yeni uygulamaya (Argus) taşımak için kullanılır

struct LearningDataBundle: Codable {
    let version: String
    let exportDate: Date
    let sourceApp: String

    // Chiron Verileri
    var chironWeights: Data?            // ChironWeights.json
    var chironDataLakeTrades: [String: Data]  // trades/{SYMBOL}_history.json
    var chironDataLakeAccuracy: [String: Data] // module_accuracy/{MODULE}_accuracy.json
    var chironDataLakeEvents: Data?     // learning_logs/events.json
    var chironCouncilRecords: Data?     // ChironCouncilRecords.json
    var chironCouncilWeights: Data?     // ChironCouncilWeights.json

    // Alkindus Verileri
    var alkindusCalibration: Data?      // alkindus_memory/calibration.json
    var alkindusPending: Data?          // alkindus_memory/pending_observations.json
    var alkindusSymbols: Data?          // alkindus_memory/symbols.json
    var alkindusTemporal: Data?         // alkindus_memory/temporal.json
    var alkindusRollingStats: Data?     // alkindus_memory/rolling_stats.json
    var alkindusCorrelations: Data?     // alkindus_memory/correlations.json
    var alkindusPatterns: Data?         // alkindus_memory/pattern_learnings.json
    var alkindusIndicators: Data?       // alkindus_memory/indicator_learnings.json
    var alkindusBacktest: Data?         // alkindus_memory/backtest_learnings.json

    // SQLite Database
    var argusScienceDB: Data?           // ArgusScience_V1.sqlite

    // İstatistikler
    var stats: MigrationStats
}

struct MigrationStats: Codable {
    var totalFiles: Int
    var totalSizeBytes: Int
    var chironWeightSymbols: Int
    var chironTradeFiles: Int
    var alkindusFilesFound: Int
    var hasSQLiteDB: Bool
}

class LearningDataMigrationService {
    static let shared = LearningDataMigrationService()
    private let fileManager = FileManager.default

    private var docsPath: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - EXPORT (Eski uygulamada çalışır)

    /// Tüm öğrenme verilerini tek bir JSON paketine toplar
    func exportAllLearningData() async throws -> URL {
        var totalFiles = 0
        var totalSize = 0

        // 1. Chiron Weights
        let chironWeightsPath = docsPath.appendingPathComponent("ChironWeights.json")
        let chironWeightsData = loadFileData(chironWeightsPath)
        if chironWeightsData != nil { totalFiles += 1; totalSize += chironWeightsData!.count }

        // 2. Chiron DataLake - Trades
        var tradeFiles: [String: Data] = [:]
        let tradesDir = docsPath.appendingPathComponent("ChironDataLake/trades")
        if let tradeFileNames = try? fileManager.contentsOfDirectory(atPath: tradesDir.path) {
            for fileName in tradeFileNames where fileName.hasSuffix(".json") {
                let filePath = tradesDir.appendingPathComponent(fileName)
                if let data = loadFileData(filePath) {
                    tradeFiles[fileName] = data
                    totalFiles += 1
                    totalSize += data.count
                }
            }
        }

        // 3. Chiron DataLake - Module Accuracy
        var accuracyFiles: [String: Data] = [:]
        let accuracyDir = docsPath.appendingPathComponent("ChironDataLake/module_accuracy")
        if let accFileNames = try? fileManager.contentsOfDirectory(atPath: accuracyDir.path) {
            for fileName in accFileNames where fileName.hasSuffix(".json") {
                let filePath = accuracyDir.appendingPathComponent(fileName)
                if let data = loadFileData(filePath) {
                    accuracyFiles[fileName] = data
                    totalFiles += 1
                    totalSize += data.count
                }
            }
        }

        // 4. Chiron DataLake - Learning Events
        let eventsPath = docsPath.appendingPathComponent("ChironDataLake/learning_logs/events.json")
        let eventsData = loadFileData(eventsPath)
        if eventsData != nil { totalFiles += 1; totalSize += eventsData!.count }

        // 5. Chiron Council
        let councilRecordsPath = docsPath.appendingPathComponent("ChironCouncilRecords.json")
        let councilRecordsData = loadFileData(councilRecordsPath)
        if councilRecordsData != nil { totalFiles += 1; totalSize += councilRecordsData!.count }

        let councilWeightsPath = docsPath.appendingPathComponent("ChironCouncilWeights.json")
        let councilWeightsData = loadFileData(councilWeightsPath)
        if councilWeightsData != nil { totalFiles += 1; totalSize += councilWeightsData!.count }

        // 6. Alkindus Memory
        let alkindusBase = docsPath.appendingPathComponent("alkindus_memory")
        let alkindusFiles: [(String, String)] = [
            ("calibration", "calibration.json"),
            ("pending", "pending_observations.json"),
            ("symbols", "symbols.json"),
            ("temporal", "temporal.json"),
            ("rollingStats", "rolling_stats.json"),
            ("correlations", "correlations.json"),
            ("patterns", "pattern_learnings.json"),
            ("indicators", "indicator_learnings.json"),
            ("backtest", "backtest_learnings.json"),
        ]

        var alkindusDataMap: [String: Data] = [:]
        var alkindusCount = 0
        for (key, fileName) in alkindusFiles {
            let path = alkindusBase.appendingPathComponent(fileName)
            if let data = loadFileData(path) {
                alkindusDataMap[key] = data
                alkindusCount += 1
                totalFiles += 1
                totalSize += data.count
            }
        }

        // 7. SQLite Database
        let sqlitePath = docsPath.appendingPathComponent("ArgusScience_V1.sqlite")
        let sqliteData = loadFileData(sqlitePath)
        if sqliteData != nil { totalFiles += 1; totalSize += sqliteData!.count }

        // Chiron weight symbol sayısı
        var chironSymbolCount = 0
        if let weightsData = chironWeightsData {
            if let dict = try? JSONSerialization.jsonObject(with: weightsData) as? [String: Any] {
                chironSymbolCount = dict.count
            }
        }

        // Bundle oluştur
        let bundle = LearningDataBundle(
            version: "2.0",
            exportDate: Date(),
            sourceApp: "Algo-Trading",
            chironWeights: chironWeightsData,
            chironDataLakeTrades: tradeFiles,
            chironDataLakeAccuracy: accuracyFiles,
            chironDataLakeEvents: eventsData,
            chironCouncilRecords: councilRecordsData,
            chironCouncilWeights: councilWeightsData,
            alkindusCalibration: alkindusDataMap["calibration"],
            alkindusPending: alkindusDataMap["pending"],
            alkindusSymbols: alkindusDataMap["symbols"],
            alkindusTemporal: alkindusDataMap["temporal"],
            alkindusRollingStats: alkindusDataMap["rollingStats"],
            alkindusCorrelations: alkindusDataMap["correlations"],
            alkindusPatterns: alkindusDataMap["patterns"],
            alkindusIndicators: alkindusDataMap["indicators"],
            alkindusBacktest: alkindusDataMap["backtest"],
            argusScienceDB: sqliteData,
            stats: MigrationStats(
                totalFiles: totalFiles,
                totalSizeBytes: totalSize,
                chironWeightSymbols: chironSymbolCount,
                chironTradeFiles: tradeFiles.count,
                alkindusFilesFound: alkindusCount,
                hasSQLiteDB: sqliteData != nil
            )
        )

        // JSON encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(bundle)

        // Temp dosyaya kaydet
        let tempDir = fileManager.temporaryDirectory
        let fileName = "Argus_Learning_Migration_\(Int(Date().timeIntervalSince1970)).json"
        let fileURL = tempDir.appendingPathComponent(fileName)
        try jsonData.write(to: fileURL)

        print("✅ Migration export tamamlandı: \(totalFiles) dosya, \(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file))")

        return fileURL
    }

    // MARK: - IMPORT (Yeni uygulamada çalışır)

    /// Migration bundle'ını içe aktarır ve dosyaları Documents'a yerleştirir
    func importLearningData(from url: URL) async throws -> MigrationStats {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(LearningDataBundle.self, from: data)

        var importedFiles = 0

        // 1. Chiron Weights
        if let weightsData = bundle.chironWeights {
            let path = docsPath.appendingPathComponent("ChironWeights.json")
            try weightsData.write(to: path)
            importedFiles += 1
            print("✅ ChironWeights.json içe aktarıldı")
        }

        // 2. Chiron DataLake - Trades
        let tradesDir = docsPath.appendingPathComponent("ChironDataLake/trades")
        try fileManager.createDirectory(at: tradesDir, withIntermediateDirectories: true)
        for (fileName, fileData) in bundle.chironDataLakeTrades {
            let path = tradesDir.appendingPathComponent(fileName)
            try fileData.write(to: path)
            importedFiles += 1
        }
        if !bundle.chironDataLakeTrades.isEmpty {
            print("✅ ChironDataLake trades: \(bundle.chironDataLakeTrades.count) dosya içe aktarıldı")
        }

        // 3. Chiron DataLake - Module Accuracy
        let accuracyDir = docsPath.appendingPathComponent("ChironDataLake/module_accuracy")
        try fileManager.createDirectory(at: accuracyDir, withIntermediateDirectories: true)
        for (fileName, fileData) in bundle.chironDataLakeAccuracy {
            let path = accuracyDir.appendingPathComponent(fileName)
            try fileData.write(to: path)
            importedFiles += 1
        }
        if !bundle.chironDataLakeAccuracy.isEmpty {
            print("✅ ChironDataLake module accuracy: \(bundle.chironDataLakeAccuracy.count) dosya içe aktarıldı")
        }

        // 4. Chiron DataLake - Learning Events
        if let eventsData = bundle.chironDataLakeEvents {
            let eventsDir = docsPath.appendingPathComponent("ChironDataLake/learning_logs")
            try fileManager.createDirectory(at: eventsDir, withIntermediateDirectories: true)
            let path = eventsDir.appendingPathComponent("events.json")
            try eventsData.write(to: path)
            importedFiles += 1
            print("✅ ChironDataLake events.json içe aktarıldı")
        }

        // 5. Chiron Council
        if let recordsData = bundle.chironCouncilRecords {
            let path = docsPath.appendingPathComponent("ChironCouncilRecords.json")
            try recordsData.write(to: path)
            importedFiles += 1
            print("✅ ChironCouncilRecords.json içe aktarıldı")
        }
        if let weightsData = bundle.chironCouncilWeights {
            let path = docsPath.appendingPathComponent("ChironCouncilWeights.json")
            try weightsData.write(to: path)
            importedFiles += 1
            print("✅ ChironCouncilWeights.json içe aktarıldı")
        }

        // 6. Alkindus Memory
        let alkindusBase = docsPath.appendingPathComponent("alkindus_memory")
        try fileManager.createDirectory(at: alkindusBase, withIntermediateDirectories: true)

        let alkindusMapping: [(Data?, String)] = [
            (bundle.alkindusCalibration, "calibration.json"),
            (bundle.alkindusPending, "pending_observations.json"),
            (bundle.alkindusSymbols, "symbols.json"),
            (bundle.alkindusTemporal, "temporal.json"),
            (bundle.alkindusRollingStats, "rolling_stats.json"),
            (bundle.alkindusCorrelations, "correlations.json"),
            (bundle.alkindusPatterns, "pattern_learnings.json"),
            (bundle.alkindusIndicators, "indicator_learnings.json"),
            (bundle.alkindusBacktest, "backtest_learnings.json"),
        ]

        for (data, fileName) in alkindusMapping {
            if let fileData = data {
                let path = alkindusBase.appendingPathComponent(fileName)
                try fileData.write(to: path)
                importedFiles += 1
                print("✅ alkindus_memory/\(fileName) içe aktarıldı")
            }
        }

        // 7. SQLite Database
        if let dbData = bundle.argusScienceDB {
            let path = docsPath.appendingPathComponent("ArgusScience_V1.sqlite")
            try dbData.write(to: path)
            importedFiles += 1
            print("✅ ArgusScience_V1.sqlite içe aktarıldı")
        }

        print("✅ Migration import tamamlandı: \(importedFiles) dosya içe aktarıldı")

        return MigrationStats(
            totalFiles: importedFiles,
            totalSizeBytes: bundle.stats.totalSizeBytes,
            chironWeightSymbols: bundle.stats.chironWeightSymbols,
            chironTradeFiles: bundle.stats.chironTradeFiles,
            alkindusFilesFound: bundle.stats.alkindusFilesFound,
            hasSQLiteDB: bundle.stats.hasSQLiteDB
        )
    }

    // MARK: - Helpers

    /// Mevcut öğrenme verisi istatistiklerini döndürür
    func getLearningDataStats() -> MigrationStats {
        var totalFiles = 0
        var totalSize = 0

        // Chiron Weights
        let weightsPath = docsPath.appendingPathComponent("ChironWeights.json")
        var chironSymbols = 0
        if let data = loadFileData(weightsPath) {
            totalFiles += 1
            totalSize += data.count
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                chironSymbols = dict.count
            }
        }

        // Trade files
        var tradeCount = 0
        let tradesDir = docsPath.appendingPathComponent("ChironDataLake/trades")
        if let files = try? fileManager.contentsOfDirectory(atPath: tradesDir.path) {
            tradeCount = files.filter { $0.hasSuffix(".json") }.count
            totalFiles += tradeCount
        }

        // Alkindus files
        var alkindusCount = 0
        let alkindusBase = docsPath.appendingPathComponent("alkindus_memory")
        let alkindusFiles = ["calibration.json", "pending_observations.json", "symbols.json",
                             "temporal.json", "rolling_stats.json", "correlations.json",
                             "pattern_learnings.json", "indicator_learnings.json", "backtest_learnings.json"]
        for fileName in alkindusFiles {
            let path = alkindusBase.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: path.path) {
                alkindusCount += 1
                totalFiles += 1
                if let attrs = try? fileManager.attributesOfItem(atPath: path.path),
                   let size = attrs[.size] as? Int {
                    totalSize += size
                }
            }
        }

        // SQLite
        let sqlitePath = docsPath.appendingPathComponent("ArgusScience_V1.sqlite")
        let hasDB = fileManager.fileExists(atPath: sqlitePath.path)
        if hasDB { totalFiles += 1 }

        return MigrationStats(
            totalFiles: totalFiles,
            totalSizeBytes: totalSize,
            chironWeightSymbols: chironSymbols,
            chironTradeFiles: tradeCount,
            alkindusFilesFound: alkindusCount,
            hasSQLiteDB: hasDB
        )
    }

    private func loadFileData(_ url: URL) -> Data? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }
}
