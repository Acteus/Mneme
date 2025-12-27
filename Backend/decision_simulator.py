"""
Mneme Decision Simulator
Monte Carlo simulation for decision analysis
"""
import numpy as np
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from config import DEFAULT_SIMULATION_RUNS, MAX_SIMULATION_RUNS


@dataclass
class Choice:
    id: int
    name: str
    description: Optional[str] = None


@dataclass
class Factor:
    id: int
    name: str
    weight: float = 1.0
    description: Optional[str] = None


@dataclass
class Score:
    choice_id: int
    factor_id: int
    score: float
    uncertainty: float = 0.0  # Standard deviation for Monte Carlo


class DecisionSimulator:
    """
    Runs Monte Carlo simulations to compare decision choices.
    
    The simulation accounts for uncertainty in scores by treating each score
    as a normal distribution centered on the given value with the specified
    standard deviation (uncertainty).
    """
    
    def __init__(self, choices: List[Choice], factors: List[Factor], scores: List[Score]):
        self.choices = {c.id: c for c in choices}
        self.factors = {f.id: f for f in factors}
        self.scores = self._organize_scores(scores)
        
        # Normalize factor weights
        total_weight = sum(f.weight for f in factors)
        self.normalized_weights = {
            f.id: f.weight / total_weight if total_weight > 0 else 1.0 / len(factors)
            for f in factors
        }
    
    def _organize_scores(self, scores: List[Score]) -> Dict[int, Dict[int, Score]]:
        """Organize scores by choice_id -> factor_id -> Score."""
        organized = {}
        for score in scores:
            if score.choice_id not in organized:
                organized[score.choice_id] = {}
            organized[score.choice_id][score.factor_id] = score
        return organized
    
    def calculate_weighted_score(self, choice_id: int) -> float:
        """Calculate the deterministic weighted score for a choice."""
        if choice_id not in self.scores:
            return 0.0
        
        total = 0.0
        for factor_id, weight in self.normalized_weights.items():
            if factor_id in self.scores[choice_id]:
                score = self.scores[choice_id][factor_id].score
                total += score * weight
        
        return total
    
    def simulate_once(self, choice_id: int, rng: np.random.Generator) -> float:
        """Run a single simulation iteration for a choice."""
        if choice_id not in self.scores:
            return 0.0
        
        total = 0.0
        for factor_id, weight in self.normalized_weights.items():
            if factor_id in self.scores[choice_id]:
                score_obj = self.scores[choice_id][factor_id]
                
                if score_obj.uncertainty > 0:
                    # Sample from normal distribution
                    sampled = rng.normal(score_obj.score, score_obj.uncertainty)
                    # Clamp to valid range [0, 10]
                    sampled = max(0, min(10, sampled))
                else:
                    sampled = score_obj.score
                
                total += sampled * weight
        
        return total
    
    def run_simulation(self, num_runs: int = DEFAULT_SIMULATION_RUNS, 
                       seed: Optional[int] = None) -> Dict[str, Any]:
        """
        Run Monte Carlo simulation comparing all choices.
        
        Returns:
            Dictionary with simulation results including:
            - choice_results: Per-choice statistics
            - rankings: Ordered list of choices by expected value
            - win_counts: How often each choice "won" in simulations
        """
        num_runs = min(num_runs, MAX_SIMULATION_RUNS)
        rng = np.random.default_rng(seed)
        
        # Storage for simulation results
        all_results = {choice_id: [] for choice_id in self.choices}
        win_counts = {choice_id: 0 for choice_id in self.choices}
        
        # Run simulations
        for _ in range(num_runs):
            round_scores = {}
            for choice_id in self.choices:
                round_scores[choice_id] = self.simulate_once(choice_id, rng)
                all_results[choice_id].append(round_scores[choice_id])
            
            # Determine winner of this round
            if round_scores:
                winner = max(round_scores, key=round_scores.get)
                win_counts[winner] += 1
        
        # Calculate statistics
        choice_results = {}
        for choice_id, results in all_results.items():
            results_array = np.array(results)
            choice_results[choice_id] = {
                "choice_id": choice_id,
                "name": self.choices[choice_id].name,
                "deterministic_score": self.calculate_weighted_score(choice_id),
                "mean": float(np.mean(results_array)),
                "std": float(np.std(results_array)),
                "min": float(np.min(results_array)),
                "max": float(np.max(results_array)),
                "percentile_5": float(np.percentile(results_array, 5)),
                "percentile_25": float(np.percentile(results_array, 25)),
                "percentile_50": float(np.percentile(results_array, 50)),
                "percentile_75": float(np.percentile(results_array, 75)),
                "percentile_95": float(np.percentile(results_array, 95)),
                "win_rate": win_counts[choice_id] / num_runs,
            }
        
        # Create rankings
        rankings = sorted(
            choice_results.values(),
            key=lambda x: x["mean"],
            reverse=True
        )
        
        return {
            "num_simulations": num_runs,
            "choice_results": choice_results,
            "rankings": rankings,
            "win_rates": {
                self.choices[cid].name: count / num_runs 
                for cid, count in win_counts.items()
            }
        }
    
    def sensitivity_analysis(self, factor_id: int, 
                            weight_range: tuple = (0.5, 2.0),
                            steps: int = 10) -> Dict[str, Any]:
        """
        Analyze how changing a factor's weight affects outcomes.
        
        Returns rankings at different weight multipliers.
        """
        original_weight = self.normalized_weights.get(factor_id, 1.0)
        results = []
        
        for multiplier in np.linspace(weight_range[0], weight_range[1], steps):
            # Temporarily modify weight
            test_weight = original_weight * multiplier
            old_weight = self.normalized_weights[factor_id]
            self.normalized_weights[factor_id] = test_weight
            
            # Renormalize
            total = sum(self.normalized_weights.values())
            temp_normalized = {k: v/total for k, v in self.normalized_weights.items()}
            self.normalized_weights = temp_normalized
            
            # Calculate deterministic scores
            scores = {
                self.choices[cid].name: self.calculate_weighted_score(cid)
                for cid in self.choices
            }
            
            results.append({
                "multiplier": float(multiplier),
                "scores": scores,
                "winner": max(scores, key=scores.get)
            })
            
            # Restore
            self.normalized_weights[factor_id] = old_weight
        
        return {
            "factor_id": factor_id,
            "factor_name": self.factors[factor_id].name,
            "analysis": results
        }


def run_decision_simulation(decision_data: Dict[str, Any], 
                           num_runs: int = DEFAULT_SIMULATION_RUNS) -> Dict[str, Any]:
    """
    Convenience function to run simulation from a decision dictionary.
    
    Args:
        decision_data: Dictionary from database.get_decision()
        num_runs: Number of simulation iterations
        
    Returns:
        Simulation results
    """
    choices = [
        Choice(id=c['id'], name=c['name'], description=c.get('description'))
        for c in decision_data.get('choices', [])
    ]
    
    factors = [
        Factor(id=f['id'], name=f['name'], weight=f.get('weight', 1.0), 
               description=f.get('description'))
        for f in decision_data.get('factors', [])
    ]
    
    scores = [
        Score(choice_id=s['choice_id'], factor_id=s['factor_id'], 
              score=s['score'], uncertainty=s.get('uncertainty', 0.0))
        for s in decision_data.get('scores', [])
    ]
    
    simulator = DecisionSimulator(choices, factors, scores)
    return simulator.run_simulation(num_runs)

