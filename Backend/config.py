"""
Mneme Configuration
"""
import os
from pathlib import Path

# Paths
APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "Mneme"
DATABASE_PATH = APP_SUPPORT_DIR / "mneme.db"
EMBEDDINGS_CACHE_DIR = APP_SUPPORT_DIR / "embeddings_cache"

# Ensure directories exist
APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
EMBEDDINGS_CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Embedding model - using a lightweight model that runs well on Mac
EMBEDDING_MODEL = "all-MiniLM-L6-v2"
EMBEDDING_DIMENSION = 384

# Decision simulator defaults
DEFAULT_SIMULATION_RUNS = 1000
MAX_SIMULATION_RUNS = 10000

