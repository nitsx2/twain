import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum TChatRole { user, ai, doctor, system }

class TChatBubble extends StatelessWidget {
  const TChatBubble({
    super.key,
    required this.role,
    required this.child,
    this.timestamp,
    this.senderLabel,
  });

  final TChatRole role;
  final Widget child;
  final String? timestamp;
  final String? senderLabel;

  @override
  Widget build(BuildContext context) {
    final isMine = role == TChatRole.user || role == TChatRole.doctor;
    final (Color bg, Color fg, String sender) = switch (role) {
      TChatRole.user => (TTokens.primary900, TTokens.neutral0, senderLabel ?? 'You'),
      TChatRole.doctor => (TTokens.primary900, TTokens.neutral0, senderLabel ?? 'Doctor'),
      TChatRole.ai => (TTokens.ai50, TTokens.neutral900, senderLabel ?? 'Twain AI'),
      TChatRole.system => (TTokens.neutral100, TTokens.neutral600, senderLabel ?? 'System'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TTokens.s2),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) _aiAvatar(),
          if (!isMine) const SizedBox(width: TTokens.s2),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TTokens.s1, vertical: 2),
                  child: Text(
                    sender,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: TTokens.neutral500,
                        ),
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(TTokens.r5),
                      topRight: const Radius.circular(TTokens.r5),
                      bottomLeft: Radius.circular(isMine ? TTokens.r5 : TTokens.r2),
                      bottomRight: Radius.circular(isMine ? TTokens.r2 : TTokens.r5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: TTokens.s4,
                    vertical: TTokens.s3,
                  ),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: fg),
                    child: child,
                  ),
                ),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TTokens.s1, vertical: 2),
                    child: Text(
                      timestamp!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: TTokens.neutral400,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [TTokens.ai400, TTokens.ai600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.auto_awesome, color: TTokens.neutral0, size: 16),
    );
  }
}
