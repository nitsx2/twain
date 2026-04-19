import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class TCard extends StatelessWidget {
  const TCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TTokens.s5),
    this.onTap,
    this.border = true,
    this.elevated = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool border;
  final bool elevated;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? TTokens.neutral0;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TTokens.r6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TTokens.r6),
            border: border ? Border.all(color: TTokens.neutral200) : null,
            boxShadow: elevated ? TTokens.shadowSm : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
