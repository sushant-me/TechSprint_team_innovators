import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class SirenService {
  // 1. Private Constructor
  SirenService._internal();

  // 2. The single instance
  static final SirenService _instance = SirenService._internal();

  // 3. Factory constructor to return the same instance
  factory SirenService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  // Expose the player state so the UI can react to it (e.g., changing icons)
  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;
  PlayerState get currentState => _player.state;

  /// Initializes the audio source ahead of time for zero-latency playback
  Future<void> preload() async {
    await _player.setSource(AssetSource('siren.mp3'));
  }

  Future<void> startSiren() async {
    try {
      if (_player.state == PlayerState.playing) return;

      await _player.setSource(AssetSource('siren.mp3'));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.resume();
    } catch (e) {
      // Handle asset not found or hardware issues
      print("Error starting siren: $e");
    }
  }

  Future<void> stopSiren() async {
    if (_player.state == PlayerState.playing || _player.state == PlayerState.paused) {
      await _player.stop();
    }
  }

  /// Call this when the app is being closed to free up hardware resources
  void dispose() {
    _player.dispose();
  }
}
