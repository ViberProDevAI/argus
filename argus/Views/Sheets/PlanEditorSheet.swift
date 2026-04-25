import SwiftUI

struct PlanEditorSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let trade: Trade
    let currentPrice: Double
    let plan: PositionPlan
    
    @State private var targetPrice: Double
    @State private var stopPrice: Double
    @State private var sellPercent: Double
    
    init(trade: Trade, currentPrice: Double, plan: PositionPlan) {
        self.trade = trade
        self.currentPrice = currentPrice
        self.plan = plan
        
        // Initialize from existing plan (Bullish Step 1)
        if let firstStep = plan.bullishScenario.steps.first, 
           case .priceAbove(let target) = firstStep.trigger {
            _targetPrice = State(initialValue: target)
            
            // Extract Percent
            if case .sellPercent(let pct) = firstStep.action {
                _sellPercent = State(initialValue: pct)
            } else if case .sellAll = firstStep.action {
                _sellPercent = State(initialValue: 100)
            } else {
                _sellPercent = State(initialValue: 50)
            }
        } else {
            _targetPrice = State(initialValue: trade.entryPrice * 1.05)
            _sellPercent = State(initialValue: 100)
        }
        
        // Initialize Stop (Bearish Step 1)
        if let firstStop = plan.bearishScenario.steps.first,
           case .priceBelow(let stop) = firstStop.trigger {
            _stopPrice = State(initialValue: stop)
        } else {
            _stopPrice = State(initialValue: trade.entryPrice * 0.95)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PLAN ÖZETİ")) {
                    HStack {
                        Text("Maliyet")
                        Spacer()
                        Text(String(format: "%.2f", trade.entryPrice))
                    }
                    HStack {
                        Text("Anlık Fiyat")
                        Spacer()
                        Text(String(format: "%.2f", currentPrice))
                            .foregroundColor(currentPrice >= trade.entryPrice ? .green : .red)
                    }
                    HStack {
                        Text("Niyet (Vortex)")
                        Spacer()
                        Label(plan.intent.rawValue, systemImage: plan.intent.icon)
                            .foregroundColor(Color(plan.intent.colorName))
                    }
                }
                
                Section(header: Text("HEDEF (TAKE PROFIT)")) {
                    VStack(alignment: .leading) {
                        Text("Hedef Fiyat: \(String(format: "%.2f", targetPrice))")
                        Slider(value: $targetPrice, in: (trade.entryPrice)...(trade.entryPrice * 2.0))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Satılacak Miktar: %\(Int(sellPercent))")
                        Slider(value: $sellPercent, in: 10...100, step: 10)
                    }
                }
                
                Section(header: Text("ZARAR KES (STOP LOSS)")) {
                    VStack(alignment: .leading) {
                        Text("Stop Fiyatı: \(String(format: "%.2f", stopPrice))")
                        Slider(value: $stopPrice, in: (trade.entryPrice * 0.5)...(trade.entryPrice))
                            .accentColor(.red)
                    }
                }
                
                Section {
                    Button(action: savePlan) {
                        Text("Planı Güncelle")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Plan Editörü")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func savePlan() {
        // Call Vortex Engine
        VortexEngine.shared.updatePlan(
            tradeId: trade.id,
            newTarget: targetPrice,
            quantityPercent: sellPercent,
            reason: "Kullanıcı tarafından manuel güncellendi"
        )
        
        // Also update Stop (Need to extend VortexEngine if needed, currently assumes Target Override)
        // Ideally we update both.
        
        presentationMode.wrappedValue.dismiss()
    }
}
