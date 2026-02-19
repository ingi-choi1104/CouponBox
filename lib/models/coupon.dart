enum CouponStatus { active, used, expired }

class Coupon {
  final int? id;
  final String barcodeValue;
  final String barcodeType;
  final String? storeName;
  final String? itemName;
  final int? amount;
  final DateTime? expiryDate;
  final String imagePath;
  final CouponStatus status;
  final DateTime addedAt;
  final DateTime? usedAt;
  final String? notes;
  final String? assetId;

  const Coupon({
    this.id,
    required this.barcodeValue,
    required this.barcodeType,
    this.storeName,
    this.itemName,
    this.amount,
    this.expiryDate,
    required this.imagePath,
    required this.status,
    required this.addedAt,
    this.usedAt,
    this.notes,
    this.assetId,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 7;
  }

  int get daysUntilExpiry {
    if (expiryDate == null) return 9999;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  String get displayName {
    if (storeName != null && storeName!.isNotEmpty) return storeName!;
    if (itemName != null && itemName!.isNotEmpty) return itemName!;
    return '쿠폰';
  }

  String get displayDetail {
    if (amount != null) {
      final formatted = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      return '$formatted원';
    }
    if (itemName != null && itemName!.isNotEmpty && itemName != storeName) {
      return itemName!;
    }
    return barcodeType;
  }

  Coupon copyWith({
    int? id,
    String? barcodeValue,
    String? barcodeType,
    String? storeName,
    String? itemName,
    int? amount,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    String? imagePath,
    CouponStatus? status,
    DateTime? addedAt,
    DateTime? usedAt,
    String? notes,
    String? assetId,
  }) {
    return Coupon(
      id: id ?? this.id,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      barcodeType: barcodeType ?? this.barcodeType,
      storeName: storeName ?? this.storeName,
      itemName: itemName ?? this.itemName,
      amount: amount ?? this.amount,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      usedAt: usedAt ?? this.usedAt,
      notes: notes ?? this.notes,
      assetId: assetId ?? this.assetId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode_value': barcodeValue,
      'barcode_type': barcodeType,
      'store_name': storeName,
      'item_name': itemName,
      'amount': amount,
      'expiry_date': expiryDate?.millisecondsSinceEpoch,
      'image_path': imagePath,
      'status': status.index,
      'added_at': addedAt.millisecondsSinceEpoch,
      'used_at': usedAt?.millisecondsSinceEpoch,
      'notes': notes,
      'asset_id': assetId,
    };
  }

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'] as int?,
      barcodeValue: map['barcode_value'] as String,
      barcodeType: map['barcode_type'] as String,
      storeName: map['store_name'] as String?,
      itemName: map['item_name'] as String?,
      amount: map['amount'] as int?,
      expiryDate: map['expiry_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiry_date'] as int)
          : null,
      imagePath: map['image_path'] as String,
      status: CouponStatus.values[map['status'] as int],
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      usedAt: map['used_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['used_at'] as int)
          : null,
      notes: map['notes'] as String?,
      assetId: map['asset_id'] as String?,
    );
  }
}
