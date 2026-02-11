import SwiftUI

struct BrandStoryView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding()
                    
                    // Argus Section
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .argus, size: 80)
                        
                        HStack {
                            Text("ARGUS")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.argus.color)
                                .tracking(4)
                            
                            Button(action: { showInfo(.argus) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.argus.color)
                                    .font(.title2)
                            }
                        }
                        
                        Text("The All-Seeing Analyst")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("İsmini Yunan mitolojisindeki 100 gözlü dev Argus Panoptes'ten alır. Argus, asla uyumaz ve her şeyi görür.\n\nAlgoritmamız da piyasadaki binlerce veri noktasını aynı anda tarar, hiçbir detayı kaçırmaz ve en derin temel analizleri saniyeler içinde sunar.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                        .background(Theme.secondaryBackground)
                    
                    // Aether Section
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .aether, size: 80)
                        
                        HStack {
                            Text("AETHER")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.aether.color)
                                .tracking(4)
                            
                            Button(action: { showInfo(.aether) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.aether.color)
                                    .font(.title2)
                            }
                        }
                        
                        Text("The Market Atmosphere")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Mitolojide tanrıların soluduğu saf, üst atmosfer tabakasıdır. Dünyevi kaosun üzerindeki berrak gökyüzünü temsil eder.\n\nArgus Aether, piyasanın gürültüsünden (noise) arınarak makro ekonomik iklimi koklar. Fırtına mı geliyor yoksa hava açık mı? Sadece fiyatı değil, atmosferi analiz eder.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                        
                        // Data Status Section
                        if let rating = MacroRegimeService.shared.getCachedRating() {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Veri Durumu")
                                    .font(.headline)
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                StatusRow(label: "Hisse Senedi (SPY)", isActive: rating.equityRiskScore != nil)
                                StatusRow(label: "Volatilite (VIX)", isActive: rating.volatilityScore != nil)
                                StatusRow(label: "Altın (XAU/USD)", isActive: rating.safeHavenScore != nil)
                                StatusRow(label: "Kripto (BTC)", isActive: rating.cryptoRiskScore != nil)
                            }
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                        .background(Theme.secondaryBackground)
                    
                    // Orion Section (New)
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .orion, size: 80)
                        
                        HStack {
                            Text("ORION")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.orion.color)
                                .tracking(4)
                            
                            Button(action: { showInfo(.orion) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.orion.color)
                                    .font(.title2)
                            }
                        }
                        
                        Text("The Hunter")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Mitolojideki büyük avcı. Orion, Argus'un gördüğü ve Aether'in kokladığı ortamda avını (fırsatları) yakalar.\n\nTeknik analiz ve zamanlama ustasıdır. Temel analiz (Argus) 'Ne almalı?' sorusunu, Makro analiz (Aether) 'Ne zaman almalı?' sorusunu, Orion ise 'Hangi fiyattan girmeli?' sorusunu yanıtlar.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }
                    Divider()
                        .background(Theme.secondaryBackground)
                    
                    // Demeter Section (New)
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .demeter, size: 80)
                        
                        HStack {
                            Text("DEMETER")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.demeter.color) // Mode enum updated
                                .tracking(4)
                            
                            Button(action: { showInfo(.demeter) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.demeter.color)
                                    .font(.title2)
                            }
                        }
                        
                        Text("The Harvest Guardian")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Yunan mitolojisinde tarım ve bereket tanrıçası. Piyasada sermayenin nereye aktığını (Sector Rotation) analiz eder.\n\nChronos zamanı ölçerdi, Demeter ise verimi ölçer. Hangi sektörün 'hasat zamanı' geldiğini ve hangisinin nadasa bırakılması gerektiğini söyler.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }
                    .padding(.top)

                    Divider().background(Theme.secondaryBackground)
                    
                    // Atlas Section
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .atlas, size: 80)
                        HStack {
                            Text("ATLAS")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.atlas.color)
                                .tracking(4)
                            Button(action: { showInfo(.atlas) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.atlas.color)
                                    .font(.title2)
                            }
                        }
                        Text("The Valuator")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        Text("Mitolojide gök kubbeyi taşıyan titan. Şirketlerin mali yükünü ve gerçek değerini tartar.\n\nBilançoları, nakit akışlarını ve rasyoları analiz ederek 'Bu hisse pahalı mı, ucuz mu?' sorusunu yanıtlar. Fiyat etiketiyle değil, değerle ilgilenir.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }
                    
                    Divider().background(Theme.secondaryBackground)
                    
                    // Hermes Section
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .hermes, size: 80)
                        HStack {
                            Text("HERMES")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.hermes.color)
                                .tracking(4)
                            Button(action: { showInfo(.hermes) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.hermes.color)
                                    .font(.title2)
                            }
                        }
                        Text("The Messenger")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        Text("Tanrıların habercisi. Piyasadaki tüm haber akışını, KAP bildirimlerini ve sosyal medya sinyallerini tarar.\n\nFiyat hareketlenmeden önce bilgiyi yakalar. Hız onun silahıdır.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }
                    
                    Divider().background(Theme.secondaryBackground)
                    
                    // Council Section
                    VStack(spacing: 16) {
                        ArgusEyeView(mode: .council, size: 80)
                        HStack {
                            Text("KONSEY")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ArgusMode.council.color)
                                .tracking(4)
                            Button(action: { showInfo(.council) }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(ArgusMode.council.color)
                                    .font(.title2)
                            }
                        }
                        Text("The Final Decision")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        Text("Agora Konseyi. Tüm modüllerin (Argus, Orion, Atlas, Aether) oylarını toplar ve nihai kararı verir.\n\nDemokratik bir yapay zeka yönetimidir. Çelişkili sinyaller burada çözülür ve işlem emrine dönüşür.")
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 40)
            }
            
            // Info Overlay
            if showInfoCard {
                SystemInfoCard(entity: selectedEntity, isPresented: $showInfoCard)
                    .zIndex(100)
            }
        }
    }
    
    // Logic
    @State private var showInfoCard = false
    @State private var selectedEntity: ArgusSystemEntity = .argus
    
    func showInfo(_ entity: ArgusSystemEntity) {
        selectedEntity = entity
        withAnimation {
            showInfoCard = true
        }
    }
}

struct BrandStoryView_Previews: PreviewProvider {
    static var previews: some View {
        BrandStoryView()
    }
}

struct StatusRow: View {
    let label: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isActive ? .green : .orange)
            Text(isActive ? "Aktif" : "Veri Yok")
                .font(.caption)
                .foregroundColor(isActive ? .green : .orange)
        }
    }
}
