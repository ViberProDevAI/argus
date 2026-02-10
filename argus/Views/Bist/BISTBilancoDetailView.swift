import SwiftUI

// MARK: - BIST Bilanço Detay Görünümü
// Atlas V2 yapısının BIST'e uyarlanmış UI'ı

struct BISTBilancoDetailView: View {
    let sembol: String
    @State private var sonuc: BISTBilancoSonuc?
    @State private var yukleniyor = true
    @State private var hata: String?
    @State private var acikBolumler: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if yukleniyor {
                    yukleniyorView
                } else if let hata = hata {
                    hataView(hata)
                } else if let sonuc = sonuc {
                    // Başlık ve Genel Skor
                    baslikKarti(sonuc)
                    egiticiGerekceKarti(sonuc)
                    
                    // Öne Çıkanlar & Uyarılar
                    if !sonuc.oneCikanlar.isEmpty || !sonuc.uyarilar.isEmpty {
                        oneCikanlarKarti(sonuc)
                    }
                    
                    // Bölüm Kartları (Sadece BorsaPy'den çekilebilen veriler)
                    bolumKarti(
                        baslik: "Değerleme",
                        skor: sonuc.degerleme,
                        metrikler: sonuc.degerlemeVerisi.tumMetrikler,
                        bolumId: "degerleme"
                    )

                    bolumKarti(
                        baslik: "Karlılık",
                        skor: sonuc.karlilik,
                        metrikler: sonuc.karlilikVerisi.tumMetrikler,
                        bolumId: "karlilik"
                    )

                    bolumKarti(
                        baslik: "Büyüme",
                        skor: sonuc.buyume,
                        metrikler: sonuc.buyumeVerisi.tumMetrikler,
                        bolumId: "buyume"
                    )

                    bolumKarti(
                        baslik: "Finansal Sağlık",
                        skor: sonuc.saglik,
                        metrikler: sonuc.saglikVerisi.tumMetrikler,
                        bolumId: "saglik"
                    )

                    bolumKarti(
                        baslik: "Nakit Kalitesi",
                        skor: sonuc.nakit,
                        metrikler: sonuc.nakitVerisi.tumMetrikler,
                        bolumId: "nakit"
                    )

                    bolumKarti(
                        baslik: "Temettü",
                        skor: sonuc.temettu,
                        metrikler: sonuc.temettuVerisi.tumMetrikler,
                        bolumId: "temettu"
                    )

                    bolumKarti(
                        baslik: "Risk Analizi",
                        skor: max(0, min(100, 100 - ((sonuc.riskVerisi.beta.deger ?? 1.0) * 20))),
                        metrikler: sonuc.riskVerisi.tumMetrikler,
                        bolumId: "risk"
                    )
                    
                    // Bilgilendirme
                    veriKaynagiNotu
                    
                    // Özet
                    ozetKarti(sonuc)
                }
            }
            .padding()
        }
        .background(InstitutionalTheme.Colors.background)
        .navigationTitle("Bilanço Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await veriYukle()
        }
    }
    
    // MARK: - Başlık Kartı
    
    private func baslikKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("KASA ÇEKİRDEĞİ")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1.1)
                Spacer()
                Text(sonuc.kaliteBandi.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(skorRengi(sonuc.toplamSkor).opacity(0.16))
                    .foregroundColor(skorRengi(sonuc.toplamSkor))
                    .clipShape(Capsule())
            }

            // Şirket İsmi ve Sembol
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sonuc.profil.isim)
                        .font(.title2.bold())
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    HStack(spacing: 8) {
                        Text(sonuc.sembol.replacingOccurrences(of: ".IS", with: ""))
                            .font(.subheadline)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        
                        // BIST Badge
                        Text("BIST")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(InstitutionalTheme.Colors.negative.opacity(0.18))
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                            .cornerRadius(4)
                        
                        // Sektör Badge
                        if let sektor = sonuc.profil.sektor {
                            Text(sektor)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(InstitutionalTheme.Colors.primary.opacity(0.18))
                                .foregroundColor(InstitutionalTheme.Colors.primary)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                
                // Piyasa Değeri
                VStack(alignment: .trailing, spacing: 4) {
                    Text(sonuc.profil.formatliPiyasaDegeri)
                        .font(.headline)
                    Text(sonuc.profil.piyasaDegeriSinifi)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            
            Divider()
            
            // Genel Skor Ring
            HStack(spacing: 24) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: sonuc.toplamSkor / 100)
                        .stroke(
                            LinearGradient(
                                colors: [skorRengi(sonuc.toplamSkor), skorRengi(sonuc.toplamSkor).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(sonuc.toplamSkor))")
                            .font(.title.bold())
                        Text("/100")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                
                // Kalite Bandı
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kalite Bandı")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    HStack {
                        Text(sonuc.kaliteBandi.rawValue)
                            .font(.title.bold())
                            .foregroundColor(skorRengi(sonuc.toplamSkor))
                        Text("(\(sonuc.kaliteBandi.aciklama))")
                            .font(.subheadline)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    
                    Text(sonuc.ozet)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(kartArkaPlan)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(skorRengi(sonuc.toplamSkor).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Öne Çıkanlar Kartı
    
    private func oneCikanlarKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !sonuc.oneCikanlar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                        Text("Pozitif Sinyaller")
                            .font(.caption.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(sonuc.oneCikanlar.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                    }
                    ForEach(sonuc.oneCikanlar, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(InstitutionalTheme.Colors.positive.opacity(0.9))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(item)
                                .font(.subheadline)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(10)
                .background(InstitutionalTheme.Colors.positive.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !sonuc.uyarilar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(InstitutionalTheme.Colors.warning)
                        Text("Kritik Notlar")
                            .font(.caption.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(sonuc.uyarilar.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.warning)
                    }
                    ForEach(sonuc.uyarilar, id: \.self) { uyari in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(InstitutionalTheme.Colors.warning.opacity(0.95))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(uyari)
                                .font(.subheadline)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(10)
                .background(InstitutionalTheme.Colors.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kartArkaPlan)
    }
    
    // MARK: - Bölüm Kartı
    
    private func bolumKarti(baslik: String, skor: Double, metrikler: [BISTMetrik], bolumId: String) -> some View {
        VStack(spacing: 0) {
            // Header
            Button {
                if acikBolumler.contains(bolumId) {
                    acikBolumler.remove(bolumId)
                } else {
                    acikBolumler.insert(bolumId)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(baslik)
                            .font(.headline)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(bolumAltBaslik(bolumId))
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    // Mini Progress Bar
                    miniIlerlemeBar(skor: skor)
                    
                    // Score
                    Text("\(Int(skor))")
                        .font(.headline)
                        .foregroundColor(skorRengi(skor))
                        .monospacedDigit()
                    
                    // Chevron
                    Image(systemName: acikBolumler.contains(bolumId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if let enGuclu = metrikler.max(by: { $0.skor < $1.skor }),
               let enZayif = metrikler.min(by: { $0.skor < $1.skor }) {
                HStack(spacing: 8) {
                    BistBolumMetrikChip(
                        etiket: "Güçlü",
                        metrik: enGuclu,
                        renk: InstitutionalTheme.Colors.positive
                    )
                    BistBolumMetrikChip(
                        etiket: "İzle",
                        metrik: enZayif,
                        renk: aciklamaRengi(enZayif.durum)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, acikBolumler.contains(bolumId) ? 8 : 12)
            }

            let bolumEtkileri = ondeGelenEtkiler(from: metrikler, limit: 3)
            if !bolumEtkileri.isEmpty {
                bolumEtkiSeridi(bolumEtkileri)
                    .padding(.horizontal)
                    .padding(.bottom, acikBolumler.contains(bolumId) ? 8 : 12)
            }
            
            // Expanded Content
            if acikBolumler.contains(bolumId) {
                VStack(spacing: 16) {
                    ForEach(metrikler) { metrik in
                        metrikSatiri(metrik)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .padding(.top, 4)
            }
        }
        .background(kartArkaPlan)
    }
    
    // MARK: - Metrik Satırı
    
    private func metrikSatiri(_ metrik: BISTMetrik) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Üst satır: İsim, Değer, Durum
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metrik.isim)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("Skor \(Int(metrik.skor)) / 100")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                
                Spacer()
                
                Text(metrik.formatliDeger)
                    .font(.subheadline.bold())
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
                
                Text(metrik.durum.etiket.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(aciklamaRengi(metrik.durum).opacity(0.16))
                    .foregroundColor(aciklamaRengi(metrik.durum))
                    .clipShape(Capsule())
            }

            metrikSkorBar(metrik.skor, renk: aciklamaRengi(metrik.durum))
            
            // Sektör karşılaştırması
            if let sektorOrt = metrik.sektorOrtalamasi {
                HStack(spacing: 8) {
                    Text("Sektör Ort:")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(BISTMetrik.formatla(sektorOrt))
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    if let farkMetni = metrikFarkMetni(metrik) {
                        Text(farkMetni)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(aciklamaRengi(metrik.durum))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(aciklamaRengi(metrik.durum).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Açıklama
            Text(metrik.aciklama)
                .font(.caption)
                .foregroundColor(aciklamaRengi(metrik.durum))
                .lineSpacing(1)
            
            // Eğitici not (varsa)
            if !metrik.egitimNotu.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                    Text(metrik.egitimNotu)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .italic()
                }
                .padding(.top, 4)
            }

            if let formul = metrik.formul, !formul.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                    Text(formul)
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
        }
        .padding(10)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Özet Kartı
    
    private func ozetKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                Text("Yatırımcı İçin Özet")
                    .font(.headline)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            
            Text(sonuc.ozet)
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            // Alt bölüm skorları grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                miniSkorKarti("Karlılık", sonuc.karlilik)
                miniSkorKarti("Değerleme", sonuc.degerleme)
                miniSkorKarti("Sağlık", sonuc.saglik)
                miniSkorKarti("Büyüme", sonuc.buyume)
                miniSkorKarti("Nakit", sonuc.nakit)
                miniSkorKarti("Temettü", sonuc.temettu)
            }
        }
        .padding()
        .background(kartArkaPlan)
    }
    
    private func miniSkorKarti(_ baslik: String, _ skor: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(baslik)
                .font(.caption2.weight(.semibold))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(skor))")
                    .font(.headline)
                    .foregroundColor(skorRengi(skor))
                    .monospacedDigit()
                Text(bolumNotu(skor))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(skorRengi(skor))
            }
            metrikSkorBar(skor, renk: skorRengi(skor))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - Helper Views
    
    private var yukleniyorView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(InstitutionalTheme.Colors.primary)
            Text("Bilanço analiz ediliyor...")
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .background(kartArkaPlan)
    }
    
    private func hataView(_ mesaj: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(InstitutionalTheme.Colors.negative)
            Text("Analiz Hatası")
                .font(.headline)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(mesaj)
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Tekrar Dene") {
                Task { await veriYukle() }
            }
            .buttonStyle(.borderedProminent)
            .tint(InstitutionalTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .background(kartArkaPlan)
    }
    
    private func miniIlerlemeBar(skor: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 6)
                
                Capsule()
                    .fill(skorRengi(skor))
                    .frame(width: geo.size.width * (skor / 100), height: 6)
            }
        }
        .frame(width: 60, height: 6)
    }

    private func metrikSkorBar(_ skor: Double, renk: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 5)
                Capsule()
                    .fill(renk)
                    .frame(width: geo.size.width * min(max(skor / 100.0, 0), 1), height: 5)
            }
        }
        .frame(height: 5)
    }

    private func bolumAltBaslik(_ bolumId: String) -> String {
        switch bolumId {
        case "degerleme":
            return "BIST temel değerleme ve oran analizi"
        case "karlilik":
            return "Marjlar, özsermaye verimliliği ve kâr kalitesi"
        case "buyume":
            return "Gelir ve net kâr büyüme dinamikleri"
        case "saglik":
            return "Borç dengesi ve likidite dayanıklılığı"
        case "nakit":
            return "Nakit üretimi ve sürdürülebilir finansman"
        case "temettu":
            return "Dağıtım kapasitesi ve devamlılık riski"
        case "risk":
            return "Beta, korelasyon ve oynaklık profili"
        default:
            return "Çekirdek finansal metrikler"
        }
    }

    private func bolumNotu(_ skor: Double) -> String {
        switch skor {
        case 85...: return "A+"
        case 70..<85: return "A"
        case 55..<70: return "B"
        case 40..<55: return "C"
        case 25..<40: return "D"
        default: return "F"
        }
    }

    private func metrikFarkMetni(_ metrik: BISTMetrik) -> String? {
        guard let deger = metrik.deger, let sektor = metrik.sektorOrtalamasi, sektor != 0 else { return nil }
        let fark = ((deger - sektor) / abs(sektor)) * 100
        let isaret = fark > 0 ? "+" : ""
        return "\(isaret)\(Int(fark.rounded()))%"
    }

    @ViewBuilder
    private func egiticiGerekceKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        let etkiler = ondeGelenEtkiler(from: tumMetrikler(sonuc), limit: 5)
        if !etkiler.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NEDEN BÖYLE?")
                        .font(.caption.weight(.bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text("İlk \(min(3, etkiler.count)) etken")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(etkiler.prefix(3))) { etki in
                            BistEtkiChip(
                                baslik: etki.isim,
                                altYazi: etki.aciklama,
                                puanMetni: String(format: "%+.0f", etki.skor - 50),
                                renk: etkiRengi(etki.etki)
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    let dilimler = donutDilimleri(from: Array(etkiler.prefix(4)))
                    ZStack {
                        Circle()
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 9)
                            .frame(width: 72, height: 72)
                        ForEach(dilimler) { dilim in
                            Circle()
                                .trim(from: dilim.baslangic, to: dilim.bitis)
                                .stroke(dilim.renk, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        Text("Katkı")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("KATKI DAĞILIMI")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        ForEach(Array(etkiler.prefix(3))) { etki in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(etkiRengi(etki.etki))
                                    .frame(width: 6, height: 6)
                                Text(etki.isim)
                                    .font(.caption2)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text(String(format: "%+.0f", etki.skor - 50))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(etkiRengi(etki.etki))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding()
            .background(kartArkaPlan)
        }
    }

    private func bolumEtkiSeridi(_ etkiler: [BistMetrikEtkisi]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(etkiler) { etki in
                    BistEtkiChip(
                        baslik: etki.isim,
                        altYazi: etki.aciklama,
                        puanMetni: String(format: "%+.0f", etki.skor - 50),
                        renk: etkiRengi(etki.etki)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func ondeGelenEtkiler(from metrikler: [BISTMetrik], limit: Int) -> [BistMetrikEtkisi] {
        metrikler
            .map { metrik in
                BistMetrikEtkisi(
                    id: metrik.id,
                    isim: metrik.isim,
                    etki: max(-1, min(1, (metrik.skor - 50.0) / 50.0)),
                    skor: metrik.skor,
                    aciklama: metrik.aciklama
                )
            }
            .sorted { abs($0.etki) > abs($1.etki) }
            .prefix(limit)
            .map { $0 }
    }

    private func donutDilimleri(from etkiler: [BistMetrikEtkisi]) -> [BistDonutDilimi] {
        let buyuklukler = etkiler.map { max(abs($0.etki), 0.05) }
        let toplam = max(buyuklukler.reduce(0, +), 0.001)
        var imlec = 0.0

        return zip(etkiler, buyuklukler).map { etki, buyukluk in
            let baslangic = imlec / toplam
            imlec += buyukluk
            let bitis = imlec / toplam
            return BistDonutDilimi(
                id: etki.id,
                baslangic: baslangic,
                bitis: bitis,
                renk: etkiRengi(etki.etki)
            )
        }
    }

    private func tumMetrikler(_ sonuc: BISTBilancoSonuc) -> [BISTMetrik] {
        sonuc.degerlemeVerisi.tumMetrikler
            + sonuc.karlilikVerisi.tumMetrikler
            + sonuc.buyumeVerisi.tumMetrikler
            + sonuc.saglikVerisi.tumMetrikler
            + sonuc.nakitVerisi.tumMetrikler
            + sonuc.temettuVerisi.tumMetrikler
            + sonuc.riskVerisi.tumMetrikler
    }

    private func etkiRengi(_ etki: Double) -> Color {
        if etki > 0.08 { return InstitutionalTheme.Colors.positive }
        if etki < -0.08 { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.warning
    }
    
    private var veriKaynagiNotu: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Text("Veri Kaynağı")
                    .font(.subheadline.bold())
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            
            Text("Bilanço verileri İş Yatırım HTML scraping yöntemiyle çekilmektedir. Şu an için sadece F/K ve PD/DD rasyoları mevcut olup, Net Kar ve Özkaynak bu verilerden türetilmektedir.")
                .font(.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            Text("Diğer metrikler (ROE, ROA, Borç/Özkaynak vb.) için veri kaynağı güncellenmesi beklenmektedir.")
                .font(.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .italic()
        }
        .padding()
        .background(kartArkaPlan)
    }
    
    private var kartArkaPlan: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: InstitutionalTheme.Colors.background.opacity(0.35), radius: 10, x: 0, y: 5)
    }
    
    private func skorRengi(_ skor: Double) -> Color {
        switch skor {
        case 70...: return InstitutionalTheme.Colors.positive
        case 50..<70: return InstitutionalTheme.Colors.warning
        case 30..<50: return InstitutionalTheme.Colors.warning.opacity(0.85)
        default: return InstitutionalTheme.Colors.negative
        }
    }
    
    private func aciklamaRengi(_ durum: BISTMetrikDurum) -> Color {
        switch durum {
        case .mukemmel, .iyi: return InstitutionalTheme.Colors.positive
        case .notr: return InstitutionalTheme.Colors.textPrimary
        case .dikkat: return InstitutionalTheme.Colors.warning
        case .kotu, .kritik: return InstitutionalTheme.Colors.negative
        case .veriYok: return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    // MARK: - Veri Yükleme
    
    private func veriYukle() async {
        yukleniyor = true
        hata = nil
        
        do {
            let analiz = try await BISTBilancoEngine.shared.analiz(sembol: sembol)
            await MainActor.run {
                self.sonuc = analiz
                self.yukleniyor = false
            }
        } catch {
            await MainActor.run {
                self.hata = error.localizedDescription
                self.yukleniyor = false
            }
        }
    }
}

struct BistBolumMetrikChip: View {
    let etiket: String
    let metrik: BISTMetrik
    let renk: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(etiket.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(renk)
            Divider()
                .frame(height: 12)
                .overlay(InstitutionalTheme.Colors.borderSubtle)
            VStack(alignment: .leading, spacing: 1) {
                Text(metrik.isim)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
                Text(metrik.formatliDeger)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(renk.opacity(0.26), lineWidth: 1)
        )
    }
}

private struct BistMetrikEtkisi: Identifiable {
    let id: String
    let isim: String
    let etki: Double
    let skor: Double
    let aciklama: String
}

private struct BistDonutDilimi: Identifiable {
    let id: String
    let baslangic: CGFloat
    let bitis: CGFloat
    let renk: Color

    init(id: String, baslangic: Double, bitis: Double, renk: Color) {
        self.id = id
        self.baslangic = CGFloat(baslangic)
        self.bitis = CGFloat(bitis)
        self.renk = renk
    }
}

private struct BistEtkiChip: View {
    let baslik: String
    let altYazi: String
    let puanMetni: String
    let renk: Color

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(renk)
                    .lineLimit(1)
                Text(altYazi)
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Text(puanMetni)
                .font(.caption2.weight(.bold))
                .foregroundColor(renk)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(renk.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BISTBilancoDetailView(sembol: "THYAO.IS")
    }
}
