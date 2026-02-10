// Smoke test — verifies the test infrastructure works.
// The real tests are organized under test/unit/ and test/widget/.

import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

void main() {
  test('Smoke test - AppTheme is accessible', () {
    expect(AppTheme.primaryIndigo, isNotNull);
    expect(AppTheme.lightTheme, isNotNull);
  });
}
