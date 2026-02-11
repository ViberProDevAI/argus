import Foundation

extension UserDefaults {
    private enum Keys {
        static let isAutoPilotLoggingEnabled = "isAutoPilotLoggingEnabled"
    }
    
    var isAutoPilotLoggingEnabled: Bool {
        get { return bool(forKey: Keys.isAutoPilotLoggingEnabled) }
        set { set(newValue, forKey: Keys.isAutoPilotLoggingEnabled) }
    }
}
