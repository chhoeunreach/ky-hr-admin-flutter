import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/models/id_card_profile.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/services/id_card_api_service.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class IdCardScreen extends StatefulWidget {
  static const String routeName = '/my-id-card';

  const IdCardScreen({Key? key}) : super(key: key);

  @override
  State<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends State<IdCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  final IdCardApiService _apiService = IdCardApiService();
  IdCardProfile? _card;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCard);
  }

  Future<void> _loadCard() async {
    try {
      final card = await _apiService.fetchMyCard();
      if (!mounted) return;
      setState(() {
        _card = card;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadCard(IdCardProfile card) async {
    try {
      EasyLoading.show(status: 'Preparing card...');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Card is not ready yet');

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw Exception('Unable to create card image');

      EasyLoading.dismiss();
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'my_card_${card.employeeCode}.png',
            mimeType: 'image/png',
          ),
        ],
        text: 'My KNEAYERNG card',
      );
    } catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download card: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final card = _card ?? IdCardProfile.fromProfile(profile);

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('My Card'),
          actions: [
            IconButton(
              tooltip: 'Download',
              onPressed: () => _downloadCard(card),
              icon: const Icon(Icons.download_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Center(
              child: Column(
                children: [
                  if (_isLoading) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _KyCard.gold,
                    ),
                    const SizedBox(height: 12),
                  ],
                  RepaintBoundary(
                    key: _cardKey,
                    child: _KyCard(card: card),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadCard(card),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Card'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _KyCard.gold,
                        foregroundColor: _KyCard.navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
    );
  }
}

class _KyCard extends StatelessWidget {
  const _KyCard({required this.card});

  static const Color navy = Color(0xff071326);
  static const Color gold = Color(0xffd6aa27);
  static const Color muted = Color(0xff758094);

  final IdCardProfile card;

  String get _name => _value(card.name, 'ឈ្មោះបុគ្គលិក');
  String get _englishName => card.englishName.trim().toUpperCase();
  String get _position => _value(card.position, 'បុគ្គលិក');
  String get _branch => _value(card.branch, 'គ្នាយើង');
  String get _department => _value(card.department, 'PHONE SHOP');
  String get _phone => _value(card.phone, '-');
  String get _employeeId => _value(card.employeeCode, 'KY-00000');

  static String _value(String value, String fallback) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 550 / 790,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          double sx(double value) => w * value / 550;
          double sy(double value) => h * value / 790;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(sx(28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: const _CardBackgroundPainter(),
              child: Stack(
                children: [
                  Positioned(
                    left: sx(25),
                    top: sy(25),
                    width: sx(82),
                    height: sx(82),
                    child: _BranchLogoBadge(logoUrl: card.branchLogoUrl),
                  ),
                  Positioned(
                    left: sx(24),
                    top: sy(128),
                    width: sx(108),
                    child: const _SideBrandBlock(),
                  ),
                  Positioned(
                    left: sx(58),
                    top: sy(235),
                    height: sy(276),
                    child: const RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'KNEAYERNG PHONE SHOP',
                        style: TextStyle(
                          color: gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: sx(36),
                    top: sy(565),
                    child: const _DotGrid(columns: 4, rows: 5, dotSize: 8),
                  ),
                  Positioned(
                    right: sx(34),
                    top: sy(115),
                    child: const _DotGrid(columns: 3, rows: 5, dotSize: 8),
                  ),
                  Positioned(
                    left: sx(205),
                    top: sy(41),
                    width: sx(258),
                    height: sy(338),
                    child: _Portrait(photoUrl: card.photoUrl),
                  ),
                  Positioned(
                    left: sx(205),
                    top: sy(389),
                    width: sx(258),
                    child: _NameBlock(name: _name, englishName: _englishName),
                  ),
                  Positioned(
                    left: sx(205),
                    top: sy(452),
                    width: sx(258),
                    child: _PositionPill(position: _position),
                  ),
                  Positioned(
                    left: sx(192),
                    top: sy(493),
                    width: sx(278),
                    child: Column(
                      children: [
                        _InfoRow(label: 'សាខា', value: _branch),
                        _InfoRow(label: 'ផ្នែក', value: _department),
                        _InfoRow(label: 'ទូរស័ព្ទ', value: _phone),
                      ],
                    ),
                  ),
                  Positioned(
                    left: sx(36),
                    top: sy(620),
                    child: _QrTile(
                      label: 'WEBSITE QR',
                      url: card.websiteQrUrl,
                      borderColor: gold,
                    ),
                  ),
                  Positioned(
                    left: sx(163),
                    top: sy(620),
                    child: _QrTile(
                      label: 'TELEGRAM QR',
                      url: card.telegramQrUrl,
                      borderColor: const Color(0xff17a7e7),
                      showSendMark: true,
                    ),
                  ),
                  Positioned(
                    left: sx(276),
                    top: sy(700),
                    width: sx(230),
                    child: _EmployeeCode(employeeId: _employeeId),
                  ),
                  Positioned(
                    left: sx(277),
                    right: sx(22),
                    top: sy(740),
                    child: _WebsitePill(website: card.companyWebsite),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BranchLogoBadge extends StatelessWidget {
  const _BranchLogoBadge({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _KyCard.gold, width: 4),
      ),
      child: ClipOval(
        child: logoUrl.trim().isEmpty
            ? Image.asset('assets/images/logo.png', fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _SideBrandBlock extends StatelessWidget {
  const _SideBrandBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'គ្នាយើង',
          maxLines: 1,
          style: TextStyle(
            color: _KyCard.gold,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'KNEAYERNG',
          style: TextStyle(
            color: _KyCard.gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: 5),
        SizedBox(width: 82, child: Divider(height: 1, color: Colors.white70)),
        SizedBox(height: 7),
        Text(
          'PHONE SHOP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff4f1ec),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _KyCard.gold, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3b000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.trim().isEmpty
          ? const Icon(Icons.person, size: 96, color: _KyCard.muted)
          : CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const ColoredBox(
                color: Color(0xfff4f1ec),
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.person, size: 96, color: _KyCard.muted),
            ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.name, required this.englishName});

  final String name;
  final String englishName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _KyCard.navy,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        if (englishName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            englishName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _KyCard.gold,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _PositionPill extends StatelessWidget {
  const _PositionPill({required this.position});

  final String position;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: _KyCard.navy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _KyCard.gold, width: 2),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'មុខតំណែង:',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _KyCard.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 22, color: _KyCard.gold),
          Expanded(
            child: Center(
              child: Text(
                position,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _KyCard.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _KyCard.gold, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: _KyCard.navy, size: 28),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _KyCard.navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(width: 1, height: 18, color: _KyCard.gold),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _KyCard.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrTile extends StatelessWidget {
  const _QrTile({
    required this.label,
    required this.url,
    required this.borderColor,
    this.showSendMark = false,
  });

  final String label;
  final String url;
  final Color borderColor;
  final bool showSendMark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 102,
              height: 102,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 3),
              ),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.qr_code_2_rounded,
                  color: _KyCard.navy,
                  size: 62,
                ),
              ),
            ),
            if (showSendMark)
              Positioned(
                right: -6,
                top: -8,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: const BoxDecoration(
                    color: Color(0xff17a7e7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.north_east_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: borderColor,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _EmployeeCode extends StatelessWidget {
  const _EmployeeCode({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'ID NO : '),
          TextSpan(
            text: employeeId,
            style: const TextStyle(color: _KyCard.gold),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _WebsitePill extends StatelessWidget {
  const _WebsitePill({required this.website});

  final String website;

  @override
  Widget build(BuildContext context) {
    final text = website.trim().isEmpty ? 'www.kneayerng.com' : website.trim();

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: _KyCard.gold,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.language, size: 12, color: _KyCard.navy),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _KyCard.navy,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid({
    required this.columns,
    required this.rows,
    required this.dotSize,
  });

  final int columns;
  final int rows;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columns * (dotSize + 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(
          columns * rows,
          (_) => Container(
            width: dotSize,
            height: dotSize,
            decoration: const BoxDecoration(
              color: Color(0xffeef3f7),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBackgroundPainter extends CustomPainter {
  const _CardBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final navyPaint = Paint()..color = _KyCard.navy;
    final goldPaint = Paint()
      ..color = _KyCard.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final creamPaint = Paint()
      ..color = const Color(0xfff5e8b7).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.32, 0)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.18,
        size.width * 0.22,
        size.height * 0.30,
        size.width * 0.22,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.64,
        size.width * 0.30,
        size.height * 0.73,
        size.width * 0.31,
        size.height * 0.84,
      )
      ..lineTo(size.width * 0.30, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(leftPath, navyPaint);

    final leftGold = Path()
      ..moveTo(size.width * 0.32, 0)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.18,
        size.width * 0.22,
        size.height * 0.30,
        size.width * 0.22,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.64,
        size.width * 0.30,
        size.height * 0.73,
        size.width * 0.31,
        size.height * 0.84,
      );
    canvas.drawPath(leftGold, goldPaint);

    final leftCream = Path()
      ..moveTo(size.width * 0.33, 0)
      ..cubicTo(
        size.width * 0.31,
        size.height * 0.18,
        size.width * 0.24,
        size.height * 0.31,
        size.width * 0.24,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.64,
        size.width * 0.31,
        size.height * 0.73,
        size.width * 0.32,
        size.height * 0.84,
      );
    canvas.drawPath(leftCream, creamPaint);

    final bottomPath = Path()
      ..moveTo(0, size.height * 0.825)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.79,
        size.width * 0.73,
        size.height * 0.79,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottomPath, navyPaint);

    final bottomGold = Path()
      ..moveTo(0, size.height * 0.825)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.79,
        size.width * 0.73,
        size.height * 0.79,
        size.width,
        size.height * 0.84,
      );
    canvas.drawPath(bottomGold, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
