import 'package:flutter_test/flutter_test.dart';
import 'package:language_app/main.dart';

void main() {
  testWidgets('renders the login experience for a signed-out user',
      (tester) async {
    await tester.pumpWidget(const LanguageApp());
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
