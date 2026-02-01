import SwiftUI

// MARK: - Expectations Entry View
// Kullanıcının ekonomik beklenti değerlerini girmesi için rehberli arayüz

struct ExpectationsEntryView: View {
    @ObservedObject private var store = ExpectationsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Card
                        headerCard
                        
                        // Release Schedule
                        releaseScheduleCard
                        
                        // Pending Expectations Section
                        pendingSection
                        
                        // Recent Surprises Section
                        if !store.getRecentSurprises().isEmpty {
                            surprisesSection
                        }
                        
                        // Info Card
                        infoCard
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle(" Ekonomik Takvim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .overlay(
                // Save confirmation toast
                VStack {
                    Spacer()
                    if showingSaveConfirmation {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Kaydedildi!")
                                .font(.caption)
                                .bold()
                        }
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                    }
                }
                .animation(.spring(), value: showingSaveConfirmation)
            )
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Beklenti Nedir?")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text("Ekonomik veriler açıklanmadan önce piyasanın beklediği değerleri girin. Gerçekleşen değer beklentiden farklı olursa \"sürpriz\" oluşur ve Aether skorunu etkiler.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    // MARK: - Release Schedule Card
    private var releaseScheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("Veri Açıklama Takvimi (ABD)")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            VStack(spacing: 8) {
                ScheduleRow(indicator: "CPI", timing: "Her ayın 10-14'ü arası", icon: "cart.fill", color: .orange)
                ScheduleRow(indicator: "İstihdam (Payrolls)", timing: "Her ayın ilk Cuma'sı", icon: "person.3.fill", color: .green)
                ScheduleRow(indicator: "İşsizlik", timing: "Her ayın ilk Cuma'sı (İstihdam ile birlikte)", icon: "person.crop.circle.badge.xmark", color: .red)
                ScheduleRow(indicator: "ICSA (Haftalık)", timing: "Her Perşembe 15:30 TSİ", icon: "person.badge.minus", color: .blue)
                ScheduleRow(indicator: "PCE", timing: "Her ayın son haftası", icon: "creditcard.fill", color: .cyan)
                ScheduleRow(indicator: "GDP", timing: "Çeyreklik - Ocak, Nisan, Temmuz, Ekim", icon: "chart.bar.fill", color: .mint)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("Veriler genellikle 15:30 veya 16:00 TSİ'de açıklanır")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    // MARK: - Pending Section
    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.cyan)
                Text("Beklenti Gir")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                
                // Saved count badge
                let savedCount = ExpectationsStore.EconomicIndicator.allCases.filter { store.getExpectation(for: $0) != nil }.count
                if savedCount > 0 {
                    Text("\(savedCount) kayıtlı")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(DesignTokens.Opacity.glassCard))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            ForEach(ExpectationsStore.EconomicIndicator.allCases) { indicator in
                ExpectationInputRow(indicator: indicator, store: store) {
                    showSaveConfirmation()
                }
            }
        }
    }
    
    // MARK: - Surprises Section
    private var surprisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("Son Sürprizler")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal)
            
            ForEach(store.getRecentSurprises().prefix(5)) { entry in
                SurpriseRow(entry: entry)
            }
        }
    }
    
    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Text("Beklenti Değerlerini Nereden Buluruz?")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Link(destination: URL(string: "https://www.investing.com/economic-calendar/")!) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                        Text("Investing.com Ekonomik Takvim")
                            .font(.caption)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .foregroundColor(.cyan)
                }
                
                Link(destination: URL(string: "https://tradingeconomics.com/calendar")!) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                        Text("Trading Economics Takvim")
                            .font(.caption)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.secondaryBackground)
        )
        .padding(.horizontal)
    }
    
    private func showSaveConfirmation() {
        showingSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingSaveConfirmation = false
        }
    }
}

// MARK: - Schedule Row
struct ScheduleRow: View {
    let indicator: String
    let timing: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(indicator)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
                .frame(width: 80, alignment: .leading)
            
            Text(timing)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Expectation Input Row
struct ExpectationInputRow: View {
    let indicator: ExpectationsStore.EconomicIndicator
    @ObservedObject var store: ExpectationsStore
    var onSave: () -> Void
    
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    
    private var existingEntry: ExpectationsStore.ExpectationEntry? {
        store.getExpectation(for: indicator)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: indicator.icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(indicator.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(indicator.helpText)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // Input or Display
                if let entry = existingEntry {
                    // Show existing value with clear button
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text("\(String(format: "%.1f", entry.expectedValue))\(indicator.unit)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        Button(action: { 
                            store.clearExpectation(for: indicator)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(DesignTokens.Opacity.glassCard))
                    .cornerRadius(8)
                } else {
                    // Input field
                    HStack(spacing: 4) {
                        TextField(indicator.placeholder, text: $inputText)
                            .font(.system(size: 14, design: .monospaced))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($isFocused)
                        
                        Text(indicator.unit)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Button(action: saveExpectation) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(inputText.isEmpty ? .gray : .green)
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Theme.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.cyan : Theme.border, lineWidth: 1)
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(existingEntry != nil ? Color.cyan.opacity(0.05) : Theme.secondaryBackground)
            )
        }
        .padding(.horizontal)
    }
    
    private var iconColor: Color {
        if existingEntry != nil { return .cyan }
        if indicator.isInverse { return .orange }
        return .green
    }
    
    private func saveExpectation() {
        let cleanedInput = inputText
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard let value = Double(cleanedInput) else { 
            print("❌ Invalid input: \(inputText)")
            return 
        }
        
        store.setExpectation(indicator: indicator, value: value)
        inputText = ""
        isFocused = false
        onSave()
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Surprise Row
struct SurpriseRow: View {
    let entry: ExpectationsStore.ExpectationEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: entry.isPositiveSurprise == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(entry.isPositiveSurprise == true ? .green : .orange)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.indicator.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                if let announcedAt = entry.announcedAt {
                    Text(announcedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            // Values
            if let actual = entry.actualValue, let surprise = entry.surprise {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.1f", actual)) vs \(String(format: "%.1f", entry.expectedValue))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(String(format: "%+.2f%@", surprise, entry.indicator.unit))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(entry.isPositiveSurprise == true ? .green : .orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.secondaryBackground)
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview {
    ExpectationsEntryView()
}
