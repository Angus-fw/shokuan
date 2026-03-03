class PaymentMessage {
  final String id;
  final double amount;
  final DateTime timestamp;
  final String payer;
  final String payee;
  final String status;
  final String? remark;

  PaymentMessage({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.payer,
    required this.payee,
    required this.status,
    this.remark,
  });

  factory PaymentMessage.fromJson(Map<String, dynamic> json) {
    return PaymentMessage(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      payer: json['payer'] as String,
      payee: json['payee'] as String,
      status: json['status'] as String,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'payer': payer,
      'payee': payee,
      'status': status,
      'remark': remark,
    };
  }

  PaymentMessage copyWith({
    String? id,
    double? amount,
    DateTime? timestamp,
    String? payer,
    String? payee,
    String? status,
    String? remark,
  }) {
    return PaymentMessage(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      payer: payer ?? this.payer,
      payee: payee ?? this.payee,
      status: status ?? this.status,
      remark: remark ?? this.remark,
    );
  }

  @override
  String toString() {
    return 'PaymentMessage(id: $id, amount: $amount, timestamp: $timestamp, payer: $payer, payee: $payee, status: $status)';
  }
}
