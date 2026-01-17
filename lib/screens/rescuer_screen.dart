import 'package:flutter/material.dart';
import 'package:ghost_signal/services/mesh_service.dart';

class RescuerScreen extends StatefulWidget {
  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> {
  final MeshService _mesh = MeshService();
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _mesh.checkPermissions();
    _startScan();
  }

  void _startScan() async {
    setState(() => _logs.add("Scanning for Ghost Signals..."));
    await _mesh.startScanning();
    // In a real app, you would bind listeners to update the UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text("RESCUER RADAR"),
          backgroundColor: Colors.green[900]),
      body: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: const Icon(Icons.radar, color: Colors.greenAccent),
          title: Text(_logs[i], style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
