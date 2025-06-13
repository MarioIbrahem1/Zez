class SmsStatus {
  final bool success;
  final String phoneNumber;
  final int simId;
  final String errorReason;
  final bool isRetry;

  SmsStatus({
    required this.success,
    required this.phoneNumber,
    required this.simId,
    this.errorReason = '',
    this.isRetry = false,
  });

  @override
  String toString() {
    return 'SmsStatus{success: $success, phoneNumber: $phoneNumber, simId: $simId, errorReason: $errorReason, isRetry: $isRetry}';
  }
}
