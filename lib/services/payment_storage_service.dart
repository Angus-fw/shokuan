import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_message.dart';

class PaymentStorageService {
  static final PaymentStorageService _instance = PaymentStorageService._internal();
  factory PaymentStorageService() => _instance;
  PaymentStorageService._internal();

  static const String _storageKey = 'payment_messages';
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveMessages(List<PaymentMessage> messages) async {
    try {
      await _init();
      
      final List<String> jsonList = messages
          .map((message) => jsonEncode(message.toJson()))
          .toList();
      
      await _prefs!.setStringList(_storageKey, jsonList);
      debugPrint('成功保存 ${messages.length} 条收款消息');
    } catch (e) {
      debugPrint('保存收款消息失败: $e');
    }
  }

  Future<List<PaymentMessage>> loadMessages() async {
    try {
      await _init();
      
      final List<String>? jsonList = _prefs!.getStringList(_storageKey);
      if (jsonList == null || jsonList.isEmpty) {
        debugPrint('没有找到存储的收款消息');
        return [];
      }
      
      final List<PaymentMessage> messages = jsonList
          .map((jsonStr) {
            try {
              final Map<String, dynamic> json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return PaymentMessage.fromJson(json);
            } catch (e) {
              debugPrint('解析单条消息失败: $e');
              return null;
            }
          })
          .whereType<PaymentMessage>()
          .toList();
      
      debugPrint('成功加载 ${messages.length} 条收款消息');
      return messages;
    } catch (e) {
      debugPrint('加载收款消息失败: $e');
      return [];
    }
  }

  Future<void> addMessage(PaymentMessage message) async {
    try {
      final List<PaymentMessage> messages = await loadMessages();
      
      messages.insert(0, message);
      
      if (messages.length > 100) {
        messages.removeRange(100, messages.length);
      }
      
      await saveMessages(messages);
      debugPrint('成功添加收款消息: ¥${message.amount}');
    } catch (e) {
      debugPrint('添加收款消息失败: $e');
    }
  }

  Future<void> removeMessage(String id) async {
    try {
      final List<PaymentMessage> messages = await loadMessages();
      messages.removeWhere((message) => message.id == id);
      await saveMessages(messages);
      debugPrint('成功删除收款消息: $id');
    } catch (e) {
      debugPrint('删除收款消息失败: $e');
    }
  }

  Future<void> clearMessages() async {
    try {
      await _init();
      await _prefs!.remove(_storageKey);
      debugPrint('成功清空所有收款消息');
    } catch (e) {
      debugPrint('清空收款消息失败: $e');
    }
  }

  Future<void> updateMessage(PaymentMessage updatedMessage) async {
    try {
      final List<PaymentMessage> messages = await loadMessages();
      
      final int index = messages.indexWhere((message) => message.id == updatedMessage.id);
      if (index != -1) {
        messages[index] = updatedMessage;
        await saveMessages(messages);
        debugPrint('成功更新收款消息: ${updatedMessage.id}');
      } else {
        debugPrint('未找到要更新的消息: ${updatedMessage.id}');
      }
    } catch (e) {
      debugPrint('更新收款消息失败: $e');
    }
  }

  Future<int> getMessageCount() async {
    try {
      final List<PaymentMessage> messages = await loadMessages();
      return messages.length;
    } catch (e) {
      debugPrint('获取消息数量失败: $e');
      return 0;
    }
  }
}