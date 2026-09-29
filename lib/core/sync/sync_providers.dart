import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_providers.dart';
import '../services/backend_status.dart';
import 'offline_write_queue.dart';
import 'sync_status.dart';

part 'sync_providers.g.dart';

/// Where a queued write actually goes. Every send is an idempotent
/// `set(..., merge: true)` on a STABLE document id, so retrying a write that
/// already landed can never create a duplicate (spec §31).
abstract class SyncSink {
  Future<void> send(PendingWrite write);
}

class FirestoreSyncSink implements SyncSink {
  FirestoreSyncSink(this._db);
  final FirebaseFirestore _db;

  @override
  Future<void> send(PendingWrite write) async {
    await _db
        .collection(write.collection)
        .doc(write.id)
        .set(write.payload, SetOptions(merge: true));
  }
}

/// No backend configured: the feature already stored its data locally, so
/// mirroring is a no-op — NOT a failure, and nothing is lost.
class LocalOnlySink implements SyncSink {
  const LocalOnlySink();

  @override
  Future<void> send(PendingWrite _) async {}
}

@Riverpod(keepAlive: true)
SyncSink syncSink(Ref ref) {
  final status = ref.watch(backendStatusProvider);
  return switch (status) {
    BackendStatus.available ||
    BackendStatus.emulator => FirestoreSyncSink(FirebaseFirestore.instance),
    BackendStatus.unavailable => const LocalOnlySink(),
  };
}

/// Connectivity seam — tests inject a fake, the app uses connectivity_plus.
abstract class ConnectivityMonitor {
  Stream<bool> get online;
  bool get isOnline;
}

class RealConnectivityMonitor implements ConnectivityMonitor {
  RealConnectivityMonitor(this._plugin);
  final Connectivity _plugin;
  bool _online = true;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get online => _plugin.onConnectivityChanged.map((results) {
    _online = results.any((r) => r != ConnectivityResult.none);
    return _online;
  });
}

/// Test double: flip online/offline and assert the queue reacts.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get online => _controller.stream;

  void set(bool value) {
    _isOnline = value;
    _controller.add(value);
  }
}

@Riverpod(keepAlive: true)
ConnectivityMonitor connectivityMonitor(Ref ref) =>
    RealConnectivityMonitor(Connectivity());

@Riverpod(keepAlive: true)
OfflineWriteQueue offlineWriteQueue(Ref ref) {
  final queue = OfflineWriteQueue();
  // Fire and forget: loading the outbox must never block the UI.
  unawaited(queue.load());
  return queue;
}

@Riverpod(keepAlive: true)
Stream<SyncStatus> syncStatus(Ref ref) {
  final queue = ref.watch(offlineWriteQueueProvider);
  final monitor = ref.watch(connectivityMonitorProvider);

  return Stream<SyncStatus>.multi((c) {
    final sink = ref.read(syncSinkProvider);
    var lastSyncedAt = DateTime.now().toUtc();
    String? lastError;
    var flushing = false;

    void emit() {
      final pending = queue.pendingCount;
      final failed = queue.failedCount;
      c.add(
        SyncStatus(
          phase: failed > 0
              ? SyncPhase.failed
              : pending > 0
              ? SyncPhase.pending
              : SyncPhase.synced,
          pendingCount: pending,
          failedCount: failed,
          lastSyncedAt: lastSyncedAt,
          lastError: lastError,
        ),
      );
    }

    Future<void> flush() async {
      if (flushing || !monitor.isOnline) return;
      flushing = true;
      try {
        final sent = await queue.flush(sink.send);
        if (sent > 0) {
          lastSyncedAt = DateTime.now().toUtc();
          lastError = null;
        }
      } catch (e) {
        lastError = e.toString();
      } finally {
        flushing = false;
        emit();
      }
    }

    emit();
    final subQueue = queue.changes.listen((_) => emit());
    final subNet = monitor.online.listen((isUp) {
      if (isUp) {
        unawaited(flush());
      } else {
        emit();
      }
    });
    c.onCancel = () async {
      await subQueue.cancel();
      await subNet.cancel();
    };
  });
}
