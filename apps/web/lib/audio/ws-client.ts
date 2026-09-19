import { WsMessage } from '../types/protocol';

export class WsClient {
  private callId: string;
  private token: string;
  private ws: WebSocket | null = null;
  private onMessage: (msg: WsMessage) => void;
  private onStatusChange: (status: 'connected' | 'disconnected' | 'error' | 'idle') => void;
  private onAudioPlay: (buffer: ArrayBuffer) => void;

  constructor(
    callId: string,
    token: string,
    onMessage: (msg: WsMessage) => void,
    onStatusChange: (status: 'connected' | 'disconnected' | 'error' | 'idle') => void,
    onAudioPlay: (buffer: ArrayBuffer) => void
  ) {
    this.callId = callId;
    this.token = token;
    this.onMessage = onMessage;
    this.onStatusChange = onStatusChange;
    this.onAudioPlay = onAudioPlay;
  }

  connect() {
    this.onStatusChange('idle');
    const url = `ws://localhost:8000/ws/call/${this.callId}?token=${this.token}`;
    this.ws = new WebSocket(url);

    this.ws.onopen = () => {
      this.onStatusChange('connected');
    };

    this.ws.onmessage = (event) => {
      if (typeof event.data === 'string') {
        try {
          const data = JSON.parse(event.data);
          this.onMessage(data as WsMessage);
        } catch (err) {
          console.error('Failed to parse WS message', err);
        }
      } else if (event.data instanceof ArrayBuffer) {
        this.onAudioPlay(event.data);
      } else if (event.data instanceof Blob) {
        event.data.arrayBuffer().then(buffer => {
          this.onAudioPlay(buffer);
        });
      }
    };

    this.ws.onerror = (err) => {
      console.error('WebSocket Error:', err);
      this.onStatusChange('error');
    };

    this.ws.onclose = () => {
      this.onStatusChange('disconnected');
    };
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  sendAudio(data: Float32Array | Int16Array) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(data.buffer);
    }
  }
}
