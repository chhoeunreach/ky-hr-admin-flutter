import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:cnattendance/models/id_card_profile.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/services/id_card_api_service.dart';
import 'package:cnattendance/utils/card_file_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class FrontSidePreviewPage extends StatefulWidget {
  static const String routeName = '/front-side-preview';

  const FrontSidePreviewPage({Key? key}) : super(key: key);

  @override
  State<FrontSidePreviewPage> createState() => _FrontSidePreviewPageState();
}

class _FrontSidePreviewPageState extends State<FrontSidePreviewPage> {
  final GlobalKey _cardKey = GlobalKey();
  final IdCardApiService _apiService = IdCardApiService();
  IdCardProfile? _card;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCard);
  }

  Future<void> _loadCard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final card = await _apiService.fetchMyCard();
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _downloadCard(IdCardProfile card) async {
    try {
      EasyLoading.show(status: 'Preparing card...');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Card is not ready yet');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw Exception('Unable to create card image');
      }

      EasyLoading.dismiss();
      await exportPngFile(
        bytes: bytes,
        fileName: 'kneayerng_card_${card.employeeCode}.png',
        text: 'KNEAYERNG ID Card',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (error) {
      EasyLoading.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download card: $error')),
      );
    }
  }

  Rect _sharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final origin = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      if (size.width > 0 && size.height > 0) {
        return origin & size;
      }
    }

    final screenSize = MediaQuery.maybeSizeOf(context) ?? const Size(1, 1);
    return Rect.fromLTWH(
      screenSize.width / 2,
      screenSize.height / 2,
      1,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackProfile = context.watch<ProfileProvider>().profile;
    final card = _card ?? IdCardProfile.fromProfile(fallbackProfile);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: _FrontCardPainter.navy,
        elevation: 0,
        title: Text(translate('more_screen.my_id_card')),
        actions: [
          IconButton(
            tooltip: translate('common.refresh'),
            onPressed: _loadCard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: translate('common.download'),
            onPressed: _loading ? null : () => _downloadCard(card),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const outerPadding = 16.0;
            const warningHeight = 52.0;
            const buttonHeight = 48.0;
            final showWarning = _error != null && _card == null;
            final availableWidth = math.max(0.0, constraints.maxWidth - 32);
            final availableHeight = math.max(
              0.0,
              constraints.maxHeight -
                  (outerPadding * 2) -
                  buttonHeight -
                  12 -
                  (showWarning ? warningHeight + 8 : 0),
            );
            final maxCardWidth = math.min(
              availableWidth,
              availableHeight * 71 / 103,
            );

            return Padding(
              padding: const EdgeInsets.all(outerPadding),
              child: Column(
                children: [
                  if (showWarning) ...[
                    SizedBox(
                      height: warningHeight,
                      child: _LoadWarning(onRetry: _loadCard),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: maxCardWidth <= 0 ? 360 : maxCardWidth,
                          child: AspectRatio(
                            aspectRatio: 71 / 103,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                RepaintBoundary(
                                  key: _cardKey,
                                  child: _FrontIdCard(card: card),
                                ),
                                if (_loading)
                                  const Positioned.fill(
                                    child: ColoredBox(
                                      color: AppColors.custom44FFFFFF,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: _FrontCardPainter.gold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : () => _downloadCard(card),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Card'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _FrontCardPainter.gold,
                        foregroundColor: _FrontCardPainter.navy,
                        disabledBackgroundColor:
                            _FrontCardPainter.gold.withValues(alpha: 0.45),
                        disabledForegroundColor:
                            _FrontCardPainter.navy.withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FrontIdCard extends StatelessWidget {
  const _FrontIdCard({required this.card});

  final IdCardProfile card;

  String get employeeCode => _fallback(card.employeeCode, 'KY-00000');
  String get khmerName => _fallback(card.name, 'ឈ្មោះបុគ្គលិក');
  String get englishName => card.englishName.trim().toUpperCase();
  String get position => _fallback(
        card.position,
        card.positionEnglish,
        card.positionKhmer,
        'បុគ្គលិក',
      );
  String get branch => _fallback(card.branch, 'គ្នាយើង');
  String get department => _fallback(card.department, 'PHONE SHOP');
  String get phone => _fallback(card.phone, '-');

  static String _fallback(String first,
      [String? second, String? third, String? fallback]) {
    for (final value in [first, second, third, fallback]) {
      final cleaned = value?.trim() ?? '';
      if (cleaned.isNotEmpty) return cleaned;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          double x(double value) => w * value;
          double y(double value) => h * value;

          return ColoredBox(
            color: _FrontCardPainter.background,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: const _FrontCardPainter()),
                ),
                Positioned(
                  left: x(0.047),
                  top: y(0.025),
                  width: x(0.142),
                  height: x(0.142),
                  child: _RoundLogo(url: card.branchLogoUrl),
                ),
                Positioned(
                  left: x(0.044),
                  top: y(0.14),
                  width: x(0.19),
                  child: const _BrandCopy(),
                ),
                Positioned(
                  left: x(0.105),
                  top: y(0.29),
                  height: y(0.34),
                  child: const RotatedBox(
                    quarterTurns: 3,
                    child: _FitText(
                      'KNEAYERNG PHONE SHOP',
                      color: _FrontCardPainter.lightGold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Positioned(
                  left: x(0.37),
                  top: y(0.035),
                  width: x(0.48),
                  height: y(0.32),
                  child: _EmployeePhoto(url: card.photoUrl),
                ),
                Positioned(
                  left: x(0.36),
                  top: y(0.358),
                  width: x(0.50),
                  height: y(0.083),
                  child: _NameBlock(
                    khmerName: khmerName,
                    englishName: englishName,
                  ),
                ),
                Positioned(
                  left: x(0.36),
                  top: y(0.455),
                  width: x(0.50),
                  height: y(0.039),
                  child: _PositionPill(position: position),
                ),
                Positioned(
                  left: x(0.34),
                  top: y(0.515),
                  width: x(0.54),
                  height: y(0.17),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _DetailRow(label: 'សាខា', value: branch)),
                      Expanded(
                        child: _DetailRow(label: 'ផ្នែក', value: department),
                      ),
                      Expanded(
                        child: _DetailRow(label: 'ទូរស័ព្ទ', value: phone),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: x(0.065),
                  top: y(0.765),
                  width: x(0.18),
                  child: _QrBlock(
                    label: 'WEBSITE QR',
                    data: card.websiteQrData,
                    borderColor: _FrontCardPainter.gold,
                  ),
                ),
                Positioned(
                  left: x(0.295),
                  top: y(0.765),
                  width: x(0.18),
                  child: _QrBlock(
                    label: 'TELEGRAM QR',
                    data: card.telegramQrData,
                    borderColor: AppColors.customFF17A7E7,
                    sendBadge: true,
                  ),
                ),
                Positioned(
                  left: x(0.50),
                  right: x(0.07),
                  top: y(0.883),
                  height: y(0.028),
                  child: _EmployeeCodeText(employeeCode: employeeCode),
                ),
                Positioned(
                  left: x(0.50),
                  right: x(0.04),
                  top: y(0.935),
                  height: y(0.034),
                  child: _WebsitePill(text: card.companyWebsiteDisplay),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BrandCopy extends StatelessWidget {
  const _BrandCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FitText(
          'គ្នាយើង',
          color: _FrontCardPainter.lightGold,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          maxLines: 1,
        ),
        SizedBox(height: 4),
        _FitText(
          'KNEAYERNG',
          color: _FrontCardPainter.lightGold,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          maxLines: 1,
        ),
        SizedBox(height: 4),
        Divider(height: 1, color: AppColors.white70),
        SizedBox(height: 7),
        _FitText(
          'PHONE SHOP',
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _RoundLogo extends StatelessWidget {
  const _RoundLogo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _FrontCardPainter.lightGold, width: 4),
      ),
      child: ClipOval(
        child: _NetworkOrAssetImage(
          url: url,
          fit: BoxFit.cover,
          fallbackAsset: 'assets/images/logo.png',
        ),
      ),
    );
  }
}

class _EmployeePhoto extends StatelessWidget {
  const _EmployeePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.customFFEEE7DB,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _FrontCardPainter.gold, width: 4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.custom36000000,
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _NetworkOrAssetImage(
          url: url,
          fit: BoxFit.cover,
          fallbackAsset: 'assets/images/dummy_avatar.png',
        ),
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.khmerName, required this.englishName});

  final String khmerName;
  final String englishName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: _FitText(
              khmerName,
              color: _FrontCardPainter.navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (englishName.isNotEmpty)
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.topCenter,
              child: _FitText(
                englishName,
                color: _FrontCardPainter.gold,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _PositionPill extends StatelessWidget {
  const _PositionPill({required this.position});

  final String position;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _FrontCardPainter.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _FrontCardPainter.gold, width: 2),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: _FitText(
                'មុខតំណែង:',
                color: _FrontCardPainter.lightGold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                maxLines: 1,
              ),
            ),
          ),
          Container(width: 1.2, color: _FrontCardPainter.gold),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _FitText(
                  position,
                  color: _FrontCardPainter.lightGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _FrontCardPainter.gold, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: _FrontCardPainter.navy, size: 22),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _FitText(
              label,
              color: _FrontCardPainter.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              maxLines: 1,
            ),
          ),
          Container(width: 1.2, height: 16, color: _FrontCardPainter.gold),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _FitText(
              value,
              color: _FrontCardPainter.navy,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({
    required this.label,
    required this.data,
    required this.borderColor,
    this.sendBadge = false,
  });

  final String label;
  final String data;
  final Color borderColor;
  final bool sendBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 2.6),
                ),
                child: QrImageView(
                  data:
                      data.trim().isEmpty ? 'https://www.kneayerng.com' : data,
                  backgroundColor: AppColors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
              if (sendBadge)
                Positioned(
                  right: -7,
                  top: -9,
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: const BoxDecoration(
                      color: AppColors.customFF17A7E7,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.north_east_rounded,
                      color: AppColors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        _FitText(
          label,
          color: borderColor,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EmployeeCodeText extends StatelessWidget {
  const _EmployeeCodeText({required this.employeeCode});

  final String employeeCode;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'ID NO : '),
            TextSpan(
              text: employeeCode,
              style: const TextStyle(color: _FrontCardPainter.lightGold),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _WebsitePill extends StatelessWidget {
  const _WebsitePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _FrontCardPainter.gold,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language, size: 12, color: _FrontCardPainter.navy),
            const SizedBox(width: 8),
            Expanded(
              child: _FitText(
                text,
                color: _FrontCardPainter.navy,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkOrAssetImage extends StatelessWidget {
  const _NetworkOrAssetImage({
    required this.url,
    required this.fit,
    required this.fallbackAsset,
  });

  final String url;
  final BoxFit fit;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Image.asset(fallbackAsset, fit: fit);
    }

    return Image(
      image: NetworkImage(url),
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(fallbackAsset, fit: fit);
      },
    );
  }
}

class _FitText extends StatelessWidget {
  const _FitText(
    this.text, {
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.letterSpacing = 0,
    this.maxLines = 1,
    this.textAlign,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.right
          ? Alignment.centerRight
          : textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          fontFamilyFallback: const [
            'Noto Sans Khmer',
            'Battambang',
            'Khmer OS',
            'Arial',
          ],
        ),
      ),
    );
  }
}

class _LoadWarning extends StatelessWidget {
  const _LoadWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _FrontCardPainter.navy),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Card API not loaded. Showing profile fallback.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _FrontCardPainter extends CustomPainter {
  const _FrontCardPainter();

  static const Color navy = AppColors.customFF0B172A;
  static const Color gold = AppColors.customFFC59B27;
  static const Color lightGold = AppColors.customFFF3D36B;
  static const Color background = AppColors.customFFFAF8F5;

  @override
  void paint(Canvas canvas, Size size) {
    final navyPaint = Paint()..color = navy;
    final goldPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.007;

    final leftPanel = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.29, 0)
      ..cubicTo(
        size.width * 0.285,
        size.height * 0.18,
        size.width * 0.215,
        size.height * 0.31,
        size.width * 0.215,
        size.height * 0.49,
      )
      ..cubicTo(
        size.width * 0.215,
        size.height * 0.64,
        size.width * 0.29,
        size.height * 0.72,
        size.width * 0.30,
        size.height * 0.84,
      )
      ..lineTo(size.width * 0.31, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(leftPanel, navyPaint);

    final divider = Path()
      ..moveTo(size.width * 0.29, 0)
      ..cubicTo(
        size.width * 0.285,
        size.height * 0.18,
        size.width * 0.215,
        size.height * 0.31,
        size.width * 0.215,
        size.height * 0.49,
      )
      ..cubicTo(
        size.width * 0.215,
        size.height * 0.64,
        size.width * 0.29,
        size.height * 0.72,
        size.width * 0.30,
        size.height * 0.84,
      );
    canvas.drawPath(divider, goldPaint);

    final bottomWave = Path()
      ..moveTo(0, size.height * 0.826)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.785,
        size.width * 0.70,
        size.height * 0.79,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottomWave, navyPaint);

    final bottomDivider = Path()
      ..moveTo(0, size.height * 0.826)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.785,
        size.width * 0.70,
        size.height * 0.79,
        size.width,
        size.height * 0.84,
      );
    canvas.drawPath(bottomDivider, goldPaint);

    _drawDots(canvas, size, Offset(size.width * 0.065, size.height * 0.72), 4,
        5, AppColors.white.withValues(alpha: 0.28));
    _drawDots(canvas, size, Offset(size.width * 0.86, size.height * 0.14), 3, 5,
        AppColors.customFFEEF3F7);
  }

  void _drawDots(
    Canvas canvas,
    Size size,
    Offset origin,
    int columns,
    int rows,
    Color color,
  ) {
    final paint = Paint()..color = color;
    final radius = size.width * 0.0075;
    final gap = size.width * 0.035;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        canvas.drawCircle(
          Offset(origin.dx + col * gap, origin.dy + row * gap),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
