import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/payment_message.dart';
import 'payment_storage_service.dart';

class PaymentListenerService extends ChangeNotifier {
  static final PaymentListenerService _instance = PaymentListenerService._internal();
  
  factory PaymentListenerService() => _instance;
  
  PaymentListenerService._internal() {
    _loadMessages();
  }

  final PaymentStorageService _storageService = PaymentStorageService();
  final List<PaymentMessage> _messages = [];
  bool _isListening = false;
  bool _isLoading = true;

  List<PaymentMessage> get messages => List.unmodifiable(_messages);
  bool get isListening => _isListening;
  bool get isLoading => _isLoading;

  Future<void> _loadMessages() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final List<PaymentMessage> storedMessages = await _storageService.loadMessages();
      _messages.clear();
      _messages.addAll(storedMessages);
      
      debugPrint('从存储加载了 ${storedMessages.length} 条收款消息');
    } catch (e) {
      debugPrint('加载存储消息失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startListening() {
    if (_isListening) return;
    
    _isListening = true;
    notifyListeners();
  }

  void stopListening() {
    if (!_isListening) return;
    
    _isListening = false;
    notifyListeners();
  }

  void addMessage(PaymentMessage message) {
    _messages.insert(0, message);
    
    if (_messages.length > 50) {
      _messages.removeLast();
    }
    
    _storageService.addMessage(message);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _storageService.clearMessages();
    notifyListeners();
  }

  void removeMessage(String id) {
    _messages.removeWhere((message) => message.id == id);
    _storageService.removeMessage(id);
    notifyListeners();
  }
}
