import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../models/coupon.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showNewCouponsNotification(int count) async {
    await _plugin.show(
      1,
      '새 쿠폰 발견!',
      '갤러리에서 쿠폰 $count개를 새로 찾았어요. 지금 확인해보세요.',
      _buildDetails(
        channelId: 'new_coupons',
        channelName: '새 쿠폰 알림',
        channelDesc: '갤러리에서 새 쿠폰을 발견했을 때 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  Future<void> showExpiringSoonNotification(List<Coupon> coupons) async {
    final dateFormat = DateFormat('M월 d일');
    String body;
    if (coupons.length == 1) {
      final coupon = coupons.first;
      final name = coupon.storeName ?? coupon.itemName ?? '쿠폰';
      final days = coupon.daysUntilExpiry;
      body = days <= 0
          ? '$name이(가) 오늘 만료돼요!'
          : '$name이(가) ${dateFormat.format(coupon.expiryDate!)}에 만료돼요! (D-$days)';
    } else {
      body = '만료 임박 쿠폰이 ${coupons.length}개 있어요. 지금 확인하세요!';
    }

    await _plugin.show(
      2,
      '쿠폰 만료 임박!',
      body,
      _buildDetails(
        channelId: 'expiring_coupons',
        channelName: '만료 임박 쿠폰',
        channelDesc: '쿠폰 만료가 임박했을 때 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  NotificationDetails _buildDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    required Importance importance,
    required Priority priority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: importance,
        priority: priority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
