import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import 'package:twain_core/twain_core.dart';

const _specialties = [
  'General Physician',
  'Cardiology',
  'Neurology',
  'Pediatrics',
  'Gynecology',
  'Dermatology',
  'ENT',
  'Psychiatry',
  'Gastroenterology',
  'Pulmonology',
  'Endocrinology',
  'Orthopedics',
  'Urology',
  'Ophthalmology',
];

class DoctorProfileScreen extends ConsumerStatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  ConsumerState<DoctorProfileScreen> createState() =>
      _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  final _fullName = TextEditingController();
  final _regNo = TextEditingController();
  final _clinicName = TextEditingController();
  final _clinicAddr = TextEditingController();
  final _phone = TextEditingController();
  String? _specialty;
  bool _loaded = false;
  bool _saving = false;
  bool _savingSig = false;
  bool _hasSignature = false;
  String? _status;
  bool _statusOk = false;
  final _sigCtrl = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF0F172A),
    exportBackgroundColor: const Color(0xFFFFFFFF),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _regNo.dispose();
    _clinicName.dispose();
    _clinicAddr.dispose();
    _phone.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(profileApiProvider).getDoctor();
      if (!mounted) return;
      setState(() {
        _fullName.text = (data['full_name'] as String?) ?? '';
        _specialty = data['specialty'] as String?;
        _regNo.text = (data['registration_no'] as String?) ?? '';
        _clinicName.text = (data['clinic_name'] as String?) ?? '';
        _clinicAddr.text = (data['clinic_address'] as String?) ?? '';
        _phone.text = (data['phone'] as String?) ?? '';
        _hasSignature = (data['has_signature'] as bool?) ?? false;
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
      await ref.read(profileApiProvider).updateDoctor({
        'full_name': _fullName.text.trim(),
        if (_specialty != null) 'specialty': _specialty,
        if (_regNo.text.isNotEmpty) 'registration_no': _regNo.text.trim(),
        if (_clinicName.text.isNotEmpty)
          'clinic_name': _clinicName.text.trim(),
        if (_clinicAddr.text.isNotEmpty)
          'clinic_address': _clinicAddr.text.trim(),
        if (_phone.text.isNotEmpty) 'phone': _phone.text.trim(),
      });
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() {
        _status = 'Saved';
        _statusOk = true;
      });
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

  Future<void> _saveSignature() async {
    if (_sigCtrl.isEmpty) {
      setState(() {
        _status = 'Sign in the box first';
        _statusOk = false;
      });
      return;
    }
    setState(() {
      _savingSig = true;
      _status = null;
    });
    try {
      final ui.Image? img = await _sigCtrl.toImage(height: 220);
      if (img == null) throw 'Could not capture signature';
      final ByteData? data =
          await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw 'Could not encode signature';
      final Uint8List bytes = data.buffer.asUint8List();
      await ref.read(profileApiProvider).uploadSignature(bytes);
      _sigCtrl.clear();
      if (!mounted) return;
      setState(() {
        _hasSignature = true;
        _status = 'Signature saved';
        _statusOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Save failed: $e';
        _statusOk = false;
      });
    } finally {
      if (mounted) setState(() => _savingSig = false);
    }
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
          DropdownButtonFormField<String>(
            value: _specialty,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Specialty',
              prefixIcon: Icon(Icons.medical_services_outlined),
            ),
            items: [
              for (final s in _specialties)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _specialty = v),
          ),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Medical registration #',
            controller: _regNo,
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Clinic name',
            controller: _clinicName,
            prefixIcon: Icons.local_hospital_outlined,
          ),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Clinic address',
            controller: _clinicAddr,
            maxLines: 2,
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: TTokens.s3),
          TField(
            label: 'Phone',
            controller: _phone,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
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
          const SizedBox(height: TTokens.s8),
          Row(
            children: [
              Text(
                'SIGNATURE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: TTokens.neutral500,
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(width: TTokens.s2),
              if (_hasSignature)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TTokens.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(TTokens.rFull),
                  ),
                  child: const Text(
                    'ON FILE',
                    style: TextStyle(
                      color: TTokens.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: TTokens.s2),
          Text(
            _hasSignature
                ? 'Signature saved. Sign below to replace.'
                : 'Sign once — Twain stamps this on every prescription PDF you sign.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: TTokens.neutral600),
          ),
          const SizedBox(height: TTokens.s3),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: TTokens.neutral200),
              borderRadius: BorderRadius.circular(TTokens.r4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TTokens.r4),
              child: Signature(
                controller: _sigCtrl,
                height: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: TTokens.s3),
          Row(
            children: [
              TButton(
                label: 'Clear',
                variant: TButtonVariant.secondary,
                icon: Icons.refresh,
                onPressed: () {
                  _sigCtrl.clear();
                  setState(() {});
                },
              ),
              const Spacer(),
              TButton(
                label: _hasSignature ? 'Replace signature' : 'Save signature',
                onPressed: _saveSignature,
                loading: _savingSig,
                icon: Icons.check,
              ),
            ],
          ),
          const SizedBox(height: TTokens.s8),
        ],
      ),
    );
  }
}
