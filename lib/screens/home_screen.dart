import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/coupon.dart';
import '../providers/coupon_provider.dart';
import '../services/barcode_scan_service.dart';
import '../services/database_service.dart';
import '../services/photo_scan_service.dart';
import '../widgets/coupon_card.dart';
import 'coupon_detail_screen.dart';
import 'settings_screen.dart';

const _bannerAdUnitId = 'ca-app-pub-6235846592723695/7122381191';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _imagePicker = ImagePicker();

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<CouponProvider>();
      await provider.loadCoupons();
      // 실시간 갤러리 변화 감지 시작
      await provider.startPhotoChangeNotify();
    });
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerAdReady = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerAd?.dispose();
    // 화면이 사라질 때 변화 감지 중지
    PhotoScanService.instance.stopChangeNotify();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.local_offer,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '쿠폰박스',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<CouponProvider>(
            builder: (_, provider, __) => provider.isScanning
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF4F46E5)),
                    tooltip: '갤러리 스캔',
                    onPressed: _scanGallery,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF6B7280)),
            tooltip: '설정',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '사용 가능'),
            Tab(text: '사용 완료'),
            Tab(text: '만료됨'),
          ],
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Color(0xFF9CA3AF),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      body: Consumer<CouponProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(provider.error!),
                  TextButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadCoupons();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildActiveList(provider),
              _buildUsedList(provider),
              _buildExpiredList(provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScanOptions,
        icon: const Icon(Icons.add),
        label: const Text(
          '쿠폰 추가',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomNavigationBar: _isBannerAdReady && _bannerAd != null
          ? Container(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildActiveList(CouponProvider provider) {
    final coupons = provider.activeCoupons;

    return RefreshIndicator(
      onRefresh: provider.loadCoupons,
      color: const Color(0xFF4F46E5),
      child: coupons.isEmpty
          ? _buildEmptyState(
              icon: Icons.local_offer_outlined,
              message: '사용 가능한 쿠폰이 없어요',
              hint: '+ 버튼을 눌러 쿠폰을 추가해보세요',
            )
          : CustomScrollView(
              slivers: [
                // 만료 임박 배너
                if (provider.expiringSoon.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildExpiringSoonBanner(provider.expiringSoon.length),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => CouponCard(
                        coupon: coupons[index],
                        onTap: () => _openDetail(coupons[index]),
                        onMarkUsed: () => _markAsUsed(coupons[index]),
                        onDelete: () => _deleteCoupon(coupons[index]),
                      ),
                      childCount: coupons.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUsedList(CouponProvider provider) {
    final coupons = provider.usedCoupons;
    return RefreshIndicator(
      onRefresh: provider.loadCoupons,
      color: const Color(0xFF4F46E5),
      child: coupons.isEmpty
          ? _buildEmptyState(
              icon: Icons.check_circle_outline,
              message: '사용 완료된 쿠폰이 없어요',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              itemBuilder: (_, i) => CouponCard(
                coupon: coupons[i],
                onTap: () => _openDetail(coupons[i]),
                onMarkActive: () => _markAsActive(coupons[i]),
                onDelete: () => _deleteCoupon(coupons[i]),
              ),
            ),
    );
  }

  Widget _buildExpiredList(CouponProvider provider) {
    final coupons = provider.expiredCoupons;
    return RefreshIndicator(
      onRefresh: provider.loadCoupons,
      color: const Color(0xFF4F46E5),
      child: coupons.isEmpty
          ? _buildEmptyState(
              icon: Icons.event_busy_outlined,
              message: '만료된 쿠폰이 없어요',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              itemBuilder: (_, i) => CouponCard(
                coupon: coupons[i],
                onTap: () => _openDetail(coupons[i]),
                onDelete: () => _deleteCoupon(coupons[i]),
              ),
            ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? hint,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSoonBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '만료 임박 쿠폰이 $count개 있어요! 기한 내 사용하세요.',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _bottomSheetItem(
                context: ctx,
                icon: Icons.photo_library_outlined,
                title: '갤러리에서 선택',
                subtitle: '사진에서 바코드를 인식해요',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              _bottomSheetItem(
                context: ctx,
                icon: Icons.camera_alt_outlined,
                title: '카메라로 촬영',
                subtitle: '직접 촬영해서 바코드를 인식해요',
                onTap: () {
                  Navigator.pop(ctx);
                  _scanWithCamera();
                },
              ),
              _bottomSheetItem(
                context: ctx,
                icon: Icons.image_search_outlined,
                title: '갤러리 자동 스캔',
                subtitle: '새로 추가된 사진에서 쿠폰을 찾아요',
                onTap: () {
                  Navigator.pop(ctx);
                  _scanGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomSheetItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF4F46E5)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      onTap: onTap,
    );
  }

  Future<void> _scanGallery() async {
    final provider = context.read<CouponProvider>();
    if (provider.isScanning) return;

    final count = await provider.scanGallery();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0 ? '쿠폰 $count개를 새로 찾았어요!' : '새로운 쿠폰을 찾지 못했어요.',
          ),
          backgroundColor:
              count > 0 ? const Color(0xFF10B981) : const Color(0xFF6B7280),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await _processImage(image.path);
  }

  Future<void> _scanWithCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null || !mounted) return;
    await _processImage(image.path);
  }

  Future<void> _processImage(String imagePath) async {
    if (!mounted) return;

    // 스캔 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF4F46E5)),
              SizedBox(width: 20),
              Text('바코드 인식 중...'),
            ],
          ),
        ),
      ),
    );

    final result = await BarcodeScanService.instance.scanImage(imagePath);

    if (!mounted) return;
    Navigator.pop(context); // 다이얼로그 닫기

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('바코드를 찾을 수 없었어요. 더 선명한 사진을 사용해보세요.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // 중복 체크
    final existing = await DatabaseService.instance
        .getCouponByBarcodeValue(result.barcodeValue);
    if (existing != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 등록된 쿠폰이에요.')),
      );
      _openDetail(existing);
      return;
    }

    // 이미지 저장
    final savedPath = await PhotoScanService.instance.saveImageToAppDir(
      File(imagePath),
      result.barcodeValue,
    );

    final coupon = Coupon(
      barcodeValue: result.barcodeValue,
      barcodeType: result.barcodeType,
      storeName: result.storeName,
      itemName: result.itemName,
      amount: result.amount,
      expiryDate: result.expiryDate,
      imagePath: savedPath,
      status: CouponStatus.active,
      addedAt: DateTime.now(),
    );

    if (mounted) {
      final provider = context.read<CouponProvider>();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CouponDetailScreen(coupon: coupon, isNew: true),
        ),
      ).then((_) => provider.loadCoupons());
    }
  }

  void _openDetail(Coupon coupon) {
    final provider = context.read<CouponProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CouponDetailScreen(coupon: coupon)),
    ).then((_) => provider.loadCoupons());
  }

  Future<void> _markAsUsed(Coupon coupon) async {
    await context.read<CouponProvider>().markAsUsed(coupon);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용 완료로 표시했어요.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _markAsActive(Coupon coupon) async {
    await context.read<CouponProvider>().markAsActive(coupon);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용 가능으로 복원했어요.')),
      );
    }
  }

  Future<void> _deleteCoupon(Coupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('쿠폰 삭제'),
        content: const Text('이 쿠폰을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<CouponProvider>().deleteCoupon(coupon);
    }
  }
}
