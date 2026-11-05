"""Regression tests for the fail-closed APK private-key detector.

All fixtures are synthetic and contain no cryptographic private keys.
"""
import base64
import unittest

from inspect_android_artifacts import has_complete_pem_private_key


class PemDetectionTests(unittest.TestCase):
    def test_bare_parser_marker_in_debug_kernel_is_not_a_key(self):
        self.assertFalse(has_complete_pem_private_key(
            b"parser accepts -----BEGIN PRIVATE KEY----- as a header"
        ))

    def test_incomplete_pem_is_not_a_complete_key(self):
        self.assertFalse(has_complete_pem_private_key(
            b"-----BEGIN PRIVATE KEY-----\nMIIEEXAMPLE\n"
        ))

    def test_complete_pem_like_der_payload_blocks_upload(self):
        # Synthetic ASN.1-like bytes, not a generated private key.
        encoded = base64.b64encode(bytes([0x30]) + bytes([0x00]) * 150)
        blob = b"-----BEGIN PRIVATE KEY-----\n" + encoded + b"\n-----END PRIVATE KEY-----"
        self.assertTrue(has_complete_pem_private_key(blob))

    def test_escaped_newlines_in_pem_are_detected(self):
        encoded = base64.b64encode(bytes([0x30]) + bytes([0x00]) * 150)
        blob = b"-----BEGIN RSA PRIVATE KEY-----\\n" + encoded + b"\\n-----END RSA PRIVATE KEY-----"
        self.assertTrue(has_complete_pem_private_key(blob))

    def test_public_key_does_not_match_private_key(self):
        encoded = base64.b64encode(bytes([0x30]) + bytes([0x00]) * 150)
        blob = b"-----BEGIN PUBLIC KEY-----\n" + encoded + b"\n-----END PUBLIC KEY-----"
        self.assertFalse(has_complete_pem_private_key(blob))


if __name__ == "__main__":
    unittest.main()
