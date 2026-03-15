import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handled) return;

    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final value = codes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;

    _handled = true;
    await _controller.stop();

    if (!mounted) return;
    Navigator.of(context).pop(value.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Scan Barcode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                onPressed: () => _controller.toggleTorch(),
                icon: const Icon(Icons.flash_on, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomHint() {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 48,
      child: Center(
        child: Text(
          'Align the barcode inside the frame',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
            ),
          ),
          Positioned.fill(child: _buildOverlay()),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
          _buildBottomHint(),
        ],
      ),
    );
  }
}
