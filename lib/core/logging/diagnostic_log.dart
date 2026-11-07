import '../data/zelo_repository.dart';

class DiagnosticLog {
  DiagnosticLog(this.repository);
  final ZeloRepository repository;
  Future<void> record(String code) async {
    if (!const {
      'NATIVE_UNCONFIRMED',
      'MONITORING_STARTED',
      'MONITORING_STOPPED',
      'SYNC_UNAVAILABLE',
      'NATIVE_RECOVERED',
    }.contains(code)) {
      return;
    }
    await repository.store.db.transaction((tx) async {
      await tx.insert('diagnostics', {
        'user_id': repository.uid,
        'code': code,
        'created_at': repository.now,
      });
      await tx.delete(
        'diagnostics',
        where: 'user_id=? AND created_at<?',
        whereArgs: [repository.uid, repository.now - 7 * 24 * 60 * 60 * 1000],
      );
      await tx.rawDelete(
        'DELETE FROM diagnostics WHERE user_id=? AND rowid NOT IN (SELECT rowid FROM diagnostics WHERE user_id=? ORDER BY created_at DESC LIMIT 200)',
        [repository.uid, repository.uid],
      );
    });
  }
}
