import SwiftUI

// MARK: - Agora Debate Sheet V2
/// Educational debate simulation with animations and terminology

struct AgoraDebateSheet: View {
    let decision: ArgusGrandDecision
    @Environment(\.dismiss) var dismiss
    
    // Animation States
    @State private var animationStep = 0
    @State private var showTerminology = false
    @State private var selectedTerm: TermDefinition? = nil
    @State private var expandedModule: String? = nil
    @State private var showInfoCard = false // NEW
    
    var body: some View {
        NavigationView { // Note: If presented from another NavigationView, this might need adjustment, but standard sheet usually needs its own NavView or uses the parent's if not modal. Given the code, it uses its own.
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. VERDICT HEADER
                        verdictHeader
                        
                        // 2. ANIMATED DEBATE SIMULATION
                        animatedDebateSection
                        
                        // 3. ALL MODULES WITH "NEDEN?" BUTTONS
                        allModulesWithWhySection
                        
                        // 4. CLAIM vs OBJECTION SUMMARY
                        claimObjectionSection
                        
                        // 5. VETOES (if any)
                        if !decision.vetoes.isEmpty {
                            vetoesSection
                        }
                        
                        // 6. TERMINOLOGY GLOSSARY
                        terminologySection
                        
                        // 7. EXTERNAL ADVISORS
                        if !decision.advisors.isEmpty {
                            Text("Danışman Görüşleri")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            ArgusAdvisorsView(advisors: decision.advisors)
                        }

                        // 8. LEARNING INSIGHT
                        learningSection
                    }
                    .padding()
                }
                .background(Color.black.ignoresSafeArea())
                
                // System Info Card Overlay
                if showInfoCard {
                    SystemInfoCard(entity: .argus, isPresented: $showInfoCard)
                        .zIndex(100)
                }
            }
            .navigationTitle("Konsey Tartışması")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showInfoCard = true }) {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear {
                startAnimation()
            }
            .sheet(item: $selectedTerm) { term in
                AgoraTermDetailSheet(term: term)
            }
        }
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        // Animate each step sequentially
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    animationStep = i
                }
            }
        }
    }
    
    // MARK: - Verdict Header
    private var verdictHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(decision.symbol)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                Text(decision.action.rawValue)
                    .font(.headline)
                    .foregroundColor(colorForAction(decision.action))
            }
            
            Spacer()
            
            // Confidence Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: decision.confidence)
                    .stroke(colorForAction(decision.action), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(decision.confidence * 100))%")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(colorForAction(decision.action).opacity(0.2))
        .cornerRadius(16)
    }
    
    // MARK: - Animated Debate Section
    private var animatedDebateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "scroll.fill")
                    .foregroundColor(.cyan)
                Text("Canlı Tartışma")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    animationStep = 0
                    startAnimation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.gray)
                }
            }
            
            // Step 1: CLAIM
            if animationStep >= 1 {
                animatedDebateCard(
                    step: "1️⃣ İDDİA",
                    speaker: claimantModule,
                    speakerIcon: iconForModule(claimantModule),
                    speakerColor: colorForModule(claimantModule),
                    speech: claimSpeech,
                    isNew: animationStep == 1
                )
                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            }
            
            // Step 2: SUPPORT
            if animationStep >= 2 {
                animatedDebateCard(
                    step: "2️⃣ DESTEK",
                    speaker: supporterModules.isEmpty ? "Yok" : supporterModules,
                    speakerIcon: "hand.thumbsup.fill",
                    speakerColor: .blue,
                    speech: supportSpeech,
                    isNew: animationStep == 2
                )
                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            }
            
            // Step 3: OBJECTION
            if animationStep >= 3 {
                animatedDebateCard(
                    step: "3️⃣ İTİRAZ",
                    speaker: objectorModules.isEmpty ? "Yok" : objectorModules,
                    speakerIcon: "hand.raised.fill",
                    speakerColor: .orange,
                    speech: objectionSpeech,
                    isNew: animationStep == 3
                )
                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            }
            
            // Step 4: FINAL VERDICT
            if animationStep >= 4 {
                animatedDebateCard(
                    step: "4️⃣ NİHAİ KARAR",
                    speaker: "KONSEY",
                    speakerIcon: "gavel.fill",
                    speakerColor: colorForAction(decision.action),
                    speech: "Tüm görüşler değerlendirildi. Karar: \(decision.action.rawValue). \(decision.reasoning)",
                    isNew: animationStep == 4
                )
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func animatedDebateCard(step: String, speaker: String, speakerIcon: String, speakerColor: Color, speech: String, isNew: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: speakerIcon)
                    .foregroundColor(speakerColor)
                
                Text(step)
                    .font(.caption)
                    .bold()
                    .foregroundColor(speakerColor)
                
                Spacer()
                
                Text(speaker)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Speech bubble
            HStack(alignment: .top) {
                Image(systemName: "quote.opening")
                    .font(.caption2)
                    .foregroundColor(speakerColor.opacity(0.5))
                
                Text(speech)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .italic()
                
                Spacer()
            }
        }
        .padding()
        .background(speakerColor.opacity(isNew ? 0.2 : 0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(speakerColor.opacity(isNew ? 0.5 : 0.2), lineWidth: isNew ? 2 : 1)
        )
        .scaleEffect(isNew ? 1.02 : 1.0)
    }
    
    // MARK: - All Modules with "Why?" Buttons
    private var allModulesWithWhySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.cyan)
                Text("Modül Detayları")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Her modülün neden böyle düşündüğünü öğrenmek için 'Neden?' butonuna tıklayın")
                .font(.caption2)
                .foregroundColor(.gray)
            
            // ORION
            moduleCardWithWhy(
                name: "ORION",
                icon: "chart.xyaxis.line",
                color: .cyan,
                stance: stanceForOrion,
                action: decision.orionDecision.action.rawValue,
                confidence: decision.orionDecision.netSupport,
                whyExplanation: orionWhyExplanation,
                isExpanded: expandedModule == "ORION"
            )
            
            // ATLAS
            if let atlas = decision.atlasDecision {
                moduleCardWithWhy(
                    name: "ATLAS",
                    icon: "building.columns.fill",
                    color: .yellow,
                    stance: stanceForAtlas(atlas),
                    action: atlas.action.rawValue,
                    confidence: atlas.netSupport,
                    whyExplanation: atlasWhyExplanation(atlas),
                    isExpanded: expandedModule == "ATLAS"
                )
            } else {
                moduleCardUnavailable(name: "ATLAS", icon: "building.columns.fill", color: .yellow, reason: "Fundamental veri yok. Sanctum'da hisse seçip yenileyin veya bekleyin.")
            }
            
            // AETHER
            moduleCardWithWhy(
                name: "AETHER",
                icon: "globe.europe.africa.fill",
                color: .purple,
                stance: stanceForAether,
                action: decision.aetherDecision.stance.rawValue,
                confidence: decision.aetherDecision.netSupport,
                whyExplanation: aetherWhyExplanation,
                isExpanded: expandedModule == "AETHER"
            )
            
            // HERMES
            if let hermes = decision.hermesDecision {
                moduleCardWithWhy(
                    name: "HERMES",
                    icon: "newspaper.fill",
                    color: .orange,
                    stance: stanceForHermes(hermes),
                    action: hermes.sentiment.rawValue,
                    confidence: hermes.netSupport,
                    whyExplanation: hermesWhyExplanation(hermes),
                    isExpanded: expandedModule == "HERMES"
                )
            } else {
                moduleCardUnavailable(name: "HERMES", icon: "newspaper.fill", color: .orange, reason: "Haber verisi yok. Sanctum'da Hermes kartından 'Haberleri Tara' butonuna tıklayın.")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func moduleCardWithWhy(name: String, icon: String, color: Color, stance: DebateStance, action: String, confidence: Double, whyExplanation: String, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                
                Spacer()
                
                // Stance badge
                Text(stance.label)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stance.color.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(stance.color)
                
                // Action badge
                Text(action)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(.white)
                
                // Why button
                Button(action: {
                    withAnimation(.spring()) {
                        expandedModule = expandedModule == name ? nil : name
                    }
                }) {
                    Text("Neden?")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
            
            // Confidence bar
            HStack {
                Text("Güven:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(confidence), height: 4)
                    }
                }
                .frame(height: 4)
                
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(width: 35, alignment: .trailing)
            }
            
            // Expanded explanation
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(color.opacity(0.3))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                            .foregroundColor(color)
                        Text("Detaylı Açıklama:")
                            .font(.caption)
                            .bold()
                            .foregroundColor(color)
                    }
                    
                    Text(whyExplanation)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
        }
        .padding()
        .background(stance.color.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stance.color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func moduleCardUnavailable(name: String, icon: String, color: Color, reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                
                Text(name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("VERİ YOK")
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.yellow)
                
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.yellow.opacity(0.8))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Claim vs Objection Summary
    private var claimObjectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                Text("Oylama Özeti")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 12) {
                voteSummaryCard(count: supportCount, label: "DESTEK", color: .green)
                voteSummaryCard(count: abstainCount, label: "ÇEKİMSER", color: .gray)
                voteSummaryCard(count: objectionCount, label: "İTİRAZ", color: .red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func voteSummaryCard(count: Int, label: String, color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.title)
                .bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Vetoes Section
    private var vetoesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                HStack(spacing: 4) {
                    Image(systemName: "nosign")
                        .foregroundColor(.red)
                    Text("VETOLAR")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.red)
                }
            }
            
            Text("Bu modüller karara VETO koydu - işlem engellendi:")
                .font(.caption2)
                .foregroundColor(.gray)
            
            ForEach(decision.vetoes, id: \.module) { veto in
                HStack {
                    Text(veto.module)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Text(veto.reason)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Terminology Section
    private var terminologySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("Terim Sözlüğü")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Anlamını öğrenmek için bir terime tıklayın")
                .font(.caption2)
                .foregroundColor(.gray)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(glossaryTerms) { term in
                    Button(action: {
                        selectedTerm = term
                    }) {
                        HStack {
                            Text(term.term)
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Learning Section
    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Ne Öğrendik?")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(learningPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(point)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var claimantModule: String {
        decision.orionDecision.netSupport > 0.5 ? "ORION" : "ATLAS"
    }
    
    private var claimSpeech: String {
        let orion = decision.orionDecision
        switch orion.action {
        case .buy:
            return "Teknik analiz güçlü alım sinyali veriyor. Trend yukarı, momentum pozitif. Net destek: %\(Int(orion.netSupport * 100))."
        case .sell:
            return "Teknik göstergeler satış sinyali veriyor. Trend kırıldı, momentum negatife döndü."
        case .hold:
            return "Teknik açıdan belirgin bir yön yok. Mevcut pozisyon korunmalı."
        }
    }
    
    private var supporterModules: String {
        var supporters: [String] = []
        if stanceForOrion == .support { supporters.append("Orion") }
        if let atlas = decision.atlasDecision, stanceForAtlas(atlas) == .support { supporters.append("Atlas") }
        if stanceForAether == .support { supporters.append("Aether") }
        if let hermes = decision.hermesDecision, stanceForHermes(hermes) == .support { supporters.append("Hermes") }
        return supporters.joined(separator: ", ")
    }
    
    private var supportSpeech: String {
        if supportCount > 0 {
            return "\(supportCount) modül bu karara destek veriyor. Konsensüs sağlanıyor, güven yükseliyor."
        }
        return "Bu karara açık destek veren modül yok. Dikkatli olunmalı."
    }
    
    private var objectorModules: String {
        var objectors: [String] = []
        if stanceForOrion == .object { objectors.append("Orion") }
        if let atlas = decision.atlasDecision, stanceForAtlas(atlas) == .object { objectors.append("Atlas") }
        if stanceForAether == .object { objectors.append("Aether") }
        if let hermes = decision.hermesDecision, stanceForHermes(hermes) == .object { objectors.append("Hermes") }
        return objectors.joined(separator: ", ")
    }
    
    private var objectionSpeech: String {
        if objectionCount > 0 {
            return "\(objectionCount) modül itiraz ediyor. Risk faktörleri dikkate alınmalı, pozisyon boyutu küçültülebilir."
        }
        return "Bu karara itiraz eden modül yok. Yol açık görünüyor."
    }
    
    private var supportCount: Int {
        var count = 0
        if stanceForOrion == .support { count += 1 }
        if let atlas = decision.atlasDecision, stanceForAtlas(atlas) == .support { count += 1 }
        if stanceForAether == .support { count += 1 }
        if let hermes = decision.hermesDecision, stanceForHermes(hermes) == .support { count += 1 }
        return count
    }
    
    private var objectionCount: Int {
        var count = 0
        if stanceForOrion == .object { count += 1 }
        if let atlas = decision.atlasDecision, stanceForAtlas(atlas) == .object { count += 1 }
        if stanceForAether == .object { count += 1 }
        if let hermes = decision.hermesDecision, stanceForHermes(hermes) == .object { count += 1 }
        return count
    }
    
    private var abstainCount: Int {
        var count = 0
        if stanceForOrion == .abstain { count += 1 }
        if decision.atlasDecision == nil { count += 1 }
        if stanceForAether == .abstain { count += 1 }
        if decision.hermesDecision == nil { count += 1 }
        return count
    }
    
    // MARK: - Why Explanations
    
    private var orionWhyExplanation: String {
        let orion = decision.orionDecision
        return """
        ORION Teknik Analiz Modülü, fiyat grafiğindeki kalıpları ve göstergeleri inceler.
        
        Bu hisse için:
        • Sinyal Gücü: \(orion.signalStrength)
        • Net Destek: %\(Int(orion.netSupport * 100))
        • Aksiyon: \(orion.action.rawValue)
        
        Orion şu göstergeleri analiz eder: RSI (aşırı alım/satım), MACD (trend), Bollinger Bantları (volatilite), EMA (trend yönü), Hacim profili.
        """
    }
    
    private func atlasWhyExplanation(_ atlas: AtlasDecision) -> String {
        return """
        ATLAS Temel Analiz Modülü, şirketin finansal sağlığını değerlendirir.
        
        Bu hisse için:
        • Aksiyon: \(atlas.action.rawValue)
        • Net Destek: %\(Int(atlas.netSupport * 100))
        
        Atlas şunlara bakar: P/E oranı, borç/özkaynak, gelir büyümesi, kar marjı, nakit akışı.
        
        Güçlü finansallar = Uzun vadeli güvenlik.
        """
    }
    
    private var aetherWhyExplanation: String {
        let aether = decision.aetherDecision
        return """
        AETHER Makroekonomik Analiz Modülü, piyasa atmosferini değerlendirir.
        
        Şu an:
        • Rejim: \(aether.stance.rawValue)
        • Piyasa Modu: \(aether.marketMode.rawValue)
        
        Aether şunlara bakar: VIX (korku endeksi), tahvil faizleri, dolar endeksi, emtia fiyatları, küresel risk iştahı.
        
        Risk-On = Alım zamanı, Risk-Off = Bekle veya sat.
        """
    }
    
    private func hermesWhyExplanation(_ hermes: HermesDecision) -> String {
        let headlines = hermes.keyHeadlines.prefix(2).joined(separator: ", ")
        return """
        HERMES Haber Analizi Modülü, son haberlerin etkisini değerlendirir.
        
        Bu hisse için:
        • Duygu Durumu: \(hermes.sentiment.displayTitle)
        • Etki Seviyesi: \(hermes.isHighImpact ? "YÜKSEK" : "Normal")
        
        Öne çıkan haberler: \(headlines.isEmpty ? "Analiz edilmedi" : headlines)
        
        Hermes, haberlerin fiyat üzerindeki potansiyel etkisini ölçer.
        """
    }
    
    private var learningPoints: [String] {
        var points: [String] = []
        
        // Consensus lesson
        if supportCount >= 3 {
            points.append("Güçlü konsensüs: \(supportCount) modül aynı yönde düşünüyor. Bu güvenilir bir sinyal.")
        } else if objectionCount > supportCount {
            points.append("Çoklu itiraz var. En az \(objectionCount) modül farklı düşünüyor. Risk yüksek.")
        }
        
        // Data completeness lesson
        if decision.atlasDecision == nil {
            points.append("Atlas (temel analiz) eksik. Finansal veriler yüklenirse karar daha güvenilir olur.")
        }
        if decision.hermesDecision == nil {
            points.append("Hermes (haber) eksik. Beklenmedik haberler fiyatı etkileyebilir.")
        }
        
        // Macro lesson
        if stanceForAether == .object {
            points.append("Makro ortam olumsuz. Piyasa genelinde satış baskısı var.")
        } else if stanceForAether == .support {
            points.append("Makro ortam olumlu. Risk iştahı yüksek, alımlar destekleniyor.")
        }
        
        // General insight
        points.append("Konsey sistemi, birden fazla perspektifi birleştirerek daha dengeli kararlar verir.")
        
        return points
    }
    
    private var glossaryTerms: [TermDefinition] {
        [
            TermDefinition(term: "Net Destek", definition: "Bir modülün kararına olan güven yüzdesi. %70+ güçlü sinyal, %30- zayıf sinyal."),
            TermDefinition(term: "Veto", definition: "Bir modülün işlemi tamamen engellemesi. Kritik risk tespit edildiğinde kullanılır."),
            TermDefinition(term: "Konsensüs", definition: "Birden fazla modülün aynı yönde karar vermesi. Güvenilirliği artırır."),
            TermDefinition(term: "Risk-On", definition: "Piyasaların risk almaya istekli olduğu dönem. Hisse senetleri yükselir."),
            TermDefinition(term: "Risk-Off", definition: "Korku ve belirsizlik dönemi. Yatırımcılar güvenli limanlara kaçar."),
            TermDefinition(term: "Makro", definition: "Ekonominin genel durumu: faizler, enflasyon, büyüme, işsizlik vb.")
        ]
    }
    
    // MARK: - Stance Helpers
    
    private var stanceForOrion: DebateStance {
        let action = decision.orionDecision.action
        switch decision.action {
        case .aggressiveBuy, .accumulate:
            return action == .buy ? .support : (action == .sell ? .object : .abstain)
        case .trim, .liquidate:
            return action == .sell ? .support : (action == .buy ? .object : .abstain)
        case .neutral:
            return .abstain
        }
    }
    
    private func stanceForAtlas(_ atlas: AtlasDecision) -> DebateStance {
        switch decision.action {
        case .aggressiveBuy, .accumulate:
            return atlas.action == .buy ? .support : (atlas.action == .sell ? .object : .abstain)
        case .trim, .liquidate:
            return atlas.action == .sell ? .support : (atlas.action == .buy ? .object : .abstain)
        case .neutral:
            return .abstain
        }
    }
    
    private var stanceForAether: DebateStance {
        let stance = decision.aetherDecision.stance
        switch decision.action {
        case .aggressiveBuy, .accumulate:
            return stance == .riskOn ? .support : (stance == .riskOff ? .object : .abstain)
        case .trim, .liquidate:
            return stance == .riskOff ? .support : (stance == .riskOn ? .object : .abstain)
        case .neutral:
            return .abstain
        }
    }
    
    private func stanceForHermes(_ hermes: HermesDecision) -> DebateStance {
        let sentimentStr = "\(hermes.sentiment)"
        let isPositive = sentimentStr.lowercased().contains("positive")
        let isNegative = sentimentStr.lowercased().contains("negative")
        
        switch decision.action {
        case .aggressiveBuy, .accumulate:
            return isPositive ? .support : (isNegative ? .object : .abstain)
        case .trim, .liquidate:
            return isNegative ? .support : (isPositive ? .object : .abstain)
        case .neutral:
            return .abstain
        }
    }
    
    // MARK: - Helpers
    
    private func colorForAction(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return .green
        case .accumulate: return .blue
        case .neutral: return .gray
        case .trim: return .orange
        case .liquidate: return .red
        }
    }
    
    private func iconForModule(_ module: String) -> String {
        switch module {
        case "ORION": return "chart.xyaxis.line"
        case "ATLAS": return "building.columns.fill"
        case "AETHER": return "globe.europe.africa.fill"
        case "HERMES": return "newspaper.fill"
        default: return "person.fill"
        }
    }
    
    private func colorForModule(_ module: String) -> Color {
        switch module {
        case "ORION": return .cyan
        case "ATLAS": return .yellow
        case "AETHER": return .purple
        case "HERMES": return .orange
        default: return .gray
        }
    }
}

// MARK: - Supporting Types

enum DebateStance {
    case claim, support, object, abstain
    
    var label: String {
        switch self {
        case .claim: return "İDDİA"
        case .support: return "DESTEK"
        case .object: return "İTİRAZ"
        case .abstain: return "ÇEKİMSER"
        }
    }
    
    var color: Color {
        switch self {
        case .claim: return .green
        case .support: return .blue
        case .object: return .red
        case .abstain: return .gray
        }
    }
}

struct TermDefinition: Identifiable {
    let id = UUID()
    let term: String
    let definition: String
}

struct AgoraTermDetailSheet: View {
    let term: TermDefinition
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(term.term)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                Text(term.definition)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Terim Açıklaması")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tamam") { dismiss() }
                }
            }
        }
    }
}
