import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification.dart';
import '../domain/notification_policy.dart';

part 'notification_providers.g.dart';

/// Where notifications go. The in-app inbox is real today; OS-level delivery
/// (flutter_local_notifications + POST_NOTIFICATIONS) is wired in the polish
/// phase — the POLICY is identical either way, which is the spec-critical
/// part.
abstract class NotificationService {
  Stream<List<AppNotification>> get inbox;
  Future<List<AppNotification>> deliver(AppNotification n);
  Future<List<AppNotification>> recent(NotificationKind kind, {int limit = 20});
}

class InAppNotificationService implements NotificationService {
  final _items = <AppNotification>[];
  final _controller = StreamController<List<AppNotification>>.broadcast();

  @override
  Stream<List<AppNotification>> get inbox async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<List<AppNotification>> deliver(AppNotification n) async {
    _items.insert(0, n);
    if (_items.length > 50) _items.removeLast();
    if (!_controller.isClosed) _controller.add(List.unmodifiable(_items));
    return List.unmodifiable(_items);
  }

  @override
  Future<List<AppNotification>> recent(
    NotificationKind kind, {
    int limit = 20,
  }) async => _items.where((i) => i.kind == kind).take(limit).toList();
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => InAppNotificationService();

@Riverpod(keepAlive: true)
class NotificationSettingsController extends _$NotificationSettingsController {
  static const _key = 'calisthenics.notifications.settings.v1';

  @override
  Future<NotificationSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return NotificationSettings.defaults;
    try {
      final names = (jsonDecode(raw) as List).cast<String>();
      return NotificationSettings({
        for (final n in names)
          if (NotificationKind.values.any((k) => k.name == n))
            NotificationKind.values.firstWhere((k) => k.name == n),
      });
    } catch (_) {
      return NotificationSettings.defaults;
    }
  }

  Future<void> set(NotificationKind kind, bool on) async {
    final next = state.value == null
        ? NotificationSettings.defaults.toggle(kind, on)
        : state.value!.toggle(kind, on);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final k in next.enabled) k.name]),
    );
  }
}

/// The single entry point every feature uses. Returns true when the
/// notification was actually delivered.
@Riverpod(keepAlive: true)
class Notifier extends _$Notifier {
  @override
  void build() {}

  Future<bool> send({
    required NotificationKind kind,
    required String title,
    required String body,
    DateTime? now,
  }) async {
    final settings = await ref.read(
      notificationSettingsControllerProvider.future,
    );
    final at = now ?? DateTime.now();
    final recentAll = await _recentAll();
    final allowed = NotificationPolicy.decide(
      kind: kind,
      title: title,
      now: at,
      settings: settings,
      recent: recentAll,
    );
    if (!allowed) return false;
    await ref
        .read(notificationServiceProvider)
        .deliver(AppNotification(kind: kind, title: title, body: body, at: at));
    return true;
  }

  Future<List<AppNotification>> _recentAll() async {
    final service = ref.read(notificationServiceProvider);
    final out = <AppNotification>[];
    for (final kind in NotificationKind.values) {
      out.addAll(await service.recent(kind, limit: 20));
    }
    return out;
  }
}
