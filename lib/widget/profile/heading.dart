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
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      child: LayoutBuilder(builder: (context, constraints) {
        final avatarSize = constraints.maxWidth < 330 ? 80.0 : 112.0;
        final fallback = ColoredBox(
          color: theme.surface,
          child: Icon(Icons.person_outline_rounded,
              color: theme.mutedText, size: 40),
        );
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
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
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(profile.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.mutedText, fontSize: 14)),
                Text(profile.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                Text(profile.email,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.mutedText, fontSize: 13)),
                if (canEdit)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: profile.phone.isEmpty
                            ? null
                            : () => Navigator.of(context)
                                .pushNamed(EditProfileScreen.routeName),
                        style: TextButton.styleFrom(
                            foregroundColor: theme.secondary,
                            backgroundColor:
                                theme.secondary.withValues(alpha: .12)),
                        child:
                            Text(translate('edit_profile_screen.edit_profile')),
                      )),
              ])),
        ]);
      }),
    );
  }
}
