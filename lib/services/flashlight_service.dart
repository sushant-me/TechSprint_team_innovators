import 'dart:async';
import 'package:torch_light/torch_light.dart';

class FlashlightService {
  bool _isStrobing = false;

  Future<void> startSosStrobe() async {
    if (_isStrobing) return;
    _isStrobing = true;
    try {
      bool hasTorch = await TorchLight.isTorchAvailable();
      if (!hasTorch) return;
      while (_isStrobing) {
        await _flash(3, 200); // S
        await Future.delayed(const Duration(milliseconds: 500));
        await _flash(3, 600); // O
        await Future.delayed(const Duration(milliseconds: 500));
        await _flash(3, 200); // S
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _flash(int count, int durationMs) async {
    for (int i = 0; i < count; i++) {
      if (!_isStrobing) return;
      await TorchLight.enableTorch();
      await Future.delayed(Duration(milliseconds: durationMs));
      await TorchLight.disableTorch();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void stopStrobe() {
    _isStrobing = false;
    TorchLight.disableTorch();
  }
}
