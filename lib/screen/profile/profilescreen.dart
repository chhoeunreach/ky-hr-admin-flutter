import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/screen/profile/front_side_preview_page.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/profile/basicdetail.dart';
import 'package:cnattendance/widget/profile/bankdetail.dart';
import 'package:cnattendance/widget/profile/companydetail.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/profile/heading.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  @override
  State<StatefulWidget> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  var initalState = true;
  Future<String>? _profileFuture;
  String? _error;

  @override
  void didChangeDependencies() {
    if (initalState) {
      getProfileDetail();
      initalState = false;
    }
    super.didChangeDependencies();
  }

  var isLoading = true;

  Future<String> getProfileDetail() => _profileFuture ??=
      _loadProfile().whenComplete(() => _profileFuture = null);

  Future<String> _loadProfile() async {
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      await context.read<ProfileProvider>().getProfile();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    return 'loaded';
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<ProfileProvider>().profile;
    final showIdCard = context
        .select<DashboardProvider, bool>((p) => p.features['id-card'] == '1');
    final enterprise = EnterpriseTheme.of(context);
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            translate('profile_screen.profile'),
            style: TextStyle(
              color: enterprise.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: IconThemeData(color: enterprise.text),
          actions: [
            if (showIdCard)
              IconButton(
                tooltip: translate('dashboard_screen.view_my_card'),
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed(FrontSidePreviewPage.routeName);
                },
                icon: Icon(Icons.badge_rounded, color: enterprise.text),
              ),
          ],
        ),
        resizeToAvoidBottomInset: true,
        body: RefreshIndicator(
          onRefresh: () {
            return getProfileDetail();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                if (isLoading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        Text(_error!),
                        TextButton(
                            onPressed: getProfileDetail,
                            child: Text(translate('connection_error.retry'))),
                      ])),
                const Heading(),
                if (showIdCard) _buildMyCardButton(context, enterprise),
                userProfile.post != ''
                    ? Container(
                        padding: const EdgeInsets.only(
                            left: 30, right: 30, top: 20, bottom: 10),
                        width: double.infinity,
                        child: Text(
                          translate('profile_screen.basic_details'),
                          style: TextStyle(
                            color: enterprise.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : SizedBox(),
                userProfile.post != '' ? BasicDetail() : SizedBox(),
                userProfile.post != ''
                    ? Container(
                        padding: const EdgeInsets.only(
                            left: 30, right: 30, top: 20, bottom: 10),
                        width: double.infinity,
                        child: Text(
                          translate('profile_screen.company_details'),
                          style: TextStyle(
                            color: enterprise.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : SizedBox(),
                userProfile.post != '' ? CompanyDetail() : SizedBox(),
                userProfile.bankName != ''
                    ? Container(
                        padding: const EdgeInsets.only(
                            left: 30, right: 30, top: 20, bottom: 10),
                        width: double.infinity,
                        child: Text(
                          translate('profile_screen.bank_details'),
                          style: TextStyle(
                            color: enterprise.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : SizedBox(),
                userProfile.bankName != '' ? BankDetail() : SizedBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyCardButton(BuildContext context, EnterpriseTheme enterprise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pushNamed(FrontSidePreviewPage.routeName);
          },
          icon: Icon(Icons.badge_rounded, color: enterprise.accent),
          label: Text(translate('dashboard_screen.view_my_card')),
          style: OutlinedButton.styleFrom(
            foregroundColor: enterprise.text,
            side: BorderSide(color: enterprise.accent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
