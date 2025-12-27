
"""
Mneme Database Layer
SQLite with vector search capabilities
"""
import sqlite3
import json
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple
from config import DATABASE_PATH, EMBEDDING_DIMENSION


def get_connection() -> sqlite3.Connection:
    """Get a database connection with proper settings."""
    conn = sqlite3.connect(str(DATABASE_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_database():
    """Initialize the database schema."""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Notes table - the Knowledge Vault
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            tags TEXT,  -- JSON array of tags
            embedding BLOB  -- Stored as numpy bytes
        )
    """)
    
    # Auto-generated tags table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS auto_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL,
            tag TEXT NOT NULL,
            confidence REAL,
            FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
        )
    """)
    
    # Decisions table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS decisions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            status TEXT DEFAULT 'active'  -- active, resolved, archived
        )
    """)
    
    # Choices for each decision
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS choices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            decision_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            FOREIGN KEY (decision_id) REFERENCES decisions(id) ON DELETE CASCADE
        )
    """)
    
    # Factors to weigh decisions
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS factors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            decision_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            weight REAL DEFAULT 1.0,  -- Importance weight 0-10
            description TEXT,
            FOREIGN KEY (decision_id) REFERENCES decisions(id) ON DELETE CASCADE
        )
    """)
    
    # Scores: how each choice rates on each factor
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            choice_id INTEGER NOT NULL,
            factor_id INTEGER NOT NULL,
            score REAL NOT NULL,  -- Score 0-10
            uncertainty REAL DEFAULT 0.0,  -- Standard deviation for simulation
            notes TEXT,
            FOREIGN KEY (choice_id) REFERENCES choices(id) ON DELETE CASCADE,
            FOREIGN KEY (factor_id) REFERENCES factors(id) ON DELETE CASCADE,
            UNIQUE(choice_id, factor_id)
        )
    """)
    
    # Simulation results
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS simulation_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            decision_id INTEGER NOT NULL,
            run_at TEXT NOT NULL,
            num_simulations INTEGER NOT NULL,
            results TEXT NOT NULL,  -- JSON with detailed results
            FOREIGN KEY (decision_id) REFERENCES decisions(id) ON DELETE CASCADE
        )
    """)
    
    # Create indexes for faster search
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_auto_tags_note ON auto_tags(note_id)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_choices_decision ON choices(decision_id)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_factors_decision ON factors(decision_id)")
    
    conn.commit()
    conn.close()


# ─────────────────────────────────────────────────────────────────────────────
# Notes Operations
# ─────────────────────────────────────────────────────────────────────────────

def create_note(title: Optional[str], content: str, tags: Optional[List[str]] = None, 
                embedding: Optional[np.ndarray] = None) -> int:
    """Create a new note and return its ID."""
    conn = get_connection()
    cursor = conn.cursor()
    
    now = datetime.utcnow().isoformat()
    tags_json = json.dumps(tags) if tags else None
    embedding_bytes = embedding.tobytes() if embedding is not None else None
    
    cursor.execute("""
        INSERT INTO notes (title, content, created_at, updated_at, tags, embedding)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (title, content, now, now, tags_json, embedding_bytes))
    
    note_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    return note_id


def update_note(note_id: int, title: Optional[str] = None, content: Optional[str] = None,
                tags: Optional[List[str]] = None, embedding: Optional[np.ndarray] = None):
    """Update an existing note."""
    conn = get_connection()
    cursor = conn.cursor()
    
    updates = []
    values = []
    
    if title is not None:
        updates.append("title = ?")
        values.append(title)
    if content is not None:
        updates.append("content = ?")
        values.append(content)
    if tags is not None:
        updates.append("tags = ?")
        values.append(json.dumps(tags))
    if embedding is not None:
        updates.append("embedding = ?")
        values.append(embedding.tobytes())
    
    if updates:
        updates.append("updated_at = ?")
        values.append(datetime.utcnow().isoformat())
        values.append(note_id)
        
        cursor.execute(f"""
            UPDATE notes SET {', '.join(updates)} WHERE id = ?
        """, values)
        
    conn.commit()
    conn.close()


def get_note(note_id: int) -> Optional[Dict[str, Any]]:
    """Get a single note by ID."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT * FROM notes WHERE id = ?", (note_id,))
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return _row_to_note(row)
    return None


def get_all_notes(limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
    """Get all notes, ordered by most recent."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT * FROM notes ORDER BY updated_at DESC LIMIT ? OFFSET ?
    """, (limit, offset))
    
    notes = [_row_to_note(row) for row in cursor.fetchall()]
    conn.close()
    
    return notes


def delete_note(note_id: int):
    """Delete a note."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM notes WHERE id = ?", (note_id,))
    conn.commit()
    conn.close()


def get_notes_with_embeddings() -> List[Tuple[int, np.ndarray]]:
    """Get all note IDs and their embeddings for search."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, embedding FROM notes WHERE embedding IS NOT NULL")
    
    results = []
    for row in cursor.fetchall():
        embedding = np.frombuffer(row['embedding'], dtype=np.float32)
        results.append((row['id'], embedding))
    
    conn.close()
    return results


def _row_to_note(row: sqlite3.Row) -> Dict[str, Any]:
    """Convert a database row to a note dictionary."""
    note = dict(row)
    note['tags'] = json.loads(note['tags']) if note['tags'] else []
    # Don't include raw embedding bytes in the output
    if 'embedding' in note:
        note['has_embedding'] = note['embedding'] is not None
        del note['embedding']
    return note


# ─────────────────────────────────────────────────────────────────────────────
# Decision Operations
# ─────────────────────────────────────────────────────────────────────────────

def create_decision(title: str, description: Optional[str] = None) -> int:
    """Create a new decision and return its ID."""
    conn = get_connection()
    cursor = conn.cursor()
    
    now = datetime.utcnow().isoformat()
    
    cursor.execute("""
        INSERT INTO decisions (title, description, created_at, updated_at)
        VALUES (?, ?, ?, ?)
    """, (title, description, now, now))
    
    decision_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    return decision_id


def get_decision(decision_id: int) -> Optional[Dict[str, Any]]:
    """Get a decision with all its choices and factors."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("SELECT * FROM decisions WHERE id = ?", (decision_id,))
    row = cursor.fetchone()
    
    if not row:
        conn.close()
        return None
    
    decision = dict(row)
    
    # Get choices
    cursor.execute("SELECT * FROM choices WHERE decision_id = ?", (decision_id,))
    decision['choices'] = [dict(r) for r in cursor.fetchall()]
    
    # Get factors
    cursor.execute("SELECT * FROM factors WHERE decision_id = ?", (decision_id,))
    decision['factors'] = [dict(r) for r in cursor.fetchall()]
    
    # Get scores
    cursor.execute("""
        SELECT s.* FROM scores s
        JOIN choices c ON s.choice_id = c.id
        WHERE c.decision_id = ?
    """, (decision_id,))
    decision['scores'] = [dict(r) for r in cursor.fetchall()]
    
    conn.close()
    return decision


def get_all_decisions(status: Optional[str] = None) -> List[Dict[str, Any]]:
    """Get all decisions, optionally filtered by status."""
    conn = get_connection()
    cursor = conn.cursor()
    
    if status:
        cursor.execute("""
            SELECT * FROM decisions WHERE status = ? ORDER BY updated_at DESC
        """, (status,))
    else:
        cursor.execute("SELECT * FROM decisions ORDER BY updated_at DESC")
    
    decisions = [dict(row) for row in cursor.fetchall()]
    conn.close()
    
    return decisions


def add_choice(decision_id: int, name: str, description: Optional[str] = None) -> int:
    """Add a choice to a decision."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO choices (decision_id, name, description)
        VALUES (?, ?, ?)
    """, (decision_id, name, description))
    
    choice_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    return choice_id


def add_factor(decision_id: int, name: str, weight: float = 1.0, 
               description: Optional[str] = None) -> int:
    """Add a factor to a decision."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO factors (decision_id, name, weight, description)
        VALUES (?, ?, ?, ?)
    """, (decision_id, name, weight, description))
    
    factor_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    return factor_id


def set_score(choice_id: int, factor_id: int, score: float, 
              uncertainty: float = 0.0, notes: Optional[str] = None):
    """Set or update a score for a choice on a factor."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO scores (choice_id, factor_id, score, uncertainty, notes)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(choice_id, factor_id) 
        DO UPDATE SET score = ?, uncertainty = ?, notes = ?
    """, (choice_id, factor_id, score, uncertainty, notes, score, uncertainty, notes))
    
    conn.commit()
    conn.close()


def save_simulation_result(decision_id: int, num_simulations: int, results: Dict[str, Any]):
    """Save a simulation result."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO simulation_results (decision_id, run_at, num_simulations, results)
        VALUES (?, ?, ?, ?)
    """, (decision_id, datetime.utcnow().isoformat(), num_simulations, json.dumps(results)))
    
    conn.commit()
    conn.close()


def delete_decision(decision_id: int):
    """Delete a decision and all related data."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM decisions WHERE id = ?", (decision_id,))
    conn.commit()
    conn.close()


# Initialize database on import
init_database()

