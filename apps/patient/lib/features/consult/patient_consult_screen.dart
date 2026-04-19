import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:twain_core/twain_core.dart';

class PatientConsultScreen extends ConsumerStatefulWidget {
  const PatientConsultScreen({super.key, required this.consultationId});
  final String consultationId;

  @override
  ConsumerState<PatientConsultScreen> createState() =>
      _PatientConsultScreenState();
}

class _PatientConsultScreenState extends ConsumerState<PatientConsultScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _finalizing = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref
          .read(consultApiProvider)
          .sendPatientMessage(widget.consultationId, text);
      ref.invalidate(patientMessagesProvider(widget.consultationId));
      _scrollToEnd();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _finalizing = true);
    try {
      await ref
          .read(consultApiProvider)
          .finalizeIntake(widget.consultationId);
      ref.invalidate(activeConsultationProvider);
      ref.invalidate(patientMessagesProvider(widget.consultationId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not finish: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final active = ref.watch(activeConsultationProvider);
    final messages = ref.watch(
      patientMessagesProvider(widget.consultationId),
    );

    final status = active.maybeWhen(
      data: (d) =>
          (d['consultation'] as Map<String, dynamic>?)?['status']
                  as String? ??
              'intake_pending',
      orElse: () => 'intake_pending',
    );
    final isDone = status == 'intake_done' || status == 'in_consultation';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          if (!isDone)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'cancel') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Cancel consultation?'),
                      content: const Text(
                        'Your intake will be discarded. You can start a new one later.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TTokens.danger,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref
                          .read(consultApiProvider)
                          .cancelConsultation(widget.consultationId);
                      ref.invalidate(activeConsultationProvider);
                      if (context.mounted) context.go('/home');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel consultation'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (isDone) _ReadyBanner(code: user?.patientCode),
          Expanded(
            child: messages.when(
              loading: () => const TLoading(message: 'Loading chat…'),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(TTokens.s5),
                child: Text('$e',
                    style: const TextStyle(color: TTokens.danger)),
              ),
              data: (msgs) {
                _scrollToEnd();
                if (msgs.isEmpty) {
                  return const TLoading(message: 'Twain AI is warming up…');
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TTokens.s4,
                    vertical: TTokens.s3,
                  ),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isPatient = m['sender_role'] == 'patient';
                    return TChatBubble(
                      role: isPatient ? TChatRole.user : TChatRole.ai,
                      child: Text(m['content'] as String? ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          if (!isDone)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                    TTokens.s3, TTokens.s2, TTokens.s3, TTokens.s3),
                decoration: const BoxDecoration(
                  color: TTokens.neutral0,
                  border: Border(
                    top: BorderSide(color: TTokens.neutral200),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Tell Twain AI what\'s going on…',
                              filled: true,
                              fillColor: TTokens.neutral50,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(TTokens.r5),
                                borderSide: const BorderSide(
                                    color: TTokens.neutral200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(TTokens.r5),
                                borderSide: const BorderSide(
                                    color: TTokens.neutral200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(TTokens.r5),
                                borderSide: const BorderSide(
                                  color: TTokens.primary900,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: TTokens.s4,
                                vertical: TTokens.s3,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: TTokens.s2),
                        Material(
                          color: TTokens.primary900,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _sending ? null : _send,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: _sending
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TTokens.s2),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _finalizing ? null : _finish,
                        icon: _finalizing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded,
                                color: TTokens.ai600),
                        label: const Text(
                          "I'm ready for the doctor",
                          style: TextStyle(
                            color: TTokens.ai600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  const _ReadyBanner({this.code});
  final int? code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          TTokens.s4, TTokens.s3, TTokens.s4, TTokens.s2),
      padding: const EdgeInsets.all(TTokens.s5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TTokens.r6),
        gradient: const LinearGradient(
          colors: [TTokens.ai400, TTokens.ai600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white),
              const SizedBox(width: TTokens.s2),
              Text(
                'Intake complete',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: TTokens.s2),
          Text(
            'Share code ${code ?? '----'} with your doctor at the clinic.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                ),
          ),
        ],
      ),
    );
  }
}
