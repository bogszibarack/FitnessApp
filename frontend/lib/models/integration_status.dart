class IntegrationStatus {
  const IntegrationStatus({
    required this.connected,
    this.lastSyncAt,
    this.lastError,
    this.detail,
  });

  final bool connected;
  final DateTime? lastSyncAt;
  final String? lastError;
  final String? detail;

  String? get lastSyncLabel {
    if (lastSyncAt == null) return null;
    final local = lastSyncAt!.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} $h:$m';
  }

  String subtitle(String fallback) {
    if (lastError != null && lastError!.isNotEmpty) {
      return 'Hiba: $lastError';
    }
    final parts = <String>[];
    if (detail != null && detail!.isNotEmpty) parts.add(detail!);
    if (lastSyncLabel != null) parts.add('Utolsó: $lastSyncLabel');
    if (parts.isNotEmpty) return parts.join(' · ');
    return fallback;
  }
}
