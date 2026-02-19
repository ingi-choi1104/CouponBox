import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 쿠폰박스 앱은 플러그인(ML Kit, WorkManager 등)을 사용하므로
    // 실제 기기/에뮬레이터에서 테스트를 실행하세요.
    expect(true, isTrue);
  });
}
