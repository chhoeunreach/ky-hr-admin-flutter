"""Unit tests for the API TLS and config-readiness monitor."""

import base64
import json
import sys
import unittest
from email.message import Message
from io import BytesIO
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_api_tls


class FakeResponse:
    status = 200

    def __init__(self, body, content_type="application/json; charset=utf-8"):
        self.body = body
        self.headers = {"Content-Type": content_type}

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self, limit):
        return self.body[:limit]


class CheckApiTlsTests(unittest.TestCase):
    def setUp(self):
        self.valid_config = {
            "enabled": False,
            "device_approval_required": True,
            "hardware_attestation": "preferred",
            "heartbeat_seconds": 120,
            "session_ttl_seconds": 300,
            "offline_grace_seconds": 0,
            "challenge_ttl_seconds": 120,
        }

    def test_parse_pin_accepts_canonical_sha256_pin(self):
        pin = "sha256/0DbDAbR7JYvhI/0wXGW346NQDHIT1r5iKC4niOiwePs="
        self.assertEqual(check_api_tls.parse_pin(pin), pin)

    def test_parse_pin_rejects_wrong_format_and_digest_length(self):
        with self.assertRaises(ValueError):
            check_api_tls.parse_pin("sha256/not-base64")
        with self.assertRaises(ValueError):
            too_short = "sha256/" + base64.b64encode(b"\0" * 31).decode("ascii")
            check_api_tls.parse_pin(too_short)
        with self.assertRaises(ValueError):
            check_api_tls.parse_pin("sha1/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")

    def test_config_endpoint_accepts_expected_json_schema(self):
        body = json.dumps(self.valid_config).encode("utf-8")
        with patch.object(
            check_api_tls.urllib.request,
            "urlopen",
            return_value=FakeResponse(body),
        ) as urlopen:
            result, errors = check_api_tls.check_config_endpoint("api.example", 3)

        self.assertTrue(result["valid_json_schema"])
        self.assertEqual(errors, [])
        request = urlopen.call_args.args[0]
        self.assertEqual(request.get_header("Accept"), "application/json")
        self.assertEqual(
            request.get_header("User-agent"),
            "KNEAYERNG-AppSecurity-Readiness/1.0",
        )

    def test_config_endpoint_rejects_html_404_even_with_http_200(self):
        with patch.object(
            check_api_tls.urllib.request,
            "urlopen",
            return_value=FakeResponse(b"<html><title>404</title></html>", "text/html"),
        ):
            result, errors = check_api_tls.check_config_endpoint("api.example", 3)

        self.assertEqual(result["http_status"], 200)
        self.assertFalse(result["valid_json_schema"])
        self.assertTrue(any("content type text/html" in error for error in errors))

    def test_config_endpoint_rejects_incomplete_schema(self):
        with patch.object(
            check_api_tls.urllib.request,
            "urlopen",
            return_value=FakeResponse(b'{"enabled":true}'),
        ):
            result, errors = check_api_tls.check_config_endpoint("api.example", 3)

        self.assertFalse(result["valid_json_schema"])
        self.assertTrue(any("session_ttl_seconds" in error for error in errors))

    def test_config_endpoint_reports_http_error_without_exposing_body(self):
        headers = Message()
        headers["Content-Type"] = "application/json"
        error = HTTPError(
            "https://api.example/api/app-security/v1/config",
            403,
            "Forbidden",
            headers,
            BytesIO(b'{"message":"private diagnostic"}'),
        )
        with patch.object(
            check_api_tls.urllib.request, "urlopen", side_effect=error
        ):
            result, errors = check_api_tls.check_config_endpoint("api.example", 3)

        self.assertEqual(result["http_status"], 403)
        self.assertFalse(result["valid_json_schema"])
        self.assertTrue(any("HTTP 403" in error for error in errors))
        self.assertNotIn("private diagnostic", str(result) + str(errors))


if __name__ == "__main__":
    unittest.main()
