import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// --- DATA MODEL ---
class BeaconSignal {
  final String id;
  final String name;
  final double lat;
  final double long;
  final String condition;   // "CRITICAL", "STABLE", "UNKNOWN"
  final String status;      // "LIVE", "LOST", "CONNECTING"
  final DateTime lastSeen;
  final Map<String, dynamic> vitalSigns;
  
  // Computed Properties for UI
  double get distance => _calculateRoughDistance(); 
  bool get isStale => DateTime.now().difference(lastSeen).inSeconds > 45;

  BeaconSignal({
    required this.id,
    required this.name,
    required this.lat,
    required this.long,
    required this.condition,
    this.status = "CONNECTING",
    required this.lastSeen,
    this.vitalSigns = const {},
  });

  // Since P2P API doesn't always give distance, we simulate "Signal Drift"
  // based on connection quality or time since last packet.
  double _calculateRoughDistance() {
    // In a real app, you'd calculate this from Lat/Long diff if GPS is available.
    // For Ghost Signal aesthetic, we return a value 0.0 - 1.0 based on "staleness"
    int age = DateTime.now().difference(lastSeen).inSeconds;
    return (age / 60).clamp(0.1, 1.0); 
  }
}

class BeaconService {
  // Strategy: P2P_STAR (1 Rescuer -> N Victims)
  // This allows the rescuer to maintain stable connections to multiple people.
  final Strategy _strategy = Strategy.P2P_STAR;
  final String _serviceId = "com.ghost.beacon.net"; 
  
  // --- STATE ---
  List<BeaconSignal> _signals = [];
  final StreamController<List<BeaconSignal>> _signalStreamCtrl = StreamController.broadcast();
  Stream<List<BeaconSignal>> get signalsStream => _signalStreamCtrl.stream;

  bool _isScanning = false;
  bool _isBroadcasting = false;
  Timer? _heartbeatTimer;
  Timer? _simulationTimer;

  // --- PERMISSION PROTOCOL ---
  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.collapsedBluetoothScan, // Only for custom scanners
        Permission.nearbyWifiDevices,
      ].request();

      // Android 13+ requires specific fine-grained permissions
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 33) {
        return statuses[Permission.nearbyWifiDevices]?.isGranted ?? false;
      }
      return statuses[Permission.location]?.isGranted ?? false;
    }
    return true; // iOS permissions handled in Info.plist
  }

  // --- RESCUER MODE (HUNTER) ---
  
  /// Starts searching for distress beacons.
  /// [simulate] : If true, generates fake signals for UI testing.
  Future<void> startScanning({bool simulate = false}) async {
    if (_isScanning) return;
    await stopAll();

    if (simulate) {
      _startSimulation();
      return;
    }

    if (!await checkPermissions()) {
      _log("❌ PERMISSIONS DENIED");
      return;
    }

    _isScanning = true;
    _log("📡 STARTING GHOST SCAN...");

    try {
      await Nearby().startDiscovery(
        "Ghost_Rescuer",
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          _log("Found Endpoint: $name ($id)");
          // 1. Register basic contact
          _updateSignal(id, name: name, status: "HANDSHAKING");

          // 2. Auto-Connect to pull data
          Nearby().requestConnection(
            "Ghost_Rescuer",
            id,
            onConnectionInitiated: (id, info) async {
              await Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endId, payload) {
                  if (payload.type == PayloadType.BYTES) {
                    _decodePayload(endId, payload.bytes!);
                  }
                },
                onPayloadTransferUpdate: (endId, update) {},
              );
            },
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                _updateSignal(id, status: "LINKED");
              } else {
                _updateSignal(id, status: "FAILED");
              }
            },
            onDisconnected: (id) => _markAsLost(id),
          );
        },
        onEndpointLost: (id) => _markAsLost(id),
        serviceId: _serviceId,
      );
    } catch (e) {
      _log("❌ SCAN ERROR: $e");
      _isScanning = false;
    }
  }

  // --- VICTIM MODE (BEACON) ---
  
  Future<void> startBroadcasting({
    required String name,
    required double lat,
    required double long,
    required String condition,
  }) async {
    await stopAll();
    if (!await checkPermissions()) return;

    _isBroadcasting = true;
    _log("🚨 ACTIVATING BEACON...");

    try {
      await Nearby().startAdvertising(
        name,
        _strategy,
        onConnectionInitiated: (id, info) async {
          // Victims auto-accept help
          await Nearby().acceptConnection(id, 
            onPayLoadRecieved: (_,__) {}, 
            onPayloadTransferUpdate: (_,__) {}
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _log("🔗 CONNECTED TO RESCUER: $id");
            // Immediate Data Burst
            _sendPulse(id, name, lat, long, condition);
            // Continuous Heartbeat
            _startHeartbeat(id, name, lat, long, condition);
          }
        },
        onDisconnected: (id) => _heartbeatTimer?.cancel(),
        serviceId: _serviceId,
      );
    } catch (e) {
      _log("❌ BROADCAST ERROR: $e");
      _isBroadcasting = false;
    }
  }

  // --- DATA HANDLING ---

  void _sendPulse(String id, String name, double lat, double long, String cond) {
    final Map<String, dynamic> data = {
      "type": "SOS",
      "name": name,
      "lat": lat,
      "long": long,
      "cond": cond,
      "batt": Random().nextInt(20) + 10, // Simulated Low Battery
      "ts": DateTime.now().toIso8601String(),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    Nearby().sendBytesPayload(id, bytes);
  }

  void _decodePayload(String id, Uint8List bytes) {
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data['type'] == 'SOS') {
        _updateSignal(
          id,
          name: data['name'],
          lat: (data['lat'] as num).toDouble(),
          long: (data['long'] as num).toDouble(),
          cond: data['cond'],
          status: "LIVE FEED",
          vitals: {'batt': data['batt'], 'pulse': 0}, // Pulse added via Sensor later
        );
      }
    } catch (e) {
      _log("⚠️ PACKET ERROR: $e");
    }
  }

  void _startHeartbeat(String id, String name, double lat, double long, String cond) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendPulse(id, name, lat, long, cond);
    });
  }

  // --- LOCAL STATE MANAGERS ---

  void _updateSignal(String id, {
    String? name, double? lat, double? long, 
    String? cond, String? status, Map<String, dynamic>? vitals
  }) {
    final idx = _signals.indexWhere((s) => s.id == id);
    final now = DateTime.now();

    if (idx != -1) {
      var old = _signals[idx];
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
      _signals.add(BeaconSignal(
        id: id,
        name: name ?? "Unknown Signal",
        lat: lat ?? 0.0,
        long: long ?? 0.0,
        condition: cond ?? "ANALYZING",
        status: status ?? "CONNECTING",
        lastSeen: now,
        vitalSigns: vitals ?? {},
      ));
    }
    
    _emit();
  }

  void _markAsLost(String id) {
    _log("🚫 SIGNAL LOST: $id");
    final idx = _signals.indexWhere((s) => s.id == id);
    if (idx != -1) {
      var old = _signals[idx];
      _signals[idx] = BeaconSignal(
        id: old.id, name: old.name, lat: old.lat, long: old.long,
        condition: old.condition, status: "LOST SIGNAL", lastSeen: old.lastSeen,
        vitalSigns: old.vitalSigns
      );
      _emit();
    }
  }

  void _emit() {
    // Sort: Critical first, then by recency
    _signals.sort((a, b) {
      if (a.condition == "CRITICAL" && b.condition != "CRITICAL") return -1;
      if (b.condition == "CRITICAL" && a.condition != "CRITICAL") return 1;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    _signalStreamCtrl.add(List.from(_signals));
  }

  // --- MOCK SIMULATION (For Development) ---
  void _startSimulation() {
    _isScanning = true;
    _log("🔮 SIMULATION MODE ACTIVE");
    
    final names = ["V-104", "V-209", "Ghost-X", "Survivor-A"];
    final conds = ["CRITICAL", "STABLE", "UNKNOWN", "STABLE"];
    
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isScanning) {
        timer.cancel();
        return;
      }
      
      // Randomly update or add a node
      final r = Random();
      final idx = r.nextInt(names.length);
      
      _updateSignal(
        "sim_$idx",
        name: names[idx],
        lat: 0.0, long: 0.0, // GPS would be real in prod
        cond: conds[idx],
        status: "LIVE FEED",
        vitals: {'batt': r.nextInt(100), 'pulse': 60 + r.nextInt(100)}
      );
    });
  }

  Future<void> stopAll() async {
    _isScanning = false;
    _isBroadcasting = false;
    _heartbeatTimer?.cancel();
    _simulationTimer?.cancel();
    
    // Safety check before calling plugin methods
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch(e) {
      // Ignore errors if plugin wasn't active
    }
    
    _signals.clear();
    _signalStreamCtrl.add([]);
  }

  void _log(String msg) {
    print("[BEACON_NET] $msg");
  }
}
