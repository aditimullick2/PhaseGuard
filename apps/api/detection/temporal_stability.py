"""
Temporal Stability Layer for PhaseGuard
Model-agnostic temporal state tracking on top of multi-window detection
"""
from typing import Dict, List, Optional
from dataclasses import dataclass, field
from enum import Enum
import time

from .multi_window import MultiWindowResult, WindowResult


class TemporalState(Enum):
    """Temporal detection states."""
    UNKNOWN = "unknown"
    LOW_RISK = "low_risk"
    SUSPICIOUS = "suspicious"
    HIGH_RISK = "high_risk"


@dataclass
class TemporalConfig:
    """Configuration for temporal stability layer."""
    # Thresholds (engineering defaults, not calibrated)
    low_risk_threshold: float = 0.30
    high_risk_threshold: float = 0.70

    # Hysteresis bands
    low_risk_exit_threshold: float = 0.40
    high_risk_exit_threshold: float = 0.60

    # Consecutive evidence requirements
    suspicious_enter_count: int = 2
    high_risk_enter_count: int = 2
    low_risk_exit_count: int = 2
    suspicious_exit_count: int = 2

    # Feature flags
    enable_hysteresis: bool = True
    enable_debounce: bool = True
    enable_early_stopping: bool = False

    # Early stopping thresholds
    early_stop_high_risk_threshold: float = 0.85
    early_stop_high_risk_count: int = 3

    def __post_init__(self):
        """Validate configuration."""
        if not (0 <= self.low_risk_threshold <= 1):
            raise ValueError("low_risk_threshold must be in [0, 1]")
        if not (0 <= self.high_risk_threshold <= 1):
            raise ValueError("high_risk_threshold must be in [0, 1]")
        if self.low_risk_threshold >= self.high_risk_threshold:
            raise ValueError("low_risk_threshold must be < high_risk_threshold")
        if not (self.low_risk_exit_threshold <= self.high_risk_exit_threshold):
            raise ValueError("low_risk_exit_threshold must be <= high_risk_exit_threshold")
        if self.suspicious_enter_count < 1:
            raise ValueError("suspicious_enter_count must be >= 1")
        if self.high_risk_enter_count < 1:
            raise ValueError("high_risk_enter_count must be >= 1")
        if self.low_risk_exit_count < 1:
            raise ValueError("low_risk_exit_count must be >= 1")
        if self.suspicious_exit_count < 1:
            raise ValueError("suspicious_exit_count must be >= 1")


@dataclass
class TemporalEvidence:
    """Evidence from a single window."""
    window_index: int
    score: float
    observed_state: TemporalState
    previous_state: TemporalState
    resulting_state: TemporalState
    consecutive_count: int
    transition: bool

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "window_index": self.window_index,
            "score": self.score,
            "observed_state": self.observed_state.value,
            "previous_state": self.previous_state.value,
            "resulting_state": self.resulting_state.value,
            "consecutive_count": self.consecutive_count,
            "transition": self.transition
        }


@dataclass
class TemporalResult:
    """Result from temporal stability layer."""
    status: str
    state: TemporalState
    aggregated_score: float
    windows_processed: int
    valid_windows: int
    failed_windows: int
    transitions: int
    early_stopped: bool
    history: List[TemporalEvidence] = field(default_factory=list)
    temporal_processing_ms: float = 0.0
    state_update_ms: float = 0.0
    total_ms: float = 0.0

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "status": self.status,
            "state": self.state.value,
            "aggregated_score": self.aggregated_score,
            "windows_processed": self.windows_processed,
            "valid_windows": self.valid_windows,
            "failed_windows": self.failed_windows,
            "transitions": self.transitions,
            "early_stopped": self.early_stopped,
            "history": [e.to_dict() for e in self.history],
            "latency": {
                "temporal_processing_ms": self.temporal_processing_ms,
                "state_update_ms": self.state_update_ms,
                "total_ms": self.total_ms
            }
        }


class TemporalStabilityLayer:
    """Temporal stability layer for multi-window detection."""

    def __init__(self, config: Optional[TemporalConfig] = None):
        """
        Initialize temporal stability layer.

        Args:
            config: Temporal configuration
        """
        self.config = config or TemporalConfig()
        self.reset()

    def reset(self) -> None:
        """Reset temporal state."""
        self.current_state = TemporalState.UNKNOWN
        self.suspicious_count = 0
        self.high_risk_count = 0
        self.low_risk_count = 0
        self.history: List[TemporalEvidence] = []
        self.transitions = 0
        self.early_stopped = False

    def _classify_score(self, score: float) -> TemporalState:
        """
        Classify a score into a state (without hysteresis).

        Args:
            score: Spoof score

        Returns:
            Observed state
        """
        if score <= self.config.low_risk_threshold:
            return TemporalState.LOW_RISK
        elif score >= self.config.high_risk_threshold:
            return TemporalState.HIGH_RISK
        else:
            return TemporalState.SUSPICIOUS

    def _check_hysteresis(self, score: float, target_state: TemporalState, current_state: TemporalState) -> bool:
        """
        Check if hysteresis allows transition to target state.

        Args:
            score: Current score
            target_state: Target state
            current_state: Current state

        Returns:
            True if transition allowed
        """
        if not self.config.enable_hysteresis:
            return True

        # From UNKNOWN, allow any transition
        if current_state == TemporalState.UNKNOWN:
            return True

        # If staying in same state, always allow
        if target_state == current_state:
            return True

        # Hysteresis prevents exiting a state unless score is clearly in another state
        if current_state == TemporalState.LOW_RISK:
            # Exiting LOW_RISK requires score above exit threshold
            return score >= self.config.low_risk_exit_threshold
        elif current_state == TemporalState.HIGH_RISK:
            # Exiting HIGH_RISK requires score below exit threshold
            return score <= self.config.high_risk_exit_threshold
        else:
            # SUSPICIOUS can transition to either side
            return True

    def _update_evidence_counters(self, observed_state: TemporalState) -> None:
        """
        Update evidence counters based on observed state.

        Args:
            observed_state: Observed state from current window
        """
        if observed_state == TemporalState.LOW_RISK:
            self.low_risk_count += 1
            self.suspicious_count = 0
            self.high_risk_count = 0
        elif observed_state == TemporalState.SUSPICIOUS:
            self.suspicious_count += 1
            self.high_risk_count = 0
            self.low_risk_count = 0
        elif observed_state == TemporalState.HIGH_RISK:
            self.high_risk_count += 1
            self.suspicious_count = 0
            self.low_risk_count = 0

    def _determine_transition(self, observed_state: TemporalState, score: float) -> TemporalState:
        """
        Determine if state transition should occur.

        Args:
            observed_state: Observed state from current window
            score: Current score

        Returns:
            New state
        """
        previous_state = self.current_state

        # From UNKNOWN, transition directly to observed state
        if previous_state == TemporalState.UNKNOWN:
            return observed_state

        # If staying in same state, allow
        if observed_state == previous_state:
            return observed_state

        # Check hysteresis
        if not self._check_hysteresis(score, observed_state, previous_state):
            # Hysteresis prevents transition
            return previous_state

        # Check debounce (consecutive evidence)
        if self.config.enable_debounce:
            # Check if we have enough consecutive evidence for the target state
            if observed_state == TemporalState.LOW_RISK:
                if self.low_risk_count >= self.config.low_risk_exit_count:
                    return observed_state
            elif observed_state == TemporalState.SUSPICIOUS:
                if self.suspicious_count >= self.config.suspicious_enter_count:
                    return observed_state
            elif observed_state == TemporalState.HIGH_RISK:
                if self.high_risk_count >= self.config.high_risk_enter_count:
                    return observed_state

            # Not enough consecutive evidence, stay in current state
            return previous_state
        else:
            # Debounce disabled, allow immediate transition
            return observed_state

    def _check_early_stopping(self) -> bool:
        """
        Check if early stopping should occur.

        Returns:
            True if should stop early
        """
        if not self.config.enable_early_stopping:
            return False

        # Stop if we have strong HIGH_RISK evidence
        if (self.current_state == TemporalState.HIGH_RISK and
            self.high_risk_count >= self.config.early_stop_high_risk_count):
            return True

        return False

    def process_window(self, window_result: WindowResult) -> Optional[TemporalEvidence]:
        """
        Process a single window and update temporal state.

        Args:
            window_result: Window result from multi-window detection

        Returns:
            Temporal evidence (None if window failed)
        """
        if window_result.status != "success":
            # Failed window, no evidence update
            return None

        score = window_result.score
        previous_state = self.current_state

        # Classify score
        observed_state = self._classify_score(score)

        # Update evidence counters
        self._update_evidence_counters(observed_state)

        # Determine transition
        new_state = self._determine_transition(observed_state, score)

        # Check if transition occurred
        transition = new_state != previous_state
        if transition:
            self.transitions += 1

        # Update current state
        self.current_state = new_state

        # Get consecutive count
        consecutive_count = 0
        if new_state == TemporalState.LOW_RISK:
            consecutive_count = self.low_risk_count
        elif new_state == TemporalState.SUSPICIOUS:
            consecutive_count = self.suspicious_count
        elif new_state == TemporalState.HIGH_RISK:
            consecutive_count = self.high_risk_count

        # Create evidence
        evidence = TemporalEvidence(
            window_index=window_result.window_index,
            score=score,
            observed_state=observed_state,
            previous_state=previous_state,
            resulting_state=new_state,
            consecutive_count=consecutive_count,
            transition=transition
        )

        self.history.append(evidence)
        return evidence

    def process_multi_window_result(self, multi_window_result: MultiWindowResult) -> TemporalResult:
        """
        Process multi-window result through temporal stability layer.

        Args:
            multi_window_result: Result from multi-window detection

        Returns:
            Temporal stability result
        """
        total_start = time.time()

        # Reset state
        self.reset()

        # Check for errors in multi-window result
        if multi_window_result.status == "detector_not_initialized":
            return TemporalResult(
                status="detector_not_initialized",
                state=TemporalState.UNKNOWN,
                aggregated_score=0.5,
                windows_processed=0,
                valid_windows=0,
                failed_windows=0,
                transitions=0,
                early_stopped=False,
                total_ms=(time.time() - total_start) * 1000
            )

        if multi_window_result.status == "insufficient_audio":
            return TemporalResult(
                status="insufficient_audio",
                state=TemporalState.UNKNOWN,
                aggregated_score=0.5,
                windows_processed=0,
                valid_windows=0,
                failed_windows=0,
                transitions=0,
                early_stopped=False,
                total_ms=(time.time() - total_start) * 1000
            )

        if multi_window_result.successful_windows == 0:
            return TemporalResult(
                status="all_windows_failed",
                state=TemporalState.UNKNOWN,
                aggregated_score=0.5,
                windows_processed=multi_window_result.window_count,
                valid_windows=0,
                failed_windows=multi_window_result.failed_windows,
                transitions=0,
                early_stopped=False,
                total_ms=(time.time() - total_start) * 1000
            )

        # Process each window
        state_update_start = time.time()
        for window_result in multi_window_result.windows:
            evidence = self.process_window(window_result)

            # Check early stopping
            if self._check_early_stopping():
                self.early_stopped = True
                break

        state_update_ms = (time.time() - state_update_start) * 1000
        temporal_processing_ms = (time.time() - total_start) * 1000

        # Determine overall status
        if self.early_stopped:
            status = "early_stopped"
        elif multi_window_result.failed_windows > 0:
            status = "partial_success"
        else:
            status = "success"

        return TemporalResult(
            status=status,
            state=self.current_state,
            aggregated_score=multi_window_result.aggregated_score,
            windows_processed=len(self.history),
            valid_windows=multi_window_result.successful_windows,
            failed_windows=multi_window_result.failed_windows,
            transitions=self.transitions,
            early_stopped=self.early_stopped,
            history=self.history,
            temporal_processing_ms=temporal_processing_ms,
            state_update_ms=state_update_ms,
            total_ms=multi_window_result.total_latency_ms + temporal_processing_ms
        )
