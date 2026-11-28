import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/settings_providers.dart';

/// Sync status: synced (sage), waiting to sync (amber) or offline (amber).
/// The colour is always paired with an icon and a label.
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final (IconData icon, Color fg, Color bg, String title) = switch (s.phase) {
      SyncPhase.synced => (
        Icons.cloud_done_outlined,
        AppColors.collected,
        AppColors.collectedTint,
        'All changes synced',
      ),
      SyncPhase.pending => (
        Icons.cloud_upload_outlined,
        AppColors.upcoming,
        AppColors.upcomingTint,
        'Changes waiting to sync',
      ),
      SyncPhase.offline => (
        Icons.cloud_off_outlined,
        AppColors.upcoming,
        AppColors.upcomingTint,
        'Offline · changes will sync',
      ),
    };
    final last = s.lastSyncedAt;
    return AppCard(
      key: const ValueKey<String>('settings_sync'),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Row(
          children: <Widget>[
            Container(
              width: AppSizes.avatarMd,
              height: AppSizes.avatarMd,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: AppSizes.iconMd),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    key: ValueKey<String>('sync_${s.phase.name}'),
                    style: AppTextStyles.titleMd,
                  ),
                  Text(
                    last == null || s.phase != SyncPhase.synced
                        ? 'Works offline · syncs automatically'
                        : 'Last synced at ${_hhmm(last)}',
                    style: AppTextStyles.bodyMdTabular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}
