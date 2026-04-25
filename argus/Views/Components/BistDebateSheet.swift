import SwiftUI

struct BistDebateSheet: View {
    let decision: BistDecisionResult
    @Binding var isPresented: Bool
    
    // Helper to aggregate modules from the struct into an array
    private var allModules: [BistModuleResult] {
        return [
            decision.faktor,
            decision.sektor,
            decision.akis,
            decision.kulis,
            decision.grafik,
            decision.bilanco,
            decision.rejim,
            decision.sirkulasyon
        ]
    }
    
    // Helper to group modules
    private var groups: (claimant: BistModuleResult?, supporters: [BistModuleResult], objectors: [BistModuleResult], abstainers: [BistModuleResult]) {
        let sortedModules = allModules.sorted { $0.score > $1.score }
        
        // 1. Claimant: The module with the strongest conviction towards the final action
        let claimant: BistModuleResult?
        
        if isBullish(decision.action) {
             claimant = sortedModules.first // Highest Score
        } else if isBearish(decision.action) {
            claimant = allModules.sorted { $0.score < $1.score }.first // Lowest Score (Sell driver)
        } else {
            // Neutral -> First one
            claimant = sortedModules.first
        }
        
        // 2. Supporters, Objectors, Abstainers
        var supporters: [BistModuleResult] = []
        var objectors: [BistModuleResult] = []
        var abstainers: [BistModuleResult] = []
        
        for module in allModules {
            if module.name == claimant?.name { continue }
            
            // Logic: Is this module agreeing with the final decision?
            let finalBullish = isBullish(decision.action)
            let finalBearish = isBearish(decision.action)
            
            let moduleBullish = isBullish(module.action)
            let moduleBearish = isBearish(module.action)
            
            if finalBullish {
                if moduleBullish { supporters.append(module) }
                else if moduleBearish { objectors.append(module) }
                else { abstainers.append(module) } // Neutral/Hold is Abstain, NOT Objection
            } else if finalBearish {
                if moduleBearish { supporters.append(module) }
                else if moduleBullish { objectors.append(module) }
                else { abstainers.append(module) }
            } else {
                // Neutral decision
                // If decision is neutral, everything is basically agreeing or abstaining
                abstainers.append(module)
            }
        }
        
        return (claimant, supporters, objectors, abstainers)
    }
    
    // Action Helpers
    private func isBullish(_ action: ArgusAction) -> Bool {
        return action == .aggressiveBuy || action == .accumulate
    }
    private func isBearish(_ action: ArgusAction) -> Bool {
        return action == .liquidate || action == .trim
    }
    
    private func isBullish(_ action: ProposedAction) -> Bool {
        return action == .buy
    }
    private func isBearish(_ action: ProposedAction) -> Bool {
        return action == .sell
    }
    
    var body: some View {
        ZStack {
            Color(hex: "020205").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "gavel.fill")
                        .foregroundColor(.white)
                    Text("Konsey Tartışması")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Kapat") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding()
                .background(Color(hex: "080b14"))
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // 1. İDDİA (CLAIMANT)
                        if let claimant = groups.claimant {
                            DebateCard(
                                type: .claim,
                                modules: [claimant],
                                title: "İDDİA",
                                color: .cyan,
                                showDetails: true
                            )
                        }
                        
                        // 2. DESTEK (SUPPORTERS)
                        if !groups.supporters.isEmpty {
                            DebateCard(
                                type: .support,
                                modules: groups.supporters,
                                title: "DESTEK",
                                color: .blue,
                                showDetails: false // Summary only
                            )
                        } else {
                             EmptyStateCard(type: .support)
                        }
                        
                        // 3. İTİRAZ (OBJECTORS)
                        if !groups.objectors.isEmpty {
                            DebateCard(
                                type: .objection,
                                modules: groups.objectors,
                                title: "İTİRAZ",
                                color: .orange,
                                showDetails: false
                            )
                        }
                        
                        // 4. ÇEKİMSER (ABSTAINERS)
                        if !groups.abstainers.isEmpty {
                            DebateCard(
                                type: .abstain,
                                modules: groups.abstainers,
                                title: "ÇEKİMSER",
                                color: .gray,
                                showDetails: false
                            )
                        }
                        
                        // 4. NİHAİ KARAR (VERDICT)
                        BistVerdictCard(decision: decision)
                            .padding(.top, 8)
                        
                        // Terim Sözlüğü (Footer)
                        HStack(spacing: 20) {
                            FooterTerm(icon: "book.fill", term: "Net Destek")
                            FooterTerm(icon: "shield.fill", term: "Veto")
                            FooterTerm(icon: "chart.pie.fill", term: "Konsensüs")
                        }
                        .padding(.top, 20)
                        .opacity(0.6)
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Subviews

enum DebateType {
    case claim // 1. İddia
    case support // 2. Destek
    case objection // 3. İtiraz
    case abstain // 4. Çekimser
}


struct DebateCard: View {
    let type: DebateType
    let modules: [BistModuleResult]
    let title: String
    let color: Color
    let showDetails: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    let num: String = {
                        switch type {
                        case .claim: return "1"
                        case .support: return "2"
                        case .objection: return "3"
                        case .abstain: return "-"
                        }
                    }()
                    
                    Text(num)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.black)
                    .tracking(1)
                    .foregroundColor(color)
                
                Spacer()
                
                // Module Names (if summarized)
                if !showDetails {
                    Text(modules.map { $0.name }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text(modules.first?.name ?? "")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.gray)
                }
            }
            
            if showDetails, let module = modules.first {
                // Full Quote Style
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.6))
                    
                    Text(module.commentary)
                        .font(.custom("Avenir-MediumItalic", size: 14)) // Elegant font
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
                
            } else {
                // Summary Style
                HStack(alignment: .top, spacing: 12) {
                    let iconName: String = {
                        switch type {
                        case .support: return "hand.thumbsup.fill"
                        case .objection: return "hand.raised.fill" // Dur
                        case .abstain: return "minus.circle.fill" // Nötr
                        default: return "circle"
                        }
                    }()
                    
                    Image(systemName: iconName)
                        .font(.caption)
                        .foregroundColor(color.opacity(0.6))
                    
                    let summaryText: String = {
                        switch type {
                        case .support: return "\(modules.count) modül bu karara destek veriyor."
                        case .objection: return "\(modules.count) modül bu karara itiraz ediyor."
                        case .abstain: return "\(modules.count) modül çekimser kalıyor."
                        default: return ""
                        }
                    }()
                    
                    Text(summaryText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
                .background(color.opacity(0.05))
        )
    }
}

struct EmptyStateCard: View {
    let type: DebateType
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 24, height: 24)
                
                Text(type == .support ? "2" : "3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            Text(type == .support ? "DESTEK" : "İTİRAZ")
                .font(.caption)
                .fontWeight(.black)
                .tracking(1)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("Yok")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                .background(Color.white.opacity(0.02))
        )
    }
}

struct BistVerdictCard: View {
    let decision: BistDecisionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Text("4")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("NİHAİ KARAR")
                    .font(.caption)
                    .fontWeight(.black)
                    .tracking(1)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("KONSEY")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(decision.reasoning)
                         .font(.custom("Avenir-Medium", size: 14))
                         .foregroundColor(.white)
                         .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                         Text("Karar:")
                            .foregroundColor(.gray)
                        Text(getActionLabel(decision.action))
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }
            .padding(.leading, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.5), lineWidth: 2)
                .background(Color.blue.opacity(0.1))
        )
    }
    
    func getActionLabel(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "HÜCUM (GÜÇLÜ AL)"
        case .accumulate: return "BİRİKTİR"
        case .neutral: return "GÖZLE"
        case .trim: return "AZALT"
        case .liquidate: return "NAKİTE GEÇ"
        }
    }
}

struct FooterTerm: View {
    let icon: String
    let term: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(term)
        }
        .font(.caption2)
        .foregroundColor(.gray)
    }
}
