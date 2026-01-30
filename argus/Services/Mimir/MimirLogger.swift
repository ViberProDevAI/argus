import Foundation

struct MimirLogger {
    nonisolated static func log(decision: String, task: MimirTask, model: String?, estTok: Int, rpm: Int, tpm: Int, cache: String, cb: String) {
        // Format: 🧠 Mimir[Type] decision=X model=Y estTok=Z rpm=A/B tpm=C/D cache=E cb=F
        let type = task.type.rawValue
        let m = model ?? "none"
        print("🧠 Mimir[\(type)] decision=\(decision) model=\(m) estTok=\(estTok) rpm=\(rpm) tpm=\(tpm) cache=\(cache) cb=\(cb)")
    }
    
    nonisolated static func error(_ msg: String) {
        print("🛑 Mimir Error: \(msg)")
    }
}
