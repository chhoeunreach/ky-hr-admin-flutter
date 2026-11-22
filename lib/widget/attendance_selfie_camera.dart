import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:cnattendance/core/theme/app_colors.dart';

class AttendanceSelfieCamera extends StatefulWidget {
  const AttendanceSelfieCamera({super.key});

  @override
  State<AttendanceSelfieCamera> createState() => _AttendanceSelfieCameraState();
}

class _AttendanceSelfieCameraState extends State<AttendanceSelfieCamera> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera([CameraDescription? camera]) async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw translate('attendance_messages.no_camera_available');
      }

      final frontCameras = _cameras
          .where((item) => item.lensDirection == CameraLensDirection.front)
          .toList();
      final frontCamera = frontCameras.isEmpty ? null : frontCameras.first;
      final selectedCamera = camera ?? frontCamera;
      if (selectedCamera == null) {
        throw translate('attendance_messages.front_camera_not_available');
      }

      final previousController = _controller;
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await previousController?.dispose();
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) return;
      setState(() => _isInitializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _switchCamera() async {
    final current = _controller?.description;
    if (current == null || _cameras.length < 2 || _isTakingPicture) {
      return;
    }

    final nextCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection != current.lensDirection,
      orElse: () => _cameras.firstWhere(
        (camera) => camera.name != current.name,
        orElse: () => current,
      ),
    );

    if (nextCamera.name == current.name) {
      return;
    }

    await _initializeCamera(nextCamera);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      final image = await controller.takePicture();
      final normalizedSelfie = await _compressPortraitSelfie(File(image.path));
      if (!mounted) return;
      Navigator.pop(context, normalizedSelfie);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTakingPicture = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<File> _compressPortraitSelfie(File file) async {
    final targetPath = p.join(
      p.dirname(file.path),
      'attendance_selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      minWidth: 720,
      minHeight: 960,
      quality: 68,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
      keepExif: false,
    );

    final compressedFile = compressed == null ? file : File(compressed.path);
    if (compressed != null && file.path != compressed.path) {
      try {
        await file.delete();
      } catch (_) {}
    }

    return _ensurePortraitIfNeeded(compressedFile);
  }

  Future<File> _ensurePortraitIfNeeded(File file) async {
    final decodedImage = img.decodeImage(await file.readAsBytes());
    if (decodedImage == null) {
      return file;
    }

    var portraitImage = img.bakeOrientation(decodedImage);
    var shouldRewrite = false;
    if (portraitImage.width > portraitImage.height) {
      portraitImage = img.copyRotate(portraitImage, angle: 90);
      shouldRewrite = true;
    }

    if (!shouldRewrite) {
      return file;
    }

    return file.writeAsBytes(img.encodeJpg(portraitImage, quality: 68));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _controller;
    final isFrontCamera =
        controller?.description.lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: Text(isFrontCamera
            ? translate('attendance_messages.take_selfie')
            : translate('attendance_messages.take_photo')),
        actions: [
          IconButton(
            tooltip: translate('attendance_messages.switch_camera'),
            onPressed: _cameras.length < 2 ? null : _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildPreview(controller),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Center(
                child: FloatingActionButton.large(
                  heroTag: "attendance-selfie-capture",
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  onPressed: _isTakingPicture ? null : _takePicture,
                  child: _isTakingPicture
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(CameraController? controller) {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.white),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Text(
          translate('attendance_messages.camera_not_ready'),
          style: const TextStyle(color: AppColors.white),
        ),
      );
    }

    return Center(
      child: CameraPreview(controller),
    );
  }
}
