import 'package:flutter_test/flutter_test.dart';
import 'package:dayweave_mobile/app.dart';
import 'package:dayweave_mobile/core/config/app_config.dart';

void main() {
  testWidgets('shows configuration guidance when Supabase is not configured', (tester) async {
    await tester.pumpWidget(buildDayweaveApp(const AppConfig(supabaseUrl: '', supabasePublishableKey: '')));
    expect(find.text('Connect Dayweave'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
