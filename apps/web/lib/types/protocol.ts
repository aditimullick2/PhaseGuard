export type AlertStatus = 'idle' | 'critical' | 'safe' | 'uncertain' | 'verifying' | 'limited';

export type WsMessage =
  | { type: 'pdi_update'; pdi_score: number; is_synthetic?: boolean }
  | { type: 'tremor_update'; tremor_energy: number; has_tremor?: boolean }
  | { type: 'transcript_update'; text: string }
  | { type: 'scambaiter_turn'; caller_text: string; ai_text: string; ts: string }
  | { type: 'factcheck_update'; status: string; message?: string }
  | { type: 'ensemble_update'; label: string; message?: string }
  | { type: 'mode_update'; mode: 'limited' | 'full' }
  | { type: 'config_info'; dsp_enabled: boolean }
  | { type: 'video_frame_captured' };
