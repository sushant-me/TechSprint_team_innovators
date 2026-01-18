import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_audio/tflite_audio.dart';

class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});
  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen> {
  String _status = "Tap START";
  double _currentConfidence = 0.0;
  double _calibratedThreshold = 0.60;

  Future<void> _startCalibration() async {
    await Permission.microphone.request();
    setState(() => _status = "Say 'HELP' clearly...");
    TfliteAudio.startAudioRecognition(
            sampleRate: 44100, bufferSize: 22016, numOfInferences: 5)
        .listen((event) {
      String result = event["recognitionResult"].toString().toLowerCase();
      double conf = double.tryParse(result.split(" ").last) ?? 0.0;
      setState(() {
        _currentConfidence = conf;
        if ((result.contains("help") || result.contains("bachau")) &&
            conf > 0.4) {
          _calibratedThreshold = conf - 0.05;
          if (_calibratedThreshold < 0.5) _calibratedThreshold = 0.5;
          _status = "Detected! Threshold: $_calibratedThreshold";
        }
      });
    }, onDone: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('voice_threshold', _calibratedThreshold);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
          title: const Text("Voice Calibration"),
          backgroundColor: Colors.transparent),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            LinearPercentIndicator(
                lineHeight: 20,
                percent: _currentConfidence,
                progressColor: Colors.green),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _startCalibration, child: const Text("START")),
          ],
        ),
      ),
    );
  }
}
