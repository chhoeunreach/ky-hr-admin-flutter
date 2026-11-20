#!/usr/bin/env python3
"""Monitor HTTPS trust, API SPKI pins, and certificate expiry.

By default, the process also checks that the public App Security config route
returns its expected JSON schema. It exits non-zero when the current
certificate is untrusted, its host name is wrong, its SPKI is not in the
configured primary/backup list, the certificate nears expiry, or the route
check fails. Use --tls-only to skip the route probe. It emits one JSON record
to stdout so a scheduler or monitoring agent can collect the result.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import socket
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


def parse_pin(value: str) -> str:
    if not value.startswith("sha256/"):
        raise ValueError("pins must use sha256/<base64> format")
    encoded = value[len("sha256/") :]
    try:
        digest = base64.b64decode(encoded, validate=True)
    except Exception as exc:  # noqa: BLE001 - normalize decoding errors
        raise ValueError("pin is not valid Base64") from exc
    if len(digest) != 32 or base64.b64encode(digest).decode("ascii") != encoded:
        raise ValueError("pin must be canonical Base64 for a 32-byte SHA-256 digest")
    return value


def spki_pin(certificate_der: bytes) -> str:
    cert = subprocess.run(
        ["openssl", "x509", "-inform", "DER", "-pubkey", "-noout"],
        input=certificate_der,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    key = subprocess.run(
        ["openssl", "pkey", "-pubin", "-outform", "DER"],
        input=cert.stdout,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    digest = hashlib.sha256(key.stdout).digest()
    return "sha256/" + base64.b64encode(digest).decode("ascii")


def certificate_expiry(certificate_der: bytes) -> dt.datetime:
    result = subprocess.run(
        ["openssl", "x509", "-inform", "DER", "-noout", "-enddate"],
        input=certificate_der,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    expiry_value = result.stdout.decode("ascii").strip().removeprefix("notAfter=")
    return dt.datetime.strptime(expiry_value, "%b %d %H:%M:%S %Y %Z").replace(
        tzinfo=dt.timezone.utc
    )


def certificate_from_file(path: Path) -> bytes:
    data = path.read_bytes()
    if b"-----BEGIN CERTIFICATE-----" in data:
        return ssl.PEM_cert_to_DER_cert(data.decode("ascii"))
    return data


def check_config_endpoint(host: str, timeout: float) -> tuple[dict, list[str]]:
    url = f"https://{host}/api/app-security/v1/config"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "KNEAYERNG-AppSecurity-Readiness/1.0",
        },
    )
    try:
        response = urllib.request.urlopen(
            request, timeout=timeout, context=ssl.create_default_context()
        )
    except urllib.error.HTTPError as exc:
        status = exc.code
        content_type = exc.headers.get("Content-Type", "")
        response_body = exc.read(65537)
        exc.close()
    else:
        with response:
            status = response.status
            content_type = response.headers.get("Content-Type", "")
            response_body = response.read(65537)

    errors = []
    if status != 200:
        errors.append(f"API config endpoint returned HTTP {status}")
    media_type = content_type.split(";", 1)[0].strip().lower()
    if media_type != "application/json":
        errors.append(f"API config endpoint returned content type {media_type or '(missing)'}")

    config = None
    if media_type == "application/json" and len(response_body) <= 65536:
        try:
            config = json.loads(response_body)
        except (UnicodeDecodeError, json.JSONDecodeError):
            errors.append("API config response body is not valid JSON")
    elif len(response_body) > 65536:
        errors.append("API config response body exceeded 64 KiB")

    required = {
        "enabled": bool,
        "device_approval_required": bool,
        "hardware_attestation": str,
        "heartbeat_seconds": int,
        "session_ttl_seconds": int,
        "offline_grace_seconds": int,
        "challenge_ttl_seconds": int,
    }
    if config is not None:
        if not isinstance(config, dict):
            errors.append("API config response must be a JSON object")
        else:
            for key, expected_type in required.items():
                if key not in config or type(config[key]) is not expected_type:
                    errors.append(f"API config field {key} is missing or has the wrong type")
                elif expected_type is int and config[key] < 0:
                    errors.append(f"API config field {key} must not be negative")

    return {
        "http_status": status,
        "content_type": content_type,
        "valid_json_schema": config is not None and not any(
            error.startswith("API config response") or error.startswith("API config field")
            for error in errors
        ),
    }, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--host",
        default=os.environ.get("KY_API_HOST", "hr.rvstechsolution.com"),
        help="exact HTTPS API host to check (default: KY_API_HOST or production host)",
    )
    parser.add_argument(
        "--pins",
        default=os.environ.get("KY_SECURITY_SPKI_PINS", ""),
        help="comma-separated primary and backup SPKI pins (defaults to KY_SECURITY_SPKI_PINS)",
    )
    parser.add_argument(
        "--warn-days",
        type=int,
        default=30,
        help="fail when the active leaf certificate expires in this many days or less",
    )
    parser.add_argument(
        "--backup-cert",
        type=Path,
        help="optional planned backup public leaf certificate; verify its SPKI and expiry too",
    )
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument(
        "--tls-only",
        action="store_true",
        help="check TLS trust, pin, and expiry without probing the App Security config route",
    )
    args = parser.parse_args()

    try:
        if not args.host or "/" in args.host or ":" in args.host:
            raise ValueError("--host must be an exact hostname without scheme, port, or path")
        if args.warn_days < 1 or args.timeout <= 0:
            raise ValueError("--warn-days and --timeout must be positive")
        pins = [parse_pin(pin.strip()) for pin in args.pins.split(",") if pin.strip()]
        if len(set(pins)) < 2:
            raise ValueError("two distinct primary and backup SPKI pins are required")

        context = ssl.create_default_context()
        with socket.create_connection((args.host, 443), timeout=args.timeout) as raw_socket:
            with context.wrap_socket(raw_socket, server_hostname=args.host) as tls_socket:
                cert_der = tls_socket.getpeercert(binary_form=True)

        live_pin = spki_pin(cert_der)
        expiry = certificate_expiry(cert_der)
        now = dt.datetime.now(dt.timezone.utc)
        days_left = (expiry - now).total_seconds() / 86400
        result = {
            "host": args.host,
            "tls_chain_and_hostname_valid": True,
            "live_spki_pin": live_pin,
            "pin_configured": live_pin in pins,
            "certificate_expires_at": expiry.isoformat(),
            "certificate_days_remaining": round(days_left, 2),
            "warning_window_days": args.warn_days,
        }
        failures = []
        if live_pin not in pins:
            failures.append("live certificate SPKI does not match either configured pin")
        if days_left <= args.warn_days:
            failures.append("live certificate is inside the expiry warning window")

        if args.backup_cert:
            backup_der = certificate_from_file(args.backup_cert)
            backup_pin = spki_pin(backup_der)
            backup_expiry_utc = certificate_expiry(backup_der)
            result["backup_certificate_spki_pin"] = backup_pin
            result["backup_certificate_expires_at"] = backup_expiry_utc.isoformat()
            if backup_pin not in pins or backup_pin == live_pin:
                failures.append("backup certificate must match the non-live configured pin")
            if (backup_expiry_utc - now).total_seconds() / 86400 <= args.warn_days:
                failures.append("backup certificate is inside the expiry warning window")

        if not args.tls_only:
            try:
                api_config, api_errors = check_config_endpoint(args.host, args.timeout)
                result["api_config"] = api_config
                failures.extend(api_errors)
            except (OSError, urllib.error.URLError, ssl.SSLError, TimeoutError) as exc:
                result["api_config"] = {"reachable": False}
                failures.append(f"API config request failed: {exc}")

        result["ok"] = not failures
        if failures:
            result["errors"] = failures
        print(json.dumps(result, sort_keys=True))
        return 1 if failures else 0
    except (OSError, ValueError, KeyError, ssl.SSLError, subprocess.CalledProcessError) as exc:
        print(json.dumps({"host": args.host, "ok": False, "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    sys.exit(main())
