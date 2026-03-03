import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/payment_message.dart';
import 'payment_listener_service.dart';

class NotificationListenerService {
  static const EventChannel _eventChannel = EventChannel('shokuan/notification_events');
  static const MethodChannel _methodChannel = MethodChannel('shokuan/notification_listener');
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  
  factory NotificationListenerService() => _instance;
  
  NotificationListenerService._internal();

  final PaymentListenerService _paymentService = PaymentListenerService();
  bool _isListening = false;
  bool _isServiceConnected = false;
  StreamSubscription? _subscription;
  Timer? _checkTimer;

  bool get isListening => _isListening;
  bool get isServiceConnected => _isServiceConnected;

  Future<void> startListening() async {
    try {
      debugPrint('开始启动通知监听...');
      
      // 先调用Android端启动监听
      final bool result = await _methodChannel.invokeMethod('startListening');
      if (!result) {
        throw Exception('启动通知监听失败');
      }
      
      // 再启动EventChannel监听（如果还没有启动）
      if (_subscription == null) {
        _subscription = _eventChannel.receiveBroadcastStream().listen(
          _onEventReceived,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: false,
        );
        debugPrint('EventChannel监听已启动');
      }
      
      _isListening = true;
      debugPrint('通知监听已启动');
    } catch (e) {
      debugPrint('启动通知监听失败: $e');
      _isListening = false;
      throw e;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      debugPrint('通知监听未运行');
      return;
    }

    try {
      debugPrint('停止通知监听...');
      
      await _methodChannel.invokeMethod('stopListening');
      
      if (_subscription != null) {
        await _subscription?.cancel();
        _subscription = null;
        debugPrint('EventChannel监听已停止');
      }
      
      _isListening = false;
      debugPrint('通知监听已停止');
    } catch (e) {
      debugPrint('停止通知监听失败: $e');
    }
  }

  Future<PermissionStatus> checkPermission() async {
    try {
      final result = await _methodChannel.invokeMethod('checkPermission');
      debugPrint('检查权限结果: $result');
      
      if (result is Map) {
        return PermissionStatus(
          hasPermission: result['hasPermission'] as bool? ?? false,
          isConnected: result['isConnected'] as bool? ?? false,
        );
      }
      
      return PermissionStatus(hasPermission: result as bool? ?? false, isConnected: false);
    } catch (e) {
      debugPrint('检查权限失败: $e');
      return PermissionStatus(hasPermission: false, isConnected: false);
    }
  }

  Future<bool> checkServiceConnected() async {
    try {
      final bool result = await _methodChannel.invokeMethod('checkServiceConnected');
      debugPrint('检查服务连接状态: $result');
      _isServiceConnected = result;
      return result;
    } catch (e) {
      debugPrint('检查服务连接状态失败: $e');
      _isServiceConnected = false;
      return false;
    }
  }

  void startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      debugPrint('定时检查服务连接状态...');
      await checkServiceConnected();
    });
    debugPrint('已启动定时检查（每5分钟）');
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('已停止定时检查');
  }

  Future<void> openPermissionSettings() async {
    try {
      await _methodChannel.invokeMethod('openPermissionSettings');
      debugPrint('已打开权限设置');
    } catch (e) {
      debugPrint('打开权限设置失败: $e');
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _methodChannel.invokeMethod('openBatteryOptimizationSettings');
      debugPrint('已打开省电优化设置');
    } catch (e) {
      debugPrint('打开省电优化设置失败: $e');
    }
  }

  Future<bool> checkBatteryOptimizationStatus() async {
    try {
      final bool result = await _methodChannel.invokeMethod('checkBatteryOptimizationStatus');
      debugPrint('省电策略状态: $result');
      return result;
    } catch (e) {
      debugPrint('检查省电策略状态失败: $e');
      return false;
    }
  }

  void _onEventReceived(dynamic data) {
    try {
      if (data is! Map) {
        debugPrint('收到无效的事件数据: $data');
        return;
      }
      
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(data);
      
      // 检查是否是服务状态变化
      if (eventData['type'] == 'service_status') {
        final isConnected = eventData['isConnected'] as bool? ?? false;
        _isServiceConnected = isConnected;
        debugPrint('收到服务状态变化: isConnected=$isConnected');
        return;
      }
      
      // 处理通知数据
      debugPrint('收到通知: ${eventData['appName']} - ${eventData['title']} - ${eventData['content']}');
      
      if (_isPaymentNotification(eventData)) {
        debugPrint('识别为支付通知，开始解析...');
        final paymentMessage = _parsePaymentNotification(eventData);
        if (paymentMessage != null) {
          _paymentService.addMessage(paymentMessage);
          debugPrint('解析到支付通知: ¥${paymentMessage.amount}, 付款人: ${paymentMessage.payer}');
        } else {
          debugPrint('解析支付通知失败');
        }
      } else {
        debugPrint('不是支付通知，跳过');
      }
    } catch (e) {
      debugPrint('处理事件时出错: $e');
    }
  }

  bool _isPaymentNotification(Map<String, dynamic> data) {
    final appName = data['appName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    
    debugPrint('检查是否为支付通知 - appName: $appName, title: $title, content: $content');
    
    final isPaymentApp = appName.contains('微信') || 
                    appName.contains('支付宝') ||
                    title.contains('微信') || 
                    title.contains('支付宝') ||
                    title.contains('微信收款助手') ||
                    title.contains('店员通') ||
                    data['packageName'] == 'com.tencent.mm' ||
                    data['packageName'] == 'com.eg.android.AlipayGphone';
    
    final isPayment = title.contains('微信支付') || 
                      title.contains('收款') || 
                      title.contains('付款') ||
                      title.contains('支付宝') ||
                      title.contains('店员通') ||
                      content.contains('收款') || 
                      content.contains('付款') ||
                      content.contains('到账');
    
    debugPrint('isPaymentApp: $isPaymentApp, isPayment: $isPayment');
    
    return isPaymentApp && isPayment;
  }

  PaymentMessage? _parsePaymentNotification(Map<String, dynamic> data) {
    try {
      final content = data['content'] as String? ?? '';
      final title = data['title'] as String? ?? '';
      final packageName = data['packageName'] as String? ?? '';
      debugPrint('开始解析通知内容 - title: $title, content: $content, packageName: $packageName');
      
      // 检查是否是支付宝通知
      final isAlipay = packageName == 'com.eg.android.AlipayGphone' || 
                      title.contains('支付宝') || 
                      content.contains('支付宝');
      
      double amount = 0.0;
      String payer = '未知用户';
      
      if (isAlipay) {
        // 解析支付宝通知
        // 格式1: "╭Demonァ轻吟通过扫码向你付款0.01元"
        // 格式2: "支付宝成功收款0.01元，点击查看。" (店员通)
        
        // 尝试匹配店员通格式
        final alipayStaffAmountRegex = RegExp(r'收款([0-9.]+)元');
        var alipayAmountMatch = alipayStaffAmountRegex.firstMatch(content);
        
        // 如果不是店员通格式，尝试匹配普通支付宝格式
        if (alipayAmountMatch == null) {
          final alipayNormalAmountRegex = RegExp(r'付款([0-9.]+)元');
          alipayAmountMatch = alipayNormalAmountRegex.firstMatch(content);
        }
        
        if (alipayAmountMatch == null) {
          debugPrint('未能匹配到支付宝金额');
          return null;
        }
        amount = double.tryParse(alipayAmountMatch.group(1)!) ?? 0.0;
        
        // 解析付款人
        if (title.contains('店员通')) {
          payer = '店员收款';
          debugPrint('识别为支付宝店员通通知');
        } else {
          // 普通支付宝付款通知 - 从开头到"通过扫码"之间的内容
          final alipayPayerRegex = RegExp(r'^(.*?)通过扫码');
          final alipayPayerMatch = alipayPayerRegex.firstMatch(content);
          if (alipayPayerMatch != null) {
            payer = alipayPayerMatch.group(1)!;
          }
        }
        
        debugPrint('匹配到支付宝金额: ¥$amount, 付款人: $payer');
      } else {
        // 解析微信通知
        // 支持多种格式：
        // 1. "个人收款码到账¥0.01"
        // 2. "[店员消息]收款到账9.00元"
        // 3. "微信支付收款0.01元(朋友到店)"
        // 4. "微信支付收款0.02元"
        final amountRegex = RegExp(r'(?:到账|收款)¥?([0-9.]+)\s*元?');
        final amountMatch = amountRegex.firstMatch(content);
        if (amountMatch == null) {
          debugPrint('未能匹配到金额');
          return null;
        }
        amount = double.tryParse(amountMatch.group(1)!) ?? 0.0;
        
        if (title.contains('微信收款助手')) {
          payer = '店员收款';
          debugPrint('识别为微信收款助手通知');
        } else if (content.contains('个人收款码到账')) {
          payer = '扫码支付用户';
          debugPrint('识别为个人收款码支付');
        } else {
          final payerRegex = RegExp(r'([^\s]+)向你');
          final payerMatch = payerRegex.firstMatch(content);
          if (payerMatch != null) {
            payer = payerMatch.group(1)!;
          }
        }
        
        debugPrint('匹配到金额: ¥$amount');
      }
      
      if (amount <= 0) {
        debugPrint('金额无效: $amount');
        return null;
      }
      
      String? remark;
      final remarkRegex = RegExp(r'备注：(.*)');
      final remarkMatch = remarkRegex.firstMatch(content);
      if (remarkMatch != null) {
        remark = remarkMatch.group(1)!;
      }
      
      debugPrint('解析结果 - 金额: ¥$amount, 付款人: $payer, 备注: $remark');
      
      return PaymentMessage(
        id: '${isAlipay ? 'ALIPAY' : 'WECHAT'}_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        timestamp: DateTime.now(),
        payer: payer,
        payee: '商户收款',
        status: 'success',
        remark: remark,
      );
    } catch (e) {
      debugPrint('解析支付通知失败: $e');
      return null;
    }
  }

  void _onError(dynamic error) {
    debugPrint('通知监听错误: $error');
  }

  void _onDone() {
    debugPrint('通知监听已完成');
    _isListening = false;
    _subscription = null;
  }

  void dispose() {
    stopListening();
    stopPeriodicCheck();
  }
}

class PermissionStatus {
  final bool hasPermission;
  final bool isConnected;

  PermissionStatus({
    required this.hasPermission,
    required this.isConnected,
  });

  @override
  String toString() {
    return 'PermissionStatus(hasPermission: $hasPermission, isConnected: $isConnected)';
  }
}
