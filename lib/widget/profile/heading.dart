import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/screen/profile/editprofilescreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class Heading extends StatelessWidget {
  const Heading({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final canEdit = context.select<DashboardProvider, bool>(
        (provider) => provider.features['update_profile'] == '1');
    final theme = EnterpriseTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final avatarSize = constraints.maxWidth < 330 ? 80.0 : 112.0;
        final fallback = ColoredBox(
          color: theme.surface,
          child: Icon(Icons.person_outline_rounded,
              color: theme.mutedText, size: 40),
        );
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12)),
                  child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: profile.avatar.isEmpty
                          ? fallback
                          : CachedNetworkImage(
                              imageUrl: profile.avatar,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                              placeholder: (_, __) => fallback,
                              errorWidget: (_, __, ___) => fallback,
                            )),
                ),
              ),
              const SizedBox(height: 14),
              Text(profile.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.mutedText, fontSize: 14)),
              const SizedBox(height: 2),
              Text(profile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: theme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(profile.email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.mutedText, fontSize: 13)),
              if (canEdit)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton(
                          onPressed: profile.phone.isEmpty
                              ? null
                              : () => Navigator.of(context).pushNamed(
                                  EditProfileScreen.routeName),
                          style: TextButton.styleFrom(
                              foregroundColor: theme.secondary,
                              backgroundColor:
                                  theme.secondary.withValues(alpha: .12)),
                          child: Text(translate(
                              'edit_profile_screen.edit_profile')),
                        ))),
            ]);
      }),
    );
  }
}
