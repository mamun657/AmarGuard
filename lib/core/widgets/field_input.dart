import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FieldInput extends StatelessWidget {
  const FieldInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.autofillHints,
    this.isDense = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseFontSize = 15.0;
    final hintFontSize = 15.0;
    final textStyle = TextStyle(
      fontSize: baseFontSize,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      style: textStyle,
      decoration: InputDecoration(
        isDense: isDense,
        contentPadding: isDense
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: hintFontSize,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: isDense ? 20 : 22),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        counterStyle: theme.textTheme.bodySmall,
      ),
    );
  }
}

class PasswordToggleSuffix extends StatelessWidget {
  const PasswordToggleSuffix({
    super.key,
    required this.visible,
    required this.onTap,
    this.dense = false,
  });

  final bool visible;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(
        visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: AppColors.textTertiary,
        size: 20,
      ),
    );
  }
}
