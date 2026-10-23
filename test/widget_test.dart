import 'package:flutter_test/flutter_test.dart';

import 'package:masar_al_lugha/l10n.dart';

void main() {
  test('localization falls back to Arabic', () {
    expect(L.t('ar', 'appName'), 'مسار اللغة');
    expect(L.t('en', 'appName'), 'Language Path');
    expect(L.t('xx', 'appName'), 'مسار اللغة');
  });
}
