import 'dart:async';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';

class BeaconSignal {
  final String id;
  final String name;
  final String lat;
  final String long;
  final String condition;
  final String status;

  BeaconSignal(
      {required this.id,
      required this.name,
      required this.lat,
      required this.long,
      required this.condition,
      this.status = "Detected"});
}

class BeaconService {
  // P2P_STAR is better for 1-to-many (One victim, many rescuers)
  final Strategy strategy = Strategy.P2P_STAR;

  List<BeaconSignal> nearbySignals = [];
  Function(List<BeaconSignal>)? onSignalsUpdated;

  // --- RESCUER MODE (Listening) ---
  Future<void> startScanning(Function(List<BeaconSignal>) onUpdate) async {
    await stopAll();
    onSignalsUpdated = onUpdate;

    try {
      await Nearby().startDiscovery("Ghost_Rescuer", strategy,
          onEndpointFound: (id, name, serviceId) {
            // Found a signal! Connect to get details.
            _addSignal(id, name, "0", "0", "Handshaking...", "Connecting");

            Nearby().requestConnection(
              "Ghost_Rescuer",
              id,
              onConnectionInitiated: (id, info) => Nearby().acceptConnection(id,
                  onPayLoadRecieved: (endId, payload) {
                String data = String.fromCharCodes(payload.bytes!);
                _parseData(endId, data);
              }),
              onConnectionResult: (id, status) {},
              onDisconnected: (id) => _removeSignal(id),
            );
          },
          onEndpointLost: (id) => _removeSignal(id!),
          serviceId: "com.ghost.beacon");
    } catch (e) {
      print("SCAN ERROR: $e");
    }
  }

  // --- VICTIM MODE (Broadcasting) ---
  Future<void> startBroadcasting(
      String name, String lat, String long, String condition) async {
    await stopAll();
    try {
      await Nearby().startAdvertising(name, strategy,
          onConnectionInitiated: (id, info) => Nearby()
              .acceptConnection(id, onPayLoadRecieved: (endId, payload) {}),
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) {
              // Send Vital Data immediately upon connection
              String msg = "SOS|$name|$lat|$long|$condition";
              Nearby().sendBytesPayload(id, Uint8List.fromList(msg.codeUnits));
            }
          },
          onDisconnected: (id) {},
          serviceId: "com.ghost.beacon");
    } catch (e) {
      print("BROADCAST ERROR: $e");
    }
  }

  void _parseData(String id, String data) {
    List<String> parts = data.split("|");
    if (parts.length >= 5 && parts[0] == "SOS") {
      // Update the placeholder signal with real data
      _addSignal(id, parts[1], parts[2], parts[3], parts[4], "DANGER");
    }
  }

  void _addSignal(String id, String name, String lat, String long, String cond,
      String status) {
    int idx = nearbySignals.indexWhere((s) => s.id == id);
    var signal = BeaconSignal(
        id: id,
        name: name,
        lat: lat,
        long: long,
        condition: cond,
        status: status);

    if (idx != -1)
      nearbySignals[idx] = signal;
    else
      nearbySignals.add(signal);

    if (onSignalsUpdated != null) onSignalsUpdated!(nearbySignals);
  }

  void _removeSignal(String id) {
    nearbySignals.removeWhere((s) => s.id == id);
    if (onSignalsUpdated != null) onSignalsUpdated!(nearbySignals);
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    nearbySignals.clear();
  }
}
