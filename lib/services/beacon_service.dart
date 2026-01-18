import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';

// --- DATA MODEL: ENRICHED INTELLIGENCE ---
class BeaconSignal {
  final String id;
  final String name;
  final double lat;
  final double long;
  final String condition;   // e.g., "Critical", "Stable"
  final String status;      // "Live Feed", "LOST SIGNAL", "Handshaking"
  final DateTime lastSeen;  // For calculating "staleness"
  final Map<String, dynamic> vitalSigns; // e.g., {'batt': 15, 'pulse': 120}

  BeaconSignal({
    required this.id,
    required this.name,
    required this.lat,
    required this.long,
    required this.condition,
    this.status = "Connecting",
    required this.lastSeen,
    this.vitalSigns = const {},
  });

  // Helper: Is the data older than 30 seconds?
  bool get isStale => DateTime.now().difference(lastSeen).inSeconds > 30;
}

class BeaconService {
  // P2P_STAR is optimal for 1 rescuer connecting to multiple victims
  final Strategy strategy = Strategy.P2P_STAR;
  final String _serviceId = "com.ghost.beacon.v2"; // Versioned ID to prevent mismatches

  // --- STATE MANAGEMENT ---
  List<BeaconSignal> _signals = [];
  final StreamController<List<BeaconSignal>> _signalStreamController = StreamController.broadcast();
  
  // Public Stream for UI to listen to
  Stream<List<BeaconSignal>> get signalsStream => _signalStreamController.stream;

  bool _isScanning = false;
  Timer? _heartbeatTimer;

  // --- RESCUER MODE (The Hunter) ---
  Future<void> startScanning() async {
    if (_isScanning) return;
    await stopAll();
    _isScanning = true;

    try {
      await Nearby().startDiscovery(
        "Ghost_Rescuer",
        strategy,
        onEndpointFound: (id, name, serviceId) {
            // 1. Optimistic Add: We see a radio signature, but no data yet
            _updateSignal(id, name: name, status: "Handshaking...");

            // 2. Auto-Connect to retrieve the SOS packet
            Nearby().requestConnection(
              "Ghost_Rescuer",
              id,
              onConnectionInitiated: (id, info) async {
                await Nearby().acceptConnection(
                  id,
                  onPayLoadRecieved: (endId, payload) {
                    if (payload.type == PayloadType.BYTES) {
                      _processPayload(endId, payload.bytes!);
                    }
                  },
                  onPayloadTransferUpdate: (endId, payloadTransferUpdate) {},
                );
              },
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                   _updateSignal(id, status: "Connected - Waiting for Data...");
                } else {
                   _updateSignal(id, status: "Connection Failed");
                }
              },
              onDisconnected: (id) => _markAsLost(id),
            );
        },
        onEndpointLost: (id) => _markAsLost(id),
        serviceId: _serviceId,
      );
    } catch (e) {
      print("❌ SCAN ERROR: $e");
      _isScanning = false;
    }
  }

  // --- VICTIM MODE (The Beacon) ---
  Future<void> startBroadcasting({
    required String name,
    required double lat,
    required double long,
    required String condition,
    Map<String, dynamic>? vitals,
  }) async {
    await stopAll();
    
    // Create initial packet
    final sosPacket = _createPacket(name, lat, long, condition, vitals);

    try {
      await Nearby().startAdvertising(
        name,
        strategy,
        onConnectionInitiated: (id, info) async {
            // Auto-accept any Rescuer who tries to help
            await Nearby().acceptConnection(
              id,
              onPayLoadRecieved: (endId, payload) {}, // Victims usually don't receive commands
              onPayloadTransferUpdate: (endId, payloadTransferUpdate) {},
            );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            // 1. BURST TRANSMISSION: Send vital data immediately
            Nearby().sendBytesPayload(id, sosPacket);
            
            // 2. START HEARTBEAT: Pulse updates every 15s in case we move
            _startHeartbeat(id, name, lat, long, condition, vitals);
          }
        },
        onDisconnected: (id) {
           _heartbeatTimer?.cancel();
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      print("❌ BROADCAST ERROR: $e");
    }
  }

  // --- INTELLIGENCE (The Brain) ---
  
  // Creates a compact JSON packet
  Uint8List _createPacket(String name, double lat, double long, String cond, Map<String, dynamic>? vitals) {
    final Map<String, dynamic> data = {
      "type": "SOS",
      "ver": 2, // Protocol versioning allows future upgrades
      "name": name,
      "lat": lat,
      "long": long,
      "cond": cond,
      "vitals": vitals ?? {'batt': 'UNKNOWN'},
      "ts": DateTime.now().toIso8601String(), // Timestamp for staleness check
    };
    return Uint8List.fromList(jsonEncode(data).codeUnits);
  }

  void _processPayload(String id, Uint8List bytes) {
    try {
      final String jsonStr = utf8.decode(bytes);
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      if (data['type'] == 'SOS') {
        _updateSignal(
          id,
          name: data['name'],
          lat: (data['lat'] as num).toDouble(),
          long: (data['long'] as num).toDouble(),
          cond: data['cond'],
          status: "Live Feed",
          vitals: data['vitals'],
        );
      }
    } catch (e) {
      print("⚠️ CORRUPT PACKET FROM $id: $e");
    }
  }

  void _startHeartbeat(String id, String name, double lat, double long, String cond, Map<String, dynamic>? vitals) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // In a real app, fetch NEW gps coordinates here
      final packet = _createPacket(name, lat, long, cond, vitals);
      Nearby().sendBytesPayload(id, packet);
    });
  }

  // --- STATE UPDATERS ---

  void _updateSignal(String id, {
      String? name, 
      double? lat, 
      double? long, 
      String? cond, 
      String? status,
      Map<String, dynamic>? vitals
  }) {
    final int idx = _signals.indexWhere((s) => s.id == id);
    final now = DateTime.now();

    if (idx != -1) {
      // Update existing record
      final old = _signals[idx];
      _signals[idx] = BeaconSignal(
        id: id,
        name: name ?? old.name,
        lat: lat ?? old.lat,
        long: long ?? old.long,
        condition: cond ?? old.condition,
        status: status ?? old.status,
        lastSeen: now,
        vitalSigns: vitals ?? old.vitalSigns,
      );
    } else {
      // Create new record
      _signals.add(BeaconSignal(
        id: id,
        name: name ?? "Unknown Signal",
        lat: lat ?? 0.0,
        long: long ?? 0.0,
        condition: cond ?? "Analyzing...",
        status: status ?? "Connecting",
        lastSeen: now,
        vitalSigns: vitals ?? {},
      ));
    }
    _signalStreamController.add(List.from(_signals));
  }

  void _markAsLost(String id) {
    // CRITICAL FEATURE: Do not delete! Mark as LOST so we know where they were.
    final int idx = _signals.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final old = _signals[idx];
      _signals[idx] = BeaconSignal(
        id: old.id,
        name: old.name,
        lat: old.lat,
        long: old.long,
        condition: old.condition,
        status: "LOST SIGNAL", // UI can turn this red/grey
        lastSeen: old.lastSeen,
        vitalSigns: old.vitalSigns,
      );
      _signalStreamController.add(List.from(_signals));
    }
  }

  Future<void> stopAll() async {
    _isScanning = false;
    _heartbeatTimer?.cancel();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _signals.clear();
    _signalStreamController.add([]);
  }
}
