"""Limited tracked-source scan. Reports paths/rules only, never matching values."""
import base64
import json
from pathlib import Path
import re
import subprocess
files=subprocess.check_output(['git','ls-files','-z'],timeout=10).decode().split('\0')
findings=[]
for name in files:
    path=Path(name)
    if not name or not path.is_file() or path.stat().st_size>2_000_000: continue
    try: content=path.read_text()
    except UnicodeError: continue
    if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',content):findings.append((name,'private-key'))
    for match in re.finditer(r'postgres(?:ql)?://[^:\s/]+:[^@\s]+@',content):
        if not re.search(r'REPLACE|EXAMPLE|fixture|placeholder',match[0],re.I):findings.append((name,'database-password-uri'))
    if re.search(r'\bsb_secret_[A-Za-z0-9_-]{24,}',content):findings.append((name,'privileged-api-key'))
    for token in re.findall(r'eyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+',content):
        try:
            payload=json.loads(base64.urlsafe_b64decode(token+'='*((-len(token))%4)))
            if payload.get('role')=='service_role':findings.append((name,'service-role-jwt'))
        except (ValueError,UnicodeError): pass
print(json.dumps({'scope':'tracked text only; selected patterns; not history/provider attestation','findings':findings},indent=2))
raise SystemExit(1 if findings else 0)
