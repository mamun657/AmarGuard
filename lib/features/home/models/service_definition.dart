import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/service_icons.dart';

enum ServiceKey {
  analyzeCall,
  checkMessage,
  checkLink,
  scanScreenshot,
  analyzeAudio,
  familySafety,
}

class ServiceDefinition {
  const ServiceDefinition({
    required this.key,
    required this.titleResolver,
    required this.descriptionResolver,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final ServiceKey key;
  final String Function(AppLocalizations l10n) titleResolver;
  final String Function(AppLocalizations l10n) descriptionResolver;
  final Widget Function({double size}) icon;
  final Color background;
  final Color foreground;

  String title(AppLocalizations l10n) => titleResolver(l10n);
  String description(AppLocalizations l10n) => descriptionResolver(l10n);

  static List<ServiceDefinition> all(BuildContext context) {
    return [
      ServiceDefinition(
        key: ServiceKey.analyzeCall,
        titleResolver: (l) => l.serviceAnalyzeCallTitle,
        descriptionResolver: (l) => l.serviceAnalyzeCallDesc,
        icon: AnalyzeCallIcon.new,
        background: AppColors.callBg,
        foreground: AppColors.callFg,
      ),
      ServiceDefinition(
        key: ServiceKey.checkMessage,
        titleResolver: (l) => l.serviceCheckMessageTitle,
        descriptionResolver: (l) => l.serviceCheckMessageDesc,
        icon: CheckMessageIcon.new,
        background: AppColors.messageBg,
        foreground: AppColors.messageFg,
      ),
      ServiceDefinition(
        key: ServiceKey.checkLink,
        titleResolver: (l) => l.serviceCheckLinkTitle,
        descriptionResolver: (l) => l.serviceCheckLinkDesc,
        icon: CheckLinkIcon.new,
        background: AppColors.linkBg,
        foreground: AppColors.linkFg,
      ),
      ServiceDefinition(
        key: ServiceKey.scanScreenshot,
        titleResolver: (l) => l.serviceScanScreenshotTitle,
        descriptionResolver: (l) => l.serviceScanScreenshotDesc,
        icon: ScanScreenshotIcon.new,
        background: AppColors.screenshotBg,
        foreground: AppColors.screenshotFg,
      ),
      ServiceDefinition(
        key: ServiceKey.analyzeAudio,
        titleResolver: (l) => l.serviceAnalyzeAudioTitle,
        descriptionResolver: (l) => l.serviceAnalyzeAudioDesc,
        icon: AnalyzeAudioIcon.new,
        background: AppColors.audioBg,
        foreground: AppColors.audioFg,
      ),
      ServiceDefinition(
        key: ServiceKey.familySafety,
        titleResolver: (l) => l.serviceFamilySafetyTitle,
        descriptionResolver: (l) => l.serviceFamilySafetyDesc,
        icon: FamilySafetyIcon.new,
        background: AppColors.familyBg,
        foreground: AppColors.familyFg,
      ),
    ];
  }

  static ServiceDefinition byKey(BuildContext context, ServiceKey key) =>
      all(context).firstWhere((s) => s.key == key);
}
