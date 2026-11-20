String kyPairingMessage(String? reason, {int? status}) => switch (reason) {
      'https_required' =>
        'This server requires a secure HTTPS address. Scan the HTTPS pairing QR from the admin panel.',
      'api_host_not_pinned' =>
        'This app build does not recognize the scanned server. Use the official app for this server.',
      'pinning_not_configured' =>
        'This app build is missing its server certificate settings. Install the official app.',
      'tls_verification_failed' =>
        'The server certificate could not be verified. Contact your administrator.',
      'security_endpoint_missing' =>
        'The scanned server does not provide the App Security endpoint. Ask your administrator to update it.',
      'security_endpoint_redirected' ||
      'security_response_invalid' =>
        'The scanned address did not return App Security settings. Scan the pairing QR from the HR admin panel.',
      'security_server_error' =>
        'The HR server could not complete the security check${status == null ? '' : ' (HTTP $status)'}. Contact your administrator.',
      'device_security_unavailable' =>
        'This app could not access Android device security. Reopen the official app and try again.',
      'security_check_failed' =>
        'The app could not complete the security check. Try again or contact your administrator.',
      _ =>
        'The security service could not be reached. Check the server connection and retry.',
    };
