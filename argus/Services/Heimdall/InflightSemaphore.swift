import Foundation

/// Burst sönümleyici eşzamanlılık limiti.
///
/// Y3-HOTFIX Phase 4 (2026-04-29): `HeimdallRateLimiter`'ın sliding window cap'i
/// **dakikalık** bir tavandı; ama 50+ task aynı anda saldırdığında pencere bir
/// saniyede tükenip kalan tüm istekler 30sn'lik kuyruğa düşüyordu. Pencere içi
/// adil kuyruk yoktu (her task kendi backoff timer'ında dönüyordu) →
/// starvation. Sonuç: "hisse açıldı, hazırlanıyor diyor, hiç gelmiyor".
///
/// Bu semaphore aynı anda **kaç istek havada** olabileceğini sabitler. Yahoo için
/// 6 → ortalama 5/sn (300/min) sliding window'u zaten doğal olarak respect ediyor;
/// ek olarak burst patlamasını engelliyor. FIFO kuyruk → fairness.
///
/// `actor` izolasyonu sayesinde counter ve waiters listesi yarış koşulu olmadan
/// güncellenir; `withCheckedContinuation` async/await sınırına şıkça oturur.
actor InflightSemaphore {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        precondition(value > 0, "Semaphore value pozitif olmalı")
        self.available = value
    }

    /// Slot açılana kadar bekler. Cancel olursa kuyruktan çıkar (continuation leak yok).
    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        // FIFO: yeni gelen waiters listesinin sonuna eklenir; release ilk waiter'ı uyandırır.
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    /// Kullanılan slotu serbest bırakır. Bekleyen varsa onu uyandırır;
    /// yoksa available counter'ı bir artırır.
    func release() {
        if !waiters.isEmpty {
            let cont = waiters.removeFirst()
            cont.resume()
        } else {
            available += 1
        }
    }

    /// Telemetri / debug için kuyruk derinliği.
    var queueDepth: Int { waiters.count }
}
