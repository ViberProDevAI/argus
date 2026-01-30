import SwiftUI

// MARK: - System Overview Sheet

struct SystemOverviewSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title("ARGUS İŞLETİM SİSTEMİ")
                    subtitle("Sistem mimarisi ve veri akışı")
                    
                    Divider().background(Theme.tint.opacity(0.3))
                    
                    educationSection("FASE 1: VERİ ALIMI") {
                        contentItem("Kaynaklar", "BIST, Yahoo Finance, EODHD, TCMB")
                        contentItem("Frekans", "1-5 dakika (anlık), günlük (temel)")
                        contentItem("Kontrol", "Heimdall Veri Kapısı → Devre Kesici")
                        
                        financialTip("İP: Veri gecikmesi hisse için çok kritik.")
                    }
                    
                    educationSection("FASE 2: SİNYAL ÜRETİMİ") {
                        contentItem("Orion", "Teknik momentum motoru (SAR, TSI, RSI)")
                        contentItem("Atlas", "Temel analiz motoru (F/K, PD/DD)")
                        contentItem("Phoenix", "Trend yakalama (ADX, Parabolik SAR)")
                        contentItem("Hermes", "Haber etki analizi (duygu puanı)")
                        contentItem("Chiron", "Makro rejim motoru (piyasa hali)")
                        
                        financialTip("İP: Her motor kendi bakış açısından bakar. Toplanınca Argus Karar.")
                    }
                    
                    educationSection("FASE 3: KARAR MOTORU") {
                        contentItem("Argus Konseyi", "Tüm motorların oyları tartılır")
                        contentItem("OtoPilot", "Son karar portföy ağırlığını günceller")
                        contentItem("Risk Kontrolü", "RiskBütçeServisi → Zarar-durdurma")
                        
                        financialTip("İP: Konsey 'oy ver' değil, tartar. Her motorun ağırlığı var.")
                    }
                    
                    educationSection("FASE 4: İŞLEM") {
                        contentItem("İleri Testi", "Kağıt üzerinde işlem (ön deneme)")
                        contentItem("Gerçek İşlem", "Broker arayüzü üzerinden (gelecek)")
                        contentItem("Tekrar Simülasyon", "Geçmiş sinyalleri yeniden canlandır")
                        
                        financialTip("İP: İleri testi yaptığınızda gerçek piyasadaki gibi.")
                    }
                }
                .padding()
            }
            .navigationTitle("Sistem Nasıl Çalışır?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .tracking(1.5)
    }
    
    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom, 8)
    }
    
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.tint)
            
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func contentItem(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
    
    private func financialTip(_ message: String) -> some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Theme.tint)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
        }
        .padding(12)
        .background(Theme.tint.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 8)
    }
}

// MARK: - Alkindus Education Sheet

struct AlkindusEducationSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title("ALKINDUS MOTORU")
                    subtitle("Yapay Zeka Piyasa Rehberi")
                    
                    Divider().background(Theme.tint.opacity(0.3))
                    
                    educationSection("YETENEK 1: PİYASA SORGULAMA") {
                        contentItem("Girdi", "Doğal dil soruları")
                        contentItem("Örnek", "XU100 bugün ne yapacak?")
                        contentItem("Çıktı", "Teknik + temel sinyal özeti")
                        
                        financialTip("İP: Sorguları Türkçe yazın, sistem anlar.")
                    }
                    
                    educationSection("YETENEK 2: STRATEJİ ÖNERİLERİ") {
                        contentItem("Senaryo", "Piyasa rejimi (trend/çapraz/riskli)")
                        contentItem("Öneri", "Uygun motor önerilir")
                        contentItem("Örnek", "Çapraz piyasa → Çorba Dalgası Aktif")
                        
                        financialTip("İP: 'Hangi motoru kullanmalıyım?' diye sorun.")
                    }
                    
                    educationSection("YETENEK 3: SINAV MANTIĞI") {
                        contentItem("Konsey", "Her motor kendi bakış açısını sunar")
                        contentItem("Toplama", "Alkindus doğal dilde özetler")
                        contentItem("İyileşme", "Geri bildirimle gelişir")
                        
                        financialTip("İP: Alkindus 'roket' değil, 'rehber'. Öğretir, emir vermez.")
                    }
                    
                    educationSection("VERİ AKIŞI") {
                        contentItem("1", "Soru → LLM Servisi")
                        contentItem("2", "Sorgu → Tüm Motorlar")
                        contentItem("3", "Toplama → Konsey Oylaması")
                        contentItem("4", "Çıktı → Doğal Dil Özeti")
                    }
                }
                .padding()
            }
            .navigationTitle("Alkindus Rehberi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .tracking(1.5)
    }
    
    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom, 8)
    }
    
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.tint)
            
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func contentItem(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
    
    private func financialTip(_ message: String) -> some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Theme.tint)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
        }
        .padding(12)
        .background(Theme.tint.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 8)
    }
}

// MARK: - Argus Lab Education Sheet

struct ArgusLabEducationSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title("ARGUS GERÇEK ZAMAN TESTİ")
                    subtitle("Strateji backtesting")
                    
                    Divider().background(Theme.tint.opacity(0.3))
                    
                    educationSection("TEMEL İLKELER") {
                        contentItem("İleri Testi", "Geçmiş veriye sinyal uygula")
                        contentItem("Nokta-Vakit", "Geleceğe bakma (yanlılık yok)")
                        contentItem("Maliyetler", "Komisyon + kayma")
                        contentItem("Rejim Uyumu", "Makro değişimleri dahil et")
                        
                        financialTip("İP: 'Neden bugün almadın?' demeyin. Gerçek zaman testi yapın.")
                    }
                    
                    educationSection("METRİKLER") {
                        contentItem("Sharpe Oranı", "Düzeltilmiş getiri")
                        contentItem("Maksimum Çekilme", "En büyük düşüş")
                        contentItem("Kazanma Oranı", "Kazanma payı")
                        contentItem("Kâr Faktörü", "Brüt kârlar/kayıplar")
                        
                        financialTip("İP: Sharpe 1'den düşükse, riskin karşılığı yok demek.")
                    }
                    
                    educationSection("DENEME SENARYOSU") {
                        contentItem("1", "2020 BIST verisi seç")
                        contentItem("2", "Orion motorunu aktif et")
                        contentItem("3", "Gerçek portföy oluştur")
                        contentItem("4", "Sonuçları incele")
                        contentItem("5", "Ağırlıkları dene (ince ayar)")
                        
                        financialTip("İP: İnce ayar yaparken 'överoptimization'a düşmeyin.")
                    }
                }
                .padding()
            }
            .navigationTitle("Argus Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    // Helpers
    private func title(_ text: String) -> some View {
        Text(text).font(.title2).fontWeight(.bold).foregroundColor(.white).tracking(1.5)
    }
    private func subtitle(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(Theme.textSecondary).padding(.bottom, 8)
    }
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundColor(Theme.tint)
            content()
        }.padding(16).background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.tint.opacity(0.2), lineWidth: 1))
    }
    private func contentItem(_ key: String, _ value: String) -> some View {
        HStack { Text(key).font(.subheadline).foregroundColor(.gray).frame(width: 120, alignment: .leading); Text(value).font(.subheadline).foregroundColor(.white).fontWeight(.medium) }
    }
    private func financialTip(_ message: String) -> some View {
        HStack { Image(systemName: "lightbulb.fill").foregroundColor(Theme.tint).font(.caption); Text(message).font(.caption).foregroundColor(Theme.textSecondary); Spacer() }.padding(12).background(Theme.tint.opacity(0.1)).cornerRadius(8).padding(.top, 8)
    }
}

// MARK: - Orion Lab Education Sheet

struct OrionLabEducationSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title("ORION TEKNİK MOTORU")
                    subtitle("Momentum ve trend analizi")
                    Divider().background(Theme.tint.opacity(0.3))
                    educationSection("GÖSTERGE KITI") {
                        contentItem("SAR (Parabolik)", "Trend yakalama, aktif trendde")
                        contentItem("TSI (Gerçek Güç)", "Momentum gücü, aşırı alım/satış")
                        contentItem("RSI (Göreceli)", "İç dinamik, ayrışma")
                        contentItem("ADX", "Trend gücü")
                        financialTip("İP: SAR yatay piyasa size 'çorba içirir'. Önce ADX kontrol edin.")
                    }
                    educationSection("GÖSTERGE DETAYLARI") {
                        contentItem("Aşırı Alım", "TSI +70 üzeri → bekleyin")
                        contentItem("Aşırı Satış", "TSI -70 altı → girin")
                        contentItem("Trend Var", "ADX > 25")
                        contentItem("Trend Yok", "ADX < 20 → çapraz piyasa")
                        financialTip("İP: ADX 10 ise piyasa çizip çizmekte demektir.")
                    }
                    educationSection("ÇOKLU ZAMAN ÇERÇEVESİ") {
                        contentItem("Günlük", "Trend yönü (makro)")
                        contentItem("4 Saat", "Güçlü destek/direnç")
                        contentItem("1 Saat", "Giriş/çıkış sinyali")
                        contentItem("15 Dakika", "Anlık ayıklama")
                        financialTip("İP: 4S ADX'i kontrol edin. Trend varsa günlük SAR'a bakın.")
                    }
                    educationSection("KULLANIM DÜZEYİ") {
                        contentItem("1", "4S ADX kontrol et → Trend var mı?")
                        contentItem("2", "Günlük SAR → Ana trend yönü")
                        contentItem("3", "1S TSI → Momentum yönü")
                        contentItem("4", "Ayrışma kontrolü → Tersine dönüş riski")
                        financialTip("İP: SAR kırıldığında çıkın. Divergence görünce dikkatli olun.")
                    }
                }.padding()
            }
            .navigationTitle("Orion Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }
        }
    }
    // Helpers copied from others
    private func title(_ text: String) -> some View { Text(text).font(.title2).fontWeight(.bold).foregroundColor(.white).tracking(1.5) }
    private func subtitle(_ text: String) -> some View { Text(text).font(.caption).foregroundColor(Theme.textSecondary).padding(.bottom, 8) }
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline).foregroundColor(Theme.tint); content() }.padding(16).background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.tint.opacity(0.2), lineWidth: 1)) }
    private func contentItem(_ key: String, _ value: String) -> some View { HStack { Text(key).font(.subheadline).foregroundColor(.gray).frame(width: 120, alignment: .leading); Text(value).font(.subheadline).foregroundColor(.white).fontWeight(.medium) } }
    private func financialTip(_ message: String) -> some View { HStack { Image(systemName: "lightbulb.fill").foregroundColor(Theme.tint).font(.caption); Text(message).font(.caption).foregroundColor(Theme.textSecondary); Spacer() }.padding(12).background(Theme.tint.opacity(0.1)).cornerRadius(8).padding(.top, 8) }
}

// MARK: - Atlas Lab Education Sheet

struct AtlasLabEducationSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title("ATLAS TEMEL MOTORU")
                    subtitle("Temel analiz ve değerleme")
                    Divider().background(Theme.tint.opacity(0.3))
                    educationSection("METRİK DÜZEYLERİ") {
                        contentItem("SEVİYE 1", "Karlılık")
                        contentItem("PD/DD", "Fiyat defter değeri")
                        contentItem("F/K", "Fiyat kâr oranı")
                        contentItem("FD/FAV", "Fiyat defter varlık")
                        financialTip("İP: PD/DD 0.5 ise defter değerinin yarısına demek.")
                    }
                    educationSection("SEVİYE 2: BÜYÜME") {
                        contentItem("CAGR", "Bileşik yıllık büyüme")
                        contentItem("Son 4 Çeyrek", "Büyüme trendi")
                        financialTip("İP: CAGR 15'den yüksekse şirket hızlı büyüyor demek.")
                    }
                    educationSection("SEVİYE 3: BORÇLULUK") {
                        contentItem("Özkaynak", "Toplam varlık oranı")
                        contentItem("Net Borç", "Özkaynak oranı")
                        financialTip("İP: Borç %50'den yüksekse risk artar.")
                    }
                    educationSection("PUAN SİSTEMİ") {
                        contentItem("Her metrik", "0-100 arası puan")
                        contentItem("Ağırlık", "PD/DD 40%, F/K 30%, CAGR 20%, Borç 10%")
                        contentItem("70-100", "Güçlü al")
                        contentItem("50-70", "Orta al")
                        contentItem("30-50", "Bekle")
                        contentItem("10-30", "Orta sat")
                        contentItem("0-10", "Güçlü sat")
                        financialTip("İP: Atlas 90/100 veriyorsa temel olarak çok ucuz demek.")
                    }
                    educationSection("VERİ KAYNAKLARI") {
                        contentItem("KAP", "Kamuoyu Aydınlatma")
                        contentItem("Matriks", "İnteraktif veriler")
                        contentItem("BIST", "Veri havuzları")
                        financialTip("İP: KAP verileri resmi, güvenilir kaynaktır.")
                    }
                }.padding()
            }
            .navigationTitle("Atlas Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }
        }
    }
    // Helpers
    private func title(_ text: String) -> some View { Text(text).font(.title2).fontWeight(.bold).foregroundColor(.white).tracking(1.5) }
    private func subtitle(_ text: String) -> some View { Text(text).font(.caption).foregroundColor(Theme.textSecondary).padding(.bottom, 8) }
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline).foregroundColor(Theme.tint); content() }.padding(16).background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.tint.opacity(0.2), lineWidth: 1)) }
    private func contentItem(_ key: String, _ value: String) -> some View { HStack { Text(key).font(.subheadline).foregroundColor(.gray).frame(width: 120, alignment: .leading); Text(value).font(.subheadline).foregroundColor(.white).fontWeight(.medium) } }
    private func financialTip(_ message: String) -> some View { HStack { Image(systemName: "lightbulb.fill").foregroundColor(Theme.tint).font(.caption); Text(message).font(.caption).foregroundColor(Theme.textSecondary); Spacer() }.padding(12).background(Theme.tint.opacity(0.1)).cornerRadius(8).padding(.top, 8) }
}

// MARK: - Chiron Lab Education Sheet

struct ChironLabEducationSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title("CHIRON MAKRO MOTORU")
                    subtitle("Piyasa rejimi deteksi")
                    Divider().background(Theme.tint.opacity(0.3))
                    educationSection("REJIM DETECTION") {
                        contentItem("TREND", "Trend piyasası → Orion aktif")
                        contentItem("CHOP", "Yatay piyasa → Çorba Dalgası aktif")
                        contentItem("RISK OFF", "Riskli piyasa → Atlas Kalkanı aktif")
                        contentItem("NEUTRAL", "Belirsiz → Bekleme modu")
                        financialTip("İP: Rejim değiştiğinde hangi motorun ağırlıklandırılacağı belli.")
                    }
                    educationSection("TANIMLAYICILAR") {
                        contentItem("Dalgalanma", "VIX, BIST volatilite indexi")
                        contentItem("Risk Free", "TCMB politika faizi")
                        contentItem("Yabancı", "Yabancı yatırımcı alış/satış")
                        contentItem("Makro Takvim", "FED, TCMB toplantı")
                        financialTip("İP: VIX 30 üzeri ise riskli piyasa demek.")
                    }
                    educationSection("ALGORİTMA") {
                        contentItem("1", "Tüm göstergeleri normalize et")
                        contentItem("2", "Rejim skoru hesapla")
                        contentItem("3", "Dominant rejim seç")
                        contentItem("4", "Motor ağırlıklarını güncelle")
                        financialTip("İP: Chiron 'rejim' değil 'hal' demek.")
                    }
                    educationSection("KULLANIM") {
                        contentItem("Soru", "Şu an hangi rejimdeyiz?")
                        contentItem("Cevap", "Chiron açıkla")
                        contentItem("Karar", "Hangi motor ağırlıklandırılacak?")
                        financialTip("İP: Çorba rejiminde Orion kapatsanız size para kazandırır.")
                    }
                }.padding()
            }
            .navigationTitle("Chiron Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }
        }
    }
    // Helpers
    private func title(_ text: String) -> some View { Text(text).font(.title2).fontWeight(.bold).foregroundColor(.white).tracking(1.5) }
    private func subtitle(_ text: String) -> some View { Text(text).font(.caption).foregroundColor(Theme.textSecondary).padding(.bottom, 8) }
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline).foregroundColor(Theme.tint); content() }.padding(16).background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.tint.opacity(0.2), lineWidth: 1)) }
    private func contentItem(_ key: String, _ value: String) -> some View { HStack { Text(key).font(.subheadline).foregroundColor(.gray).frame(width: 120, alignment: .leading); Text(value).font(.subheadline).foregroundColor(.white).fontWeight(.medium) } }
    private func financialTip(_ message: String) -> some View { HStack { Image(systemName: "lightbulb.fill").foregroundColor(Theme.tint).font(.caption); Text(message).font(.caption).foregroundColor(Theme.textSecondary); Spacer() }.padding(12).background(Theme.tint.opacity(0.1)).cornerRadius(8).padding(.top, 8) }
}

// MARK: - Coming Soon Sheet

struct ComingSoonSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                title("YAKINDA GELECEK")
                subtitle("Bu özellikler geliştirme aşamasında")
                
                Divider().background(Theme.tint.opacity(0.3))
                
                educationSection("BETA MODÜLLER") {
                    contentItem("Sirkiye Aether", "Sektörel akış analizi")
                    contentItem("Poseidon", "Risk simülasyonu")
                    contentItem("Zephyr", "Volatilite scanner")
                    
                    financialTip("İP: Beta modülleri yakında test edebilirsin.")
                }
                
                educationSection("YENİ ÖZELLİKLER") {
                    contentItem("Voice Trading", "Sesli komut desteği")
                    contentItem("Social Sentiment", "Twitter/X analizi")
                    contentItem("Multi-Asset", "Crypto + Forex")
                    
                    financialTip("İP: Roadmap'e güncellemeleri takip edin.")
                }
                
                educationSection("NE ZAMAN?") {
                    contentItem("Q1 2026", "Live broker entegrasyonu")
                    contentItem("Q2 2026", "Voice trading")
                    contentItem("Q3 2026", "Multi-asset")
                    contentItem("Q4 2026", "Social sentiment")
                    
                    financialTip("İP: Yeni özellikler için bekleyen listesine eklenebilirsin.")
                }
            }
            .padding()
        }
        .navigationTitle("Yakında Gelecek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Kapat") { dismiss() }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .tracking(1.5)
    }
    
    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom, 8)
    }
    
    private func educationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.tint)
            
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func contentItem(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
    
    private func financialTip(_ message: String) -> some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Theme.tint)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
        }
        .padding(12)
        .background(Theme.tint.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 8)
    }
}
