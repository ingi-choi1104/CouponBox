import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'barcode_scan_service.dart';
import 'database_service.dart';
import 'notification_service.dart';
import '../models/coupon.dart';

class PhotoScanService {
  static final PhotoScanService instance = PhotoScanService._();
  PhotoScanService._();

  static const _lastScanKey = 'last_scan_timestamp';
  static const _installTimeKey = 'app_install_timestamp';

  // 변화 감지 상태
  bool _isNotifying = false;
  bool _scanPending = false;
  VoidCallback? _onNewCouponsFound;

  // ──────────────────────────────────────────────
  // 설치 시간 관리
  // ──────────────────────────────────────────────

  /// 앱 최초 실행 시 설치 시간을 기록합니다. (이미 기록된 경우 무시)
  Future<void> setInstallTimeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_installTimeKey)) {
      await prefs.setInt(
        _installTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  // ──────────────────────────────────────────────
  // 갤러리 스캔
  // ──────────────────────────────────────────────

  /// 갤러리에서 새 사진을 스캔하여 바코드가 있는 쿠폰을 찾습니다.
  /// 반환값: 새로 추가된 쿠폰 수
  Future<int> scanNewPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScanTs = prefs.getInt(_lastScanKey) ?? 0;
    final installTs =
        prefs.getInt(_installTimeKey) ?? DateTime.now().millisecondsSinceEpoch;

    // 마지막 스캔 시간이 없으면 앱 설치 시간 이후 사진만 검색
    final lastScan = lastScanTs == 0
        ? DateTime.fromMillisecondsSinceEpoch(installTs)
        : DateTime.fromMillisecondsSinceEpoch(lastScanTs);

    final filterOption = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      updateTimeCond: DateTimeCond(
        min: lastScan,
        max: DateTime.now().add(const Duration(minutes: 1)),
      ),
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: filterOption,
    );

    int newCouponsFound = 0;

    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;

      final assets = await album.getAssetListRange(
        start: 0,
        end: count.clamp(0, 200),
      );

      for (final asset in assets) {
        final existingByAsset =
            await DatabaseService.instance.getCouponByAssetId(asset.id);
        if (existingByAsset != null) continue;

        final file = await asset.originFile;
        if (file == null) continue;

        final scanResult =
            await BarcodeScanService.instance.scanImage(file.path);
        if (scanResult == null) continue;

        final existingByBarcode = await DatabaseService.instance
            .getCouponByBarcodeValue(scanResult.barcodeValue);
        if (existingByBarcode != null) continue;

        final savedPath =
            await saveImageToAppDir(file, scanResult.barcodeValue);

        final coupon = Coupon(
          barcodeValue: scanResult.barcodeValue,
          barcodeType: scanResult.barcodeType,
          storeName: scanResult.storeName,
          itemName: scanResult.itemName,
          amount: scanResult.amount,
          expiryDate: scanResult.expiryDate,
          imagePath: savedPath,
          status: CouponStatus.active,
          addedAt: asset.createDateTime,
          assetId: asset.id,
        );

        await DatabaseService.instance.insertCoupon(coupon);
        newCouponsFound++;
      }
    }

    await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
    await DatabaseService.instance.markExpiredCoupons();

    return newCouponsFound;
  }

  /// 이미지 파일을 앱 전용 저장소로 복사합니다.
  Future<String> saveImageToAppDir(File file, String barcodeValue) async {
    final appDir = await getApplicationDocumentsDirectory();
    final couponsDir = Directory(p.join(appDir.path, 'coupons'));
    if (!await couponsDir.exists()) {
      await couponsDir.create(recursive: true);
    }

    final ext =
        p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
    final safeName = barcodeValue
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .substring(0, barcodeValue.length.clamp(0, 30));
    final fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(couponsDir.path, fileName);

    await file.copy(destPath);
    return destPath;
  }

  // ──────────────────────────────────────────────
  // 실시간 변화 감지
  // ──────────────────────────────────────────────

  /// 갤러리 변화 감지를 시작합니다.
  /// [onNewCouponsFound]: 새 쿠폰이 발견됐을 때 호출될 콜백
  Future<void> startChangeNotify({required VoidCallback onNewCouponsFound}) async {
    if (_isNotifying) return;
    _onNewCouponsFound = onNewCouponsFound;
    PhotoManager.addChangeCallback(_handleMediaChange);
    await PhotoManager.startChangeNotify();
    _isNotifying = true;
  }

  /// 갤러리 변화 감지를 중지합니다.
  Future<void> stopChangeNotify() async {
    if (!_isNotifying) return;
    PhotoManager.removeChangeCallback(_handleMediaChange);
    await PhotoManager.stopChangeNotify();
    _isNotifying = false;
    _onNewCouponsFound = null;
  }

  bool get isNotifying => _isNotifying;

  /// photo_manager가 미디어 변화를 감지하면 호출됩니다.
  void _handleMediaChange(MethodCall call) {
    // 이미 스캔 대기 중이면 무시 (짧은 시간 내 여러 변화 배치 처리)
    if (_scanPending) return;
    _scanPending = true;

    // 2초 후 스캔 — 사진 저장이 완전히 끝난 뒤 실행
    Future.delayed(const Duration(seconds: 2), _runChangeTriggeredScan);
  }

  Future<void> _runChangeTriggeredScan() async {
    _scanPending = false;
    try {
      final count = await scanNewPhotos();
      if (count > 0) {
        await NotificationService.instance.showNewCouponsNotification(count);
        _onNewCouponsFound?.call();
      }
    } catch (_) {
      // 변화 감지 스캔 중 오류는 무시
    }
  }

  // ──────────────────────────────────────────────
  // 유틸
  // ──────────────────────────────────────────────

  /// 마지막 스캔 시간 초기화 (전체 다시 스캔용)
  Future<void> resetLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastScanKey);
  }

  /// 마지막 스캔 시간 반환
  Future<DateTime?> getLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastScanKey);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }
}
