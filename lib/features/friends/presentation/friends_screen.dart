import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';

/// Friends tab (spec §20 + §21). Friend system + live training presence
/// land in Phase 6–7; this is the designed empty state.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ShellAppBar(title: 'Friends'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppEmptyState(
          title: 'No friends yet',
          message:
              'Add one training partner by username and you\'ll see their '
              'live training activity here.',
          icon: Icons.people_outline,
        ),
      ),
    );
  }
}
