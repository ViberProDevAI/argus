import SwiftUI

struct ArgusSimulatorView: View {
    // MARK: - Simulation State
    @State private var atlasScore: Double = 50
    @State private var orionScore: Double = 50
    @State private var aetherScore: Double = 50
    @State private var athenaScore: Double = 50
    @State private var hermesScore: Double = 50
    @State private var demeterScore: Double = 50
    
    // Test Case Management
    struct TestCase: Identifiable, Codable {
        let id: UUID
        let name: String
        let result: ArgusDecisionResult
        
        init(id: UUID = UUID(), name: String, result: ArgusDecisionResult) {
            self.id = id
            self.name = name
            self.result = result
        }
    }
    @State private var savedCases: [TestCase] = [] {
        didSet {
            // Usually State didSet doesn't work for persistence in SwiftUI View structs this way if modified internally via bindings, 
            // but for simple append actions it might receive updates. 
            // Better to save explicitly in functions.
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Prediction Card (Live Preview)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Canlı Simülasyon")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    ArgusSolarCardView(
                        decision: simulatedResult,
                        explanation: nil, // No AI for sim
                        isLoading: false
                    )
                    .padding(.horizontal)
                }
                
                // 2. Control Panel (Sliders)
                VStack(spacing: 20) {
                    sliderRow(label: "ATLAS (Temel)", value: $atlasScore, color: .blue)
                    sliderRow(label: "ATHENA (Faktör)", value: $athenaScore, color: .cyan)
                    sliderRow(label: "ORION (Teknik)", value: $orionScore, color: .purple)
                    sliderRow(label: "AETHER (Makro)", value: $aetherScore, color: .orange)
                    sliderRow(label: "HERMES (Haber)", value: $hermesScore, color: .pink)
                    sliderRow(label: "DEMETER (Sektör)", value: $demeterScore, color: .green)
                }
                .padding()
                .background(Theme.secondaryBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // 3. Action Buttons
                HStack(spacing: 16) {
                    Button(action: resetScores) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Sıfırla")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: saveSnapshot) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Snapshot Kaydet")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.tint)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // 4. Saved Snapshots
                if !savedCases.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Kaydedilen Senaryolar")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(savedCases) { testCase in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(testCase.name)
                                        .font(.subheadline)
                                        .bold()
                                    Text("Core: \(testCase.result.letterGradeCore) | Pulse: \(testCase.result.letterGradePulse)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(Int(testCase.result.finalScoreCore))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Theme.tint)
                            }
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.top)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) } // Space for CustomTabBar
        .navigationTitle("Argus Simulator ")
        .onAppear {
            loadSnapshots()
        }
    }
    
    // MARK: - Helpers
    
    private var simulatedResult: ArgusDecisionResult {
        ArgusDecisionEngine.shared.makeDecision(
            symbol: "LAB-TEST",
            assetType: .stock,
            atlas: atlasScore,
            orion: orionScore,
            orionDetails: nil,
            aether: aetherScore,
            hermes: hermesScore,
            athena: athenaScore,
            phoenixAdvice: nil,
            demeterScore: demeterScore,
            marketData: nil
        ).1 // Take Result (Ignore Trace)
    }
    
    private func resetScores() {
        withAnimation {
            atlasScore = 50
            orionScore = 50
            aetherScore = 50
            aetherScore = 50
            athenaScore = 50
            hermesScore = 50
            demeterScore = 50
        }
    }
    
    private func saveSnapshot() {
        let newCase = TestCase(
            name: "Test #\(savedCases.count + 1) - \(Date().formatted(date: .omitted, time: .shortened))",
            result: simulatedResult
        )
        withAnimation {
            savedCases.insert(newCase, at: 0)
            persistSnapshots()
        }
    }
    
    // MARK: - Persistence
    private let storageKey = "argusSimSnapshots"
    
    private func persistSnapshots() {
        if let data = try? JSONEncoder().encode(savedCases) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadSnapshots() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TestCase].self, from: data) {
            self.savedCases = decoded
        }
    }
    
    private func sliderRow(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(color)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.subheadline)
                    .bold()
                    .monospacedDigit()
            }
            
            Slider(value: value, in: 0...100, step: 1)
                .accentColor(color)
        }
    }
}
