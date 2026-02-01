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
                    
                    // Öne Çıkanlar & Uyarılar
                    if !sonuc.oneCikanlar.isEmpty || !sonuc.uyarilar.isEmpty {
                        oneCikanlarKarti(sonuc)
                    }
                    
                    // Bölüm Kartları (Sadece BorsaPy'den çekilebilen veriler)
                    bolumKarti(
                        baslik: " Değerleme",
                        skor: sonuc.degerleme,
                        metrikler: sonuc.degerlemeVerisi.tumMetrikler,
                        bolumId: "degerleme"
                    )
                    
                    // Bilgilendirme
                    veriKaynagiNotu
                    
                    // Özet
                    ozetKarti(sonuc)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Bilanço Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await veriYukle()
        }
    }
    
    // MARK: - Başlık Kartı
    
    private func baslikKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        VStack(spacing: 16) {
            // Şirket İsmi ve Sembol
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sonuc.profil.isim)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text(sonuc.sembol.replacingOccurrences(of: ".IS", with: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // BIST Badge
                        Text("BIST")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                        
                        // Sektör Badge
                        if let sektor = sonuc.profil.sektor {
                            Text(sektor)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
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
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Genel Skor Ring
            HStack(spacing: 24) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
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
                            .foregroundColor(.secondary)
                    }
                }
                
                // Kalite Bandı
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kalite Bandı")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(sonuc.kaliteBandi.rawValue)
                            .font(.title.bold())
                            .foregroundColor(skorRengi(sonuc.toplamSkor))
                        Text("(\(sonuc.kaliteBandi.aciklama))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(sonuc.ozet)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: skorRengi(sonuc.toplamSkor).opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(skorRengi(sonuc.toplamSkor).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Öne Çıkanlar Kartı
    
    private func oneCikanlarKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Öne Çıkanlar
            ForEach(sonuc.oneCikanlar, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(item)
                        .font(.subheadline)
                }
            }
            
            // Uyarılar
            ForEach(sonuc.uyarilar, id: \.self) { uyari in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(uyari)
                        .font(.subheadline)
                }
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
                    Text(baslik)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Mini Progress Bar
                    miniIlerlemeBar(skor: skor)
                    
                    // Score
                    Text("\(Int(skor))")
                        .font(.headline)
                        .foregroundColor(skorRengi(skor))
                    
                    // Chevron
                    Image(systemName: acikBolumler.contains(bolumId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if acikBolumler.contains(bolumId) {
                VStack(spacing: 16) {
                    ForEach(metrikler) { metrik in
                        metrikSatiri(metrik)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(kartArkaPlan)
    }
    
    // MARK: - Metrik Satırı
    
    private func metrikSatiri(_ metrik: BISTMetrik) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Üst satır: İsim, Değer, Durum
            HStack {
                Text(metrik.isim)
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                Text(metrik.formatliDeger)
                    .font(.subheadline.bold())
                
                Text(metrik.durum.emoji)
            }
            
            // Sektör karşılaştırması
            if let sektorOrt = metrik.sektorOrtalamasi {
                HStack {
                    Text("Sektör Ort:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(BISTMetrik.formatla(sektorOrt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Açıklama
            Text(metrik.aciklama)
                .font(.caption)
                .foregroundColor(aciklamaRengi(metrik.durum))
            
            // Eğitici not (varsa)
            if !metrik.egitimNotu.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(metrik.egitimNotu)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.top, 4)
            }
            
            Divider()
        }
    }
    
    // MARK: - Özet Kartı
    
    private func ozetKarti(_ sonuc: BISTBilancoSonuc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.orange)
                Text("Yatırımcı İçin Özet")
                    .font(.headline)
            }
            
            Text(sonuc.ozet)
                .font(.subheadline)
            
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
        VStack(spacing: 4) {
            Text(baslik)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(Int(skor))")
                .font(.headline)
                .foregroundColor(skorRengi(skor))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Views
    
    private var yukleniyorView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Bilanço analiz ediliyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func hataView(_ mesaj: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Analiz Hatası")
                .font(.headline)
            Text(mesaj)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Tekrar Dene") {
                Task { await veriYukle() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
    
    private func miniIlerlemeBar(skor: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                Capsule()
                    .fill(skorRengi(skor))
                    .frame(width: geo.size.width * (skor / 100), height: 6)
            }
        }
        .frame(width: 60, height: 6)
    }
    
    private var veriKaynagiNotu: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Veri Kaynağı")
                    .font(.subheadline.bold())
            }
            
            Text("Bilanço verileri İş Yatırım HTML scraping yöntemiyle çekilmektedir. Şu an için sadece F/K ve PD/DD rasyoları mevcut olup, Net Kar ve Özkaynak bu verilerden türetilmektedir.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Diğer metrikler (ROE, ROA, Borç/Özkaynak vb.) için veri kaynağı güncellenmesi beklenmektedir.")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(kartArkaPlan)
    }
    
    private var kartArkaPlan: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func skorRengi(_ skor: Double) -> Color {
        switch skor {
        case 70...: return .green
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
    
    private func aciklamaRengi(_ durum: BISTMetrikDurum) -> Color {
        switch durum {
        case .mukemmel, .iyi: return .green
        case .notr: return .primary
        case .dikkat: return .orange
        case .kotu, .kritik: return .red
        case .veriYok: return .secondary
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

// MARK: - Preview

#Preview {
    NavigationStack {
        BISTBilancoDetailView(sembol: "THYAO.IS")
    }
}
