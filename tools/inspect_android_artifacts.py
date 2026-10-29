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



def has_complete_pem_private_key(payload):
    """Detect actual PEM private-key material, not parser strings in Dart VM.

    A bare BEGIN delimiter appears in third-party crypto parsers bundled in
    Flutter's debug kernel. Requiring a matching END delimiter and decodable
    key body avoids that false positive without permitting valid PEM keys.
    """
    begin = re.compile(rb'-----BEGIN ((?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY)-----')
    for marker in begin.finditer(payload):
        end = b'-----END ' + marker.group(1) + b'-----'
        # PEM keys have bounded encoded bodies. Large unrelated compiled
        # sections must not be treated as a PEM body.
        candidate = payload[marker.end():marker.end() + 16384]
        end_index = candidate.find(end)
        if end_index < 0:
            continue
        body = candidate[:end_index].strip()
        # Support both actual newlines and escaped newlines inside strings.
        body = body.replace(b'\\r\\n', b'\n').replace(b'\\n', b'\n')
        lines = body.splitlines()
        # Traditional PEM encrypted keys can have Proc-Type/DEK-Info headers.
        encoded = b''.join(line.strip() for line in lines
                           if line.strip() and b':' not in line)
        if len(encoded) < 100:
            continue
        try:
            decoded = base64.b64decode(encoded, validate=True)
        except (ValueError, base64.binascii.Error):
            continue
        if len(decoded) >= 64 and (
            decoded.startswith(b'\x30') or decoded.startswith(b'openssh-key-v1\x00')
        ):
            return True
    return False


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
    assert set(permissions) <= allowed, 'Unexpected merged permission: ' + repr(permissions)
    providers = app.findall('provider')
    provider = next(p for p in providers if p.get(NS + 'name').endswith('PrintFileProvider'))
    assert provider.get(NS + 'authorities') == expected + '.flutter.printing'
    assert provider.get(NS + 'exported') == 'false'
    assert provider.get(NS + 'grantUriPermissions') == 'true'
    exported = [node.get(NS + 'name') for node in app if node.get(NS + 'exported') == 'true']
    assert exported == ['br.edu.ufcg.petsaude.petita.MainActivity'], 'Unexpected exported component: ' + repr(exported)
    # A manifest declaration alone does not prove Kotlin compiled the Activity.
    activity_code = run(analyzer, 'dex', 'code', '--class', 'br.edu.ufcg.petsaude.petita.MainActivity', apk).stdout
    assert 'MainActivity' in activity_code, 'Launcher Activity missing from DEX'
    paths = run(tools / 'aapt', 'dump', 'xmltree', apk, 'res/xml/flutter_printing_file_paths.xml').stdout
    assert 'cache-path' in paths and '/share/' in paths and 'root-path' not in paths
    certificate = run(tools / 'apksigner', 'verify', '--verbose', '--print-certs', apk, check=False)
    assert (certificate.returncode == 0) == (kind == 'debug'), 'Unexpected signing status'
    fingerprint = re.findall(r'certificate SHA-256 digest: ([0-9a-f]+)', certificate.stdout)
    with zipfile.ZipFile(apk) as archive:
        for entry in archive.infolist():
            payload = archive.read(entry)
            # Identify the *rule* and ZIP entry, never the matched bytes.
            # This keeps the check fail-closed while allowing safe diagnosis
            # of false positives in binary/resources before any APK upload.
            credential_rules = [
                ('postgres-url', rb'postgres(?:ql)?://[^\s]{1,200}:[^\s]{1,200}@'),

                ('supabase-secret', rb'\bsb_secret_[A-Za-z0-9_-]{16,}'),
                ('supabase-personal-token', rb'\bsbp_[A-Za-z0-9_-]{20,}'),
            ]
            if has_complete_pem_private_key(payload):
                safe_entry = entry.filename.encode('unicode_escape').decode('ascii')[:180]
                raise AssertionError(
                    f'Potential embedded credential; rule=complete-private-key; '
                    f'apk={kind}; zip-entry={safe_entry}; inspect privately'
                )
            for rule_name, pattern in credential_rules:
                if re.search(pattern, payload):
                    safe_entry = entry.filename.encode('unicode_escape').decode('ascii')[:180]
                    raise AssertionError(
                        f'Potential embedded credential; rule={rule_name}; '
                        f'apk={kind}; zip-entry={safe_entry}; inspect privately'
                    )
            for token in re.findall(rb'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}', payload):
                try:
                    segment = token.split(b'.')[1]
                    claims = json.loads(base64.urlsafe_b64decode(segment + b'=' * (-len(segment) % 4)))
                except (ValueError, UnicodeError):
                    continue
                assert claims.get('role') != 'service_role', 'Potential embedded privileged token; inspect privately'
    (output / f'{kind}-manifest.xml').write_text(xml)
    (output / f'{kind}-main-activity-dex.txt').write_text(activity_code)
    (output / f'{kind}-pdf-provider.txt').write_text(paths)
    return {'file': apk.name, 'sha256': sha(apk), 'bytes': apk.stat().st_size, 'package': expected,
            'versionCode': 20, 'versionName': manifest.get(NS + 'versionName'), 'minSdk': 24, 'targetSdk': 36,
            'permissions': permissions, 'exportedComponents': exported, 'mainActivityInDex': True, 'certificateSha256': fingerprint,
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
    # Preserve safe manifest diagnostics for both APKs before any assertion can
    # reject one. The separate CI artifact never includes a rejected APK.
    diagnostics = []
    analyzer = args.sdk / 'cmdline-tools/latest/bin/apkanalyzer'
    for kind, apk in [('debug', debug), ('releasecheck', release)]:
        xml = run(analyzer, 'manifest', 'print', apk).stdout
        (args.output / f'{kind}-manifest.xml').write_text(xml)
        manifest = ET.fromstring(xml)
        app = manifest.find('application')
        diagnostics.append({'kind': kind, 'package': manifest.get('package'),
                            'exportedComponents': [{'name': node.get(NS + 'name'), 'permission': node.get(NS + 'permission')}
                                                   for node in app if node.get(NS + 'exported') == 'true'],
                            'permissions': [node.get(NS + 'name') for node in manifest.findall('uses-permission')]})
    (args.output / 'manifest-component-diagnostics.json').write_text(json.dumps(diagnostics, indent=2))
    print('Merged manifest diagnostics:', json.dumps(diagnostics), flush=True)
    artifacts = [inspect(debug, 'debug', args.sdk, args.output), inspect(release, 'releasecheck', args.sdk, args.output)]
    assert not run('git', 'diff', '--name-only').stdout.strip(), 'Build changed tracked source files; reconcile before claiming commit provenance'
    report = {'purpose': 'internal synthetic-data tests only; not an INPI registration hash',
              'commit': run('git', 'rev-parse', 'HEAD').stdout.strip(),
              'tree': run('git', 'rev-parse', 'HEAD^{tree}').stdout.strip(),
              'pullRequestHead': os.environ.get('PETITA_PR_HEAD_SHA'),
              'trackedWorkingTreeClean': True,
              'workflowRun': os.environ.get('GITHUB_RUN_ID'),
              'flutter': run('flutter', '--version', '--machine').stdout,
              'internalTestDefine': True, 'questionnaireSha256': QUESTION_HASH, 'officialIconSha256': ICON_HASH,
              'gradleWrapperJarSha256': sha(ROOT / 'android/gradle/wrapper/gradle-wrapper.jar'),
              'artifacts': artifacts, 'physicalDeviceTest': 'not performed'}
    (args.output / 'test-build-provenance.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(artifacts, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
