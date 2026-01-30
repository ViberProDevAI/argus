import SwiftUI
import Combine

// MARK: - Scout Story Detail View
struct ScoutStoryDetailView: View {
    let stories: [ScoutStory]
    let startIndex: Int
    var onDismiss: () -> Void
    var onAddToWatchlist: ((String) -> Void)?
    var onGoToDetail: ((String) -> Void)?
    
    // State
    @State private var currentIndex: Int
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var dragOffset: CGFloat = 0
    
    // Timer
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let storyDuration: Double = 5.0
    
    init(stories: [ScoutStory], startIndex: Int, onDismiss: @escaping () -> Void, onAddToWatchlist: ((String) -> Void)? = nil, onGoToDetail: ((String) -> Void)? = nil) {
        self.stories = stories
        self.startIndex = startIndex
        self.onDismiss = onDismiss
        self.onAddToWatchlist = onAddToWatchlist
        self.onGoToDetail = onGoToDetail
        
        _currentIndex = State(initialValue: min(startIndex, max(0, stories.count - 1)))
    }
    
    private var currentStory: ScoutStory {
        if stories.indices.contains(currentIndex) {
            return stories[currentIndex]
        }
        return stories.first ?? ScoutStory(id: UUID(), symbol: "Error", price: 0, changePercent: 0, orionScore: 0, signal: .hold, highlights: [], scannedAt: Date(), isViewed: true)
    }
    
    var body: some View {
        ZStack {
            // 1. Background (Void)
            Theme.background.ignoresSafeArea()
            
            // 2. Content Layer (Draggable)
            VStack(spacing: 0) {
                // Progress Bars
                progressBars
                    .padding(.top, 44)
                    .padding(.horizontal)
                
                // Header (Symbol + Close Button)
                storyHeader
                    .padding(.top, 16)
                    .padding(.horizontal)
                    .zIndex(2) // Ensure header is above tap areas
                
                Spacer()
                
                // Main Content
                storyContent
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Actions
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
            }
            .offset(y: dragOffset)
            .zIndex(1) // Content above background
            
            // 3. Invisible Tap Areas (Navigation)
            // Use GeometryReader to position them exactly behind content but handle taps
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left Tap (Previous)
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.3)
                        .onTapGesture { previousStory() }
                    
                    // Middle Tap (Pause)
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.4)
                        .onTapGesture { togglePause() }
                    
                    // Right Tap (Next)
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.3)
                        .onTapGesture { nextStory() }
                }
            }
            .zIndex(0) // Below Content, Above Background
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        onDismiss()
                    } else {
                        withAnimation { dragOffset = 0 }
                    }
                }
        )
        .onReceive(timer) { _ in
            guard !isPaused else { return }
            let increment = 0.1 / storyDuration
            if progress < 1.0 {
                progress += increment
            } else {
                nextStory()
            }
        }
        .onAppear {
            print("🚀 Scout Story Opened (Safe Mode): \(currentStory.symbol)")
            markAsViewed()
        }
        .statusBarHidden(true)
    }
    
    // MARK: - Components
    
    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<stories.count, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index < currentIndex ? 1.0 : 0.3))
                    .overlay(
                        GeometryReader { geo in
                            if index == currentIndex {
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: geo.size.width * CGFloat(progress))
                            }
                        }
                    )
                    .frame(height: 3)
            }
        }
    }
    
    private var storyHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(currentStory.signalColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(Text(currentStory.symbol.prefix(4)).font(.system(size: 14, weight: .bold)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(currentStory.symbol).font(.headline).foregroundColor(.white)
                Text(currentStory.timeAgo).font(.caption).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
        }
    }
    
    private var storyContent: some View {
        VStack(spacing: 24) {
            // Price
            VStack(spacing: 4) {
                Text(String(format: "$%.2f", currentStory.price))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Image(systemName: currentStory.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.2f%%", currentStory.changePercent))
                }
                .font(.title3.bold())
                .foregroundColor(currentStory.changePercent >= 0 ? .green : .red)
            }
            
            // Orion Score
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    Text("Orion Skoru").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
                HStack(alignment: .bottom, spacing: 8) {
                    Text(String(format: "%.0f", currentStory.orionScore))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(currentStory.signalColor)
                    Text("/100").font(.title2).foregroundColor(.secondary).padding(.bottom, 12)
                    Spacer()
                    Text(currentStory.signal.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(currentStory.signalColor))
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.secondaryBackground))
            
            // Highlights
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(currentStory.highlights) { highlight in
                    highlightCard(highlight)
                }
            }
        }
    }
    
    private func highlightCard(_ highlight: ScoutHighlight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: highlight.type.icon).foregroundColor(highlight.type.color)
                Text(highlight.type.rawValue).font(.caption).foregroundColor(.secondary)
            }
            Text(highlight.value).font(.caption2).foregroundColor(.primary).lineLimit(2)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(highlight.type.color).frame(width: geo.size.width * CGFloat(highlight.score / 30.0))
                }
            }.frame(height: 4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.secondaryBackground))
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: { onAddToWatchlist?(currentStory.symbol) }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Watchlist'e Ekle")
                }
                .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
            }
            Button(action: { onGoToDetail?(currentStory.symbol) }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Detay")
                }
                .font(.headline).foregroundColor(.primary).frame(maxWidth: .infinity).padding().background(RoundedRectangle(cornerRadius: 14).fill(Theme.secondaryBackground))
            }
        }
    }
    
    // MARK: - Logic
    
    private func nextStory() {
        if currentIndex < stories.count - 1 {
            currentIndex += 1
            progress = 0
            markAsViewed()
        } else {
            onDismiss()
        }
    }
    
    private func previousStory() {
        if progress > 0.2 {
            progress = 0
        } else if currentIndex > 0 {
            currentIndex -= 1
            progress = 0
        }
    }
    
    private func togglePause() {
        isPaused.toggle()
    }
    
    private func markAsViewed() {
        ScoutStoryStore.shared.markViewed(currentStory.id)
    }
}

// MARK: - Preview
#Preview {
    ScoutStoryDetailView(
        stories: [
            ScoutStory(
                id: UUID(), symbol: "AAPL", price: 198.50, changePercent: 2.3, orionScore: 78, signal: .strongBuy,
                highlights: [ScoutHighlight(type: .structure, value: "Support test", score: 25)],
                scannedAt: Date(), isViewed: false
            )
        ],
        startIndex: 0,
        onDismiss: {}
    )
}
