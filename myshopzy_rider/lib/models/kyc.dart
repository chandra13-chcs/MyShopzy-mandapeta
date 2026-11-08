enum KycStatus { notSubmitted, pending, approved, rejected }

class KycData {
  final String aadhaarNumber;
  final String panNumber;
  final String aadhaarPhotoPath;
  final String panPhotoPath;
  final String passportPhotoPath;
  final KycStatus status;
  final String? rejectReason;
  final DateTime? submittedAt;

  const KycData({
    this.aadhaarNumber = '',
    this.panNumber = '',
    this.aadhaarPhotoPath = '',
    this.panPhotoPath = '',
    this.passportPhotoPath = '',
    this.status = KycStatus.notSubmitted,
    this.rejectReason,
    this.submittedAt,
  });

  KycData copyWith({
    String? aadhaarNumber,
    String? panNumber,
    String? aadhaarPhotoPath,
    String? panPhotoPath,
    String? passportPhotoPath,
    KycStatus? status,
    String? rejectReason,
    bool clearRejectReason = false,
    DateTime? submittedAt,
    bool clearSubmittedAt = false,
  }) =>
      KycData(
        aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
        panNumber: panNumber ?? this.panNumber,
        aadhaarPhotoPath: aadhaarPhotoPath ?? this.aadhaarPhotoPath,
        panPhotoPath: panPhotoPath ?? this.panPhotoPath,
        passportPhotoPath: passportPhotoPath ?? this.passportPhotoPath,
        status: status ?? this.status,
        rejectReason:
            clearRejectReason ? null : rejectReason ?? this.rejectReason,
        submittedAt:
            clearSubmittedAt ? null : submittedAt ?? this.submittedAt,
      );

  Map<String, dynamic> toJson() => {
        'aadhaarNumber': aadhaarNumber,
        'panNumber': panNumber,
        'aadhaarPhotoPath': aadhaarPhotoPath,
        'panPhotoPath': panPhotoPath,
        'passportPhotoPath': passportPhotoPath,
        'status': status.name,
        'rejectReason': rejectReason,
        'submittedAt': submittedAt?.toIso8601String(),
      };

  factory KycData.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    return KycData(
      aadhaarNumber: json['aadhaarNumber'] as String? ?? '',
      panNumber: json['panNumber'] as String? ?? '',
      aadhaarPhotoPath: json['aadhaarPhotoPath'] as String? ?? '',
      panPhotoPath: json['panPhotoPath'] as String? ?? '',
      passportPhotoPath: json['passportPhotoPath'] as String? ?? '',
      status: KycStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => KycStatus.notSubmitted,
      ),
      rejectReason: json['rejectReason'] as String?,
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
    );
  }
}
