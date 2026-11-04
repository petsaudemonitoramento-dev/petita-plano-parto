"""Permite ao APK Flutter encontrar engines TTS sem solicitar permissoes invasivas.

Uso depois do flutter create: python3 tool/prepare_android_tts_manifest.py
Nao instala, baixa ou ativa vozes no telefone da gestante.
"""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    raise SystemExit("AndroidManifest.xml inexistente: execute flutter create --platforms=android .")
content = manifest.read_text(encoding="utf-8")
action = "android.intent.action.TTS_SERVICE"
if action in content:
    print("Configuracao TTS ja presente no manifesto.")
else:
    marker = "<application"
    if marker not in content:
        raise SystemExit("Manifesto sem <application>; verificar antes de alterar.")
    block = (
        "<queries>\n"
        "    <intent>\n"
        f'        <action android:name="{action}" />\n'
        "    </intent>\n"
        "</queries>\n    "
    )
    content = content.replace(marker, block + marker, 1)
    manifest.write_text(content, encoding="utf-8")
    print("Manifesto Android atualizado para consulta de voz local TTS.")
