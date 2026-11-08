import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/neon_button.dart';

/// ISBN Scan Screen — uses mobile_scanner to scan ISBN barcodes.
/// After a barcode is detected, shows a pre-filled form for the manager to
/// complete title, author, and publisher manually, then pops with the result.
class ISBNScanScreen extends StatefulWidget {
  const ISBNScanScreen({super.key});

  @override
  State<ISBNScanScreen> createState() => _ISBNScanScreenState();
}

class _ISBNScanScreenState extends State<ISBNScanScreen> {
  MobileScannerController? _cameraController;
  bool _scanned = false;
  String? _isbn;
  final _isbnController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _publisherController = TextEditingController();
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _scanned = true;
      _isbn = rawValue;
      _isbnController.text = rawValue;
      _showForm = true;
    });
  }

  void _confirmAndReturn() {
    if (_isbnController.text.trim().isEmpty) return;
    context.pop({
      'isbn': _isbnController.text.trim(),
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim(),
      'publisher': _publisherController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text('Scan ISBN', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: _showForm ? _buildForm() : _buildScanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Point the camera at a book barcode',
            style: AppTypography.bodyMedium.copyWith(color: context.textSecondaryColor),
          ),
        ),
        const SizedBox(height: 20),
        // Camera preview
        Expanded(
          child: Center(
            child: Container(
              width: 300,
              height: 300,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: MobileScanner(
                  controller: _cameraController!,
                  onDetect: _onBarcodeDetected,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Manual ISBN entry fallback
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _showForm = true;
              });
            },
            icon: const Icon(Icons.keyboard_rounded),
            label: const Text('Enter ISBN Manually'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Success indicator
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 36, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _isbn != null ? 'ISBN Detected!' : 'Enter ISBN Details',
              style: AppTypography.titleMedium.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 24),

          // ISBN field (pre-filled, editable)
          Text('ISBN', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _isbnController,
            style: AppTypography.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'ISBN number',
              prefixIcon: Icon(Icons.qr_code_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text('Title', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            style: AppTypography.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Book title',
              prefixIcon: Icon(Icons.menu_book_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Author
          Text('Author', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _authorController,
            style: AppTypography.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Author name',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Publisher
          Text('Publisher', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _publisherController,
            style: AppTypography.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Publisher name',
              prefixIcon: Icon(Icons.business_rounded),
            ),
          ),
          const SizedBox(height: 28),

          // Confirm button
          NeonButton(
            text: 'Add Book with ISBN',
            onPressed: _confirmAndReturn,
            width: double.infinity,
            icon: Icons.add_rounded,
          ),
          const SizedBox(height: 12),

          // Rescan button
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _scanned = false;
                  _showForm = false;
                  _isbn = null;
                  _isbnController.clear();
                  _titleController.clear();
                  _authorController.clear();
                  _publisherController.clear();
                });
              },
              icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              label: Text('Scan Again', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
