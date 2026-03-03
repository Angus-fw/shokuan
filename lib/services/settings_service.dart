import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal() {
    _loadSettings();
  }

  static const String _fontSizeKey = 'font_size';
  static const String _autoListenKey = 'auto_listen';
  static const double _defaultFontSize = 18.0;
  static const bool _defaultAutoListen = true;

  double _fontSize = _defaultFontSize;
  bool _autoListen = _defaultAutoListen;

  double get fontSize => _fontSize;
  bool get autoListen => _autoListen;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
      _autoListen = prefs.getBool(_autoListenKey) ?? _defaultAutoListen;
      debugPrint('加载设置 - 字体大小: $_fontSize, 自动监听: $_autoListen');
      notifyListeners();
    } catch (e) {
      debugPrint('加载设置失败: $e');
      _fontSize = _defaultFontSize;
      _autoListen = _defaultAutoListen;
    }
  }

  Future<void> setFontSize(double size) async {
    try {
      _fontSize = size;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, size);
      debugPrint('保存字体大小: $size');
      notifyListeners();
    } catch (e) {
      debugPrint('保存字体大小失败: $e');
    }
  }

  Future<void> setAutoListen(bool value) async {
    try {
      _autoListen = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoListenKey, value);
      debugPrint('保存自动监听设置: $value');
      notifyListeners();
    } catch (e) {
      debugPrint('保存自动监听设置失败: $e');
    }
  }

  Future<void> resetFontSize() async {
    await setFontSize(_defaultFontSize);
  }
}