import 'package:flutter/foundation.dart';
import '../models/coupon.dart';
import '../services/database_service.dart';
import '../services/photo_scan_service.dart';

class CouponProvider extends ChangeNotifier {
  List<Coupon> _coupons = [];
  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
  int _newCouponsCount = 0;

  List<Coupon> get coupons => _coupons;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String? get error => _error;
  int get newCouponsCount => _newCouponsCount;

  List<Coupon> get activeCoupons {
    final list = _coupons
        .where((c) => c.status == CouponStatus.active && !c.isExpired)
        .toList();
    list.sort((a, b) {
      // 만료 임박 순으로 정렬
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
    return list;
  }

  List<Coupon> get usedCoupons {
    final list = _coupons
        .where((c) => c.status == CouponStatus.used)
        .toList();
    list.sort(
      (a, b) => (b.usedAt ?? b.addedAt).compareTo(a.usedAt ?? a.addedAt),
    );
    return list;
  }

  List<Coupon> get expiredCoupons {
    final list = _coupons
        .where(
          (c) =>
              c.status == CouponStatus.expired ||
              (c.status == CouponStatus.active && c.isExpired),
        )
        .toList();
    list.sort(
      (a, b) => (b.expiryDate ?? b.addedAt).compareTo(
        a.expiryDate ?? a.addedAt,
      ),
    );
    return list;
  }

  List<Coupon> get expiringSoon =>
      activeCoupons.where((c) => c.isExpiringSoon).toList();

  Future<void> loadCoupons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await DatabaseService.instance.markExpiredCoupons();
      _coupons = await DatabaseService.instance.getAllCoupons();
    } catch (e) {
      _error = '쿠폰을 불러오는 데 실패했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> scanGallery() async {
    if (_isScanning) return 0;
    _isScanning = true;
    _newCouponsCount = 0;
    notifyListeners();

    try {
      final count = await PhotoScanService.instance.scanNewPhotos();
      _newCouponsCount = count;
      await loadCoupons();
      return count;
    } catch (e) {
      _error = '갤러리 스캔에 실패했습니다.';
      return 0;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> markAsUsed(Coupon coupon) async {
    final updated = coupon.copyWith(
      status: CouponStatus.used,
      usedAt: DateTime.now(),
    );
    await DatabaseService.instance.updateCoupon(updated);
    final idx = _coupons.indexWhere((c) => c.id == coupon.id);
    if (idx != -1) {
      _coupons[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> markAsActive(Coupon coupon) async {
    final updated = coupon.copyWith(status: CouponStatus.active);
    await DatabaseService.instance.updateCoupon(updated);
    final idx = _coupons.indexWhere((c) => c.id == coupon.id);
    if (idx != -1) {
      _coupons[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteCoupon(Coupon coupon) async {
    if (coupon.id != null) {
      await DatabaseService.instance.deleteCoupon(coupon.id!);
    }
    _coupons.removeWhere((c) => c.id == coupon.id);
    notifyListeners();
  }

  Future<void> updateCoupon(Coupon coupon) async {
    await DatabaseService.instance.updateCoupon(coupon);
    final idx = _coupons.indexWhere((c) => c.id == coupon.id);
    if (idx != -1) {
      _coupons[idx] = coupon;
      notifyListeners();
    }
  }

  Future<void> addCoupon(Coupon coupon) async {
    final id = await DatabaseService.instance.insertCoupon(coupon);
    _coupons.insert(0, coupon.copyWith(id: id));
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // 실시간 변화 감지
  // ──────────────────────────────────────────────

  Future<void> startPhotoChangeNotify() async {
    await PhotoScanService.instance.startChangeNotify(
      onNewCouponsFound: loadCoupons,
    );
  }

  Future<void> stopPhotoChangeNotify() async {
    await PhotoScanService.instance.stopChangeNotify();
  }

  bool get isChangeNotifyActive => PhotoScanService.instance.isNotifying;
}
