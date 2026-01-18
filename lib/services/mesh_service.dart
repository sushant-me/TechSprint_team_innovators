import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart'; // Essential for Android version checks
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

// --- DATA MODELS ---

enum MeshRole {
  idle,       // Doing nothing
  broadcaster,// I am the victim (Advertising)
  receiver,   // I am the rescuer (Discovering)
}

class MeshMessage {
  final String senderId;
  final String senderName;
  final String content;     // The actual SOS data
  final String type;        // 'SOS', 'ACK', 'CHAT'
  final int timestamp;

  MeshMessage({
    required this.senderId, 
    required this.senderName, 
    required this.content, 
    required this.type,
    required this.timestamp
  });

  Map<String, dynamic> toJson() => {
    'sid': senderId,
    'nm': senderName,
    'msg': content,
    'typ': type,
    'ts': timestamp,
  };

  factory MeshMessage.fromJson(Map<String, dynamic> json) {
    return MeshMessage(
      senderId: json['sid'] ?? 'unknown',
      senderName: json['nm'] ?? 'Anonymous',
      content: json['msg'] ?? '',
      type: json['typ'] ?? 'UNKNOWN',
      timestamp: json['ts'] ?? 0,
    );
  }
}

class MeshNetworkService {
  // CONFIG
  static const String _serviceId = "com.ghost.mesh.v1"; // Versioned Service ID
  final Strategy _strategy = Strategy.P2P_CLUSTER; // The best for M-to-N mesh

  // STATE
  String _myEndpointId = "UNKNOWN";
  String _myUserName = "Ghost_User";
  MeshRole _currentRole = MeshRole.idle;
  
  // Active Connections: Map<EndpointID, ConnectionInfo>
  final Map<String, ConnectionInfo> _connectedNodes = {};
  
  // STREAMS (For UI)
  final StreamController<List<String>> _peersController = StreamController.broadcast();
  final StreamController<MeshMessage> _messageController = StreamController.broadcast();
  
  Stream<List<String>> get connectedPeers => _peersController.stream;
  Stream<MeshMessage> get incomingMessages => _messageController.stream;

  // --- 1. INITIALIZATION & PERMISSIONS ---
  
  /// Call this first! Handles the nightmare of Android Permissions
  Future<bool> initializeMesh(String userName) async {
    _myUserName = userName;
    
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      // Permission Set depends on Android Version
      Map<Permission, PermissionStatus> statuses = {};
      
      if (sdkInt >= 33) {
        // Android 13+ (Granular)
        statuses = await [
          Permission.bluetooth,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.nearbyWifiDevices,
          Permission.location, // Still needed for some hardware discovery
        ].request();
      } else if (sdkInt >= 31) {
        // Android 12 (Bluetooth Scans required)
        statuses = await [
          Permission.bluetooth,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.location,
        ].request();
      } else {
        // Android 11 and below (Location is king)
        statuses = await [
          Permission.location,
          Permission.storage, // Sometimes needed for file payloads
        ].request();
      }

      // Check if critical permissions are granted
      bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
      bool bleGranted = (sdkInt >= 31) 
          ? (statuses[Permission.bluetoothScan]?.isGranted ?? false) 
          : true; // Implicit in older versions if location is on

      if (!locationGranted || !bleGranted) {
        print("❌ MESH ERROR: Critical Permissions Denied");
        return false;
      }
      
      // Check if Location Service (GPS) is actually on
      bool locEnabled = await Permission.location.serviceStatus.isEnabled;
      if (!locEnabled) {
         print("⚠️ GPS Service is OFF - Discovery might fail");
         // Optionally prompt user to turn it on
      }
    }
    return true;
  }

  // --- 2. THE VICTIM ENGINE (Broadcaster) ---
  
  Future<void> enterEmergencyMode() async {
    await stopMesh(); // Reset first
    _currentRole = MeshRole.broadcaster;
    print("🚨 MESH: Starting Emergency Broadcast...");

    try {
      bool success = await Nearby().startAdvertising(
        _myUserName,
        _strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      print("🚨 MESH: Advertising Result: $success");
    } catch (e) {
      print("❌ MESH ERROR (Advertise): $e");
    }
  }

  // --- 3. THE RESCUER ENGINE (Scanner) ---
  
  Future<void> enterRescuerMode() async {
    await stopMesh();
    _currentRole = MeshRole.receiver;
    print("🛡️ MESH: Starting Search Scan...");

    try {
      bool success = await Nearby().startDiscovery(
        _myUserName,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          print("👀 MESH: Found Node $name ($id). Requesting Connection...");
          // Auto-Connect to build the mesh
          Nearby().requestConnection(
            _myUserName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
          );
        },
        onEndpointLost: (id) {
          print("💨 MESH: Signal Lost: $id");
        },
        serviceId: _serviceId,
      );
      print("🛡️ MESH: Discovery Result: $success");
    } catch (e) {
       print("❌ MESH ERROR (Discovery): $e");
    }
  }

  // --- 4. HANDSHAKE PROTOCOL ---

  /// Called when two phones physically find each other
  void _onConnectionInit(String id, ConnectionInfo info) {
    print("🤝 MESH: Handshake with ${info.endpointName} ($id)");
    // In a mesh, we trust everyone for SOS. Auto-Accept.
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endId, payload) {
        if (payload.type == PayloadType.BYTES) {
          _handleIncomingMessage(endId, payload.bytes!);
        }
      },
      onPayloadTransferUpdate: (endId, update) {
        // Handle file progress if needed
      }
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      print("✅ MESH: Linked to $id");
      _connectedNodes[id] = ConnectionInfo(id, "Unknown", false); // Store ref
      _peersController.add(_connectedNodes.keys.toList());
      
      // If I am a victim, immediately scream SOS upon connection
      if (_currentRole == MeshRole.broadcaster) {
        broadcastMessage("SOS ALERT! I need help!", type: "SOS");
      }
    } else {
      print("❌ MESH: Connection Failed to $id: $status");
    }
  }

  void _onDisconnected(String id) {
    print("💔 MESH: Node Dropped ($id)");
    _connectedNodes.remove(id);
    _peersController.add(_connectedNodes.keys.toList());
  }

  // --- 5. DATA LAYER ---

  /// Broadcasts a message to ALL connected nodes
  void broadcastMessage(String content, {String type = 'CHAT'}) {
    final msg = MeshMessage(
      senderId: _myEndpointId, // Note: You need to set this properly in real app
      senderName: _myUserName,
      content: content,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final payload = Uint8List.fromList(jsonEncode(msg.toJson()).codeUnits);

    for (String nodeId in _connectedNodes.keys) {
      try {
        Nearby().sendBytesPayload(nodeId, payload);
      } catch (e) {
        print("⚠️ Failed to send to $nodeId");
      }
    }
  }

  void _handleIncomingMessage(String senderEndpointId, Uint8List bytes) {
    try {
      String jsonStr = String.fromCharCodes(bytes);
      MeshMessage msg = MeshMessage.fromJson(jsonDecode(jsonStr));
      
      print("📩 MESH MSG: [${msg.type}] ${msg.senderName}: ${msg.content}");
      _messageController.add(msg);
      
      // REBROADCAST LOGIC (Simple Flood)
      // If I receive an SOS, and I have other connections, pass it on!
      if (msg.type == "SOS") {
        // NOTE: In a real app, check a 'messageId' to prevent infinite loops
        // _rebroadcast(msg, excludeId: senderEndpointId);
      }
      
    } catch (e) {
      print("⚠️ CORRUPT PACKET: $e");
    }
  }

  Future<void> stopMesh() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _connectedNodes.clear();
    _currentRole = MeshRole.idle;
    print("🛑 MESH: Stopped");
  }
}
