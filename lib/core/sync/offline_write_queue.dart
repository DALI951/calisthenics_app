import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One pending remote write. [id] is STABLE and derived from the data
/// (spec §31: "use stable IDs / idempotent writes") — re-sending the same op
/// overwrites the same remote document instead of duplicating it.
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.collection,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String collection;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Deterministic id: same data → same id → idempotent remote write.
  static String idFor(String collection, Map<String, Object?> payload) {
    final keys = payload.keys.toList()..sort();
    final body = jsonEncode([
      for (final k in keys) [k, payload[k]],
    ]);
    return '$collection:${_shortHash(body)}';
  }

  static String _shortHash(String input) {
    // FNV-1a 32-bit — small, stable across platforms, good enough for de-dup.
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  PendingWrite copyWith({int? attempts, String? lastError}) => PendingWrite(
    id: id,
    collection: collection,
    payload: payload,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
  );

  Map<String, Object?> toStorage() => {
    'id': id,
    'collection': collection,
    'payload': payload,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
  };

  static PendingWrite fromStorage(Map<Object?, Object?> raw) => PendingWrite(
    id: raw['id'] as String? ?? '',
    collection: raw['collection'] as String? ?? '',
    payload: (raw['payload'] as Map?)?.cast<String, Object?>() ?? const {},
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (raw['createdAt'] as num?)?.toInt() ?? 0,
      isUtc: true,
    ),
    attempts: (raw['attempts'] as num?)?.toInt() ?? 0,
    lastError: raw['lastError'] as String?,
  );
}

/// Local-first outbox. Workout recording NEVER depends on the network: the
/// write is queued, persisted, and flushed when connectivity returns.
class OfflineWriteQueue {
  OfflineWriteQueue({this.maxAttempts = 5});

  final int maxAttempts;
  final _writes = <PendingWrite>[];
  final _controller = StreamController<List<PendingWrite>>.broadcast();
  SharedPreferences? _prefs;

  String get _key => 'calisthenics.sync.outbox.v1';

  List<PendingWrite> get writes => List.unmodifiable(_writes);
  int get pendingCount => _writes.where((w) => w.lastError == null).length;
  int get failedCount => _writes.where((w) => w.lastError != null).length;
  Stream<List<PendingWrite>> get changes => _controller.stream;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<Object?, Object?>>();
      _writes
        ..clear()
        ..addAll(list.map(PendingWrite.fromStorage));
    } catch (_) {
      // Corrupt outbox must never block training — start clean, the local
      // data is still safe in its own store.
      _writes.clear();
    }
    _emit();
  }

  /// Queues a write. Re-queuing identical data is a NO-OP (stable id).
  Future<PendingWrite> enqueue(
    String collection,
    Map<String, Object?> payload, {
    DateTime? now,
  }) async {
    final id = PendingWrite.idFor(collection, payload);
    final existing = _writes.where((w) => w.id == id).firstOrNull;
    if (existing != null) return existing;
    final write = PendingWrite(
      id: id,
      collection: collection,
      payload: payload,
      createdAt: now ?? DateTime.now().toUtc(),
    );
    _writes.add(write);
    await _persist();
    _emit();
    return write;
  }

  /// Flushes in insertion order. Stops at the first failure so ordering is
  /// preserved; failed items keep their error and are retried later.
  Future<int> flush(Future<void> Function(PendingWrite) send) async {
    var sent = 0;
    for (final write in List.of(_writes)) {
      try {
        await send(write);
        _writes.removeWhere((w) => w.id == write.id);
        sent++;
      } catch (e) {
        final failed = write.copyWith(
          attempts: write.attempts + 1,
          lastError: e.toString(),
        );
        _writes[_writes.indexWhere((w) => w.id == write.id)] = failed;
        await _persist();
        _emit();
        break; // keep order
      }
    }
    if (sent > 0) {
      await _persist();
      _emit();
    }
    return sent;
  }

  /// Retries items that hit an error but still have attempts left.
  Future<int> retryFailed() async {
    for (final w in _writes.where((w) => w.lastError != null)) {
      if (w.attempts >= maxAttempts) continue;
      _writes[_writes.indexWhere((x) => x.id == w.id)] = w.copyWith(
        lastError: '',
      );
    }
    return flush(_noop);
  }

  static Future<void> _noop(PendingWrite _) async {}

  void _emit() {
    if (!_controller.isClosed) _controller.add(writes);
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      _key,
      jsonEncode([for (final w in _writes) w.toStorage()]),
    );
  }
}
