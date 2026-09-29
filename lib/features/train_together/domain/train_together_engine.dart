import 'live_pair_state.dart';

/// Pure Train-Together logic (spec §22): synchronization rules, rest gating,
/// and the "don't strand anybody" grace period.
class TrainTogetherEngine {
  const TrainTogetherEngine._();

  /// How long a partner may be offline before the app stops waiting and
  /// offers to continue solo. Training together must NEVER trap someone.
  static const partnerGrace = Duration(seconds: 20);

  /// Stale nodes (client crashed without onDisconnect firing) count as
  /// offline after this long.
  static const staleAfter = Duration(minutes: 3);

  /// What phase should MY client display, given both published states.
  static LivePhase phaseForMe(LivePairState pair) {
    final me = pair.me;
    final partner = pair.partner;
    if (me == null) return LivePhase.working;
    if (me.phase == LivePhase.finished) return LivePhase.finished;
    if (partner == null || !pair.partnerOnline) {
      // Partner away: keep working, don't wait forever.
      return me.setComplete ? LivePhase.waiting : LivePhase.working;
    }
    if (me.setComplete && partner.setComplete) {
      if (me.exerciseName != partner.exerciseName) {
        // Diverged (one substituted): finish the set together anyway.
        return LivePhase.resting;
      }
      return me.phase == LivePhase.finished
          ? LivePhase.finished
          : LivePhase.resting;
    }
    return me.setComplete ? LivePhase.waiting : LivePhase.working;
  }

  /// Copy shown to the user — honest wording, no pressure, no shaming
  /// (spec §27: never shame).
  static String statusLine(LivePairState pair) {
    final partner = pair.partner;
    final phase = phaseForMe(pair);
    if (phase == LivePhase.finished) {
      return 'Both of you finished. Nice work. 💪';
    }
    if (partner == null || !pair.partnerOnline) {
      final lastSeen = partner?.updatedAt;
      final mins = lastSeen == null
          ? null
          : DateTime.now().toUtc().difference(lastSeen).inMinutes;
      return partner == null
          ? 'Waiting for your partner to join…'
          : 'Your partner is away${mins == null || mins < 1 ? '' : ' (last seen ${mins}m ago)'}. '
                'Keep going or wait here.';
    }
    return switch (phase) {
      LivePhase.resting => 'Both done — resting together.',
      LivePhase.waiting => 'Set complete — waiting for @${partner.handle}.',
      LivePhase.exerciseDone => 'Exercise done. Next one?',
      _ => 'Go. @${partner.handle} is on it too.',
    };
  }

  /// True when the UI should offer "continue without your partner".
  static bool shouldOfferSoloContinue(LivePairState pair) {
    final partner = pair.partner;
    if (partner == null || partner.online) return false;
    final seen = partner.updatedAt;
    if (seen == DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)) {
      return true;
    }
    return DateTime.now().toUtc().difference(seen) >= partnerGrace;
  }

  /// Node considered stale (crashed client) after [staleAfter].
  static bool isStale(LiveAthleteState? s, DateTime now) {
    if (s == null) return true;
    if (!s.online) return true;
    return now.toUtc().difference(s.updatedAt) > staleAfter;
  }

  /// Rest timer: identical on both phones, anchored to the first finished
  /// set so the countdown cannot drift apart.
  static ({int seconds, DateTime? startedAt}) restWindow({
    required LivePairState pair,
    required int restSeconds,
    required DateTime now,
  }) {
    if (pair.meSetComplete && pair.partnerSetComplete) {
      final started = pair.restStartedAt ?? now;
      return (seconds: restSeconds, startedAt: started);
    }
    return (seconds: restSeconds, startedAt: null);
  }

  /// Encouragement the pair can send — short, no audio, no camera.
  static const cheers = ['💪', '🔥', '👏', '🫡', '😅'];
}
