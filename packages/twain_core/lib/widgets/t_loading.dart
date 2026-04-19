import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class TLoading extends StatelessWidget {
  const TLoading({super.key, this.message, this.size = 28});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: TTokens.primary900,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: TTokens.s4),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: TTokens.neutral600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
