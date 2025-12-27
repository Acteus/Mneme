# Mneme

A local-first macOS app for thinking, remembering, and deciding.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Python](https://img.shields.io/badge/Python-3.9+-green)

---

## What it is

Mneme helps you:
- **Store** notes, ideas, and snippets
- **Retrieve** them by meaning, not keywords
- **Model** decisions and explore "what if" scenarios

Everything runs entirely on your Mac. No cloud. No accounts.

---

## Core Features

### Knowledge Vault

Write and save notes that are automatically:
- Embedded with semantic vectors
- Lightly auto-tagged

Search using natural language:
- "ideas related to career change"
- "thoughts about burnout"
- "things I'm grateful for"

### Decision Simulator

- Define a decision
- List your choices
- Assign weighted factors
- Run Monte Carlo simulations to compare outcomes
- Visualize results with uncertainty

It's a structured way to think, not to be told what to do.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | SwiftUI (native macOS) |
| Backend | Python 3.9+ |
| Database | SQLite (local storage) |
| Search | Sentence Transformers (semantic embeddings) |
| Bridge | JSON over stdin/stdout |

---

## Getting Started

### Prerequisites

- macOS 14.0+
- Python 3.9+
- Xcode 15+

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Acteus/Mneme.git
   cd Mneme
   ```

2. **Set up the Python backend**
   ```bash
   cd Backend
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Open in Xcode**
   ```bash
   open Mneme.xcodeproj
   ```

4. **Build and run** (⌘R)

The app will automatically start the Python backend when launched.

---

## Project Structure

```
Mneme/
├── Mneme/                    # SwiftUI app
│   ├── MnemeApp.swift       # App entry point
│   ├── ContentView.swift    # Main navigation
│   ├── Models/              # Data models
│   ├── Views/               # UI views
│   │   ├── Vault/          # Knowledge Vault views
│   │   └── Decision/       # Decision Simulator views
│   ├── ViewModels/          # View models
│   └── Services/            # Python bridge
│
├── Backend/                  # Python backend
│   ├── bridge.py            # JSON process bridge
│   ├── vault.py             # Knowledge Vault API
│   ├── embeddings.py        # Semantic search
│   ├── decision_simulator.py # Monte Carlo simulation
│   ├── database.py          # SQLite layer
│   └── config.py            # Configuration
│
└── README.md
```

---

## Data Storage

All data is stored locally in:
```
~/Library/Application Support/Mneme/
├── mneme.db              # SQLite database
└── embeddings_cache/     # Cached ML models
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Etymology

**Mneme** (Μνήμη) is the Greek goddess of memory and one of the original three Muses. The name comes from the Greek word for "memory."

