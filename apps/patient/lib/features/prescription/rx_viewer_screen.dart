import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:twain_core/twain_core.dart';

class RxViewerScreen extends ConsumerStatefulWidget {
  const RxViewerScreen({super.key, required this.prescriptionId});
  final String prescriptionId;

  @override
  ConsumerState<RxViewerScreen> createState() => _RxViewerScreenState();
}

class _RxViewerScreenState extends ConsumerState<RxViewerScreen> {
  late final Future<PdfController> _ctrlFuture = _load();

  Future<PdfController> _load() async {
    final bytes = await ref
        .read(consultApiProvider)
        .getPdfBytes(widget.prescriptionId);
    final doc = PdfDocument.openData(bytes);
    return PdfController(document: doc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription'),
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
      ),
      body: FutureBuilder<PdfController>(
        future: _ctrlFuture,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const TLoading(message: 'Loading prescription…');
          }
          if (s.hasError) {
            return TError(message: '${s.error}');
          }
          return PdfView(
            controller: s.data!,
            scrollDirection: Axis.vertical,
          );
        },
      ),
    );
  }
}
