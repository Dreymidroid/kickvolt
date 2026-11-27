import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/entitlements/entitlement_service.dart';

void main() {
  group('UnlimitedEntitlementService (M6 stub)', () {
    const service = UnlimitedEntitlementService();

    test('current returns all entitlements enabled', () async {
      final ent = await service.current();
      expect(ent.isPro, isTrue);
      expect(ent.hasGuideVideo, isTrue);
      expect(ent.hasUnlimitedExports, isTrue);
      expect(ent.hasAdvancedDetection, isTrue);
    });

    test('exportQuota is unlimited', () async {
      final quota = await service.exportQuota();
      expect(quota.isUnlimited, isTrue);
      expect(quota.limit, isNull);
      expect(quota.remaining, isNull);
    });

    test('canExport is true and recordExport is a harmless no-op', () async {
      expect(await service.canExport(), isTrue);
      await service.recordExport();
      expect(await service.canExport(), isTrue);
    });

    test('changes stream completes cleanly without errors', () async {
      expect(await service.changes.toList(), isEmpty);
    });
  });

  group('ExportQuota.limited', () {
    test('stores remaining and limit and reports isUnlimited == false', () {
      const quota = ExportQuota.limited(remaining: 29, limit: 30);
      expect(quota.isUnlimited, isFalse);
      expect(quota.remaining, 29);
      expect(quota.limit, 30);
    });
  });
}
