#!/usr/bin/env python3
"""Security, architecture and manifest gate for signed lightweight Petita test APKs.
All signing keys are ephemeral, generated exclusively in Actions and discarded.
Never prints matched credential bytes.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

from inspect_android_artifacts import has_complete_pem_private_key

ANDROID_NS = '{http://schemas.android.com/apk/res/android}'
EXPECTED_PACKAGE = 'br.edu.ufcg.petsaude.petita.releasecheck'
APPROVED_PERMISSIONS = {
    'android.permission.INTERNET',
    EXPECTED_PACKAGE + '.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}
SECRET_PATTERNS = (
    ('postgres-url', re.compile(rb'postgres(?:ql)?://[^\s]{1,200}:[^\s]{1,200}@')),
    ('supabase-secret', re.compile(rb'\bsb_secret_[A-Za-z0-9_-]{16,}')),
    ('supabase-personal-token', re.compile(rb'\bsbp_[A-Za-z0-9_-]{20,}')),
)

def run(*args):
    return subprocess.run([str(a) for a in args], capture_output=True, text=True, check=True).stdout

def inspect(apk, abi, sdk):
    apk = Path(apk)
    assert apk.is_file(), 'APK was not produced'
    assert apk.stat().st_size < 100 * 1024 * 1024, 'Test APK exceeds 100 MiB'
    tools = sdk / 'build-tools' / '36.0.0'
    analyzer = sdk / 'cmdline-tools' / 'latest' / 'bin' / 'apkanalyzer'
    cert = run(tools / 'apksigner', 'verify', '--verbose', '--print-certs', apk)
    assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in cert, 'APK v2 signature invalid'
    xml = run(analyzer, 'manifest', 'print', apk)
    manifest = ET.fromstring(xml)
    assert manifest.get('package') == EXPECTED_PACKAGE, 'Unexpected package ID'
    # ABI-specific version codes are produced by the installed Flutter Gradle
    # plugin. The invariant is the app's source versionCode (20), optionally
    # offset by whole thousands for ABI-specific APKs. The bundled libraries
    # are separately verified to match exactly the requested architecture.
    version_code = int(manifest.get(ANDROID_NS + 'versionCode'))
    assert version_code >= 20 and version_code % 1000 == 20, (
        f'Unexpected Flutter split APK version code: {version_code}'
    )
    app = manifest.find('application')
    assert app.get(ANDROID_NS + 'label') == 'Petita', 'Unexpected application label'
    assert app.get(ANDROID_NS + 'debuggable', 'false') == 'false', 'Debugging unexpectedly enabled'
    assert app.get(ANDROID_NS + 'allowBackup') == 'false', 'Backup enabled'
    assert app.get(ANDROID_NS + 'usesCleartextTraffic') == 'false', 'Plaintext traffic enabled'
    permissions = {x.get(ANDROID_NS + 'name') for x in manifest.findall('uses-permission')}
    assert permissions <= APPROVED_PERMISSIONS, 'Unreviewed Android permission'
    providers = app.findall('provider')
    p = next((p for p in providers if p.get(ANDROID_NS + 'name', '').endswith('PrintFileProvider')), None)
    assert p is not None, 'Missing PDF sharing provider'
    assert p.get(ANDROID_NS + 'exported') == 'false', 'PDF provider exposed'
    assert p.get(ANDROID_NS + 'grantUriPermissions') == 'true', 'PDF temporary URI grants missing'
    assert p.get(ANDROID_NS + 'authorities') == EXPECTED_PACKAGE + '.flutter.printing'
    exported = [x.get(ANDROID_NS + 'name') for x in app if x.get(ANDROID_NS + 'exported') == 'true']
    assert exported == ['br.edu.ufcg.petsaude.petita.MainActivity'], 'Unexpected exported component'

    safe_paths = False
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        supported_abis = sorted({n.split('/')[1] for n in names if n.startswith('lib/') and len(n.split('/')) > 2})
        assert supported_abis == [abi], 'APK has unexpected ABI libraries'
        assert f'lib/{abi}/libflutter.so' in names, 'Flutter native library missing'
        assert f'lib/{abi}/libapp.so' in names, 'AOT Dart library missing'
        for entry in archive.infolist():
            payload = archive.read(entry)
            if has_complete_pem_private_key(payload):
                raise AssertionError('Potential private key in APK; inspect privately')
            for name, pattern in SECRET_PATTERNS:
                if pattern.search(payload):
                    raise AssertionError(f'Potential embedded credential ({name}); inspect privately')
            for token in re.findall(rb'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}', payload):
                try:
                    part = token.split(b'.')[1]
                    claims = json.loads(base64.urlsafe_b64decode(part + b'=' * (-len(part) % 4)))
                except (ValueError, UnicodeError):
                    continue
                if isinstance(claims, dict) and claims.get('role') == 'service_role':
                    raise AssertionError('Potential privileged JWT; inspect privately')
        for xmlpath in [n for n in names if n.startswith('res/') and n.endswith('.xml')]:
            result = subprocess.run([str(tools / 'aapt'), 'dump', 'xmltree', str(apk), xmlpath],
                                    text=True, capture_output=True)
            if result.returncode == 0 and 'cache-path' in result.stdout and '/share/' in result.stdout:
                assert 'root-path' not in result.stdout, 'Unsafe PDF provider root-path'
                safe_paths = True
                break
    assert safe_paths, 'Safe PDF FileProvider path not found'
    return {'name': apk.name, 'size_bytes': apk.stat().st_size,
            'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
            'abi': abi, 'package': EXPECTED_PACKAGE,
            'installable_signed': True, 'internal_test_only': True}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', required=True, type=Path)
    parser.add_argument('--abi', choices=['x86_64', 'arm64-v8a'], required=True)
    parser.add_argument('--sdk', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect(args.apk, args.abi, args.sdk), ensure_ascii=False))

if __name__ == '__main__':
    main()
