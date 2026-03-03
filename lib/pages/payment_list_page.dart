import 'package:flutter/material.dart';
import '../models/payment_message.dart';
import '../services/payment_listener_service.dart';
import '../services/notification_listener_service.dart';
import '../services/settings_service.dart';

// 省电策略状态显示组件
class _BatteryOptimizationStatusWidget extends StatefulWidget {
  final NotificationListenerService notificationService;
  final SettingsService settingsService;

  const _BatteryOptimizationStatusWidget({required this.notificationService, required this.settingsService});

  @override
  State<_BatteryOptimizationStatusWidget> createState() => _BatteryOptimizationStatusWidgetState();
}

class _BatteryOptimizationStatusWidgetState extends State<_BatteryOptimizationStatusWidget> {
  bool _isOptimized = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    setState(() => _isChecking = true);
    try {
      final status = await widget.notificationService.checkBatteryOptimizationStatus();
      setState(() {
        _isOptimized = status;
        _isChecking = false;
      });
    } catch (e) {
      debugPrint('检查省电策略状态失败: $e');
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ListenableBuilder(
        listenable: widget.settingsService,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('调整收款金额的字体大小'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('小'),
                  Slider(
                    value: widget.settingsService.fontSize,
                    min: 14.0,
                    max: 50.0,
                    divisions: 36,
                    label: '${widget.settingsService.fontSize.toInt()}',
                    onChanged: (value) {
                      widget.settingsService.setFontSize(value);
                    },
                  ),
                  const Text('大'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '当前大小: ${widget.settingsService.fontSize.toInt()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 32),
              const Text(
                '省电策略设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '为确保应用能够持续监听收款通知，建议将省电策略设置为"无限制"',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('当前状态: '),
                  if (_isChecking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          _isOptimized ? Icons.check_circle : Icons.warning,
                          color: _isOptimized ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isOptimized ? '已设置为无限制' : '需要设置为无限制',
                          style: TextStyle(
                            color: _isOptimized ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  widget.notificationService.openBatteryOptimizationSettings();
                  // 打开设置后，延迟检查状态
                  Future.delayed(const Duration(seconds: 5), () {
                    _checkBatteryStatus();
                  });
                },
                icon: const Icon(Icons.battery_charging_full),
                label: const Text('设置省电策略'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({super.key});

  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> with WidgetsBindingObserver {
  final PaymentListenerService _paymentService = PaymentListenerService();
  final NotificationListenerService _notificationService = NotificationListenerService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionOnStart();
    _notificationService.startPeriodicCheck();
  }

  Future<void> _checkPermissionOnStart() async {
    final permissionStatus = await _notificationService.checkPermission();
    
    if (!permissionStatus.hasPermission) {
      // 没有权限，显示权限对话框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPermissionDialog();
      });
    } else if (!permissionStatus.isConnected) {
      // 有权限但服务未连接，引导用户跳转设置页触发重新绑定
      if (_settingsService.autoListen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showServiceReconnectDialog();
        });
      }
    } else if (_settingsService.autoListen) {
      // 有权限、服务已连接且允许自动监听，尝试启动监听
      try {
        await _notificationService.startListening();
        setState(() {});
      } catch (e) {
        debugPrint('自动启动监听失败: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.stopListening();
    _paymentService.stopListening();
    _notificationService.stopPeriodicCheck();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 应用从后台返回前台时检查权限
      _checkPermissionOnResume();
    }
  }

  Future<void> _checkPermissionOnResume() async {
    final permissionStatus = await _notificationService.checkPermission();
    if (permissionStatus.hasPermission && !permissionStatus.isConnected) {
      // 有权限但服务未连接，引导用户跳转设置页触发重新绑定
      if (_settingsService.autoListen) {
        _showServiceReconnectDialog();
      }
    } else if (permissionStatus.hasPermission && permissionStatus.isConnected && _settingsService.autoListen && !_notificationService.isListening) {
      // 有权限、服务已连接、允许自动监听且未启动监听，自动启动
      try {
        await _notificationService.startListening();
        setState(() {});
      } catch (e) {
        debugPrint('自动启动监听失败: $e');
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_notificationService.isListening) {
      // 用户手动停止监听，记录这个偏好
      await _settingsService.setAutoListen(false);
      await _notificationService.stopListening();
    } else {
      final permissionStatus = await _notificationService.checkPermission();
      if (!permissionStatus.hasPermission) {
        _showPermissionDialog();
        return;
      }
      
      try {
        // 用户手动启动监听，记录这个偏好
        await _settingsService.setAutoListen(true);
        await _notificationService.startListening();
      } catch (e) {
        _showErrorDialog('启动监听失败', '请确保已授予通知访问权限');
        return;
      }
    }
    setState(() {});
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('需要通知访问权限'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('为了监听微信和支付宝支付通知，需要授予应用通知访问权限。'),
            SizedBox(height: 12),
            Text('请按以下步骤操作：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. 点击"去设置"按钮'),
            Text('2. 找到"收款助手"应用'),
            Text('3. 开启通知访问权限开关'),
            Text('4. 返回应用即可开始监听'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _notificationService.openPermissionSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showServiceReconnectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('需要重新连接通知服务'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('检测到通知监听服务未连接，需要重新绑定服务。'),
            SizedBox(height: 12),
            Text('请按以下步骤操作：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. 点击"去设置"按钮'),
            Text('2. 无需修改任何设置，直接返回应用'),
            Text('3. 系统会自动重新连接服务'),
            SizedBox(height: 8),
            Text('注意：仅需打开页面后返回，无需修改开关', 
              style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _notificationService.openPermissionSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _clearMessages() {
    _paymentService.clearMessages();
  }

  void _showAddMessageDialog() {
    final amountController = TextEditingController();
    final payerController = TextEditingController();
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加收款消息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥',
                ),
              ),
              TextField(
                controller: payerController,
                decoration: const InputDecoration(
                  labelText: '付款人',
                ),
              ),
              TextField(
                controller: remarkController,
                decoration: const InputDecoration(
                  labelText: '备注',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount! <= 0) {
                _showErrorDialog('错误', '请输入有效的金额');
                return;
              }
              final message = PaymentMessage(
                id: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
                amount: amount!,
                timestamp: DateTime.now(),
                payer: payerController.text.isEmpty ? '手动添加' : payerController.text,
                payee: '商户收款',
                status: 'success',
                remark: remarkController.text.isEmpty ? null : remarkController.text,
              );
              _paymentService.addMessage(message);
              Navigator.of(context).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置'),
        content: _BatteryOptimizationStatusWidget(
          notificationService: _notificationService,
          settingsService: _settingsService,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _settingsService.resetFontSize();
              Navigator.of(context).pop();
            },
            child: const Text('恢复默认'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _toggleListening();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _notificationService.isListening ? Colors.red : Colors.green,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _notificationService.isListening ? Icons.pause : Icons.play_arrow,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(_notificationService.isListening ? '停止监听' : '开始监听'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      appBar: isLandscape ? null : AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('收款消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showFontSizeDialog,
            tooltip: '字体设置',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearMessages,
            tooltip: '清空消息',
          ),
        ],
      ),
      floatingActionButton: isLandscape ? FloatingActionButton(
        onPressed: _showFontSizeDialog,
        tooltip: '设置',
        child: const Icon(Icons.settings),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListenableBuilder(
        listenable: _settingsService,
        builder: (context, child) {
          return ListenableBuilder(
            listenable: _paymentService,
            builder: (context, child) {
              final messages = _paymentService.messages;
              
              if (_paymentService.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无收款消息',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _notificationService.isListening ? '正在监听中...' : '点击设置开始监听',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _PaymentMessageCard(
                    message: message,
                    fontSize: _settingsService.fontSize,
                    onTap: () => _showMessageDetails(message),
                    onLongPress: () => _showDeleteConfirmDialog(message),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showMessageDetails(PaymentMessage message) {
    final isAlipay = message.id.startsWith('ALIPAY_');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('收款详情'),
        content: ListenableBuilder(
          listenable: _settingsService,
          builder: (context, child) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DetailRow(label: '订单号', value: message.id),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: '金额', 
                    value: '¥${message.amount.toStringAsFixed(2)}', 
                    isValueBold: true, 
                    fontSize: _settingsService.fontSize,
                    valueColor: isAlipay ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(label: '收款人', value: message.payee),
                  const SizedBox(height: 8),
                  _DetailRow(label: '状态', value: _getStatusText(message.status)),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: '时间',
                    value: _formatDateTime(message.timestamp),
                  ),
                  if (message.remark != null) ...[
                    const SizedBox(height: 8),
                    _DetailRow(label: '备注', value: message.remark!),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(PaymentMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要删除这条收款消息吗？\n¥${message.amount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _paymentService.removeMessage(message.id);
              Navigator.of(context).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return '成功';
      case 'pending':
        return '处理中';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

class _PaymentMessageCard extends StatelessWidget {
  final PaymentMessage message;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double fontSize;

  const _PaymentMessageCard({
    required this.message,
    required this.onTap,
    required this.onLongPress,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isAlipay = message.id.startsWith('ALIPAY_');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: message.status.toLowerCase() == 'success' 
              ? Colors.transparent 
              : _getStatusColor(message.status),
          child: _getStatusWidget(message.status),
        ),
        title: Text(
          '¥${message.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: isAlipay ? Colors.blue : Colors.green,
          ),
        ),
        subtitle: message.remark != null
            ? Text(
                message.remark!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            : null,
        trailing: Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _getStatusWidget(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        // 根据id前缀判断是微信还是支付宝支付
        final isAlipay = message.id.startsWith('ALIPAY_');
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            isAlipay ? 'assets/images/支付宝.png' : 'assets/images/微信.png',
            width: 24,
            height: 24,
            fit: BoxFit.cover,
          ),
        );
      case 'pending':
        return Icon(Icons.hourglass_empty, color: Colors.white);
      case 'failed':
        return Icon(Icons.close, color: Colors.white);
      default:
        return Icon(Icons.help, color: Colors.white);
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isValueBold;
  final double? fontSize;
  final Color? valueColor;

  const _DetailRow({
    required this.label, 
    required this.value, 
    this.isValueBold = false,
    this.fontSize,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isValueBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: valueColor ?? Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }
}
