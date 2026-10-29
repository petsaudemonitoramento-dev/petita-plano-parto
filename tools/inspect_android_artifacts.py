#!/usr/bin/env python3
"""Fail-closed checks and provenance for internal APKs, without signing secrets."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NS = '{http://schemas.android.com/apk/res/android}'
QUESTION_HASH = '9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd'
ICON_HASH = 'bea39885f9277a0d059a1a100c4821320617a56ff21c5d4178ad45cb8429ceb9'


def run(*args, check=True):
    return subprocess.run(list(map(str, args)), text=True, capture_output=True, check=check)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_checks():
    assert sha(ROOT / 'assets/data/birth_plan_flow.json') == QUESTION_HASH
    assert len(json.loads((ROOT / 'assets/data/birth_plan_flow.json').read_text())) == 31
    assert sha(ROOT / 'assets/branding/Petita_icone_android_1024.png') == ICON_HASH
    manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
    app = manifest.find('application')
    assert app.get(NS + 'label') == 'Petita'
    assert app.get(NS + 'allowBackup') == 'false'
    assert app.get(NS + 'usesCleartextTraffic') == 'false'
    assert app.get(NS + 'dataExtractionRules')
    assert app.get(NS + 'fullBackupContent')
    assert [x.get(NS + 'name') for x in manifest.findall('uses-permission')] == ['android.permission.INTERNET']
    for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
        for name in ['ic_launcher', 'ic_launcher_foreground', 'ic_launcher_monochrome']:
            assert (ROOT / f'android/app/src/main/res/mipmap-{density}/{name}.png').exists()
    assert (ROOT / 'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml').exists()


def inspect(apk, kind, sdk, output):
    tools = sdk / 'build-tools/36.0.0'
    analyzer = sdk / 'cmdline-tools/latest/bin/apkanalyzer'
    xml = run(analyzer, 'manifest', 'print', apk).stdout
    manifest = ET.fromstring(xml)
    app = manifest.find('application')
    expected = 'br.edu.ufcg.petsaude.petita.' + ('internal' if kind == 'debug' else 'releasecheck')
    assert manifest.get('package') == expected, 'Unexpected package identity'
    assert manifest.get(NS + 'versionCode') == '20'
    assert manifest.get(NS + 'versionName') == ('0.2.0-internal' if kind == 'debug' else '0.2.0-unsigned-test')
    assert manifest.find('uses-sdk').get(NS + 'minSdkVersion') == '24'
    assert manifest.find('uses-sdk').get(NS + 'targetSdkVersion') == '36'
    assert app.get(NS + 'allowBackup') == 'false'
    assert app.get(NS + 'usesCleartextTraffic') == 'false'
    assert app.get(NS + 'debuggable', 'false') == ('true' if kind == 'debug' else 'false')
    permissions = [x.get(NS + 'name') for x in manifest.findall('uses-permission')]
    allowed = {'android.permission.INTERNET', expected + '.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
    assert set(permissions) <= allowed, 'Unexpected merged permission'
    providers = app.findall('provider')
    provider = next(p for p in providers if p.get(NS + 'name').endswith('PrintFileProvider'))
    assert provider.get(NS + 'authorities') == expected + '.flutter.printing'
    assert provider.get(NS + 'exported') == 'false'
    assert provider.get(NS + 'grantUriPermissions') == 'true'
    exported = [node.get(NS + 'name') for node in app if node.get(NS + 'exported') == 'true']
    assert exported == ['br.edu.ufcg.petsaude.petita.MainActivity'], 'Unexpected exported component'
    paths = run(tools / 'aapt', 'dump', 'xmltree', apk, 'res/xml/flutter_printing_file_paths.xml').stdout
    assert 'cache-path' in paths and '/share/' in paths and 'root-path' not in paths
    certificate = run(tools / 'apksigner', 'verify', '--verbose', '--print-certs', apk, check=False)
    assert (certificate.returncode == 0) == (kind == 'debug'), 'Unexpected signing status'
    fingerprint = re.findall(r'certificate SHA-256 digest: ([0-9a-f]+)', certificate.stdout)
    with zipfile.ZipFile(apk) as archive:
        for entry in archive.infolist():
            payload = archive.read(entry)
            for pattern in [rb'postgres(?:ql)?://[^\s]{1,200}:[^\s]{1,200}@', rb'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----', rb'\bsb_secret_[A-Za-z0-9_-]{16,}', rb'\bsbp_[A-Za-z0-9_-]{20,}']:
                assert not re.search(pattern, payload), 'Potential embedded credential; inspect privately'
            for token in re.findall(rb'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}', payload):
                try:
                    segment = token.split(b'.')[1]
                    claims = json.loads(base64.urlsafe_b64decode(segment + b'=' * (-len(segment) % 4)))
                except (ValueError, UnicodeError):
                    continue
                assert claims.get('role') != 'service_role', 'Potential embedded privileged token; inspect privately'
    (output / f'{kind}-manifest.xml').write_text(xml)
    (output / f'{kind}-pdf-provider.txt').write_text(paths)
    return {'file': apk.name, 'sha256': sha(apk), 'bytes': apk.stat().st_size, 'package': expected,
            'versionCode': 20, 'versionName': manifest.get(NS + 'versionName'), 'minSdk': 24, 'targetSdk': 36,
            'permissions': permissions, 'exportedComponents': exported, 'certificateSha256': fingerprint,
            'signing': 'ephemeral Android debug key' if kind == 'debug' else 'unsigned; not installable/distributable',
            'credentialPatternCheck': 'passed; not a proof of absence of all possible secrets'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-only', action='store_true')
    parser.add_argument('--sdk', type=Path, default=os.environ.get('ANDROID_HOME'))
    parser.add_argument('--output', type=Path, default=ROOT / 'build/android-evidence')
    args = parser.parse_args()
    source_checks()
    if args.source_only:
        print('Android source checks and canonical assets passed.')
        return
    args.output.mkdir(parents=True, exist_ok=True)
    debug = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
    release = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
    artifacts = [inspect(debug, 'debug', args.sdk, args.output), inspect(release, 'releasecheck', args.sdk, args.output)]
    report = {'purpose': 'internal synthetic-data tests only; not an INPI registration hash',
              'commit': run('git', 'rev-parse', 'HEAD').stdout.strip(),
              'tree': run('git', 'rev-parse', 'HEAD^{tree}').stdout.strip(),
              'pullRequestHead': os.environ.get('PETITA_PR_HEAD_SHA'),
              'workflowRun': os.environ.get('GITHUB_RUN_ID'),
              'flutter': run('flutter', '--version', '--machine').stdout,
              'internalTestDefine': True, 'questionnaireSha256': QUESTION_HASH, 'officialIconSha256': ICON_HASH,
              'gradleWrapperJarSha256': sha(ROOT / 'android/gradle/wrapper/gradle-wrapper.jar'),
              'artifacts': artifacts, 'physicalDeviceTest': 'not performed'}
    (args.output / 'test-build-provenance.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(artifacts, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
