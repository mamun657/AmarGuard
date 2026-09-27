import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/service_definition.dart';

class MaintenanceSheet {
  MaintenanceSheet._();

  static Future<void> show(
    BuildContext context, {
    required ServiceDefinition service,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _MaintenanceContent(
          service: service,
          theme: theme,
          title: l10n.maintenanceTitle,
          body: l10n.maintenanceBody(service.title(l10n)),
          preparing: l10n.maintenancePreparing,
          gotIt: l10n.maintenanceGotIt,
        );
      },
    );
  }
}

class _MaintenanceContent extends StatelessWidget {
  const _MaintenanceContent({
    required this.service,
    required this.theme,
    required this.title,
    required this.body,
    required this.preparing,
    required this.gotIt,
  });

  final ServiceDefinition service;
  final ThemeData theme;
  final String title;
  final String body;
  final String preparing;
  final String gotIt;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: media.viewInsets.bottom + 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: service.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: service.icon(size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: isBangla ? 18 : 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
                fontSize: isBangla ? 12.5 : 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preparing,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                fontSize: isBangla ? 11 : 12,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(gotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
