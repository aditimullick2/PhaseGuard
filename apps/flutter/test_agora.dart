import 'package:agora_rtc_engine/agora_rtc_engine.dart';
void main() {
  RtcEngine? e;
  e?.playEffect(
    soundId: 1,
    filePath: 'test.wav',
    loopCount: 1,
    pitch: 1.0,
    pan: 0.0,
    gain: 100.0,
    publish: true,
  );
}
