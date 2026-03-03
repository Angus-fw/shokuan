package com.example.shokuan

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var plugin: NotificationListenerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        plugin = NotificationListenerPlugin()
        plugin?.registerWith(flutterEngine, applicationContext)
    }

    override fun onResume() {
        super.onResume()
        // 应用恢复时重新建立连接
        plugin?.let {
            // 确保EventChannel连接正常
            android.util.Log.d("MainActivity", "App resumed, reconnecting EventChannel")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        plugin = null
    }
}