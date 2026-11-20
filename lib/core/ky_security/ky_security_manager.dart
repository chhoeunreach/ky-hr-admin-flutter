import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/core/ky_security/ky_certificate_pinning.dart';
import 'package:cnattendance/core/ky_security/ky_offline_authorization_lease.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Android Keystore backed device registration client.
///
/// The client remains fail-open only while the server explicitly reports that
/// enforcement is disabled. Once enabled, API access requires registration and
/// an authorized device session.
class KySecurityManager {
  static final KySecurityManager shared = KySecurityManager();
  KySecurityManager({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _client = client ?? KyCertificatePinning.sharedClient;

  static const _native = MethodChannel('kneayerng/ky_security');
  static const _installationKey = 'ky_security_installation_uuid_v1';
  final Preferences _preferences;
  final http.Client _client;
  String? _root;
  String? _deviceId;
  String? _sessionId;
  String? _sessionToken;
  String? _refreshToken;
  String? _activeKeyAlias;
  int? _activeUserId;
  DateTime? _sessionExpiresAt;
  Map<String, dynamic>? _authorizationState;
  Future<Map<String, dynamic>>? _authorizationFlight;
  DateTime? _authorizationCheckedAt;
  bool _serverSecurityEnabled = false;
  int _offlineGraceSeconds = 0;
  int? _lastSessionOpenStatus;
  Map<String, dynamic>? _optionalUpdate;

  bool get enforcementEnabled => _serverSecurityEnabled;
  bool get securityApplies => Platform.isAndroid;
  Map<String, dynamic>? get optionalUpdate => _optionalUpdate;

  Future<Map<String, dynamic>> initialize() async {
    try {
      return await _initializeOnline();
    } catch (error) {
      if (_isOfflineTransportFailure(error)) {
        return _offlineAuthorizationState();
      }
      if (error is TlsException || error is HandshakeException) {
        return _pairingFailure('tls_verification_failed');
      }
      if (error is PlatformException || error is MissingPluginException) {
        return _pairingFailure('device_security_unavailable');
      }
      return _pairingFailure('security_check_failed');
    }
  }

  bool _isOfflineTransportFailure(Object error) {
    if (error is TimeoutException || error is SocketException) return true;
    if (error is http.ClientException) {
      final message = error.toString().toLowerCase();
      return message.contains('failed host lookup') ||
          message.contains('connection timed out') ||
          message.contains('network is unreachable') ||
          message.contains('connection refused') ||
          message.contains('connection reset') ||
          message.contains('connection closed before full header') ||
          message.contains('software caused connection abort');
    }
    return false;
  }

  static String? pairingTransportProblem(Uri base) {
    final localDebug = kDebugMode &&
        !KyCertificatePinning.enabled &&
        base.scheme == 'http' &&
        const {'127.0.0.1', 'localhost', '::1'}.contains(base.host);
    if (base.scheme != 'https' && !localDebug) return 'https_required';
    if (KyCertificatePinning.enabled) {
      if (!KyCertificatePinning.protectsHost(base.host))
        return 'api_host_not_pinned';
      if (!KyCertificatePinning.hasUsablePinSet) {
        return 'pinning_not_configured';
      }
    }
    return null;
  }

  static Map<String, dynamic> _pairingFailure(String reason, [int? status]) => {
        'state': 'offlineRestricted',
        'reason': reason,
        if (status != null) 'status': status,
      };

  Future<Map<String, dynamic>> _initializeOnline() async {
    if (!securityApplies) {
      return {'state': 'restricted', 'reason': 'android_required'};
    }
    final base = Uri.parse(await _preferences.getAppUrl());
    final transportReason = pairingTransportProblem(base);
    if (transportReason != null) return _pairingFailure(transportReason);

    final root =
        '${base.toString().replaceFirst(RegExp(r'/+$'), '')}/api/app-security/v1';
    if (_root != null && _root != root) clearLocalSession();
    _root = root;
    final request = http.Request('GET', Uri.parse('$root/config'))
      ..headers['Accept'] = 'application/json'
      ..followRedirects = false;
    final policyResponse = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 6));
    final statusCode = policyResponse.statusCode;
    if (statusCode != 200) {
      if (statusCode == 404 || statusCode == 405) {
        return _pairingFailure('security_endpoint_missing', statusCode);
      }
      if (statusCode >= 300 && statusCode < 400) {
        return _pairingFailure('security_endpoint_redirected', statusCode);
      }
      if (statusCode >= 500 && base.scheme == 'https') {
        return _offlineAuthorizationState(
            reason: 'security_server_error', status: statusCode);
      }
      return _pairingFailure('security_server_error', statusCode);
    }

    final dynamic policy;
    try {
      policy = jsonDecode(policyResponse.body);
    } on FormatException {
      return _pairingFailure('security_response_invalid');
    }
    if (policy is! Map || policy['enabled'] is! bool) {
      return _pairingFailure('security_response_invalid');
    }
    if (policy['enabled'] == false) {
      clearLocalSession();
      _root = root;
      _offlineGraceSeconds = 0;
      return {'state': 'disabled'};
    }
    if (base.scheme != 'https') return _pairingFailure('https_required');
    _serverSecurityEnabled = true;
    _offlineGraceSeconds = (policy['offline_grace_seconds'] as num?)
            ?.toInt()
            .clamp(0, 86400)
            .toInt() ??
        0;
    if (_offlineGraceSeconds == 0) _clearOfflineLease();

    final identity = await _native.invokeMapMethod<String, dynamic>('identity');
    if (identity == null || identity['packageName'] != 'com.kneayerng.hrms') {
      return {'state': 'releaseVerificationFailed'};
    }
    final token = await _preferences.getToken();
    if (token.isEmpty) return {'state': 'registrationRequired'};
    final localUser = await _preferences.getUser();
    if (localUser.id <= 0) return {'state': 'registrationRequired'};
    final keyAlias = 'kneayerng_device_key_u${localUser.id}';
    if (_activeUserId != null && _activeUserId != localUser.id) {
      clearLocalSession();
    }
    _activeKeyAlias = keyAlias;
    _activeUserId = localUser.id;
    _root = root;
    _serverSecurityEnabled = true;

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final releaseResponse = await _client.post(
      Uri.parse('$root/releases/check'),
      headers: headers,
      body: {
        'package_name': '${identity['packageName']}',
        'signing_sha256': '${identity['signingSha256']}',
        'version_code': '${identity['versionCode']}',
        'android_sdk': '${identity['androidSdk']}',
      },
    );
    if (releaseResponse.statusCode != 200) {
      if (releaseResponse.statusCode >= 500)
        return _offlineAuthorizationState();
      _clearOfflineLease();
      return {
        'state': releaseResponse.statusCode == 428
            ? 'unsupportedAndroid'
            : 'releaseVerificationFailed',
        'status': releaseResponse.statusCode
      };
    }
    final release = jsonDecode(releaseResponse.body) as Map<String, dynamic>;
    if (release['mandatory_update'] == true) {
      _optionalUpdate = null;
      _clearOfflineLease();
      return {'state': 'mandatoryUpdate', ...release};
    }
    final latestRelease = release['latest_release'];
    final latestVersionCode = latestRelease is Map
        ? (latestRelease['version_code'] as num?)?.toInt()
        : null;
    _optionalUpdate = latestRelease is Map &&
            latestRelease['compatible_with_device'] != false &&
            (latestRelease['minimum_android_sdk'] == null ||
                (identity['androidSdk'] as num).toInt() >=
                    (latestRelease['minimum_android_sdk'] as num).toInt()) &&
            latestVersionCode != null &&
            latestVersionCode > (identity['versionCode'] as num).toInt()
        ? Map<String, dynamic>.from(latestRelease)
        : null;

    final installationUuid = await _installationUuid();

    final statusResponse = await _client.post(
      Uri.parse('$root/devices/status'),
      headers: headers,
      body: {'installation_uuid': installationUuid},
    );
    if (statusResponse.statusCode == 200) {
      final status = jsonDecode(statusResponse.body) as Map<String, dynamic>;
      if (status['authorized'] == true && status['device_id'] is String) {
        final expectedFingerprint = status['public_key_fingerprint'];
        if (expectedFingerprint is! String) {
          _clearOfflineLease();
          return {'state': 'keyMismatch'};
        }
        final selectedAlias =
            await _native.invokeMethod<String>('selectKeyAlias', {
          'preferredAlias': keyAlias,
          'publicKeyFingerprint': expectedFingerprint,
        });
        if (selectedAlias == null) {
          _clearOfflineLease();
          await _native.invokeMethod<String>('rotateInstallationIdentity');
          final preferences = await SharedPreferences.getInstance();
          await preferences.remove(_installationKey);
          return {
            'state': 'registrationRequired',
            'reason': 'device_key_unavailable',
          };
        }
        _activeKeyAlias = selectedAlias;
        _deviceId = status['device_id'] as String;
        final hadSession = _sessionId != null && _sessionToken != null;
        final session = hadSession
            ? {'session_id': _sessionId}
            : await _openSession(root, headers, _deviceId!);
        if (session != null) {
          final heartbeat = await _heartbeat(
            root,
            localUser.id,
            (policy['heartbeat_seconds'] as num?)?.toInt() ?? 120,
            force: !hadSession || _offlineGraceSeconds > 0,
            identity: identity,
            installationUuid: installationUuid,
          );
          if (heartbeat != null) return heartbeat;
          await _reportClientRiskSignals(root, localUser.id);
        } else if (_lastSessionOpenStatus == 428) {
          _clearOfflineLease();
          return {'state': 'unsupportedAndroid', 'status': 428};
        } else if ((_lastSessionOpenStatus ?? 0) >= 500) {
          return _offlineAuthorizationState();
        } else {
          _clearOfflineLease();
        }
        return {
          'state': session == null ? 'sessionExpired' : 'authorized',
          if (session != null && _optionalUpdate != null)
            'optional_update': _optionalUpdate,
          ...status
        };
      }
      _clearOfflineLease();
      return {'state': _stateFor(status['status']), ...status};
    }
    if (statusResponse.statusCode != 404) {
      if (statusResponse.statusCode >= 500) return _offlineAuthorizationState();
      _clearOfflineLease();
      return {
        'state': 'offlineRestricted',
        'status': statusResponse.statusCode
      };
    }
    _clearOfflineLease();
    return _register(root, headers, identity);
  }

  Future<Map<String, dynamic>> _register(
    String root,
    Map<String, String> headers,
    Map<String, dynamic> identity,
  ) async {
    final challengeResponse =
        await _client.post(Uri.parse('$root/challenge'), headers: headers);
    if (challengeResponse.statusCode != 200) {
      return {
        'state': 'registrationRequired',
        'status': challengeResponse.statusCode
      };
    }
    final challengeData =
        jsonDecode(challengeResponse.body) as Map<String, dynamic>;
    final installationUuid = await _installationUuid();
    final challenge = challengeData['challenge'] as String;
    final attestationChallenge =
        base64Url.decode(base64Url.normalize(challenge));
    final key = await _native.invokeMapMethod<String, dynamic>('ensureKey', {
      'attestationChallenge': Uint8List.fromList(attestationChallenge),
      'keyAlias': _activeKeyAlias,
      'forceNew': true,
    });
    if (key == null || key['publicKey'] is! String) {
      return {'state': 'restricted', 'reason': 'keystore_unavailable'};
    }
    final proof =
        'ky-device-registration-v1\n${challengeData['challenge_id']}\n$challenge\n$installationUuid';
    final signature = await _native.invokeMethod<String>('sign', {
      'payload': Uint8List.fromList(utf8.encode(proof)),
      'keyAlias': _activeKeyAlias,
    });
    final response = await _client.post(
      Uri.parse('$root/devices/register'),
      headers: headers,
      body: {
        'challenge_id': '${challengeData['challenge_id']}',
        'challenge': challenge,
        'challenge_signature': signature ?? '',
        'installation_uuid': installationUuid,
        'public_key': '${key['publicKey']}',
        'package_name': '${identity['packageName']}',
        'signing_sha256': '${identity['signingSha256']}',
        'version_name': '${identity['versionName'] ?? ''}',
        'version_code': '${identity['versionCode']}',
        'android_sdk': '${identity['androidSdk']}',
        'android_version': '${identity['androidVersion'] ?? ''}',
        'device_model': '${identity['deviceModel'] ?? ''}',
        for (var i = 0;
            i < (key['attestationChain'] as List? ?? []).length;
            i++)
          'attestation_chain[$i]': '${(key['attestationChain'] as List)[i]}',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      return {
        'state': response.statusCode == 428
            ? 'unsupportedAndroid'
            : 'registrationRequired',
        'status': response.statusCode,
      };
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (result['authorized'] == true && result['device_id'] is String) {
      _deviceId = result['device_id'] as String;
      final session = await _openSession(root, headers, _deviceId!);
      if (session != null) {
        final user = await _preferences.getUser();
        final heartbeat = await _heartbeat(
          root,
          user.id,
          120,
          force: true,
          identity: identity,
          installationUuid: installationUuid,
        );
        if (heartbeat != null) return heartbeat;
        await _reportClientRiskSignals(root, user.id);
      } else if (_lastSessionOpenStatus == 428) {
        _clearOfflineLease();
        return {'state': 'unsupportedAndroid', 'status': 428};
      } else if ((_lastSessionOpenStatus ?? 0) >= 500) {
        return _offlineAuthorizationState();
      }
      return {
        'state': session == null ? 'sessionExpired' : 'authorized',
        if (session != null && _optionalUpdate != null)
          'optional_update': _optionalUpdate,
        ...result
      };
    }
    return {'state': _stateFor(result['status']), ...result};
  }

  Future<Map<String, dynamic>> _offlineAuthorizationState(
      {String reason = 'network_unreachable', int? status}) async {
    final restricted = _pairingFailure(reason, status);
    if (_root != null && Uri.tryParse(_root!)?.scheme != 'https')
      return restricted;
    try {
      if (!Platform.isAndroid) return restricted;
      final user = await _preferences.getUser();
      if (user.id <= 0) return restricted;
      final identity =
          await _native.invokeMapMethod<String, dynamic>('identity');
      if (identity == null) return restricted;
      final installationUuid = await _installationUuid();
      final stored = await _native
          .invokeMapMethod<String, dynamic>('readAuthorizationLease');
      if (stored == null || stored['payload'] is! String) {
        return restricted;
      }
      final claims = KyOfflineAuthorizationLease.decodePayload(
          stored['payload'] as String);
      if (claims == null ||
          !KyOfflineAuthorizationLease.matchesInstallation(
            claims,
            userId: user.id,
            installationUuid: installationUuid,
            identity: identity,
            maximumAllowedSeconds:
                KyOfflineAuthorizationLease.maximumLeaseSeconds,
          )) {
        _clearOfflineLease();
        return restricted;
      }
      _serverSecurityEnabled = true;
      _deviceId = claims['device_id'] as String;
      _activeUserId = user.id;
      _activeKeyAlias = 'kneayerng_device_key_u${user.id}';
      return {
        'state': 'offlineAuthorized',
        'device_id': claims['device_id'],
        'status': 'approved',
        'offline_lease_expires_at': claims['expires_at'],
      };
    } catch (_) {
      return restricted;
    }
  }

  Future<bool> _storeAuthorizationLease(
    dynamic lease, {
    required int userId,
    required String deviceId,
    required String installationUuid,
    required Map<String, dynamic> identity,
    required String? serverTime,
  }) async {
    if (_offlineGraceSeconds <= 0 || lease is! Map) {
      _clearOfflineLease();
      return false;
    }
    final payload = lease['payload'];
    final signature = lease['signature'];
    final keyId = lease['key_id'];
    if (payload is! String || signature is! String || keyId is! String) {
      _clearOfflineLease();
      return false;
    }
    final claims = KyOfflineAuthorizationLease.decodePayload(payload);
    if (claims == null ||
        !KyOfflineAuthorizationLease.matchesInstallation(
          claims,
          userId: userId,
          installationUuid: installationUuid,
          identity: identity,
          maximumAllowedSeconds: _offlineGraceSeconds,
        ) ||
        claims['device_id'] != deviceId) {
      _clearOfflineLease();
      return false;
    }
    final serverTimestamp =
        DateTime.tryParse(serverTime ?? '')?.toUtc().millisecondsSinceEpoch;
    if (serverTimestamp == null) {
      _clearOfflineLease();
      return false;
    }
    final remainingSeconds =
        (claims['expires_at'] as int) - (serverTimestamp ~/ 1000);
    if (remainingSeconds < 1 ||
        remainingSeconds > (claims['lease_seconds'] as int)) {
      _clearOfflineLease();
      return false;
    }
    return await _native.invokeMethod<bool>('storeAuthorizationLease', {
          'payload': payload,
          'signature': signature,
          'keyId': keyId,
          'leaseSeconds': remainingSeconds,
        }) ==
        true;
  }

  void _clearOfflineLease() {
    if (!Platform.isAndroid) return;
    _native.invokeMethod<void>('clearAuthorizationLease').catchError((_) {});
  }

  /// Applies signed headers when server enforcement is enabled. Returns null
  /// when security is disabled or the request is unauthenticated. A denied local
  /// state is returned to callers as an exception so the business API is not sent.
  Future<bool> enforcementRequired(Map<String, String> existingHeaders,
      {Uri? uri}) async {
    final hasBearer =
        (existingHeaders['Authorization'] ?? '').startsWith('Bearer ');
    if (KyCertificatePinning.enabled &&
        hasBearer &&
        uri != null &&
        !KyCertificatePinning.protectsHost(uri.host)) {
      throw const KySecurityAccessException('apiHostNotTrusted');
    }
    if (!Platform.isAndroid || !hasBearer) return false;
    final currentUser = await _preferences.getUser();
    if (_activeUserId != null && _activeUserId != currentUser.id) {
      clearLocalSession();
    }
    final age = _authorizationCheckedAt == null
        ? null
        : DateTime.now().difference(_authorizationCheckedAt!);
    if (age == null ||
        age > const Duration(seconds: 30) ||
        _authorizationState == null) {
      final flight = _authorizationFlight ??=
          initialize().whenComplete(() => _authorizationFlight = null);
      try {
        _authorizationState = await flight;
      } catch (_) {
        _authorizationState = {'state': 'offlineRestricted'};
      }
      _authorizationCheckedAt = DateTime.now();
    }
    final state = _authorizationState!;
    if (state['state'] == 'disabled') return false;
    if (state['state'] != 'authorized' &&
        state['state'] != 'offlineAuthorized') {
      if (state['state'] == 'offlineRestricted') _authorizationCheckedAt = null;
      throw KySecurityAccessException('${state['state'] ?? 'restricted'}');
    }
    return true;
  }

  Future<Map<String, String>?> authorizeRequest({
    required String method,
    required Uri uri,
    required String body,
    String? bodySha256,
    required Map<String, String> existingHeaders,
  }) async {
    if (!await enforcementRequired(existingHeaders, uri: uri)) return null;
    final signed = await signedHeaders(
        method: method, uri: uri, body: body, bodySha256: bodySha256);
    if (signed == null) throw const KySecurityAccessException('sessionExpired');
    return {...existingHeaders, ...signed};
  }

  Future<Map<String, String>?> signedHeaders({
    required String method,
    required Uri uri,
    required String body,
    String? bodySha256,
  }) async {
    final root = _root;
    final deviceId = _deviceId;
    if (root == null || deviceId == null || _sessionId == null) return null;
    if (_sessionExpiresAt == null ||
        _sessionExpiresAt!
            .isBefore(DateTime.now().add(const Duration(seconds: 20)))) {
      if (!await _refreshSession()) {
        _sessionId = null;
        _sessionToken = null;
        _refreshToken = null;
        final token = await _preferences.getToken();
        final replacement = await _openSession(
            root,
            {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            deviceId);
        if (replacement == null) return null;
      }
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = base64Url
        .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    final requestUri = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final canonical =
        '${method.toUpperCase()}\n$requestUri\n${bodySha256 ?? sha256.convert(utf8.encode(body)).toString()}\n$timestamp\n$nonce\n$deviceId\n$_sessionId';
    final signature = await _native.invokeMethod<String>('sign', {
      'payload': Uint8List.fromList(utf8.encode(canonical)),
      'keyAlias': _activeKeyAlias,
    });
    final token = await _preferences.getToken();
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-KY-Device': deviceId,
      'X-KY-Session': _sessionId!,
      'X-KY-Session-Token': _sessionToken!,
      'X-KY-Timestamp': '$timestamp',
      'X-KY-Nonce': nonce,
      'X-KY-Signature': signature ?? '',
    };
  }

  Future<Map<String, dynamic>?> _openSession(
      String root, Map<String, String> headers, String deviceId) async {
    _lastSessionOpenStatus = null;
    final response = await _client.post(Uri.parse('$root/sessions'),
        headers: headers, body: {'device_id': deviceId});
    if (response.statusCode != 200) {
      _lastSessionOpenStatus = response.statusCode;
      return null;
    }
    _setSession(jsonDecode(response.body) as Map<String, dynamic>);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _reportClientRiskSignals(String root, int userId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = 'ky_security_integrity_reported_at_$userId';
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastReport = preferences.getInt(key) ?? 0;
      if (now - lastReport < const Duration(hours: 24).inMilliseconds) return;

      final signals = await _native.invokeListMethod<String>('riskSignals') ??
          const <String>[];
      const allowed = {
        'root_detected',
        'emulator_detected',
        'instrumentation_detected',
        'debug_build',
        'debugger_attached',
        'hooking_detected',
        'vpn_detected',
        'network_transport_wifi',
        'network_transport_cellular',
        'network_transport_ethernet'
      };
      final reportable =
          signals.where(allowed.contains).toSet().toList(growable: false);
      if (reportable.isEmpty) {
        await preferences.setInt(key, now);
        return;
      }

      final uri = Uri.parse('$root/integrity/report');
      final body = jsonEncode({'signals': reportable});
      final headers = await signedHeaders(method: 'POST', uri: uri, body: body);
      if (headers == null) return;
      final response = await _client
          .post(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) await preferences.setInt(key, now);
    } catch (_) {
      // Integrity heuristics are best-effort review signals and never gate app use.
    }
  }

  Future<Map<String, dynamic>?> _heartbeat(
    String root,
    int userId,
    int intervalSeconds, {
    bool force = false,
    required Map<String, dynamic> identity,
    required String installationUuid,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = 'ky_security_heartbeat_at_$userId';
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastHeartbeat = preferences.getInt(key) ?? 0;
      final interval =
          Duration(seconds: intervalSeconds.clamp(30, 900).toInt());
      if (!force && now - lastHeartbeat < interval.inMilliseconds) return null;

      final uri = Uri.parse('$root/heartbeat');
      const body = '{}';
      final headers = await signedHeaders(method: 'POST', uri: uri, body: body);
      if (headers == null) return {'state': 'sessionExpired'};
      final response = await _client
          .post(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        if (result['authorized'] == true) {
          await preferences.setInt(key, now);
          await _storeAuthorizationLease(
            result['authorization_lease'],
            userId: userId,
            deviceId: '${result['device_id'] ?? _deviceId ?? ''}',
            installationUuid: installationUuid,
            identity: identity,
            serverTime: result['server_time'] as String?,
          );
          return null;
        }
        _clearOfflineLease();
        return {'state': _stateFor(result['status'])};
      }
      if (response.statusCode == 401) {
        _clearOfflineLease();
        _sessionId = null;
        _sessionToken = null;
        _refreshToken = null;
        _sessionExpiresAt = null;
        return {'state': 'sessionExpired', 'status': response.statusCode};
      }
      if (response.statusCode == 423) {
        _clearOfflineLease();
        return {'state': 'blocked', 'status': response.statusCode};
      }
      if (response.statusCode == 426) {
        _clearOfflineLease();
        return {'state': 'mandatoryUpdate', 'status': response.statusCode};
      }
      if (response.statusCode == 428) {
        _clearOfflineLease();
        return {'state': 'unsupportedAndroid', 'status': response.statusCode};
      }
      if (response.statusCode >= 500) return _offlineAuthorizationState();
      return {'state': 'offlineRestricted', 'status': response.statusCode};
    } catch (error) {
      if (_isOfflineTransportFailure(error))
        return _offlineAuthorizationState();
      return {'state': 'offlineRestricted'};
    }
  }

  Future<bool> _refreshSession() async {
    final root = _root;
    final sessionId = _sessionId;
    final refresh = _refreshToken;
    if (root == null || sessionId == null || refresh == null) return false;
    final proof = 'ky-session-refresh-v1\n$sessionId\n$refresh';
    final signature = await _native.invokeMethod<String>('sign', {
      'payload': Uint8List.fromList(utf8.encode(proof)),
      'keyAlias': _activeKeyAlias,
    });
    final token = await _preferences.getToken();
    final response = await _client.post(
      Uri.parse('$root/sessions/refresh'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: {'refresh_token': refresh, 'signature': signature ?? ''},
    );
    if (response.statusCode != 200) return false;
    _setSession(jsonDecode(response.body) as Map<String, dynamic>);
    return true;
  }

  void _setSession(Map<String, dynamic> session) {
    _sessionId = session['session_id'] as String?;
    _sessionToken = session['session_token'] as String?;
    _refreshToken = session['refresh_token'] as String?;
    _sessionExpiresAt =
        DateTime.tryParse(session['expires_at'] as String? ?? '');
  }

  /// Clears process-local session material after the existing server logout
  /// request has revoked it. The installation key and Android Keystore key are
  /// intentionally retained for subsequent sign-ins on this installation.
  void clearLocalSession() {
    _clearOfflineLease();
    _root = null;
    _deviceId = null;
    _sessionId = null;
    _sessionToken = null;
    _refreshToken = null;
    _sessionExpiresAt = null;
    _authorizationState = null;
    _authorizationCheckedAt = null;
    _activeKeyAlias = null;
    _activeUserId = null;
    _serverSecurityEnabled = false;
    _optionalUpdate = null;
    _lastSessionOpenStatus = null;
  }

  /// Invalidates cached authorization after a server-side rejection so the
  /// next API call rechecks release, device, and session state. The failed
  /// business request is never retried automatically.
  void handleProtectedApiStatus(int statusCode) {
    if (!_serverSecurityEnabled || !{401, 423, 426, 428}.contains(statusCode))
      return;
    if (statusCode == 401 || statusCode == 428) {
      _sessionId = null;
      _sessionToken = null;
      _refreshToken = null;
      _sessionExpiresAt = null;
    }
    if (statusCode == 428) _clearOfflineLease();
    _authorizationState = null;
    _authorizationCheckedAt = null;
  }

  Future<String> _installationUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final value = await _native.invokeMethod<String>('installationIdentity', {
      'legacyUuid': prefs.getString(_installationKey),
      'keyAlias': _activeKeyAlias,
    });
    if (value == null || value.isEmpty) {
      throw PlatformException(
        code: 'KY_INSTALL_IDENTITY',
        message: 'Installation identity is unavailable',
      );
    }
    await prefs.remove(_installationKey);
    return value;
  }

  String _stateFor(dynamic status) => switch (status) {
        428 || '428' => 'unsupportedAndroid',
        'pending' => 'pendingApproval',
        'blocked' => 'blocked',
        'revoked' => 'revoked',
        're_registration_required' ||
        'registration_required' =>
          'registrationRequired',
        _ => 'restricted',
      };
}

class KySecurityAccessException implements Exception {
  const KySecurityAccessException(this.state);
  final String state;
  @override
  String toString() => 'KNEAYERNG security authorization failed: $state';
}
