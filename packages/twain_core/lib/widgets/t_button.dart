import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum TButtonVariant { primary, secondary, ghost, danger, ai }

enum TButtonSize { sm, md, lg }

class TButton extends StatelessWidget {
  const TButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TButtonVariant.primary,
    this.size = TButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TButtonVariant variant;
  final TButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final pad = switch (size) {
      TButtonSize.sm =>
        const EdgeInsets.symmetric(horizontal: TTokens.s3, vertical: TTokens.s2),
      TButtonSize.md =>
        const EdgeInsets.symmetric(horizontal: TTokens.s5, vertical: TTokens.s3),
      TButtonSize.lg =>
        const EdgeInsets.symmetric(horizontal: TTokens.s6, vertical: TTokens.s4),
    };
    final fontSize = switch (size) {
      TButtonSize.sm => 13.0,
      TButtonSize.md => 14.0,
      TButtonSize.lg => 16.0,
    };

    final (Color bg, Color fg, Color? border) = switch (variant) {
      TButtonVariant.primary => (TTokens.primary900, TTokens.neutral0, null),
      TButtonVariant.secondary =>
        (TTokens.neutral0, TTokens.primary900, TTokens.primary900),
      TButtonVariant.ghost => (Colors.transparent, TTokens.primary900, null),
      TButtonVariant.danger => (TTokens.danger, TTokens.neutral0, null),
      TButtonVariant.ai => (TTokens.ai500, TTokens.neutral0, null),
    };

    final disabled = onPressed == null || loading;
    final effBg = disabled ? TTokens.neutral200 : bg;
    final effFg = disabled ? TTokens.neutral500 : fg;

    final Widget content = loading
        ? SizedBox(
            height: fontSize,
            width: fontSize,
            child: CircularProgressIndicator(color: effFg, strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2, color: effFg),
                const SizedBox(width: TTokens.s2),
              ],
              Text(
                label,
                style: TextStyle(
                  color: effFg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          );

    final button = Material(
      color: effBg,
      borderRadius: BorderRadius.circular(TTokens.r4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        child: Container(
          padding: pad,
          alignment: fullWidth ? Alignment.center : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TTokens.r4),
            border: border != null
                ? Border.all(
                    color: disabled ? TTokens.neutral300 : border,
                    width: 1,
                  )
                : null,
          ),
          child: content,
        ),
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
