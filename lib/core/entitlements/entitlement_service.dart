/// What the current user may do. The payments milestone fills these in for
/// real; M6 allows everything.
class Entitlements {
  const Entitlements({
    this.isPro = true,
    this.hasGuideVideo = true,
    this.hasUnlimitedExports = true,
    this.hasAdvancedDetection = true,
  });

  final bool isPro;
  final bool hasGuideVideo;
  final bool hasUnlimitedExports;
  final bool hasAdvancedDetection;
}

/// Exports left in the current window, or unlimited.
class ExportQuota {
  const ExportQuota.unlimited() : remaining = null, limit = null;

  const ExportQuota.limited({required int this.remaining, required int this.limit});

  final int? remaining;
  final int? limit;

  bool get isUnlimited => limit == null;
}

/// The **one** place any code asks "is this allowed?". No other code checks
/// Pro status or counts exports.
abstract interface class EntitlementService {
  Stream<Entitlements> get changes;
  Future<Entitlements> current();

  /// Remaining this window, or unlimited.
  Future<ExportQuota> exportQuota();
  Future<bool> canExport();

  /// Call once per successful beat pack.
  Future<void> recordExport();
}

/// M6 stub: everything allowed, quota unlimited, nothing recorded.
class UnlimitedEntitlementService implements EntitlementService {
  const UnlimitedEntitlementService();

  @override
  Stream<Entitlements> get changes => const Stream<Entitlements>.empty();

  @override
  Future<Entitlements> current() async => const Entitlements();

  @override
  Future<ExportQuota> exportQuota() async => const ExportQuota.unlimited();

  @override
  Future<bool> canExport() async => true;

  @override
  Future<void> recordExport() async {}
}
