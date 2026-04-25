import Foundation
import Speech
import AVFoundation
import Combine

/// 🎤 THE EARS OF ARGUS 🎤
/// Handles real-time speech recognition using SFSpeechRecognizer.
/// Designed for low-latency command parsing.
class ArgusSpeechService: ObservableObject {
    static let shared = ArgusSpeechService()
    
    @Published var recognizedText: String = ""
    @Published var isRecording = false
    @Published var errorMsg: String? = nil
    @Published var audioLevel: Float = 0.0 // For Waveform Visualization
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) // Türkçe Odağı
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private init() {
        // Authorization will be requested lazily when startRecording is called
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("🎤 Argus Speech: Authorized")
                case .denied:
                    self.errorMsg = "Mikrofon izni reddedildi."
                case .restricted:
                    self.errorMsg = "Konuşma tanıma kısıtlı."
                case .notDetermined:
                    self.errorMsg = "İzin bekleniyor."
                @unknown default:
                    self.errorMsg = "Bilinmeyen durum."
                }
            }
        }
    }
    
    func startRecording() throws {
        // Request authorization first (lazy)
        requestAuthorization()

        // Cancel previous task if any
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let request = recognitionRequest else {
            print("🛑 ArgusSpeech: Unable to create request")
            throw NSError(domain: "ArgusSpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create speech recognition request"])
        }
        
        request.shouldReportPartialResults = true
        
        // Tap for Waveform Visualization
        inputNode.removeTap(onBus: 0) // Safety
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            
            // Calculate Audio Level (RMS)
            let channelData = buffer.floatChannelData?[0]
            let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            let rms = sqrt(channelDataValue.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)
            
            DispatchQueue.main.async {
                // Normalize roughly between 0 and 1 for UI
                self.audioLevel = min(max((avgPower + 50) / 50, 0), 1)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            var isFinal = false
            
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString // Real-time update
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopRecording()
            }
        }
        
        isRecording = true
        recognizedText = ""
        errorMsg = nil
        print("🎤 Argus Speech: Recording Started")
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isRecording = false
        print("🎤 Argus Speech: Recording Stopped")
        
        // Reset session (optional, helps with other audio)
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
