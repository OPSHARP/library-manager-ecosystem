import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Parse QR data and navigate to the Library Preview screen.
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _processing = true;

    try {
      Map<String, dynamic> data;
      if (raw.startsWith('{')) {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } else {
        data = {'ownerUid': raw};
      }
      await _navigateToPreviewFromQr(data);
    } catch (_) {
      _showError('Invalid QR code');
      _processing = false;
    }
  }

  Future<void> _navigateToPreviewFromQr(Map<String, dynamic> data) async {
    final ownerUid = data['ownerUid'] ?? data['owner'] ?? data['uid'];
    if (ownerUid == null || ownerUid.toString().isEmpty) {
      _showError('Invalid QR code');
      _processing = false;
      return;
    }
    final owner = ownerUid.toString();
    final libraryId = (data['libraryId'] ?? data['lib'] ?? '').toString();

    // Don't let an already-joined student re-request the same library.
    if (ref.read(authProvider).ownerUid == owner) {
      _showError('You are already a member of this library.');
      _processing = false;
      return;
    }

    final registryData = <String, dynamic>{
      'ownerUid': owner,
      'libraryId': libraryId,
      'libraryName': (data['libraryName'] ?? data['name'] ?? 'Library').toString(),
      'contactNumber': (data['contactNumber'] ?? data['phone'] ?? '').toString(),
      'address': (data['address'] ?? '').toString(),
    };

    // Enrich with the live library doc (seat capacity, available seats,
    // facilities, currency) so the preview is accurate after a quick scan.
    final lib = await ref
        .read(authProvider.notifier)
        .fetchLibraryDoc(owner, libraryId);
    if (lib != null) {
      registryData['seatCapacity'] = lib['seatCapacity'] ?? 0;
      registryData['availableSeats'] = lib['availableSeats'] ?? 0;
      registryData['currency'] = lib['currency'] ?? '\$';
      final fac = lib['facilities'];
      if (fac is List) {
        registryData['facilities'] = fac;
      } else {
        registryData['facilities'] = const <String>[];
      }
      if ((registryData['libraryName'] ?? 'Library').toString() == 'Library' &&
          lib['libraryName'] is String) {
        registryData['libraryName'] = lib['libraryName'];
      }
      if ((registryData['contactNumber'] ?? '').toString().isEmpty) {
        registryData['contactNumber'] = lib['contactNumber'] ?? '';
      }
      if ((registryData['address'] ?? '').toString().isEmpty) {
        registryData['address'] = lib['address'] ?? '';
      }
    }

    if (mounted) {
      context.push('/library-preview', extra: registryData);
    }
    Future.delayed(const Duration(seconds: 2), () => _processing = false);
  }

  Future<void> _pickQrFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final capture = await _scannerController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        _onDetect(capture);
      } else {
        if (mounted) _showError('No QR code found in the selected image');
      }
    } catch (_) {
      if (mounted) _showError('Could not process the selected image');
    }
  }

  void _showCodeDialog() {
    final codeCtrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Enter Library Code'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: codeCtrl,
            placeholder: 'e.g. A7X3K9',
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) =>
                Navigator.pop(ctx, codeCtrl.text.trim().toUpperCase()),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.pop(ctx, codeCtrl.text.trim().toUpperCase()),
            child: const Text('Search'),
          ),
        ],
      ),
    ).then((code) async {
      if (code == null || code.toString().isEmpty) return;
      final registry = await ref
          .read(authProvider.notifier)
          .lookupLibraryByCode(code.toString());
      if (registry != null && mounted) {
        context.push('/library-preview', extra: registry);
      } else if (mounted) {
        final error = ref.read(authProvider).error ?? 'Library not found';
        _showError(error);
      }
    });
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => context.go('/auth'));
      return const SizedBox.shrink();
    }

    if (!authState.hasProfile) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => context.go('/profile-create'));
      return const SizedBox.shrink();
    }

    return CupertinoPageScaffold(
      backgroundColor: AppColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.floatingBar,
        middle: const Text('Join Library'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'Scan the QR code at your library, or enter its code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: CupertinoColors.black,
                              border: Border.all(
                                color: AppColors.systemGray4,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: MobileScanner(
                              controller: _scannerController,
                              onDetect: _onDetect,
                            ),
                          ),
                        ),
                        const Positioned.fill(child: _ScannerCorners()),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: _pickQrFromGallery,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.photo,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Pick QR from Gallery',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showCodeDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.systemBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.padlock,
                          color: AppColors.systemBlue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Enter Library Code',
                          style: TextStyle(
                            color: AppColors.systemBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative scanning corners overlay that fills its parent.
class _ScannerCorners extends StatelessWidget {
  const _ScannerCorners();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ScannerCornersPainter()),
    );
  }
}

class _ScannerCornersPainter extends CustomPainter {
  static const double _length = 28;
  static const double _stroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.systemBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const inset = 2.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(inset, _length)
        ..lineTo(inset, inset)
        ..lineTo(_length, inset),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - _length, inset)
        ..lineTo(w - inset, inset)
        ..lineTo(w - inset, _length),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - inset, h - _length)
        ..lineTo(w - inset, h - inset)
        ..lineTo(w - _length, h - inset),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(_length, h - inset)
        ..lineTo(inset, h - inset)
        ..lineTo(inset, h - _length),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScannerCornersPainter oldDelegate) => false;
}
