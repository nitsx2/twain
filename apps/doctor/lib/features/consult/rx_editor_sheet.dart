import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain_core/twain_core.dart';

/// Bottom sheet that edits a Claude-drafted prescription and signs it.
class RxEditorSheet extends ConsumerStatefulWidget {
  const RxEditorSheet({
    super.key,
    required this.consultationId,
    required this.initialDraft,
  });

  final String consultationId;
  final Map<String, dynamic> initialDraft;

  @override
  ConsumerState<RxEditorSheet> createState() => _RxEditorSheetState();
}

class _RxEditorSheetState extends ConsumerState<RxEditorSheet> {
  late List<_MedRow> _meds;
  late TextEditingController _advice;
  late TextEditingController _followUp;
  late List<TextEditingController> _labs;
  late List<TextEditingController> _lifestyle;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    final initialMeds = (d['medicines'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    _meds = initialMeds.isEmpty
        ? [_MedRow.empty()]
        : initialMeds.map(_MedRow.fromJson).toList();
    _advice = TextEditingController(text: (d['advice'] as String?) ?? '');
    _followUp = TextEditingController(text: (d['follow_up'] as String?) ?? '');
    _labs = ((d['labs'] as List?)?.cast<String>() ?? const <String>[])
        .map((s) => TextEditingController(text: s))
        .toList();
    _lifestyle = ((d['lifestyle'] as List?)?.cast<String>() ?? const <String>[])
        .map((s) => TextEditingController(text: s))
        .toList();
  }

  @override
  void dispose() {
    for (final m in _meds) {
      m.dispose();
    }
    _advice.dispose();
    _followUp.dispose();
    for (final c in _labs) {
      c.dispose();
    }
    for (final c in _lifestyle) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sign() async {
    final medicines = _meds
        .where((m) => m.generic.text.trim().isNotEmpty)
        .map((m) => m.toJson())
        .toList(growable: false);

    if (medicines.isEmpty) {
      setState(() => _error = 'Add at least one medicine.');
      return;
    }

    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      await ref.read(consultApiProvider).signRx(widget.consultationId, {
        'medicines': medicines,
        'labs': _labs
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'lifestyle': _lifestyle
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'advice': _advice.text.trim().isEmpty ? null : _advice.text.trim(),
        'follow_up':
            _followUp.text.trim().isEmpty ? null : _followUp.text.trim(),
      });
      ref.invalidate(doctorMessagesProvider(widget.consultationId));
      ref.invalidate(doctorConsultProvider(widget.consultationId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: TTokens.neutral0,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(TTokens.r6)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: TTokens.neutral300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    TTokens.s5, TTokens.s2, TTokens.s3, TTokens.s3),
                child: Row(
                  children: [
                    const Icon(Icons.medication_outlined,
                        color: TTokens.primary900),
                    const SizedBox(width: TTokens.s2),
                    Text(
                      'Prescription',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(TTokens.s5),
                  children: [
                    _sectionLabel('Medicines'),
                    const SizedBox(height: TTokens.s2),
                    for (int i = 0; i < _meds.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: TTokens.s3),
                        child: _MedEditor(
                          row: _meds[i],
                          onRemove: _meds.length > 1
                              ? () {
                                  setState(() {
                                    _meds[i].dispose();
                                    _meds.removeAt(i);
                                  });
                                }
                              : null,
                        ),
                      ),
                    TButton(
                      label: 'Add medicine',
                      icon: Icons.add,
                      variant: TButtonVariant.secondary,
                      onPressed: () =>
                          setState(() => _meds.add(_MedRow.empty())),
                    ),
                    const SizedBox(height: TTokens.s6),
                    _sectionLabel('Investigations (labs)'),
                    const SizedBox(height: TTokens.s2),
                    _StringList(
                      controllers: _labs,
                      onAdd: () => setState(
                          () => _labs.add(TextEditingController())),
                      onRemove: (i) => setState(() {
                        _labs[i].dispose();
                        _labs.removeAt(i);
                      }),
                      placeholder: 'e.g. CBC, HbA1c',
                    ),
                    const SizedBox(height: TTokens.s6),
                    _sectionLabel('Lifestyle / advice'),
                    const SizedBox(height: TTokens.s2),
                    _StringList(
                      controllers: _lifestyle,
                      onAdd: () => setState(
                          () => _lifestyle.add(TextEditingController())),
                      onRemove: (i) => setState(() {
                        _lifestyle[i].dispose();
                        _lifestyle.removeAt(i);
                      }),
                      placeholder: 'e.g. Avoid fried food for 2 weeks',
                    ),
                    const SizedBox(height: TTokens.s6),
                    TField(
                      label: 'Notes for patient',
                      controller: _advice,
                      maxLines: 3,
                    ),
                    const SizedBox(height: TTokens.s3),
                    TField(
                      label: 'Follow-up',
                      controller: _followUp,
                      maxLines: 2,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: TTokens.s3),
                      Text(_error!,
                          style: const TextStyle(color: TTokens.danger)),
                    ],
                    const SizedBox(height: TTokens.s6),
                    TButton(
                      label: 'Sign & send prescription',
                      onPressed: _sign,
                      loading: _signing,
                      fullWidth: true,
                      size: TButtonSize.lg,
                      icon: Icons.check_rounded,
                    ),
                    const SizedBox(height: TTokens.s4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: TTokens.neutral500,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _MedRow {
  _MedRow({
    required this.generic,
    required this.brand,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });

  factory _MedRow.empty() => _MedRow(
        generic: TextEditingController(),
        brand: TextEditingController(),
        dose: TextEditingController(),
        route: TextEditingController(),
        frequency: TextEditingController(),
        duration: TextEditingController(),
        instructions: TextEditingController(),
      );

  factory _MedRow.fromJson(Map<String, dynamic> j) => _MedRow(
        generic: TextEditingController(
            text: (j['generic_name'] ?? j['name'] ?? '') as String),
        brand: TextEditingController(text: (j['brand_name'] ?? '') as String),
        dose: TextEditingController(text: (j['dose'] ?? '') as String),
        route: TextEditingController(text: (j['route'] ?? '') as String),
        frequency:
            TextEditingController(text: (j['frequency'] ?? '') as String),
        duration:
            TextEditingController(text: (j['duration'] ?? '') as String),
        instructions: TextEditingController(
            text: (j['instructions'] ?? '') as String),
      );

  final TextEditingController generic;
  final TextEditingController brand;
  final TextEditingController dose;
  final TextEditingController route;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController instructions;

  Map<String, dynamic> toJson() => {
        'generic_name': generic.text.trim(),
        if (brand.text.trim().isNotEmpty) 'brand_name': brand.text.trim(),
        if (dose.text.trim().isNotEmpty) 'dose': dose.text.trim(),
        if (route.text.trim().isNotEmpty) 'route': route.text.trim(),
        if (frequency.text.trim().isNotEmpty) 'frequency': frequency.text.trim(),
        if (duration.text.trim().isNotEmpty) 'duration': duration.text.trim(),
        if (instructions.text.trim().isNotEmpty)
          'instructions': instructions.text.trim(),
      };

  void dispose() {
    generic.dispose();
    brand.dispose();
    dose.dispose();
    route.dispose();
    frequency.dispose();
    duration.dispose();
    instructions.dispose();
  }
}

class _MedEditor extends StatelessWidget {
  const _MedEditor({required this.row, this.onRemove});
  final _MedRow row;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TTokens.s4),
      decoration: BoxDecoration(
        color: TTokens.neutral50,
        borderRadius: BorderRadius.circular(TTokens.r5),
        border: Border.all(color: TTokens.neutral200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TField(
                  label: 'Generic',
                  controller: row.generic,
                ),
              ),
              const SizedBox(width: TTokens.s2),
              Expanded(
                child: TField(
                  label: 'Brand',
                  controller: row.brand,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: TTokens.danger),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: TTokens.s2),
          Row(
            children: [
              Expanded(
                child: TField(label: 'Dose', controller: row.dose),
              ),
              const SizedBox(width: TTokens.s2),
              Expanded(
                child: TField(label: 'Route', controller: row.route),
              ),
            ],
          ),
          const SizedBox(height: TTokens.s2),
          Row(
            children: [
              Expanded(
                child: TField(
                  label: 'Frequency (e.g. 1-0-1)',
                  controller: row.frequency,
                ),
              ),
              const SizedBox(width: TTokens.s2),
              Expanded(
                child: TField(
                  label: 'Duration',
                  controller: row.duration,
                ),
              ),
            ],
          ),
          const SizedBox(height: TTokens.s2),
          TField(
            label: 'Instructions',
            controller: row.instructions,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _StringList extends StatelessWidget {
  const _StringList({
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
    required this.placeholder,
  });
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: TTokens.s2),
            child: Row(
              children: [
                Expanded(
                  child: TField(
                    controller: controllers[i],
                    hint: placeholder,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: TTokens.neutral400),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TButton(
            label: controllers.isEmpty ? 'Add' : 'Add another',
            icon: Icons.add,
            variant: TButtonVariant.ghost,
            size: TButtonSize.sm,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}
