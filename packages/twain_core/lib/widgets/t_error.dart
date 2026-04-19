import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 't_button.dart';

class TError extends StatelessWidget {
  const TError({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TTokens.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFEE2E2),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: TTokens.danger,
              ),
            ),
            const SizedBox(height: TTokens.s5),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TTokens.s2),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: TTokens.neutral600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TTokens.s5),
              TButton(
                label: 'Try again',
                onPressed: onRetry,
                variant: TButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
