import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'providers/coupon_provider.dart';
import 'services/notification_service.dart';
import 'services/photo_scan_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AdMob 초기화
  await MobileAds.instance.initialize();

  // 알림 서비스 초기화
  await NotificationService.instance.initialize();

  // 최초 실행 시 앱 설치 시간 기록
  await PhotoScanService.instance.setInstallTimeIfNeeded();

  runApp(const CouponBoxApp());
}

class CouponBoxApp extends StatelessWidget {
  const CouponBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CouponProvider()),
      ],
      child: MaterialApp(
        title: '쿠폰박스',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F46E5),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ko', 'KR'),
        home: const _PermissionGate(),
      ),
    );
  }
}

/// 앱 시작 시 권한 요청 → 누락 사진 스캔 → 실시간 감지 시작 → 홈 화면
class _PermissionGate extends StatefulWidget {
  const _PermissionGate();

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 갤러리 접근 권한
    await PhotoManager.requestPermissionExtend();

    // 알림 권한
    await NotificationService.instance.requestPermission();

    // 앱이 닫혀있는 동안 추가된 사진 스캔 (누락분 보정)
    await PhotoScanService.instance.scanNewPhotos();

    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF4F46E5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_offer, size: 72, color: Colors.white),
              SizedBox(height: 16),
              Text(
                '쿠폰박스',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '쿠폰을 자동으로 관리해드려요',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(color: Colors.white54),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
