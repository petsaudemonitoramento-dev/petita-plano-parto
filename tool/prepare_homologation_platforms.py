"""Harden ephemeral homologation scaffolds only; never rewrites Dart or production IDs."""
from pathlib import Path
import re
import sys
platform=sys.argv[1]
if platform=='android':
    manifest=Path('android/app/src/main/AndroidManifest.xml')
    content=manifest.read_text()
    content=content.replace('<application','<uses-permission android:name="android.permission.INTERNET"/>\n    <application',1)
    content=content.replace('<application','<application android:allowBackup="false" android:usesCleartextTraffic="false"',1)
    content=re.sub(r'android:label="[^"]+"','android:label="Petita Homologação"',content,count=1)
    manifest.write_text(content)
    gradle=Path('android/app/build.gradle.kts'); content=gradle.read_text()
    content,n=re.subn(r'applicationId = "[^"]+"','applicationId = "br.edu.ufcg.petsaude.petita.homologacao"',content,count=1)
    assert n==1,'Unexpected Gradle applicationId'
    content,n=re.subn(r'minSdk = flutter.minSdkVersion','minSdk = maxOf(flutter.minSdkVersion, 23)',content,count=1)
    assert n==1,'Unexpected Gradle minSdk'
    gradle.write_text(content)
elif platform=='ios':
    project=Path('ios/Runner.xcodeproj/project.pbxproj');content=project.read_text()
    content=re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',lambda m:'PRODUCT_BUNDLE_IDENTIFIER = br.edu.ufcg.petsaude.petita.homologacao'+('.RunnerTests' if 'RunnerTests' in m[1] else '')+';',content)
    content=content.replace('INFOPLIST_FILE = Runner/Info.plist;','INFOPLIST_FILE = Runner/Info.plist;\n                CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
    project.write_text(content)
    Path('ios/Runner/Runner.entitlements').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>keychain-access-groups</key><array><string>$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string></array></dict></plist>''')
else: raise SystemExit('Only ephemeral android/ios homologation scaffolds allowed')
print('Homologation identifier and platform protection configured; no deployment/signing.')
