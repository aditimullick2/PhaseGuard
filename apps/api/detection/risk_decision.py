"""
Risk Decision Layer for PhaseGuard
Final three-way risk decision on top of temporal stability
"""
from typing import Dict, Optional
from dataclasses import dataclass, field
from enum import Enum
import time

from .temporal_stability import TemporalState, TemporalResult, TemporalEvidence


class RiskDecision(str, Enum):
    """Final user-facing risk decisions."""
    SAFE = "SAFE"
    SUSPICIOUS = "SUSPICIOUS"
    HIGH_RISK = "HIGH_RISK"


class ConfidenceLevel(str, Enum):
    """Human-readable confidence bands."""
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class DecisionReason(str, Enum):
    """Explicit reason codes for decisions."""
    LOW_RISK_EVIDENCE = "LOW_RISK_EVIDENCE"
    SUSPICIOUS_EVIDENCE = "SUSPICIOUS_EVIDENCE"
    HIGH_RISK_EVIDENCE = "HIGH_RISK_EVIDENCE"
    AMBIGUOUS_EVIDENCE = "AMBIGUOUS_EVIDENCE"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"
    DETECTOR_FAILURE = "DETECTOR_FAILURE"
    INVALID_AUDIO = "INVALID_AUDIO"


@dataclass
class RiskDecisionConfig:
    """Configuration for risk decision layer."""
    # Score thresholds (engineering defaults, not calibrated)
    safe_threshold: float = 0.30
    high_risk_threshold: float = 0.70

    # Ambiguous region
    ambiguous_low: float = 0.30
    ambiguous_high: float = 0.70

    # Confidence weights (engineering defaults, not calibrated)
    temporal_agreement_weight: float = 0.40
    evidence_coverage_weight: float = 0.30
    boundary_separation_weight: float = 0.30

    # Confidence bands
    confidence_low_threshold: float = 0.40
    confidence_high_threshold: float = 0.70

    def __post_init__(self):
        """Validate configuration."""
        if not (0 <= self.safe_threshold < self.high_risk_threshold <= 1):
            raise ValueError("safe_threshold must be < high_risk_threshold, both in [0, 1]")
        if not (0 <= self.ambiguous_low <= self.ambiguous_high <= 1):
            raise ValueError("ambiguous bounds must be in [0, 1]")
        if not (0 <= self.temporal_agreement_weight <= 1):
            raise ValueError("temporal_agreement_weight must be in [0, 1]")
        if not (0 <= self.evidence_coverage_weight <= 1):
            raise ValueError("evidence_coverage_weight must be in [0, 1]")
        if not (0 <= self.boundary_separation_weight <= 1):
            raise ValueError("boundary_separation_weight must be in [0, 1]")
        total_weight = (self.temporal_agreement_weight +
                       self.evidence_coverage_weight +
                       self.boundary_separation_weight)
        if not (0.90 <= total_weight <= 1.10):  # Allow small floating-point error
            raise ValueError(f"Confidence weights must sum to ~1.0, got {total_weight}")


@dataclass
class RiskDecisionResult:
    """Final risk decision result."""
    risk_decision: RiskDecision
    temporal_state: TemporalState
    aggregated_score: Optional[float]

    confidence: float
    confidence_level: ConfidenceLevel

    ambiguous: bool
    decision_reason: DecisionReason

    valid_windows: int
    failed_windows: int
    total_windows: int

    evidence_coverage: float
    temporal_agreement: float
    boundary_separation: float

    transitions: int
    early_stopped: bool

    decision_latency_ms: float
    total_latency_ms: float

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "risk_decision": self.risk_decision.value,
            "temporal_state": self.temporal_state.value,
            "aggregated_score": self.aggregated_score,
            "confidence": self.confidence,
            "confidence_level": self.confidence_level.value,
            "ambiguous": self.ambiguous,
            "decision_reason": self.decision_reason.value,
            "evidence": {
                "total_windows": self.total_windows,
                "valid_windows": self.valid_windows,
                "failed_windows": self.failed_windows,
                "evidence_coverage": self.evidence_coverage,
                "temporal_agreement": self.temporal_agreement,
                "boundary_separation": self.boundary_separation
            },
            "transitions": self.transitions,
            "early_stopped": self.early_stopped,
            "latency_ms": {
                "decision": self.decision_latency_ms,
                "total": self.total_latency_ms
            }
        }


class RiskDecisionLayer:
    """Risk decision layer for final three-way decision."""

    def __init__(self, config: Optional[RiskDecisionConfig] = None):
        """
        Initialize risk decision layer.

        Args:
            config: Risk decision configuration
        """
        self.config = config or RiskDecisionConfig()

    def _map_temporal_to_decision(self, temporal_state: TemporalState) -> tuple[RiskDecision, DecisionReason]:
        """
        Map temporal state to risk decision.

        Args:
            temporal_state: Temporal state from Phase 3K

        Returns:
            Tuple of (risk_decision, decision_reason)
        """
        if temporal_state == TemporalState.LOW_RISK:
            return RiskDecision.SAFE, DecisionReason.LOW_RISK_EVIDENCE
        elif temporal_state == TemporalState.SUSPICIOUS:
            return RiskDecision.SUSPICIOUS, DecisionReason.SUSPICIOUS_EVIDENCE
        elif temporal_state == TemporalState.HIGH_RISK:
            return RiskDecision.HIGH_RISK, DecisionReason.HIGH_RISK_EVIDENCE
        else:  # UNKNOWN
            return RiskDecision.SUSPICIOUS, DecisionReason.INSUFFICIENT_EVIDENCE

    def _is_ambiguous(self, score: float) -> bool:
        """
        Check if score is in ambiguous region.

        Args:
            score: Aggregated score

        Returns:
            True if score is in ambiguous region
        """
        return self.config.ambiguous_low <= score < self.config.ambiguous_high

    def _calculate_evidence_coverage(self, valid_windows: int, total_windows: int) -> float:
        """
        Calculate evidence coverage ratio.

        Args:
            valid_windows: Number of successful windows
            total_windows: Total number of windows

        Returns:
            Coverage ratio in [0, 1]
        """
        if total_windows == 0:
            return 0.0
        return valid_windows / total_windows

    def _calculate_temporal_agreement(self, history: list[TemporalEvidence], final_state: TemporalState) -> float:
        """
        Calculate temporal agreement with final state.

        Args:
            history: Temporal evidence history
            final_state: Final temporal state

        Returns:
            Agreement ratio in [0, 1]
        """
        if not history:
            return 0.0

        # Count how many windows support the final state
        supporting = 0
        for evidence in history:
            if evidence.resulting_state == final_state:
                supporting += 1

        return supporting / len(history)

    def _calculate_boundary_separation(self, score: float) -> float:
        """
        Calculate distance from decision boundaries.

        Args:
            score: Aggregated score

        Returns:
            Normalized distance in [0, 1]
        """
        if score <= self.config.safe_threshold:
            # Distance from safe_threshold
            distance = self.config.safe_threshold - score
            # Normalize: at 0.0, distance = 0.3, so normalized = 1.0
            return min(distance / self.config.safe_threshold, 1.0)
        elif score >= self.config.high_risk_threshold:
            # Distance from high_risk_threshold
            distance = score - self.config.high_risk_threshold
            # Normalize: at 1.0, distance = 0.3, so normalized = 1.0
            return min(distance / (1.0 - self.config.high_risk_threshold), 1.0)
        else:
            # In ambiguous region, distance from nearest boundary
            distance_low = abs(score - self.config.ambiguous_low)
            distance_high = abs(score - self.config.ambiguous_high)
            min_distance = min(distance_low, distance_high)
            # Normalize by half the ambiguous region width
            ambiguous_width = self.config.ambiguous_high - self.config.ambiguous_low
            return min(min_distance / (ambiguous_width / 2), 1.0)

    def _calculate_confidence(self,
                             temporal_agreement: float,
                             evidence_coverage: float,
                             boundary_separation: float,
                             temporal_state: TemporalState) -> float:
        """
        Calculate decision confidence.

        Args:
            temporal_agreement: Temporal agreement ratio
            evidence_coverage: Evidence coverage ratio
            boundary_separation: Boundary separation
            temporal_state: Temporal state

        Returns:
            Confidence score in [0, 1]
        """
        # UNKNOWN state has zero confidence
        if temporal_state == TemporalState.UNKNOWN:
            return 0.0

        # Clamp individual components to [0, 1]
        temporal_agreement = max(0.0, min(1.0, temporal_agreement))
        evidence_coverage = max(0.0, min(1.0, evidence_coverage))
        boundary_separation = max(0.0, min(1.0, boundary_separation))

        # Weighted combination
        confidence = (
            self.config.temporal_agreement_weight * temporal_agreement +
            self.config.evidence_coverage_weight * evidence_coverage +
            self.config.boundary_separation_weight * boundary_separation
        )

        # Clamp to [0, 1]
        return max(0.0, min(1.0, confidence))

    def _map_confidence_to_level(self, confidence: float) -> ConfidenceLevel:
        """
        Map confidence score to confidence level.

        Args:
            confidence: Confidence score in [0, 1]

        Returns:
            Confidence level
        """
        if confidence < self.config.confidence_low_threshold:
            return ConfidenceLevel.LOW
        elif confidence < self.config.confidence_high_threshold:
            return ConfidenceLevel.MEDIUM
        else:
            return ConfidenceLevel.HIGH

    def make_decision(self, temporal_result: TemporalResult) -> RiskDecisionResult:
        """
        Make final risk decision from temporal result.

        Args:
            temporal_result: Result from Phase 3K temporal stability layer

        Returns:
            Final risk decision result
        """
        decision_start = time.time()

        # Handle error states
        if temporal_result.status == "detector_not_initialized":
            return RiskDecisionResult(
                risk_decision=RiskDecision.SUSPICIOUS,
                temporal_state=TemporalState.UNKNOWN,
                aggregated_score=None,
                confidence=0.0,
                confidence_level=ConfidenceLevel.LOW,
                ambiguous=False,
                decision_reason=DecisionReason.DETECTOR_FAILURE,
                valid_windows=0,
                failed_windows=0,
                total_windows=0,
                evidence_coverage=0.0,
                temporal_agreement=0.0,
                boundary_separation=0.0,
                transitions=0,
                early_stopped=False,
                decision_latency_ms=(time.time() - decision_start) * 1000,
                total_latency_ms=temporal_result.total_ms
            )

        if temporal_result.status == "insufficient_audio":
            return RiskDecisionResult(
                risk_decision=RiskDecision.SUSPICIOUS,
                temporal_state=TemporalState.UNKNOWN,
                aggregated_score=None,
                confidence=0.0,
                confidence_level=ConfidenceLevel.LOW,
                ambiguous=False,
                decision_reason=DecisionReason.INVALID_AUDIO,
                valid_windows=0,
                failed_windows=0,
                total_windows=0,
                evidence_coverage=0.0,
                temporal_agreement=0.0,
                boundary_separation=0.0,
                transitions=0,
                early_stopped=False,
                decision_latency_ms=(time.time() - decision_start) * 1000,
                total_latency_ms=temporal_result.total_ms
            )

        if temporal_result.status == "all_windows_failed":
            total_windows = temporal_result.failed_windows
            return RiskDecisionResult(
                risk_decision=RiskDecision.SUSPICIOUS,
                temporal_state=TemporalState.UNKNOWN,
                aggregated_score=temporal_result.aggregated_score,
                confidence=0.0,
                confidence_level=ConfidenceLevel.LOW,
                ambiguous=False,
                decision_reason=DecisionReason.DETECTOR_FAILURE,
                valid_windows=0,
                failed_windows=temporal_result.failed_windows,
                total_windows=total_windows,
                evidence_coverage=0.0,
                temporal_agreement=0.0,
                boundary_separation=0.0,
                transitions=0,
                early_stopped=False,
                decision_latency_ms=(time.time() - decision_start) * 1000,
                total_latency_ms=temporal_result.total_ms
            )

        # Map temporal state to risk decision
        risk_decision, decision_reason = self._map_temporal_to_decision(temporal_result.state)

        # Check for ambiguity
        score = temporal_result.aggregated_score
        is_ambiguous = self._is_ambiguous(score)

        # Override reason if ambiguous
        if is_ambiguous and decision_reason == DecisionReason.SUSPICIOUS_EVIDENCE:
            decision_reason = DecisionReason.AMBIGUOUS_EVIDENCE

        # Calculate total windows
        total_windows = temporal_result.valid_windows + temporal_result.failed_windows

        # Calculate confidence components
        evidence_coverage = self._calculate_evidence_coverage(
            temporal_result.valid_windows,
            total_windows
        )

        temporal_agreement = self._calculate_temporal_agreement(
            temporal_result.history,
            temporal_result.state
        )

        boundary_separation = self._calculate_boundary_separation(score)

        # Calculate confidence
        confidence = self._calculate_confidence(
            temporal_agreement,
            evidence_coverage,
            boundary_separation,
            temporal_result.state
        )

        # Map confidence to level
        confidence_level = self._map_confidence_to_level(confidence)

        decision_latency_ms = (time.time() - decision_start) * 1000

        return RiskDecisionResult(
            risk_decision=risk_decision,
            temporal_state=temporal_result.state,
            aggregated_score=score,
            confidence=confidence,
            confidence_level=confidence_level,
            ambiguous=is_ambiguous,
            decision_reason=decision_reason,
            valid_windows=temporal_result.valid_windows,
            failed_windows=temporal_result.failed_windows,
            total_windows=total_windows,
            evidence_coverage=evidence_coverage,
            temporal_agreement=temporal_agreement,
            boundary_separation=boundary_separation,
            transitions=temporal_result.transitions,
            early_stopped=temporal_result.early_stopped,
            decision_latency_ms=decision_latency_ms,
            total_latency_ms=temporal_result.total_ms
        )
