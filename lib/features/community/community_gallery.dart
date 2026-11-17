import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Uses the native photo library for media; document uploads use FilePicker.
Future<List<PlatformFile>> pickCommunityGalleryMedia(String type,
    {bool multipleImages = true}) async {
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    // This plugin version otherwise uses ACTION_GET_CONTENT (the Files UI).
    implementation.useAndroidPhotoPicker = true;
  }
  final picker = ImagePicker();
  final List<XFile> selected;
  if (type == 'video') {
    final XFile? video;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // PHPicker supports video-only selection, including limited Photos access.
      final path = await const MethodChannel('cnattendance/community_gallery')
          .invokeMethod<String>('pickVideo');
      video = path == null ? null : XFile(path);
    } else {
      video = await picker.pickVideo(source: ImageSource.gallery);
    }
    selected = video == null ? [] : [video];
  } else if (multipleImages) {
    selected = await picker.pickMultiImage(requestFullMetadata: false);
  } else {
    final image = await picker.pickImage(
        source: ImageSource.gallery, requestFullMetadata: false);
    selected = image == null ? [] : [image];
  }
  return Future.wait(selected.map((file) async => PlatformFile(
        name: file.name,
        path: file.path,
        size: await file.length(),
      )));
}
