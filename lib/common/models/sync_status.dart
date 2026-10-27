/// Whether what a screen shows is up to date with the server.
enum SyncStatus {
  /// Data comes from the server and every local change is saved there.
  synced,

  /// Online, but local changes are still on their way to the server.
  syncing,

  /// The data comes from the device cache: no connection. Changes are
  /// saved on the device and sent once the connection is back.
  offline;

  /// Status of several listeners together, from their snapshot metadata
  /// (`isFromCache`, `hasPendingWrites`). No listener yet means synced, so
  /// nothing is shown while loading.
  static SyncStatus combine(
      Iterable<({bool fromCache, bool pendingWrites})> listeners) {
    var syncing = false;
    for (final l in listeners) {
      if (l.fromCache) return SyncStatus.offline;
      if (l.pendingWrites) syncing = true;
    }
    return syncing ? SyncStatus.syncing : SyncStatus.synced;
  }
}
