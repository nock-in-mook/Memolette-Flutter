import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memolette/main.dart';

void main() {
  testWidgets('アプリ起動テスト', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MemolettApp()),
    );
    // Memolette タイトルが表示される
    expect(find.text('Memolette'), findsOneWidget);
  });
}
