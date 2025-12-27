"""
Mneme Embeddings Engine
Semantic search using sentence transformers
"""
import numpy as np
from typing import List, Optional, Tuple
from sentence_transformers import SentenceTransformer

from config import EMBEDDING_MODEL, EMBEDDINGS_CACHE_DIR


class EmbeddingEngine:
    """Handles text embedding and semantic similarity search."""
    
    _instance: Optional['EmbeddingEngine'] = None
    _model: Optional[SentenceTransformer] = None
    
    def __new__(cls):
        """Singleton pattern - only one model instance."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if self._model is None:
            self._load_model()
    
    def _load_model(self):
        """Load the sentence transformer model."""
        print(f"Loading embedding model: {EMBEDDING_MODEL}")
        self._model = SentenceTransformer(
            EMBEDDING_MODEL,
            cache_folder=str(EMBEDDINGS_CACHE_DIR)
        )
        print("Model loaded successfully")
    
    def embed(self, text: str) -> np.ndarray:
        """Generate embedding for a single text."""
        embedding = self._model.encode(text, convert_to_numpy=True)
        return embedding.astype(np.float32)
    
    def embed_batch(self, texts: List[str]) -> np.ndarray:
        """Generate embeddings for multiple texts."""
        embeddings = self._model.encode(texts, convert_to_numpy=True)
        return embeddings.astype(np.float32)
    
    @staticmethod
    def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
        """Calculate cosine similarity between two vectors."""
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
    
    def search(self, query: str, embeddings: List[Tuple[int, np.ndarray]], 
               top_k: int = 10) -> List[Tuple[int, float]]:
        """
        Search for most similar items to a query.
        
        Args:
            query: The search query text
            embeddings: List of (id, embedding) tuples to search through
            top_k: Number of results to return
            
        Returns:
            List of (id, similarity_score) tuples, sorted by similarity
        """
        if not embeddings:
            return []
        
        query_embedding = self.embed(query)
        
        # Calculate similarities
        similarities = []
        for item_id, item_embedding in embeddings:
            sim = self.cosine_similarity(query_embedding, item_embedding)
            similarities.append((item_id, sim))
        
        # Sort by similarity (descending) and return top_k
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:top_k]


def get_embedding_engine() -> EmbeddingEngine:
    """Get the singleton embedding engine instance."""
    return EmbeddingEngine()


# ─────────────────────────────────────────────────────────────────────────────
# Auto-tagging
# ─────────────────────────────────────────────────────────────────────────────

# Common topic keywords for lightweight auto-tagging
TOPIC_KEYWORDS = {
    "work": ["job", "career", "office", "meeting", "deadline", "project", "boss", "colleague", "salary", "promotion"],
    "personal": ["family", "friend", "relationship", "love", "home", "life", "self"],
    "health": ["exercise", "diet", "sleep", "stress", "anxiety", "mental", "physical", "doctor", "medication"],
    "finance": ["money", "budget", "investment", "savings", "expense", "income", "debt", "financial"],
    "learning": ["learn", "study", "course", "book", "read", "skill", "education", "training"],
    "creative": ["idea", "create", "design", "art", "write", "music", "imagine", "inspiration"],
    "decision": ["decide", "choice", "option", "consider", "weigh", "pros", "cons", "dilemma"],
    "goal": ["goal", "objective", "plan", "target", "achieve", "milestone", "resolution"],
    "reflection": ["think", "reflect", "realize", "understand", "insight", "perspective", "meaning"],
}


def auto_tag(text: str, threshold: int = 2) -> List[Tuple[str, float]]:
    """
    Generate lightweight auto-tags based on keyword matching.
    
    Args:
        text: The text to analyze
        threshold: Minimum keyword matches to suggest a tag
        
    Returns:
        List of (tag, confidence) tuples
    """
    text_lower = text.lower()
    words = set(text_lower.split())
    
    tags = []
    for tag, keywords in TOPIC_KEYWORDS.items():
        matches = sum(1 for kw in keywords if kw in text_lower)
        if matches >= threshold:
            # Confidence based on number of matches (normalized)
            confidence = min(matches / len(keywords), 1.0)
            tags.append((tag, confidence))
    
    # Sort by confidence
    tags.sort(key=lambda x: x[1], reverse=True)
    return tags

