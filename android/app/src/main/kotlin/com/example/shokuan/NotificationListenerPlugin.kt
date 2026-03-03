package com.example.shokuan

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

class NotificationListenerPlugin : EventChannel.StreamHandler, MethodChannel.MethodCallHandler {
    private val TAG = "NotificationListenerPlugin"
    private val METHOD_CHANNEL = "shokuan/notification_listener"
    private val EVENT_CHANNEL = "shokuan/notification_events"
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var context: Context? = null
    private var eventSink: EventChannel.EventSink? = null

    fun registerWith(flutterEngine: FlutterEngine, context: Context) {
        this.context = context
        Log.d(TAG, "Registering plugin with Flutter engine")
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(this)
        
        Log.d(TAG, "Plugin registered successfully")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method call: ${call.method}")
        when (call.method) {
            "startListening" -> {
                startListening(result)
            }
            "stopListening" -> {
                stopListening(result)
            }
            "checkPermission" -> {
                checkPermission(result)
            }
            "checkServiceConnected" -> {
                checkServiceConnected(result)
            }
            "openPermissionSettings" -> {
                openPermissionSettings(result)
            }
            "openBatteryOptimizationSettings" -> {
                openBatteryOptimizationSettings(result)
            }
            "checkBatteryOptimizationStatus" -> {
                checkBatteryOptimizationStatus(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        NotificationListener.setEventSink(events)
        Log.d(TAG, "Event stream started listening, sink: ${events != null}")
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        NotificationListener.setEventSink(null)
        Log.d(TAG, "Event stream cancelled")
    }

    private fun startListening(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Starting notification listener")
            NotificationListener.getInstance().startListening()
            result.success(true)
            Log.d(TAG, "Listening started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting listener", e)
            result.success(false)
        }
    }

    private fun stopListening(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Stopping notification listener")
            NotificationListener.getInstance().stopListening()
            result.success(true)
            Log.d(TAG, "Listening stopped successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping listener", e)
            result.success(false)
        }
    }

    private fun checkPermission(result: MethodChannel.Result) {
        // 检查系统设置中的权限
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            val packageName = context?.packageName ?: ""
            val enabledListeners = Settings.Secure.getString(
                context?.contentResolver,
                "enabled_notification_listeners"
            )
            val hasPermission = enabledListeners?.contains(packageName) == true
            Log.d(TAG, "Checking permission: $hasPermission, package: $packageName, listeners: $enabledListeners")
            hasPermission
        } else {
            false
        }
        
        // 检查NotificationListener服务是否实际连接
        val listenerInstance = NotificationListener.getInstance()
        val isConnected = NotificationListener.isServiceConnected()
        
        Log.d(TAG, "Service connection status: hasPermission=$hasPermission, isConnected=$isConnected")
        
        // 返回权限和服务连接状态
        result.success(mapOf(
            "hasPermission" to hasPermission,
            "isConnected" to isConnected
        ))
    }

    private fun checkServiceConnected(result: MethodChannel.Result) {
        val isConnected = NotificationListener.isServiceConnected()
        Log.d(TAG, "Checking service connection: $isConnected")
        result.success(isConnected)
    }

    private fun openPermissionSettings(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Opening permission settings")
            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context?.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening settings", e)
            result.success(false)
        }
    }

    private fun openBatteryOptimizationSettings(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Opening battery optimization settings")
            val intent = Intent()
            
            // 尝试打开应用详情页面的电池设置
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                val uri = android.net.Uri.fromParts("package", context?.packageName, null)
                intent.data = uri
            } else {
                // 对于旧版本，打开电池设置
                intent.action = Settings.ACTION_SETTINGS
            }
            
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context?.startActivity(intent)
            result.success(true)
            Log.d(TAG, "Battery optimization settings opened successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening battery optimization settings", e)
            // 如果特定页面打不开，尝试打开设置主页
            try {
                val fallbackIntent = Intent(Settings.ACTION_SETTINGS)
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context?.startActivity(fallbackIntent)
                result.success(true)
            } catch (e2: Exception) {
                Log.e(TAG, "Error opening fallback settings", e2)
                result.success(false)
            }
        }
    }

    private fun checkBatteryOptimizationStatus(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Checking battery optimization status")
            
            val isOptimized: Boolean
            val packageName = context?.packageName
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context?.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager?
                isOptimized = powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
            } else {
                // 旧版本系统默认未优化
                isOptimized = true
            }
            
            Log.d(TAG, "Battery optimization status: $isOptimized")
            result.success(isOptimized)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking battery optimization status", e)
            result.success(false)
        }
    }
}