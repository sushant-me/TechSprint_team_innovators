import 'package:audioplayers/audioplayers.dart';

class SirenService {
  // STATIC instance ensures we control the SAME player from any screen
  static final AudioPlayer _player = AudioPlayer();

  Future<void> startSiren() async {
    if (_player.state == PlayerState.playing)
      return; // Don't start if already ringing
    await _player.setSource(AssetSource('siren.mp3'));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.resume();
  }

  Future<void> stopSiren() async {
    await _player.stop();
    await _player.release();
  }
}
