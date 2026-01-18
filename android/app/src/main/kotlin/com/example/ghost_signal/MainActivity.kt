package com.example.ghost_signal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Optional: Define a specific Channel Name for native communication
    // private val CHANNEL = "com.example.ghost_signal/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // This is where you would handle specific native calls if needed.
        // For example, if you need to handle specific Bluetooth/WiFi tasks 
        // that plugins don't support.
        
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getNativeInfo") {
                // Handle native call
                result.success("Signal Strength: Strong")
            } else {
                result.notImplemented()
            }
        }
      
    }
}
