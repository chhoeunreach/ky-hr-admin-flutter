import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hexcolor/hexcolor.dart';

class InvoiceLiveTextResult {
  final String photoPath;
  final String text;

  const InvoiceLiveTextResult({
    required this.photoPath,
    required this.text,
  });
}

class InvoiceLiveTextScannerScreen extends StatefulWidget {
  const InvoiceLiveTextScannerScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceLiveTextScannerScreen> createState() =>
      _InvoiceLiveTextScannerScreenState();
}

class _InvoiceLiveTextScannerScreenState
    extends State<InvoiceLiveTextScannerScreen> {
  final _textRecognizer = TextRecognizer();

  CameraController? _controller;
  String _recognizedText = '';
  String? _errorMessage;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isTakingPhoto = false;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera found.';
          _isInitializing = false;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await controller.initialize();
      await controller.startImageStream(_processCameraImage);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now();
    if (_isProcessingFrame ||
        now.difference(_lastProcessedAt) < const Duration(milliseconds: 900)) {
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    final inputImage = _inputImageFromCameraImage(
      image,
      controller.description.sensorOrientation,
    );
    if (inputImage == null) return;

    _isProcessingFrame = true;
    _lastProcessedAt = now;
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted) return;
      setState(() => _recognizedText = recognizedText.text.trim());
    } catch (_) {
      // Camera stream OCR can fail for an individual frame; keep scanning.
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final bytes = image.planes.length == 1
        ? image.planes.first.bytes
        : _concatenatePlaneBytes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlaneBytes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future<void> _copyText() async {
    final text = _recognizedText.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || _isTakingPhoto) return;

    setState(() => _isTakingPhoto = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(
        context,
        InvoiceLiveTextResult(
          photoPath: photo.path,
          text: _recognizedText.trim(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTakingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not take photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildCameraPreview(controller),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildTextPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(CameraController? controller) {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not ready',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Center(
      child: CameraPreview(controller),
    );
  }

  Widget _buildTextPanel() {
    final hasText = _recognizedText.trim().isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 76, maxHeight: 150),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                hasText ? _recognizedText : 'Point camera at invoice text...',
                style: TextStyle(
                  color: hasText ? Colors.black87 : Colors.black45,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasText ? _copyText : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Text'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white38,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTakingPhoto ? null : _takePhoto,
                  icon: _isTakingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt, size: 18),
                  label: Text(_isTakingPhoto ? 'Saving...' : 'Use Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HexColor('#036eb7'),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
