import Foundation

struct MimirLogger {
    nonisolated static func log(decision: String, task: MimirTask, model: String?, estTok: Int, rpm: Int, tpm: Int, cache: String, cb: String) {
        let type = task.type.rawValue
        let m = model ?? "none"
        let msg = "[\(type)] decision=\(decision) model=\(m) estTok=\(estTok) rpm=\(rpm) tpm=\(tpm) cache=\(cache) cb=\(cb)"
        ArgusLogger.info(.mimir, msg)
    }

    nonisolated static func error(_ msg: String) {
        ArgusLogger.error(.mimir, msg)
    }
}
