import 'package:cnattendance/data/source/datastore/preferences.dart';

/// Shared feature-flag checks for the Asset Management module.
///
/// Semantics are intentionally kept identical to the previous per-call sites:
/// - [canOpenAdminAsync] mirrors the MoreScreen / drawer "admin entry" gate
///   (AND of every known admin key being absent-or-not-'0').
/// - [crud] mirrors [AdminAssetListController]'s granular create/edit/delete
///   computation (OR of '1' flags, admin grants, absent-key fallback).
class AssetPermissions {
  AssetPermissions._();

  static Future<Map<String, String>> _features() => Preferences().getFeatures();

  /// Whether the admin Asset Management entry points should be visible.
  static bool canOpenAdmin(Map<String, String> features) =>
      features['assets-admin'] != '0' &&
      features['asset_management'] != '0' &&
      features['asset-management'] != '0' &&
      features['list_assets'] != '0';

  static Future<bool> canOpenAdminAsync() =>
      _features().then(canOpenAdmin);

  /// Granular CRUD abilities for the admin list/detail screens.
  static Future<({bool create, bool edit, bool delete})> crud() async {
    final features = await _features();
    if (features.isEmpty) {
      return (create: true, edit: true, delete: true);
    }

    final hasAssetAdmin = features['assets-admin'] == '1' ||
        features['asset-management'] == '1' ||
        features['asset_management'] == '1' ||
        features['assets'] == '1' ||
        features['ASSETS'] == '1' ||
        features['list_assets'] == '1';

    return (
      create: features['create_assets'] == '1' ||
          features['add_assets'] == '1' ||
          hasAssetAdmin ||
          !features.containsKey('create_assets'),
      edit: features['edit_assets'] == '1' ||
          features['update_assets'] == '1' ||
          hasAssetAdmin ||
          !features.containsKey('edit_assets'),
      delete: features['delete_assets'] == '1' ||
          hasAssetAdmin ||
          !features.containsKey('delete_assets'),
    );
  }
}
