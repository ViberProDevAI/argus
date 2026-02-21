# Contributing to Argus

Thank you for your interest in contributing to Argus!

## Getting Started

### Prerequisites
- Xcode 16+
- iOS 17+ deployment target
- Swift 5.9+

### Setup

1. Clone the repository
2. Copy `Secrets.xcconfig.example` to `Secrets.xcconfig`
3. Fill in your own API keys (see below)
4. Open `argus.xcodeproj` in Xcode
5. Set your Development Team in Signing & Capabilities
6. Build and run

### API Keys

Argus uses several third-party data providers. You'll need to obtain your own API keys:

| Provider | Purpose | Get Key |
|----------|---------|---------|
| Twelve Data | Market quotes & charts | [twelvedata.com](https://twelvedata.com) |
| FMP | Fundamentals & news | [financialmodelingprep.com](https://financialmodelingprep.com) |
| Gemini | AI analysis | [ai.google.dev](https://ai.google.dev) |
| Groq | Fast LLM inference | [groq.com](https://groq.com) |
| FRED | Economic data | [fred.stlouisfed.org](https://fred.stlouisfed.org) |

Place your keys in `Secrets.xcconfig` (this file is gitignored).

## Architecture

Argus follows MVVM architecture with SwiftUI:

```
argus/
├── Views/           # SwiftUI view components
├── ViewModels/      # ViewModel layer (state management)
├── Services/        # Business logic & external integrations
├── Models/          # Data structures (Codable)
├── Navigation/      # Routing and deep linking
├── Extensions/      # Helper extensions
└── Utilities/       # Utility functions
```

### Key Modules
- **Alkindus**: AI-powered market analysis and pattern learning
- **Aether Council**: Multi-agent decision-making system
- **Chiron**: Backtesting and strategy evaluation
- **Hermes**: News and data feed management
- **Orion**: Technical analysis and pattern recognition
- **Phoenix**: Scenario analysis and risk modeling

## Coding Standards

### Naming
- Views: `...View` (e.g., `AlkindusDashboardView`)
- ViewModels: `...ViewModel` (e.g., `PortfolioViewModel`)
- Services: descriptive (e.g., `MarketDataProvider`)

### Style
- Use `async/await` over closures
- Error handling with `do/catch`, return fallback values
- Private state: `@State private var`
- RGB colors preferred (see existing patterns)

### Commit Messages
```
<type>: <description>

feat:     New feature
fix:      Bug fix
UI Fix:   Visual fix
Enhance:  Improvement
```

## Testing

Test on multiple screen sizes:
- iPhone SE (375x667)
- iPhone 14 (390x844)
- iPhone 14 Pro Max (430x932)

## License

See [LICENSE](LICENSE) for details.
