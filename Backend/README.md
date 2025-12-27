# Mneme Backend

Python-based backend for semantic search and decision simulation.

## Setup

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Components

- **vault.py** - Knowledge Vault API for notes and semantic search
- **embeddings.py** - Sentence transformer embeddings engine
- **decision_simulator.py** - Monte Carlo decision simulation
- **database.py** - SQLite database layer
- **bridge.py** - JSON process bridge for Swift communication
- **config.py** - Configuration settings

## Usage

### Direct Python API

```python
from vault import get_vault

vault = get_vault()

# Create a note
note = vault.create_note(
    content="I've been thinking about changing careers...",
    title="Career thoughts"
)

# Search by meaning
results = vault.search("ideas about career change")
```

### Decision Simulator

```python
import database as db
from decision_simulator import run_decision_simulation

# Create decision
decision_id = db.create_decision("Where to live?", "Comparing cities")

# Add choices
sf = db.add_choice(decision_id, "San Francisco")
ny = db.add_choice(decision_id, "New York")

# Add factors
cost = db.add_factor(decision_id, "Cost of Living", weight=8)
career = db.add_factor(decision_id, "Career Opportunities", weight=9)

# Set scores (with uncertainty for simulation)
db.set_score(sf, cost, score=3, uncertainty=0.5)  # Expensive, somewhat certain
db.set_score(sf, career, score=9, uncertainty=1.0)  # Great for tech
db.set_score(ny, cost, score=4, uncertainty=0.5)
db.set_score(ny, career, score=8, uncertainty=1.0)

# Run simulation
decision = db.get_decision(decision_id)
results = run_decision_simulation(decision, num_runs=1000)
```

### Process Bridge (for Swift)

The bridge communicates via JSON over stdin/stdout:

```bash
# Start the bridge
python bridge.py
```

Example request/response:
```json
{"action": "vault.search", "params": {"query": "career ideas"}}
{"success": true, "data": {"results": [...], "count": 5}}
```

## Data Storage

All data is stored locally in:
```
~/Library/Application Support/Mneme/
├── mneme.db          # SQLite database
└── embeddings_cache/ # Cached model files
```

