"""Compare release candidates with the exact previously approved debug APK."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--variant', choices=['universal', 'split'], required=True)
parser.add_argument('--build-tools', type=Path, required=True)
parser.add_argument('--apk-dir', type=Path, required=True)
parser.add_argument('--report', type=Path, required=True)
a = parser.parse_args()

def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def run(*cmd):
    return subprocess.check_output([str(x) for x in cmd], text=True, stderr=subprocess.STDOUT)

def assets(apk):
    with zipfile.ZipFile(apk) as z:
        assert z.testzip() is None, f'Corrupt ZIP: {apk}'
        # Project-owned content only, not generated manifests or fonts tree-shaken by Flutter.
        prefix = 'assets/flutter_assets/assets/'
        return {n[len(prefix):]: hashlib.sha256(z.read(n)).hexdigest()
                for n in z.namelist() if n.startswith(prefix) and not n.endswith('/')}

def abis(apk):
    with zipfile.ZipFile(apk) as z:
        names = set(z.namelist())
        return sorted(n.split('/')[1] for n in names if re.fullmatch(r'lib/[^/]+/libflutter\.so', n))

def cert(apk):
    output = run(a.build_tools / 'apksigner', 'verify', '--print-certs', apk)
    return re.findall(r'Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)', output)

baseline_assets = assets(a.baseline)
assert baseline_assets and 'data/birth_plan_flow.json' in baseline_assets
baseline_size = a.baseline.stat().st_size
baseline_cert = cert(a.baseline)
baseline_abis = abis(a.baseline)
assert baseline_cert and baseline_abis
expected = {'app-release.apk': sorted(baseline_abis)} if a.variant == 'universal' else {
    'app-armeabi-v7a-release.apk': ['armeabi-v7a'],
    'app-arm64-v8a-release.apk': ['arm64-v8a'],
    'app-x86_64-release.apk': ['x86_64'],
}
reports = []
for filename, architectures in expected.items():
    apk = a.apk_dir / filename
    assert apk.is_file(), f'Missing {filename}'
    assert assets(apk) == baseline_assets, f'Bundled project assets changed: {filename}'
    assert abis(apk) == architectures, f'Unexpected ABIs: {filename}'
    badging = run(a.build_tools / 'aapt', 'dump', 'badging', apk)
    assert "package: name='br.edu.ufcg.petsaude.petita.homologacao'" in badging
    assert 'application-debuggable' not in badging, f'Debuggable APK: {filename}'
    manifest = run(a.build_tools / 'aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml')
    for marker in ['android.intent.action.TTS_SERVICE', 'android.permission.INTERNET', 'allowBackup', 'usesCleartextTraffic']:
        assert marker in manifest, f'Missing {marker}: {filename}'
    for marker in ['allowBackup', 'usesCleartextTraffic']:
        line = next(x for x in manifest.splitlines() if marker in x)
        assert re.search(r'=\(type 0x12\)0x0(?:\s|$)', line), f'Protection not false: {line}'
    signer = cert(apk)
    assert signer
    size = apk.stat().st_size
    assert size < baseline_size, f'No size improvement: {filename}'
    reports.append({'file': filename, 'bytes': size, 'reduction_pct': round(100*(1-size/baseline_size), 2),
                    'abis': architectures, 'sha256': sha(apk),
                    'certificate_sha256': signer, 'same_signer_as_previous': signer == baseline_cert})
report = {'baseline_bytes': baseline_size, 'baseline_sha256': sha(a.baseline),
          'project_assets_identical': len(baseline_assets), 'variant': a.variant,
          'baseline_certificate_sha256': baseline_cert, 'candidates': reports,
          'scope': 'homologation only; physical Android installation and signing continuity not established'}
a.report.write_text(json.dumps(report, indent=2) + '\n')
print(a.report.read_text())
