"""Query OSV using only public package names/versions from pubspec.lock."""
import json
from pathlib import Path
import urllib.request
import yaml
lock=yaml.safe_load(Path('pubspec.lock').read_text())
packages=[(name,p['version']) for name,p in lock['packages'].items() if p['source']=='hosted']
body={'queries':[{'package':{'ecosystem':'Pub','name':name},'version':version} for name,version in packages]}
request=urllib.request.Request('https://api.osv.dev/v1/querybatch',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
try:
    with urllib.request.urlopen(request,timeout=30) as response: results=json.load(response)['results']
except Exception as e:
    print('OSV BLOCKED:',type(e).__name__);raise SystemExit(2)
assert len(results)==len(packages)
findings=[{'package':name,'version':version,'ids':[v['id'] for v in result['vulns']]} for (name,version),result in zip(packages,results) if result.get('vulns')]
evidence={'source':'OSV querybatch','ecosystem':'Pub','packages':len(packages),'findings':findings,'scope':'known advisories only; not a guarantee of absence'}
Path('build/test_artifacts').mkdir(parents=True,exist_ok=True)
Path('build/test_artifacts/pub-osv.json').write_text(json.dumps(evidence,indent=2)+'\n')
print(json.dumps(evidence,indent=2))
raise SystemExit(1 if findings else 0)
