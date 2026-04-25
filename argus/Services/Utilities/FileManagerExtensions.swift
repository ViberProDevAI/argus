import Foundation

// MARK: - Safe FileManager Helpers
/// App Store güvenli dosya yolu erişimi.
/// `.first!` yerine bu metodları kullan — sandbox kısıtlamalarında crash olmaz.

extension FileManager {

    /// Documents dizinini güvenli şekilde döndürür.
    /// `.urls(for:in:).first!` yerine bu kullanılmalı.
    var safeDocumentsURL: URL? {
        urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Documents dizinini döndürür; erişilemezse geçici dizini fallback olarak kullanır.
    var documentsURL: URL {
        urls(for: .documentDirectory, in: .userDomainMask).first
            ?? temporaryDirectory
    }

    /// Verilen dosya adını Documents dizininde güvenli şekilde oluşturur.
    func documentsPath(for filename: String) -> URL {
        documentsURL.appendingPathComponent(filename)
    }
}
