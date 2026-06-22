import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SplashState();
}

class SplashState extends State<SplashScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final preferences = Preferences();
      if (await preferences.getHardReset()) {
        await preferences.clearPrefs();
        await preferences.saveHardReset(false);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      } else {
        final routeName = await preferences.getToken() == ''
            ? LoginScreen.routeName
            : DashboardScreen.routeName;
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, routeName);
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Center(
          child: Image.asset(
        "assets/icons/logo_bnw.png",
        width: 120,
        height: 120,
      )),
    );
  }
}
