import SwiftUI
import CoreMotion
import Combine

// MARK: - Liquid Motion Manager
/// Jiroskop verisini okur ve "viskozite" ekleyerek yumuşatır.
/// Sanki suyun içinde değil de, jel içinde hareket ediyormuş hissi verir.
class LiquidMotionManager: ObservableObject {
    private var motionManager: CMMotionManager
    
    // Yayınlanan "Yumuşatılmış" Vektörler
    @Published var pitch: Double = 0.0 // X ekseni (Öne/Arkaya eğim)
    @Published var roll: Double = 0.0  // Y ekseni (Sağa/Sola eğim)
    
    // Viskozite Ayarı (0.0 - 1.0)
    // Düşük değer = Daha yavaş/ağır tepki (Yüksek viskozite)
    // Yüksek değer = Daha hızlı tepki (Düşük viskozite)
    private let viscosity: Double = 0.05
    
    init() {
        self.motionManager = CMMotionManager()
        self.startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ LiquidMotion: Cihaz hareket sensörü yok (Simülatör olabilir).")
            // Simülatör için hafif bir "nefes alma" hareketi simüle edebiliriz
            startSimulation()
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            
            // Low-Pass Filter (Interpolation)
            // Yeni değer = Eski * (1 - k) + Yeni * k
            withAnimation(.linear(duration: 0.1)) {
                self.pitch = (self.pitch * (1.0 - self.viscosity)) + (data.attitude.pitch * self.viscosity)
                self.roll = (self.roll * (1.0 - self.viscosity)) + (data.attitude.roll * self.viscosity)
            }
        }
    }
    
    // Simülatör ve Preview İçin Otomatik Hareket
    private func startSimulation() {
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let time = Date().timeIntervalSince1970
            // Sinüs dalgası ile yapay salınım
            self.pitch = sin(time * 0.5) * 0.2
            self.roll = cos(time * 0.3) * 0.3
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
