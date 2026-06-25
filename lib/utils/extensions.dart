import 'package:flutter/material.dart';
import 'package:flash_me/l10n/app_localizations.dart';
import 'package:flash_me/theme/app_colors.dart';

// Shorthand so widgets can write context.l10n.someKey instead of
// AppLocalizations.of(context)!.someKey.
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

// Shorthand for the semantic colour extension — context.appColors.correct etc.
extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}