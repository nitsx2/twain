import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:twain_core/twain_core.dart';

import 'rx_editor_sheet.dart';

class DoctorConsultScreen extends ConsumerStatefulWidget {
  const DoctorConsultScreen({
    super.key,
    required this.consultationId,
    this.patientName,
    this.patientCode,
  });
  final String consultationId;
  final String? patientName;
  final int? patientCode;

  @override
  ConsumerState<DoctorConsultScreen> createState() =>
      _DoctorConsultScreenState();
}

class _DoctorConsultScreenState extends ConsumerState<DoctorConsultScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _rec = AudioRecorder();

  bool _sending = false;
  bool _recording = false;
  bool _processingAudio = false;
  bool _draftingRx = false;
  DateTime? _recStartedAt;
  String? _recError;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref
          .read(consultApiProvider)
          .brainChat(widget.consultationId, text);
      ref.invalidate(doctorMessagesProvider(widget.consultationId));
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_processingAudio) return;
    setState(() => _recError = null);
    if (_recording) {
      try {
        final path = await _rec.stop();
        setState(() {
          _recording = false;
          _processingAudio = true;
        });
        if (path == null) throw 'No audio captured';
        Uint8List bytes;
        if (kIsWeb) {
          final r = await Dio().get<List<int>>(
            path,
            options: Options(responseType: ResponseType.bytes),
          );
          bytes = Uint8List.fromList((r.data ?? const []).cast<int>());
        } else {
          throw 'Recording upload currently supported on web';
        }
        if (bytes.isEmpty) throw 'Captured audio is empty';
        await ref
            .read(consultApiProvider)
            .uploadRecording(widget.consultationId, bytes);
        ref.invalidate(doctorConsultProvider(widget.consultationId));
        ref.invalidate(doctorMessagesProvider(widget.consultationId));
        _scrollToEnd();
      } catch (e) {
        setState(() => _recError = '$e');
      } finally {
        if (mounted) setState(() => _processingAudio = false);
      }
    } else {
      try {
        if (!await _rec.hasPermission()) {
          setState(() => _recError = 'Microphone permission denied');
          return;
        }
        await _rec.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: 'twain_consult.webm',
        );
        setState(() {
          _recording = true;
          _recStartedAt = DateTime.now();
        });
      } catch (e) {
        setState(() => _recError = '$e');
      }
    }
  }

  Future<void> _createPrescription() async {
    if (_draftingRx) return;
    setState(() => _draftingRx = true);
    try {
      final data =
          await ref.read(consultApiProvider).draftRx(widget.consultationId);
      ref.invalidate(doctorMessagesProvider(widget.consultationId));
      final draft = (data['draft'] as Map<String, dynamic>?) ?? {};
      if (!mounted) return;
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RxEditorSheet(
          consultationId: widget.consultationId,
          initialDraft: draft,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not draft Rx: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _draftingRx = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(doctorConsultProvider(widget.consultationId));
    final messages = ref.watch(doctorMessagesProvider(widget.consultationId));

    return Scaffold(
      backgroundColor: TTokens.neutral50,
      appBar: AppBar(
        title: detail.maybeWhen(
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (d['patient_name'] as String?) ??
                    widget.patientName ??
                    'Patient',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Code ${d['patient_code'] ?? widget.patientCode ?? "----"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: TTokens.neutral500,
                    ),
              ),
            ],
          ),
          orElse: () => const Text('Consultation'),
        ),
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
          TextButton.icon(
            icon: const Icon(Icons.stop_circle_outlined, color: TTokens.danger),
            label: const Text('Close',
                style: TextStyle(color: TTokens.danger)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Close consultation?'),
                  content: const Text(
                    'This ends the consultation. The patient can then start a new one.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: TTokens.danger),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await ref
                      .read(consultApiProvider)
                      .closeConsultation(widget.consultationId);
                  if (context.mounted) context.go('/home');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: detail.when(
              loading: () => const TLoading(message: 'Loading consultation…'),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(TTokens.s5),
                child: Text('$e',
                    style: const TextStyle(color: TTokens.danger)),
              ),
              data: (d) {
                final intake =
                    d['intake_summary'] as Map<String, dynamic>?;
                return messages.when(
                  loading: () => const TLoading(),
                  error: (e, _) => Text('$e',
                      style: const TextStyle(color: TTokens.danger)),
                  data: (msgs) {
                    _scrollToEnd();
                    return ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: TTokens.s4,
                        vertical: TTokens.s3,
                      ),
                      children: [
                        _IntakeSummaryCard(summary: intake),
                        const SizedBox(height: TTokens.s3),
                        for (final m in msgs) _MessageBubble(m: m),
                        if (_processingAudio)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: TTokens.s4),
                            child: TLoading(
                              message: 'Transcribing & analysing…',
                            ),
                          ),
                        const SizedBox(height: TTokens.s3),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _input,
            onSend: _sendMessage,
            sending: _sending,
            recording: _recording,
            processing: _processingAudio,
            draftingRx: _draftingRx,
            recStartedAt: _recStartedAt,
            onMic: _toggleRecording,
            onRx: _createPrescription,
            recError: _recError,
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.recording,
    required this.processing,
    required this.draftingRx,
    required this.recStartedAt,
    required this.onMic,
    required this.onRx,
    required this.recError,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final bool recording;
  final bool processing;
  final bool draftingRx;
  final DateTime? recStartedAt;
  final VoidCallback onMic;
  final VoidCallback onRx;
  final String? recError;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: TTokens.neutral0,
          border: Border(top: BorderSide(color: TTokens.neutral200)),
        ),
        padding: const EdgeInsets.fromLTRB(
            TTokens.s3, TTokens.s2, TTokens.s3, TTokens.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recording && recStartedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: TTokens.danger,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _RecTimer(start: recStartedAt!),
                  ],
                ),
              ),
            if (recError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  recError!,
                  style: const TextStyle(color: TTokens.danger, fontSize: 12),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: draftingRx ? null : onRx,
                  style: TextButton.styleFrom(
                    foregroundColor: TTokens.ai700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: draftingRx
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.medication_outlined, size: 18),
                  label: Text(
                    draftingRx
                        ? 'Drafting…'
                        : 'Create / update prescription',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: recording
                          ? 'Recording in progress…'
                          : 'Ask Brain — e.g. reduce duration to 7 days',
                      filled: true,
                      fillColor: TTokens.neutral50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(TTokens.rFull),
                        borderSide:
                            const BorderSide(color: TTokens.neutral200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(TTokens.rFull),
                        borderSide:
                            const BorderSide(color: TTokens.neutral200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(TTokens.rFull),
                        borderSide: const BorderSide(
                            color: TTokens.primary900, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: TTokens.s4, vertical: TTokens.s3),
                    ),
                  ),
                ),
                const SizedBox(width: TTokens.s2),
                Material(
                  color: recording
                      ? TTokens.danger
                      : (processing
                          ? TTokens.neutral300
                          : TTokens.primary900),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: processing ? null : onMic,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: processing
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              recording ? Icons.stop : Icons.mic,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: TTokens.ai600,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: sending ? null : onSend,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecTimer extends StatefulWidget {
  const _RecTimer({required this.start});
  final DateTime start;
  @override
  State<_RecTimer> createState() => _RecTimerState();
}

class _RecTimerState extends State<_RecTimer> {
  late final Stream<int> _tick =
      Stream<int>.periodic(const Duration(seconds: 1), (i) => i);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _tick,
      builder: (_, __) {
        final elapsed = DateTime.now().difference(widget.start);
        final mins = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final secs = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        return Text('Recording · $mins:$secs',
            style: const TextStyle(
                color: TTokens.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12));
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final role = m['sender_role'] as String? ?? 'system';
    final contentType = m['content_type'] as String? ?? 'text';
    final content = m['content'] as String? ?? '';
    final payload = m['payload'] as Map<String, dynamic>?;

    final TChatRole r;
    final String? label;
    switch (role) {
      case 'patient':
        r = TChatRole.user;
        label = 'Patient';
        break;
      case 'twain_ai':
        r = TChatRole.ai;
        label = 'Twain AI';
        break;
      case 'doctor':
        r = TChatRole.doctor;
        label = 'You';
        break;
      case 'brain_ai':
        r = TChatRole.ai;
        label = contentType == 'summary_full'
            ? 'Brain — analysis'
            : contentType == 'rx_draft'
                ? 'Brain — Rx draft'
                : contentType == 'diagnosis'
                    ? 'Brain — diagnosis'
                    : 'Brain';
        break;
      default:
        r = TChatRole.system;
        label = contentType == 'transcript' ? 'Transcript' : null;
    }

    Widget child;
    if (contentType == 'summary_full' && payload != null) {
      child = _SummaryBlock(payload: payload);
    } else if (contentType == 'rx_draft' && payload != null) {
      child = _RxDraftBlock(payload: payload);
    } else if (contentType == 'diagnosis') {
      final actions =
          ((payload?['action_items'] as List?)?.cast<String>()) ?? const [];
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (content.isNotEmpty) Text(content),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: TTokens.s2),
            for (final a in actions) Text('• $a'),
          ],
        ],
      );
    } else if (contentType == 'rx_signed') {
      final pid = payload?['prescription_id'] as String?;
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.receipt_long_outlined,
                  color: TTokens.ai700, size: 18),
              SizedBox(width: 6),
              Text(
                'Prescription signed & sent',
                style: TextStyle(
                    color: TTokens.ai700, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(content),
          ],
          if (pid != null) ...[
            const SizedBox(height: 4),
            Text('Rx #${pid.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                    fontSize: 11,
                    color: TTokens.neutral500,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      );
    } else {
      child = Text(content.isEmpty ? '—' : content);
    }

    return TChatBubble(role: r, senderLabel: label, child: child);
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final chief = payload['chief_complaint'] as String? ?? '';
    final findings = payload['findings'] as String? ?? '';
    final ddx = (payload['differential'] as List?)?.cast<String>() ?? const [];
    final assessment = payload['assessment'] as String? ?? '';
    final recs =
        (payload['recommendations'] as List?)?.cast<String>() ?? const [];
    final red =
        (payload['red_flags'] as List?)?.cast<String>() ?? const [];

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              style:
                  const TextStyle(color: TTokens.neutral900, fontSize: 13),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TTokens.neutral600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chief.isNotEmpty) row('Chief complaint', chief),
        if (findings.isNotEmpty) row('Findings', findings),
        if (assessment.isNotEmpty) row('Assessment', assessment),
        if (ddx.isNotEmpty) row('Differentials', ddx.join(', ')),
        if (recs.isNotEmpty) ...[
          const SizedBox(height: 2),
          const Text('Recommendations:',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TTokens.neutral600,
                  fontSize: 13)),
          for (final r in recs)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text('• $r',
                  style: const TextStyle(
                      color: TTokens.neutral900, fontSize: 13)),
            ),
        ],
        if (red.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Red flags: ${red.join('; ')}',
                style: const TextStyle(
                    color: TTokens.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

class _RxDraftBlock extends StatelessWidget {
  const _RxDraftBlock({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final meds = (payload['medicines'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    final labs = (payload['labs'] as List?)?.cast<String>() ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Draft prescription',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: TTokens.neutral700)),
        const SizedBox(height: 4),
        for (final m in meds)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '• ${m['generic_name'] ?? ''}'
              '${m['dose'] != null && (m['dose'] as String).isNotEmpty ? " ${m['dose']}" : ""}'
              '${m['frequency'] != null && (m['frequency'] as String).isNotEmpty ? " · ${m['frequency']}" : ""}'
              '${m['duration'] != null && (m['duration'] as String).isNotEmpty ? " · ${m['duration']}" : ""}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        if (labs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Labs: ${labs.join(", ")}',
                style: const TextStyle(
                    fontSize: 12, color: TTokens.neutral600)),
          ),
        const SizedBox(height: 6),
        const Text(
          'Tap "Create / update prescription" to edit and sign.',
          style: TextStyle(
              fontSize: 11,
              color: TTokens.neutral500,
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _IntakeSummaryCard extends StatelessWidget {
  const _IntakeSummaryCard({this.summary});
  final Map<String, dynamic>? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox.shrink();
    final s = summary!;
    final chief = (s['chief_complaint'] as String?) ?? '';
    final duration = (s['duration'] as String?) ?? '';
    final allergies =
        (s['allergies'] as List?)?.cast<String>() ?? const [];
    final redFlags =
        (s['red_flags'] as List?)?.cast<String>() ?? const [];
    final summaryText = (s['patient_summary'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: TTokens.s2),
      padding: const EdgeInsets.all(TTokens.s3),
      decoration: BoxDecoration(
        color: TTokens.ai50,
        borderRadius: BorderRadius.circular(TTokens.r5),
        border: Border.all(color: TTokens.ai200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: TTokens.ai700),
              const SizedBox(width: 4),
              Text(
                'INTAKE SUMMARY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: TTokens.ai700,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (chief.isNotEmpty)
            Text(
              chief,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          if (duration.isNotEmpty)
            Text('Duration: $duration',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: TTokens.neutral700,
                    )),
          if (allergies.isNotEmpty)
            Text('Allergies: ${allergies.join(", ")}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: TTokens.neutral700,
                    )),
          if (redFlags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⚠ Red flags: ${redFlags.join("; ")}',
                style: const TextStyle(
                  color: TTokens.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          if (summaryText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(summaryText,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
