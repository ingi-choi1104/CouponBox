import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/coupon_provider.dart';
import '../services/photo_scan_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _notifyDaysBefore = 7;
  DateTime? _lastScanTime;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScan = await PhotoScanService.instance.getLastScanTime();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notifyDaysBefore = prefs.getInt('notify_days_before') ?? 7;
      _lastScanTime = lastScan;
      _isLoading = false;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('notify_days_before', _notifyDaysBefore);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('갤러리 스캔'),
                _buildScanSection(),
                _buildSectionHeader('알림'),
                _buildNotificationSection(),
                _buildSectionHeader('데이터'),
                _buildDataSection(),
                _buildSectionHeader('앱 정보'),
                _buildAboutSection(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildScanSection() {
    final lastScanStr = _lastScanTime != null
        ? DateFormat('M월 d일 HH:mm').format(_lastScanTime!)
        : '아직 스캔하지 않았어요';

    final isNotifying = context.read<CouponProvider>().isChangeNotifyActive;

    return _buildCard([
      ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isNotifying
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isNotifying ? Icons.sensors : Icons.sensors_off,
            size: 20,
            color: isNotifying
                ? const Color(0xFF10B981)
                : Colors.grey,
          ),
        ),
        title: const Text('실시간 감지'),
        subtitle: Text(
          isNotifying ? '새 사진이 추가되면 즉시 쿠폰을 인식해요' : '앱을 열면 자동으로 시작돼요',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isNotifying
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isNotifying ? '작동 중' : '대기',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isNotifying ? const Color(0xFF10B981) : Colors.grey,
            ),
          ),
        ),
      ),
      _buildDivider(),
      ListTile(
        title: const Text('마지막 스캔'),
        subtitle: Text(lastScanStr),
        leading: const Icon(Icons.history, color: Color(0xFF4F46E5)),
      ),
      _buildDivider(),
      ListTile(
        title: const Text('지금 스캔하기'),
        subtitle: const Text('갤러리에서 새 쿠폰 검색'),
        leading: const Icon(Icons.search, color: Color(0xFF4F46E5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _runManualScan,
      ),
      _buildDivider(),
      ListTile(
        title: const Text('전체 다시 스캔'),
        subtitle: const Text('설치 이후 사진 전체 재스캔'),
        leading: const Icon(Icons.refresh, color: Color(0xFF4F46E5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _runFullRescan,
      ),
    ]);
  }

  Widget _buildNotificationSection() {
    return _buildCard([
      SwitchListTile(
        title: const Text('만료 임박 알림'),
        subtitle: const Text('쿠폰 만료 전 알림 받기'),
        secondary: const Icon(
          Icons.notifications_outlined,
          color: Color(0xFF4F46E5),
        ),
        value: _notificationsEnabled,
        activeThumbColor: const Color(0xFF4F46E5),
        activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
        onChanged: (val) async {
          setState(() => _notificationsEnabled = val);
          if (val) {
            await NotificationService.instance.requestPermission();
          }
          await _saveNotificationSettings();
        },
      ),
      if (_notificationsEnabled) ...[
        _buildDivider(),
        ListTile(
          title: const Text('만료 며칠 전 알림'),
          subtitle: Text('만료 $_notifyDaysBefore일 전'),
          leading: const Icon(Icons.event_outlined, color: Color(0xFF4F46E5)),
          trailing: DropdownButton<int>(
            value: _notifyDaysBefore,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1일 전')),
              DropdownMenuItem(value: 3, child: Text('3일 전')),
              DropdownMenuItem(value: 7, child: Text('7일 전')),
              DropdownMenuItem(value: 14, child: Text('14일 전')),
              DropdownMenuItem(value: 30, child: Text('30일 전')),
            ],
            onChanged: (val) async {
              if (val == null) return;
              setState(() => _notifyDaysBefore = val);
              await _saveNotificationSettings();
            },
          ),
        ),
      ],
    ]);
  }

  Widget _buildDataSection() {
    return _buildCard([
      ListTile(
        title: const Text('통계 보기'),
        leading: const Icon(Icons.bar_chart, color: Color(0xFF4F46E5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showStatistics,
      ),
    ]);
  }

  Widget _buildAboutSection() {
    return _buildCard([
      const ListTile(
        title: Text('앱 이름'),
        subtitle: Text('쿠폰박스'),
        leading: Icon(Icons.local_offer, color: Color(0xFF4F46E5)),
      ),
      _buildDivider(),
      const ListTile(
        title: Text('버전'),
        subtitle: Text('1.0.0'),
        leading: Icon(Icons.info_outline, color: Color(0xFF4F46E5)),
      ),
    ]);
  }

  Widget _buildCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 16, color: Colors.grey[100]);
  }

  Future<void> _runManualScan() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('갤러리 스캔 중...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final count = await context.read<CouponProvider>().scanGallery();
    final lastScan = await PhotoScanService.instance.getLastScanTime();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0 ? '쿠폰 $count개를 새로 찾았어요!' : '새로운 쿠폰을 찾지 못했어요.',
          ),
        ),
      );
      setState(() => _lastScanTime = lastScan);
    }
  }

  Future<void> _runFullRescan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 재스캔'),
        content: const Text('설치 이후의 사진을 전체 다시 스캔할까요?\n시간이 조금 걸릴 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await PhotoScanService.instance.resetLastScanTime();
    await _runManualScan();
  }

  Future<void> _showStatistics() async {
    final provider = context.read<CouponProvider>();
    await provider.loadCoupons();

    if (!mounted) return;

    final stats = {
      'active': provider.activeCoupons.length,
      'used': provider.usedCoupons.length,
      'expired': provider.expiredCoupons.length,
      'expiringSoon': provider.expiringSoon.length,
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('쿠폰 통계'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow('사용 가능', stats['active'] ?? 0, const Color(0xFF10B981)),
            _statRow(
              '만료 임박',
              stats['expiringSoon'] ?? 0,
              const Color(0xFFF59E0B),
            ),
            _statRow('사용 완료', stats['used'] ?? 0, Colors.grey),
            _statRow('만료됨', stats['expired'] ?? 0, const Color(0xFFEF4444)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(
            '$count개',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
