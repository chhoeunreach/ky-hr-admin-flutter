import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:cnattendance/core/ky_security/ky_pairing_message.dart';
import 'package:cnattendance/core/ky_security/ky_optional_update_prompt.dart';
import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Explains server-side installation decisions after successful account login.
class SecurityGateScreen extends StatefulWidget {
  const SecurityGateScreen({super.key, required this.initialState});
  final Map<String, dynamic> initialState;

  @override
  State<SecurityGateScreen> createState() => _SecurityGateScreenState();
}

class _SecurityGateScreenState extends State<SecurityGateScreen> {
  late Map<String, dynamic> _state = widget.initialState;
  bool _checking = false;
  bool _signingOut = false;

  String get _status => '${_state['state'] ?? 'restricted'}';

  String get _message => switch (_status) {
        'pendingApproval' =>
          'This installation is waiting for an administrator to approve it.',
        'mandatoryUpdate' =>
          'Install the latest official KNEAYERNG app to continue.',
        'blocked' =>
          'This installation is blocked. Contact your administrator.',
        'revoked' =>
          'This installation has been revoked. Contact your administrator.',
        'releaseVerificationFailed' =>
          'The app release could not be verified. Install the official app or contact support.',
        'unsupportedAndroid' =>
          'This Android version or security patch does not meet device policy. Update Android or use a supported device.',
        'sessionExpired' =>
          'A secure session could not be opened. Please retry.',
        'offlineRestricted' => kyPairingMessage(
            _state['reason'] as String?,
            status: _state['status'] as int?,
          ),
        'offlineAuthorized' =>
          'Offline access is temporarily available using your recent server authorization.',
        'registrationRequired' =>
          'This installation could not be registered. If you reinstalled the app or lost or reset its secure key, contact your administrator to verify your account and retire the old device registration or approve a secure re-registration. After they confirm, tap Check again. Do not keep retrying while the old registration is still active.',
        _ => 'This installation is not authorized to access the app.',
      };

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      final latest = await KySecurityManager.shared.initialize();
      if (!mounted) return;
      setState(() => _state = latest);
      if (latest['state'] == 'authorized' ||
          latest['state'] == 'offlineAuthorized' ||
          latest['state'] == 'disabled' ||
          !KySecurityManager.shared.securityApplies) {
        await context.read<DashboardProvider>().getFeatures();
        if (!mounted) return;
        final optionalUpdate = latest['optional_update'];
        if (optionalUpdate is Map) {
          await KyOptionalUpdatePrompt.show(
            context,
            Map<String, dynamic>.from(optionalUpdate),
          );
          if (!mounted) return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
            DashboardScreen.routeName, (route) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _state = {'state': 'offlineRestricted'});
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openOfficialDownload() async {
    final url = _state['latest_release'] is Map
        ? (_state['latest_release'] as Map)['download_url'] as String?
        : null;
    final uri = Uri.tryParse(url ?? 'https://kneayerng.com/app');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await context.read<MoreScreenProvider>().logout();
      if (!mounted) return;
      await context.read<Auth>().resetAppUrl();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign out: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mandatory = _status == 'mandatoryUpdate';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _status == 'pendingApproval'
                        ? Icons.pending_actions_rounded
                        : Icons.shield_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    mandatory ? 'App update required' : 'App security check',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(_message, textAlign: TextAlign.center),
                  if (_state['risk_score'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Risk score: ${_state['risk_score']}'),
                  ],
                  const SizedBox(height: 24),
                  if (mandatory)
                    FilledButton.icon(
                      onPressed: _openOfficialDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Download official app'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _retry,
                    icon: _checking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_checking ? 'Checking…' : 'Check again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _signingOut ? null : _signOut,
                    icon: _signingOut
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_signingOut ? 'Signing out…' : 'Sign out'),
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
