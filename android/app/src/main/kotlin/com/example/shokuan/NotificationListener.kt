package com.example.shokuan

import android.app.Notification
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

class NotificationListener : NotificationListenerService() {
    private var isListening = false
    private var eventSink: EventChannel.EventSink? = null
    private var isServiceConnected = false

    companion object {
        private var instance: NotificationListener? = null
        private const val TAG = "NotificationListener"
        
        fun getInstance(): NotificationListener {
            if (instance == null) {
                instance = NotificationListener()
            }
            return instance!!
        }
        
        fun setEventSink(sink: EventChannel.EventSink?) {
            instance?.eventSink = sink
            Log.d(TAG, "EventSink updated: ${sink != null}")
        }
        
        fun isServiceConnected(): Boolean {
            return instance?.isServiceConnected ?: false
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        // 服务创建时默认启用监听，等待系统连接
        isListening = true
        Log.d(TAG, "Service created, listening enabled")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener connected")
        isServiceConnected = true
        isListening = true
        Log.d(TAG, "Auto-started listening on connection")
        // 通知Flutter层服务已连接
        sendServiceStatusToFlutter(true)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "Listener disconnected")
        isServiceConnected = false
        isListening = false
        // 通知Flutter层服务已断开
        sendServiceStatusToFlutter(false)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        
        if (!isListening || sbn == null) {
            Log.d(TAG, "Skipping notification: isListening=$isListening, sbn=$sbn")
            return
        }
        
        try {
            val packageName = sbn.packageName
            val notification = sbn.notification ?: return
            
            Log.d(TAG, "Processing notification from: $packageName")
            
            // 监听微信和支付宝的通知
            if (!packageName.contains("com.tencent.mm") && !packageName.contains("com.eg.android.AlipayGphone")) {
                Log.d(TAG, "Not a payment app, skipping")
                return
            }
            
            val extras = notification.extras
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            
            val appName = try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0)).toString()
            } catch (e: Exception) {
                packageName
            }
            
            val content = if (bigText.isNotEmpty()) bigText else text
            
            Log.d(TAG, "Notification content - title: $title, content: $content")
            
            // 检查是否是支付相关的通知
            if (isPaymentNotification(title, content)) {
                val data = mapOf(
                    "appName" to appName,
                    "packageName" to packageName,
                    "title" to title,
                    "content" to content,
                    "timestamp" to System.currentTimeMillis()
                )
                
                sendNotificationToFlutter(data)
                Log.d(TAG, "Payment notification: $data")
            } else {
                Log.d(TAG, "Not a payment notification")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }

    private fun isPaymentNotification(title: String, content: String): Boolean {
        val paymentKeywords = listOf("微信支付", "收款", "付款", "转账", "红包", "支付成功")
        val isPayment = paymentKeywords.any { title.contains(it) || content.contains(it) }
        Log.d(TAG, "Checking payment notification: title=$title, content=$content, isPayment=$isPayment")
        return isPayment
    }

    private fun sendNotificationToFlutter(data: Map<String, Any>) {
        Handler(Looper.getMainLooper()).post {
            try {
                if (eventSink != null) {
                    eventSink?.success(data)
                    Log.d(TAG, "Sent notification to Flutter: $data")
                } else {
                    Log.w(TAG, "EventSink is null, cannot send notification to Flutter")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending to Flutter", e)
            }
        }
    }

    private fun sendServiceStatusToFlutter(isConnected: Boolean) {
        Handler(Looper.getMainLooper()).post {
            try {
                if (eventSink != null) {
                    val statusData = mapOf(
                        "type" to "service_status",
                        "isConnected" to isConnected,
                        "timestamp" to System.currentTimeMillis()
                    )
                    eventSink?.success(statusData)
                    Log.d(TAG, "Sent service status to Flutter: isConnected=$isConnected")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending service status to Flutter", e)
            }
        }
    }

    fun startListening(): Boolean {
        return try {
            isListening = true
            Log.d(TAG, "Listening started")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting listener", e)
            false
        }
    }

    fun stopListening(): Boolean {
        return try {
            isListening = false
            Log.d(TAG, "Listening stopped")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping listener", e)
            false
        }
    }

    fun checkPermission(): Boolean {
        // 检查是否有通知监听权限
        val packageName = packageName
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        val hasPermission = enabledListeners?.contains(packageName) == true
        Log.d(TAG, "Checking permission: isListening=$isListening, hasPermission=$hasPermission, package=$packageName")
        return hasPermission
    }

    fun openPermissionSettings() {
        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        isListening = false
        instance = null
        Log.d(TAG, "Service destroyed")
    }
}