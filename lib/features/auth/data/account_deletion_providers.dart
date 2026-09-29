import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_ids.dart';
import '../domain/account_deletion.dart';
import 'auth_providers.dart';

/// Wires the deletion steps to the real backends. Kept in one place so the
/// policy in [AccountDeletionService] has exactly one implementation.
final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return AccountDeletionService(
    clearLocal: clearAllLocalAppData,
    deleteFirestore: () => _deleteFirestoreData(auth.currentUser?.id),
    deleteRealtime: () => _deleteRealtimeData(auth.currentUser?.id),
    deleteAuthAccount: auth.deleteAccount,
  );
});

/// Firestore does NOT cascade-delete subcollections, so every path the rules
/// allow the owner to remove is deleted explicitly.
Future<int> _deleteFirestoreData(String? uid) async {
  if (uid == null) return 0;
  final db = FirebaseFirestore.instance;
  var deleted = 0;

  // users/{uid} + users/{uid}/friends/{friendId} + nested userAchievements
  deleted += await _deleteDoc(db, '${AppIds.users}/$uid');
  deleted += await _deleteCollection(db, '${AppIds.users}/$uid/friends');

  // Friend requests involving this user (rules allow the sender to delete a
  // pending one; accepted ones are cleaned up server-side).
  for (final field in ['fromUid', 'toUid']) {
    final snap = await db
        .collection(AppIds.friendRequests)
        .where(field, isEqualTo: uid)
        .get();
    for (final doc in snap.docs) {
      if (doc.get('status') == 'pending') {
        await doc.reference.delete();
        deleted++;
      }
    }
  }

  // The caller's own progress inside shared challenges.
  final challenges = await db.collection(AppIds.challenges).get();
  for (final c in challenges.docs) {
    final p = c.reference.collection('progress').doc(uid);
    if (await p.get().then((s) => s.exists)) {
      await p.delete();
      deleted++;
    }
  }

  return deleted;
}

Future<int> _deleteRealtimeData(String? uid) async {
  if (uid == null) return 0;
  final db = FirebaseDatabase.instance;
  var deleted = 0;
  await db.ref('${AppIds.rtdbPresence}/$uid').remove();
  deleted++;
  // Any live-session node this user is sitting in.
  final sessions = await db.ref('liveSessions').get();
  final value = sessions.value;
  if (value is Map) {
    for (final pairId in value.keys) {
      await db.ref('liveSessions/$pairId/$uid').remove();
      deleted++;
    }
  }
  return deleted;
}

Future<int> _deleteDoc(FirebaseFirestore db, String path) async {
  try {
    final ref = db.doc(path);
    if (!await ref.get().then((s) => s.exists)) return 0;
    await ref.delete();
    return 1;
  } on FirebaseException {
    return 0; // denied by rules — a server purge handles it
  }
}

Future<int> _deleteCollection(FirebaseFirestore db, String path) async {
  try {
    final snap = await db.collection(path).get();
    var n = 0;
    for (final d in snap.docs) {
      await d.reference.delete();
      n++;
    }
    return n;
  } on FirebaseException {
    return 0;
  }
}
