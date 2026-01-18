import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghost_signal/services/mesh_service.dart';

class RescuerScreen extends StatefulWidget {
  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> with SingleTickerProviderStateMixin {
  final MeshService _mesh = MeshService();
  final List<String> _logs = [];
  late AnimationController _radarController;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _initializeRescuerMode();
  }

  void _initializeRescuerMode() async {
    await _mesh.checkPermissions();
    _startScan();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _addLog("INITIALIZING_RADAR_SCAN...");
      _addLog("MODE: PASSIVE_LISTENING");
    });
    
    _mesh.startScanning();
    
    // Simulate finding signals (In production, replace with MeshService Stream)
    Timer(const Duration(seconds: 2), () => _addLog("SIGNAL_FOUND: ID_098 - DISTANCE: NEAR"));
  }

  void _addLog(String msg) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _logs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $msg");
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050F05), // Deep military green-black
      appBar: AppBar(
        title: const Text("RESCUER_RADAR_v2", 
          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.green[900],
        elevation: 10,
        actions: [
          IconButton(
            icon: Icon(Icons.sync, color: _isScanning ? Colors.greenAccent : Colors.white),
            onPressed: () => _startScan(),
          )
        ],
      ),
      body: Column(
        children: [
          _buildRadarVisualizer(),
          _buildStatsBar(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                border: Border(top: BorderSide(color: Colors.green[800]!, width: 2)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (ctx, i) => _buildTerminalLine(_logs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarVisualizer() {
    return Container(
      height: 250,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Pulsing Radar Rings
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                double progress = (_radarController.value + (index / 3)) % 1;
                return Container(
                  width: progress * 300,
                  height: progress * 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(1 - progress),
                      width: 2,
                    ),
                  ),
                );
              },
            );
          }),
          const Icon(Icons.navigation, color: Colors.greenAccent, size: 40),
          const Positioned(
            top: 20, right: 40,
            child: Icon(Icons.location_on, color: Colors.redAccent, size: 20), // Target Found
          )
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem("NODES", "12"),
          _statItem("STRENGTH", "92%"),
          _statItem("RANGE", "450m"),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildTerminalLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text(">> ", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, 
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
