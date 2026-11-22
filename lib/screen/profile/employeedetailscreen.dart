import 'package:cnattendance/provider/employeedetailcontroller.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/cartTitle.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({
    super.key,
    this.employeeId,
    this.chatUsername,
    this.chatName = '',
    this.chatAvatar = '',
    this.controller,
  });

  final String? employeeId;
  final String? chatUsername;
  final String chatName;
  final String chatAvatar;
  final EmployeeDetailController? controller;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late final EmployeeDetailController _controller;
  late final String _employeeId;
  Future<EmployeeDetail>? _details;
  EmployeeDetail? _lastDetails;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? EmployeeDetailController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_details != null) return;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final routeId = arguments is Map ? arguments['employeeId'] : null;
    _employeeId = (widget.employeeId ?? routeId?.toString() ?? '').trim();
    _details = _loadDetails();
  }

  Future<EmployeeDetail> _loadDetails() async {
    _loading = true;
    try {
      final details = await _controller.getEmployeeDetail(
        _lastDetails?.employeeId ?? _employeeId,
        username: widget.chatUsername?.trim() ?? '',
      );
      if (mounted) _lastDetails = details;
      return details;
    } finally {
      _loading = false;
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final request = _loadDetails();
    setState(() {
      _details = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  Widget _buildProfileAvatar(String imageUrl) {
    const fallback = ColoredBox(
      color: AppColors.white10,
      child: Center(
        child: Icon(Icons.person, color: AppColors.white70, size: 64),
      ),
    );
    final uri = Uri.tryParse(imageUrl);
    final hasImage = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    return SizedBox(
      width: 180,
      height: 180,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeDetail>(
      future: _details,
      builder: (context, snapshot) {
        final details = _lastDetails;
        final profile = details?.profile;
        final name = (profile?.name.trim().isNotEmpty ?? false)
            ? profile!.name
            : widget.chatName.trim();
        final avatar = (profile?.avatar.trim().isNotEmpty ?? false)
            ? profile!.avatar.trim()
            : widget.chatAvatar.trim();
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          decoration: RadialDecoration(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(name.isEmpty ? _label('profile') : name),
            ),
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(child: _buildProfileAvatar(avatar)),
                  if (loading && details == null)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (snapshot.hasError && !loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          Text(
                            _label('load_failed'),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: Text(translate('royal.retry')),
                          ),
                        ],
                      ),
                    ),
                  if (details != null) ..._buildDetails(details, name, avatar),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDetails(
    EmployeeDetail details,
    String name,
    String avatar,
  ) {
    final profile = details.profile;
    final username = profile.username.trim();
    final phone = profile.phone.trim();
    final canStartChat = widget.chatUsername == null && username.isNotEmpty;

    return [
      if (phone.isNotEmpty || canStartChat)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (phone.isNotEmpty)
              IconButton(
                tooltip: _label('phone_number'),
                onPressed: () async {
                  final url = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                icon: const Icon(Icons.call, color: AppColors.white),
              ),
            if (canStartChat)
              IconButton(
                onPressed: () {
                  Get.to(() => const ChatScreen(), arguments: {
                    'name': name,
                    'avatar': avatar,
                    'username': username,
                    'employeeId': details.employeeId,
                  });
                },
                icon: const Icon(Icons.message, color: AppColors.white),
              ),
          ],
        ),
      ..._section('basic_details', {
        'fullname': name,
        'username': username,
        'phone_number': phone,
        if (details.canViewPrivateDetails) 'dob': profile.dob,
        'gender': profile.gender,
        if (details.canViewPrivateDetails) 'address': profile.address,
      }),
      ..._section('company_details', {
        'job_position': profile.post,
        'branch': profile.branch,
        'department': profile.department,
        'employment_type': profile.employment_type,
        'joined_date': profile.joining_date,
      }),
      if (profile.all_awards.isNotEmpty) ...[
        _heading('achievements'),
        for (final award in profile.all_awards)
          ListTile(
            leading: const Text('🏆'),
            title: Text(award.award_name),
          ),
      ],
    ];
  }

  List<Widget> _section(String title, Map<String, String> fields) {
    final rows = fields.entries
        .where((field) => field.value.trim().isNotEmpty)
        .map((field) => CardTitle(_label(field.key), field.value))
        .toList();

    if (rows.isEmpty) return const [];
    return [
      _heading(title),
      Card(
        shape: ButtonBorder(),
        color: AppColors.white10,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ),
      ),
    ];
  }

  Widget _heading(String key) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
        child: Text(
          _label(key),
          style: const TextStyle(color: AppColors.white70, fontSize: 15),
        ),
      );

  String _label(String key) => translate('employee_detail_screen.$key');
}
