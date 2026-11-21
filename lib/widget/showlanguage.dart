import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ShowLanguage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: enterprise.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: enterprise.cardBorder),
      ),
      height: 500,
      padding: const EdgeInsets.all(20) +
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    translate('common.select_language'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: enterprise.text,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Icon(Icons.close, color: enterprise.text),
                  )
                ],
              ),
            ),
            languageCard(context, enterprise, "ខ្មែរ", "🇰🇭", "km"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "English", "🇺🇸", "en"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "русский", "🇷🇺", "ru"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "Española", "🇪🇸", "es"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "فារسی", "🇮🇷", "fa"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "हिंदी", "🇮🇳", "in"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "Turkish", "🇹🇷", "tr"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "Deutsch", "🇩🇪", "de"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "Français", "🇫🇷", "fr"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "नेपाली", "🇳🇵", "ne"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "عربي", "🇦🇪", "ar"),
            Divider(
              endIndent: 10,
              indent: 10,
              height: 1,
              color: enterprise.cardBorder,
            ),
            languageCard(context, enterprise, "Português", "🇵🇹", "pt"),
          ],
        ),
      ),
    );
  }

  Widget languageCard(BuildContext context, EnterpriseTheme enterprise,
      String title, String flag, String language) {
    final storage = GetStorage();
    final currentLang = storage.read("language") ?? "km";
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 5),
      dense: false,
      visualDensity: VisualDensity.compact,
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 20),
      ),
      trailing: language == currentLang
          ? Icon(
              Icons.check,
              color: enterprise.accent,
            )
          : const SizedBox.shrink(),
      title: Text(
        title,
        style: TextStyle(
          color: enterprise.text,
          fontWeight: language == currentLang ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        final storage = GetStorage();
        storage.write("language", language);
        changeLocale(context, language);
        Get.updateLocale(Locale(language));
      },
    );
  }
}
