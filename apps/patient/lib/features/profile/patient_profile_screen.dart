import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:twain_core/twain_core.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _sex = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _meds = TextEditingController();
  DateTime? _dob;
  bool _saving = false;
  bool _loaded = false;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _sex.dispose();
    _allergies.dispose();
    _conditions.dispose();
    _meds.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(profileApiProvider).getPatient();
      if (!mounted) return;
      setState(() {
        _fullName.text = (data['full_name'] as String?) ?? '';
        _phone.text = (data['phone'] as String?) ?? '';
        _sex.text = (data['sex'] as String?) ?? '';
        _allergies.text = (data['allergies'] as String?) ?? '';
        _conditions.text = (data['conditions'] as String?) ?? '';
        _meds.text = (data['current_meds'] as String?) ?? '';
        final dobStr = data['dob'] as String?;
        if (dobStr != null && dobStr.isNotEmpty) {
          try {
            _dob = DateTime.parse(dobStr);
          } catch (_) {}
        }
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _status = 'Failed to load: $e';
        _statusOk = false;
      });
    }
  }

  Future<void> _save() async {
    if (_fullName.text.trim().isEmpty) {
      setState(() {
        _status = 'Full name is required';
        _statusOk = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await ref.read(profileApiProvider).updatePatient({
        'full_name': _fullName.text.trim(),
        if (_dob != null) 'dob': DateFormat('yyyy-MM-dd').format(_dob!),
        if (_sex.text.isNotEmpty) 'sex': _sex.text.trim(),
        if (_phone.text.isNotEmpty) 'phone': _phone.text.trim(),
        if (_allergies.text.isNotEmpty) 'allergies': _allergies.text.trim(),
        if (_conditions.text.isNotEmpty) 'conditions': _conditions.text.trim(),
        if (_meds.text.isNotEmpty) 'current_meds': _meds.text.trim(),
      });
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() {
        _status = 'Saved';
        _statusOk = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Save failed: $e';
        _statusOk = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: const TLoading(message: 'Loading profile…'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TTokens.s5),
        children: [
          if (_status != null)
            Container(
              margin: const EdgeInsets.only(bottom: TTokens.s4),
              padding: const EdgeInsets.all(TTokens.s3),
              decoration: BoxDecoration(
                color: _statusOk
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(TTokens.r4),
              ),
              child: Text(
                _status!,
                style: TextStyle(
                  color: _statusOk ? TTokens.success : TTokens.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TField(
            label: 'Full name',
            controller: _fullName,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: TTokens.s3),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(TTokens.r4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                _dob == null ? 'Select' : DateFormat('d MMM yyyy').format(_dob!),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: TTokens.s3),
          TField(label: 'Sex (M / F / Other)', controller: _sex),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Phone',
            controller: _phone,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: TTokens.s3),
          TField(label: 'Allergies', controller: _allergies, maxLines: 2),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Ongoing conditions',
            controller: _conditions,
            maxLines: 2,
          ),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Current medications',
            controller: _meds,
            maxLines: 2,
          ),
          const SizedBox(height: TTokens.s6),
          TButton(
            label: 'Save profile',
            onPressed: _save,
            loading: _saving,
            fullWidth: true,
            size: TButtonSize.lg,
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: TTokens.s6),
        ],
      ),
    );
  }
}
