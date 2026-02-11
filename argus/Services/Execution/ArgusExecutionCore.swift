import Foundation
import Combine

/// "The Brain"
/// Unified Execution Finite State Machine (FSM).
/// Coordinates Scanning -> Proposing -> Gating -> Executing -> Learning.
actor ArgusExecutionCore: ObservableObject {
    static let shared = ArgusExecutionCore()
    
    // UI State
    @MainActor @Published var state: ArgusExecutionState = .idle
    @MainActor @Published var activeProposal: ArgusProposal?
    
    private let inbox = ArgusInboxService.shared
    private let scheduler = ArgusScheduler.shared // We will build this next
    
    private init() {}
    
    // MARK: - Entry Points
    
    /// Called by Scheduler or UI to start a cycle for a symbol
    func process(symbol: String, trigger: ExecutionTrigger) async {
        await MainActor.run { self.state = .scanning }
        
        print("🧠 Core: Processing \(symbol) via \(trigger)")
        
        // 1. SCAN & PROPOSE (Delegated to specialized engines)
        // Here we would call the relevant engine (Sniper, Shadow, etc.)
        // But engines should act as "Proposers".
        // For MVP refactor, let's assume engines act and then call `submit(proposal:)`.
        // OR we actively ask them here. Ideally, Core asks Engine.
        
        // MVP Step: Trigger Analysis
        // This part requires adapting existing Engines to return 'ArgusProposal' instead of acting directly.
        // We will do this refactor in `ArgusSniperEngine` later.
    }
    
    /// Engines call this to submit a trade idea
    func submit(proposal: ArgusProposal) async {
        await MainActor.run {
            self.state = .proposing
            self.activeProposal = proposal
        }
        
        // 2. RISK GATING (Data Policy)
        if await !checkRiskGate(proposal: proposal) {
             await reject(proposal: proposal, reason: "Risk Gate Failed (Data/Budget)")
             return
        }
        
        // 3. EXECUTE or SHADOW?
        // Depending on Trigger/Engine type
        if proposal.engine == .shadow || proposal.action == .skip {
            // Log as Shadow/Skip and finish
            let event = await inbox.createRejectionEvent(symbol: proposal.symbol, proposal: proposal, reason: "Shadow Mode / Skip")
            await inbox.log(event: event)
            await resetState()
            return
        }
        
        // 4. REAL EXECUTION
        await executeTrade(proposal: proposal)
    }
    
    // MARK: - Internals
    
    private func checkRiskGate(proposal: ArgusProposal) async -> Bool {
        await MainActor.run { self.state = .riskGating }
        
        // Rule 1: Data Health
        if proposal.dataHealth < 0.7 && proposal.action != .sell {
            print("⛔ Core: Blocked \(proposal.symbol) - Poor Data Health (\(proposal.dataHealth))")
            return false
        }
        
        // Rule 2: Budget / Exposure (Mock for now)
        // if exposure > max ... return false
        
        return true
    }
    
    private func executeTrade(proposal: ArgusProposal) async {
        await MainActor.run { self.state = .executing }
        
        print("🚀 Core: EXECUTING \(proposal.action) \(proposal.symbol)")
        
        // Call Broker / ViewModel
        // Mock Execution Price
        let price = 100.0 // Replace with real quote fetch
        
        // Log Success to Inbox
        let event = await inbox.createProposalEvent(symbol: proposal.symbol, proposal: proposal, price: price)
        // Note: Ideally createProposalEvent should be "createExecutionEvent" or we update type.
        // For now using proposal event but we should refine.
        
        await inbox.log(event: event)
        
        // Verify
        await verifyExecution(symbol: proposal.symbol)
    }
    
    private func reject(proposal: ArgusProposal, reason: String) async {
        let event = await inbox.createRejectionEvent(symbol: proposal.symbol, proposal: proposal, reason: reason)
        await inbox.log(event: event)
        await resetState()
    }
    
    private func verifyExecution(symbol: String) async {
        await MainActor.run { self.state = .verifying }
        // Check if position exists...
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        await resetState()
    }
    
    private func resetState() async {
        await MainActor.run {
            self.state = .idle
            self.activeProposal = nil
        }
    }
}
