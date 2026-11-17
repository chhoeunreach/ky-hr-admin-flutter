import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/community/community_device_gallery.dart';
import 'package:cnattendance/features/community/community_gallery.dart';
import 'package:cnattendance/features/community/community_media_picker.dart';
import 'package:cnattendance/features/community/community_strings.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_ios/image_picker_ios.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_feature_test.dart' show FakeCommunityApi;

class _Gallery extends ImagePickerPlatform {
  int photoCalls = 0;
  ImageSource? videoSource;
  ImageSource? imageSource;
  Completer<List<XFile>>? pendingImages;
  List<XFile> images = [];
  XFile? video;

  @override
  Future<List<XFile>> getMultiImageWithOptions(
      {MultiImagePickerOptions options =
          const MultiImagePickerOptions()}) async {
    photoCalls++;
    return pendingImages?.future ?? images;
  }

  @override
  Future<XFile?> getImageFromSource(
      {required ImageSource source,
      ImagePickerOptions options = const ImagePickerOptions()}) async {
    imageSource = source;
    return images.isEmpty ? null : images.first;
  }

  @override
  Future<XFile?> getVideo(
      {required ImageSource source,
      CameraDevice preferredCameraDevice = CameraDevice.rear,
      Duration? maxDuration}) async {
    videoSource = source;
    return video;
  }
}

class _AndroidGallery extends ImagePickerAndroid {
  final List<bool> photoPickerAtSelection = [];
  final List<ImageSource> videoSources = [];

  @override
  Future<List<XFile>> getMultiImageWithOptions(
      {MultiImagePickerOptions options =
          const MultiImagePickerOptions()}) async {
    photoPickerAtSelection.add(useAndroidPhotoPicker);
    return [];
  }

  @override
  Future<XFile?> getVideo(
      {required ImageSource source,
      CameraDevice preferredCameraDevice = CameraDevice.rear,
      Duration? maxDuration}) async {
    photoPickerAtSelection.add(useAndroidPhotoPicker);
    videoSources.add(source);
    return null;
  }
}

class _IOSGallery extends ImagePickerIOS {
  final List<bool> fullMetadataRequests = [];
  final List<ImageSource> videoSources = [];

  @override
  Future<List<XFile>> getMultiImageWithOptions(
      {MultiImagePickerOptions options =
          const MultiImagePickerOptions()}) async {
    fullMetadataRequests.add(options.imageOptions.requestFullMetadata);
    return [];
  }

  @override
  Future<XFile?> getImageFromSource(
      {required ImageSource source,
      ImagePickerOptions options = const ImagePickerOptions()}) async {
    expect(source, ImageSource.gallery);
    fullMetadataRequests.add(options.requestFullMetadata);
    return null;
  }

  @override
  Future<XFile?> getVideo(
      {required ImageSource source,
      CameraDevice preferredCameraDevice = CameraDevice.rear,
      Duration? maxDuration}) async {
    videoSources.add(source);
    return null;
  }
}

XFile _media(String name) => XFile.fromData(Uint8List(12), path: '/tmp/$name');

final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
final _tempDirs = <Directory>[];

CommunityGalleryItem _galleryItem(String name, {bool video = false}) {
  final directory = Directory.systemTemp.createTempSync('community-gallery-');
  _tempDirs.add(directory);
  final file = File('${directory.path}/$name')
    ..writeAsBytesSync(List.filled(12, 0));
  return CommunityGalleryItem(
      id: name,
      isVideo: video,
      width: 100,
      height: 100,
      title: name,
      duration: video ? const Duration(seconds: 12) : null,
      size: 12,
      thumbnail: (_) async => _pixel,
      file: () async => file);
}

CommunityGalleryLoader _galleryLoader(List<CommunityGalleryItem> items) =>
    ({required String type, required int page, required int size}) async {
      if (page > 0) return const CommunityGalleryPage();
      return CommunityGalleryPage(
          items: items
              .where((item) => type == 'video' ? item.isVideo : !item.isVideo)
              .toList(),
          hasNext: false);
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeGallery = MethodChannel('cnattendance/community_gallery');
  var nativeVideoCalls = 0;
  late ImagePickerPlatform original;
  setUp(() {
    nativeVideoCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeGallery, (call) async {
      expect(call.method, 'pickVideo');
      nativeVideoCalls++;
      return null;
    });
    original = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _Gallery();
    SharedPreferences.setMockInitialValues({});
    debugCommunityGalleryLoader = null;
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });
  tearDown(() {
    ImagePickerPlatform.instance = original;
    debugCommunityGalleryLoader = null;
    for (final directory in _tempDirs) {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    _tempDirs.clear();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeGallery, null);
  });

  test(
      'photos retain multiple gallery selections and videos use gallery source',
      () async {
    final gallery = ImagePickerPlatform.instance as _Gallery;
    gallery.images = [_media('one.jpg'), _media('two.png')];
    final photos = await pickCommunityGalleryMedia('image');
    expect(photos.map((file) => file.name), ['one.jpg', 'two.png']);
    expect(photos.first.size, 12);
    gallery.video = _media('clip.mp4');
    final videos = await pickCommunityGalleryMedia('video');
    expect(gallery.videoSource, ImageSource.gallery);
    expect(videos.single.path, '/tmp/clip.mp4');
    await pickCommunityGalleryMedia('image', multipleImages: false);
    expect(gallery.imageSource, ImageSource.gallery);
  });

  test('Android media selection enables the system photo picker', () async {
    final android = _AndroidGallery();
    ImagePickerPlatform.instance = android;
    await pickCommunityGalleryMedia('image');
    android.useAndroidPhotoPicker = false;
    await pickCommunityGalleryMedia('video');
    expect(android.photoPickerAtSelection, [true, true]);
    expect(android.videoSources, [ImageSource.gallery]);
  });

  test('iOS story photo selection uses Photos without requesting full metadata',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = _IOSGallery();
    ImagePickerPlatform.instance = ios;
    await pickCommunityGalleryMedia('image', multipleImages: false);
    expect(ios.fullMetadataRequests, [false]);
  });

  test('iOS video picker returns an uploadable cached video path', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final directory =
        Directory.systemTemp.createTempSync('ios-community-gallery-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final video = File('${directory.path}/selected.mov')
      ..writeAsBytesSync(List.filled(12, 0));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeGallery, (_) async {
      nativeVideoCalls++;
      return video.path;
    });
    final files = await pickCommunityGalleryMedia('video');
    expect(nativeVideoCalls, 1);
    expect(files.single.path, video.path);
    expect(files.single.size, 12);
  });

  Widget feed() => ChangeNotifierProvider(
        create: (_) => DashboardProvider()
          ..features = {
            'social_feed.view': '1',
            'social_feed.create': '1',
            'social_feed.stories.view': '0'
          },
        child: MaterialApp(home: SocialFeedScreen(api: FakeCommunityApi())),
      );

  testWidgets('feed opens the in-app gallery before the composer',
      (tester) async {
    debugCommunityGalleryLoader =
        _galleryLoader([_galleryItem('one.jpg'), _galleryItem('two.png')]);
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(communityText('Photo')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsOneWidget);
    expect(find.byType(SocialPostComposer), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gallery-item-one.jpg')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('gallery-item-two.png')));
    await tester.pump();
    await tester.tap(find.text('${communityText('Add')} (2)'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsNothing);
    expect(find.byType(SocialPostComposer), findsOneWidget);
    expect(find.text('one.jpg'), findsOneWidget);
    expect(find.text('two.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('canceling gallery selection leaves the user on the feed',
      (tester) async {
    debugCommunityGalleryLoader =
        _galleryLoader([_galleryItem('clip.mp4', video: true)]);
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(communityText('Video')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsOneWidget);
    await tester.tap(find.byTooltip(communityText('Close')));
    await tester.pumpAndSettle();
    expect(find.byType(SocialPostComposer), findsNothing);
    expect(find.byType(SocialFeedScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('composer Photo button opens the in-app gallery', (tester) async {
    debugCommunityGalleryLoader =
        _galleryLoader([_galleryItem('attached.jpg')]);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(home: SocialPostComposer(api: FakeCommunityApi())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText('Photo')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsOneWidget);
    expect(find.text(communityText('Photos')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gallery-item-attached.jpg')));
    await tester.pump();
    await tester.tap(find.text('${communityText('Add')} (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsNothing);
    expect(find.text('attached.jpg'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Post opens the in-app gallery for Photo and Video',
      (tester) async {
    debugCommunityGalleryLoader = _galleryLoader(
        [_galleryItem('one.jpg'), _galleryItem('clip.mp4', video: true)]);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(home: SocialPostComposer(api: FakeCommunityApi())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText('Photo')));
    await tester.pumpAndSettle();
    expect(find.text(communityText('Photos')), findsOneWidget);
    await tester.tap(find.byTooltip(communityText('Close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText('Video')));
    await tester.pumpAndSettle();
    expect(find.text(communityText('Videos')), findsOneWidget);
    await tester.tap(find.byTooltip(communityText('Close')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Story opens the in-app gallery', (tester) async {
    debugCommunityGalleryLoader = _galleryLoader([_galleryItem('story.jpg')]);
    await tester.pumpWidget(
        MaterialApp(home: SocialStoryComposer(api: FakeCommunityApi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText('Photo')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gallery-item-story.jpg')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsNothing);
    expect(find.text(communityText('Share story')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('feed composer opens a writable Create post screen',
      (tester) async {
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText("What's on your mind?")));
    await tester.pumpAndSettle();
    expect(find.byType(SocialPostComposer), findsOneWidget);
    final body = find.byType(TextField).first;
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isTrue);
    expect(
        tester.widget<TextField>(body).controller!.selection.isValid, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(body);
    await tester.enterText(body, 'Posting from the feed');
    await tester.pump();
    expect(find.text('Posting from the feed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tabbed feed opens Create Post with the keyboard visible',
      (tester) async {
    final controller = PersistentTabController();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider()
        ..features = {
          'social_feed.view': '1',
          'social_feed.create': '1',
          'social_feed.stories.view': '0',
        },
      child: MaterialApp(
        home: PersistentTabView(
          controller: controller,
          tabs: [
            PersistentTabConfig(
              item: ItemConfig(icon: const Icon(Icons.dynamic_feed_outlined)),
              screen: SocialFeedScreen(api: FakeCommunityApi()),
            ),
          ],
          navBarBuilder: (_) => const SizedBox(height: 56),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText("What's on your mind?")));
    await tester.pumpAndSettle();
    expect(find.byType(SocialPostComposer), findsOneWidget);
    final body = find.byType(TextField).first;
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Create Story opens ready to type and publishes its caption',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(MaterialApp(home: SocialStoryComposer(api: api)));
    await tester.pumpAndSettle();
    final caption = find.byType(TextField).first;
    expect(tester.widget<TextField>(caption).focusNode!.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(caption);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(caption).focusNode!.hasFocus, isTrue);
    expect(tester.widget<TextField>(caption).controller!.selection.isValid,
        isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(caption, 'Team update');
    await tester.tap(find.text(communityText('Share story')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST social-stories'));
    expect(api.payloads.single?['caption'], 'Team update');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create Story caption accepts typed text after picking media',
      (tester) async {
    debugCommunityGalleryLoader = _galleryLoader([_galleryItem('story.jpg')]);
    await tester.pumpWidget(
        MaterialApp(home: SocialStoryComposer(api: FakeCommunityApi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText('Photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-item-story.jpg')));
    await tester.pumpAndSettle();
    final caption = find.byType(TextField);
    await tester.tap(caption);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(caption, 'Our team offsite');
    await tester.pump();
    expect(find.text('Our team offsite'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Post keeps typed text while adding media from gallery',
      (tester) async {
    debugCommunityGalleryLoader =
        _galleryLoader([_galleryItem('attached.jpg')]);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(home: SocialPostComposer(api: FakeCommunityApi())),
    ));
    await tester.pumpAndSettle();
    final body = find.byType(TextField).first;
    await tester.enterText(body, 'Quarterly update');
    await tester.pump();
    expect(find.text('Quarterly update'), findsOneWidget);
    await tester.tap(find.text(communityText('Photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-item-attached.jpg')));
    await tester.pump();
    await tester.tap(find.text('${communityText('Add')} (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsNothing);
    expect(find.text('Quarterly update'), findsOneWidget);
    await tester.tap(body);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(body, 'Quarterly update!');
    await tester.pump();
    expect(find.text('Quarterly update!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Post typed text stays legible in dark mode',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: SocialPostComposer(api: FakeCommunityApi()),
      ),
    ));
    await tester.pumpAndSettle();
    final body = find.byType(TextField).first;
    final context = tester.element(body);
    expect(
        Theme.of(context).textTheme.bodyLarge?.color, const Color(0xff101828));
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .style
            .color,
        const Color(0xff101828));
    await tester.tap(body);
    await tester.enterText(body, 'Visible in dark mode');
    await tester.pump();
    expect(find.text('Visible in dark mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed gallery file reads show an error and allow retry',
      (tester) async {
    var attempts = 0;
    final file = _galleryItem('retry.jpg');
    final item = CommunityGalleryItem(
      id: file.id,
      isVideo: false,
      width: 100,
      height: 100,
      title: file.title,
      size: 12,
      thumbnail: file.thumbnail,
      file: () async {
        attempts++;
        if (attempts == 1) throw StateError('Media download failed');
        return file.file();
      },
    );
    debugCommunityGalleryLoader = _galleryLoader([item]);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => pickCommunityMedia(context, 'image'),
                      child: const Text('Open gallery')),
                ))));
    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-item-retry.jpg')));
    await tester.pump();
    await tester.tap(find.text('${communityText('Add')} (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMediaPicker), findsOneWidget);
    expect(find.textContaining('Media download failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('${communityText('Add')} (1)'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(CommunityMediaPicker), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Post publishes a Facebook-style white-text background',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(home: SocialPostComposer(api: api)),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Monday motivation');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('post-background-ocean')),
        warnIfMissed: false);
    await tester.pump();
    final editable =
        tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editable.style.color, Colors.white);
    expect(editable.controller.text, 'Monday motivation');
    await tester.tap(find.text(communityText('Publish post')));
    await tester.pumpAndSettle();
    expect(api.payloads.last?['background'], 'ocean');
    expect(api.payloads.last?['body'], 'Monday motivation');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Post restores every saved poll option from drafts',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'social_feed_draft_new': jsonEncode({
        'body': 'Draft poll',
        'poll_enabled': true,
        'poll_question': 'Best day?',
        'poll_closes_at': '2026-11-20 18:30',
        'poll_options': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      })
    });
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(home: SocialPostComposer(api: FakeCommunityApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Option 4'), findsOneWidget);
    expect(find.text('Option 5'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);
    expect(find.text('2026-11-20 18:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Create Post layout fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(home: SocialPostComposer(api: FakeCommunityApi())),
    ));
    await tester.pumpAndSettle();
    expect(find.text(communityText('Publish post')), findsOneWidget);
    expect(find.text('Add to your post'), findsOneWidget);
    await tester.drag(
        find.byWidgetPredicate((widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal),
        const Offset(-320, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityText('Poll')));
    await tester.pumpAndSettle();
    expect(find.text('Create a poll'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
