import Foundation
import Combine
import LocalAuthentication
import Security
import SwiftUI

/// Manages Biometric Authentication (FaceID/TouchID) and Keychain Access
final class SecurityService: ObservableObject {
    static let shared = SecurityService()
    
    @Published var isLocked: Bool = true // Default to locked
    @Published var biometricType: LABiometryType = .none
    
    private let context = LAContext()
    
    private init() {
        checkBiometryType()
    }
    
    // MARK: - Biometrics
    
    func checkBiometryType() {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }
    
    func authenticate(reason: String = "Portföy erişimi için doğrulama gerekiyor", completion: @escaping (Bool) -> Void) {
        let context = LAContext() // Fresh context
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isLocked = false
                        completion(true)
                    } else {
                        // Failed
                        completion(false)
                    }
                }
            }
        } else {
            // No Biometrics available -> Fallback to unlocked or Passcode?
            // For now, if no biometrics, we assume unlocked for usability, or force passcode.
            // Let's assume unlocked if hardware not supported to avoid locking user out.
            DispatchQueue.main.async {
                self.isLocked = false
                completion(true)
            }
        }
    }
    
    func lock() {
        self.isLocked = true
    }
    
    // MARK: - Keychain Wrapper
    
    func save(key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary) // Delete existing
        
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    // String Helper
    func saveString(key: String, value: String) {
        if let data = value.data(using: .utf8) {
            _ = save(key: key, data: data)
        }
    }
    
    func loadString(key: String) -> String? {
        if let data = load(key: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
