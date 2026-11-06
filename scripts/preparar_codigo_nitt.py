#!/usr/bin/env python3
"""Preparacao de fontes Petita para avaliacao institucional; sem calculo de hash."""

from __future__ import annotations

import io
import os
import re
import subprocess
import tarfile
import textwrap
import zipfile
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

ORIGIN_COMMIT = "d34f4a33e8e9e098ec87730a08feff28218661da"
OUT = Path(os.environ.get("PETITA_NITT_OUTPUT", "dist-nitt"))
NAME = "Petita_0.3.0_build21"
CODE_EXTENSIONS = {".dart", ".ts", ".js", ".sql", ".yaml", ".toml", ".py", ".html", ".mjs"}

PDF_SOURCE_FILES = [
    "lib/main.dart",
    "lib/app.dart",
    "lib/config/app_theme.dart",
    "lib/models/consent_record.dart",
    "lib/models/birth_plan_question.dart",
    "lib/screens/consent/consent_gate_screen.dart",
    "lib/screens/chat/chat_screen.dart",
    "lib/screens/birth_plan/birth_plan_summary_screen.dart",
    "lib/services/birth_plan_explanations.dart",
    "lib/services/gestational_age_service.dart",
    "lib/services/storage_service.dart",
    "lib/services/faq_search_service.dart",
    "lib/services/pdf_service.dart",
    "lib/services/supabase_service.dart",
    "supabase/functions/ask-petita-rag/index.ts",
    "supabase/functions/process-support-document/index.ts",
    "supabase/functions/delete-support-document/index.ts",
    "documentos/supabase_patch_v6_rag_documentos.sql",
]

def in_scope(path: str) -> bool:
    if path in {"pubspec.yaml", "pubspec.lock", "README.md", "supabase/config.toml"}:
        return True
    if path.startswith(("lib/", "test/", "tool/", "scripts/", "web/", "supabase/functions/")):
        return True
    if path.startswith(("assets/data/", "assets/images/", "assets/fonts/", "assets/legal/")):
        return True
    if path == "assets/branding/Petita_icone_android_1024.png":
        return True
    if path.startswith("documentos/supabase_") and path.endswith(".sql"):
        return True
    return False

def source_snapshot() -> dict[str, bytes]:
    # git archive aponta somente para o commit candidato aprovado; nao inclui .git.
    tar_bytes = subprocess.check_output(
        ["git", "archive", "--format=tar", ORIGIN_COMMIT],
    )
    selected: dict[str, bytes] = {}
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as tf:
        for member in tf.getmembers():
            if not member.isfile():
                continue
            path = member.name.replace("\\", "/")
            if path.startswith("/") or ".." in Path(path).parts:
                raise RuntimeError("Caminho inseguro no arquivo Git")
            if not in_scope(path):
                continue
            stream = tf.extractfile(member)
            if stream is None:
                raise RuntimeError("Arquivo sem conteudo: " + path)
            selected[path] = stream.read()
    for mandatory in [
        "pubspec.yaml", "pubspec.lock",
        "assets/data/birth_plan_flow.json",
        "assets/fonts/DejaVuSans-LICENSE.txt",
        *PDF_SOURCE_FILES,
    ]:
        if mandatory not in selected:
            raise RuntimeError("Faltando arquivo obrigatorio: " + mandatory)
    return selected

def inspect_secrets(files: dict[str, bytes]) -> None:
    # Revisao automatica conservadora: nao substitui revisao humana de segredos.
    patterns = (
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
        re.compile(r"(?:postgres|postgresql)://[^/\s@:]+:[^/\s@]+@", re.I),
        re.compile(r"ghp_[A-Za-z0-9]{25,}"),
        re.compile(r"github_pat_[A-Za-z0-9_]{30,}"),
        re.compile(r"AKIA[A-Z0-9]{16}"),
    )
    for path, content in files.items():
        if any(s in path.lower() for s in (".env", ".temp", "keystore", "backup", ".p12", ".jks")):
            raise RuntimeError("Arquivo nao apropriado ao NITT: " + path)
        if Path(path).suffix.lower() not in CODE_EXTENSIONS:
            continue
        text = content.decode("utf-8", errors="replace")
        if any(p.search(text) for p in patterns):
            raise RuntimeError("Possivel credencial em " + path + "; revisar sem exibir valor")

def doc_readme(file_count: int) -> str:
    return f"""PETITA — CODIGO-FONTE PARA REVISAO DO NITT/UFCG
==================================================
Software: Petita — Plano de Parto, PET Saude/UFCG
Versao de codigo selecionada: 0.3.0, build 21
Commit de origem: {ORIGIN_COMMIT}
Arquivos do repositorio selecionados: {file_count}
Finalidade: material tecnico de revisao institucional; NAO SUBMETIDO.

O ZIP contem codigo-fonte e recursos necessarios para entender o aplicativo
Flutter (lib/, assets/, web/, pubspec.*), suas Edge Functions de apoio, SQL
versionado/proposto, testes e ferramentas de compilacao. Os pacotes de
terceiros referenciados em pubspec.lock NAO foram incorporados.

O PDF disponibilizado em separado apresenta uma SELECAO REPRESENTATIVA do
codigo autoral e nao substitui os arquivos integrais do ZIP.

O commit escolhido e o da versao 0.3.0+21 que passou na auditoria Cloud.
Nao inclui alteracoes posteriores de relatorios nem pretende incorporar
as PRs Neon/Android que continuam separadas e sem integracao.

LIMITACOES IMPORTANTES
- SEM uso assistencial ou com dados reais nesta etapa.
- Autenticacao Neon/Google, RLS e isolamento remoto das UBS nao homologados.
- Dados locais sensiveis ainda demandam cifragem e migracao segura.
- RAG externo desativado por padrao ate haver quota/autorizacao homologadas.
- Estrutura Android permanente e assinatura institucional dependem de etapa
  propria. O ZIP e codigo-fonte, nao APK.
- O NITT definira eventual necessidade de selecao diferente para registro.

Os arquivos em assets/ sao recursos de reproducao, nao declaracao de
titularidade sobre mascote, fontes ou marcas institucionais. Conferir a
nota sobre autoria e terceiros antes de enviar.

NAO foi gerado hash criptografico do pacote neste procedimento.
"""

def third_party_note() -> str:
    return """AUTORIA, TITULARIDADE E COMPONENTES DE TERCEIROS — CONFERENCIA NITT
=====================================================================
1. IDENTIFICACAO PRELIMINAR
Projeto: Petita — Plano de Parto / PET Saude UFCG.
Desenvolvimento indicado nos documentos tecnicos do projeto:
Lucca Nunes dos Santos Pereira de Araujo.
Este campo NAO define sozinho a lista final de criadores e nao exclui
participacoes autorais de outros colaboradores.

2. TITULARIDADE
A Petita foi desenvolvida no contexto institucional do PET Saude/UFCG.
A titularidade patrimonial deve ser confirmada pelo NITT/UFCG de acordo
com os vinculos, termos, contribuicoes e instrumentos institucionais.
Nao apresentar a autoria de uma pessoa ou a presenca da marca UFCG como
prova definitiva de titularidade.

3. LICENCA DO CODIGO PROPRIO
Nenhum arquivo LICENSE geral foi identificado no commit selecionado.
Nao aplicar automaticamente licenca de software livre ou cessao de
direitos no pacote; depender de orientacao institucional.

4. DEPENDENCIAS DE TERCEIROS
O pubspec.yaml e o pubspec.lock identificam dependencias Flutter/Dart
como pdf, printing, shared_preferences, image, flutter_tts,
supabase_flutter e outras dependencias indiretas.
As bibliotecas externas NAO sao copiadas para este ZIP, apenas declaradas
para instalacao. A auditoria identificou 100 pacotes; licencas e
obrigacoes individuais devem ser conferidas com a equipe/NITT.

5. FONTES E IDENTIDADE VISUAL
As fontes DejaVuSans.ttf e DejaVuSans-Bold.ttf sao acompanhadas
pelo arquivo assets/fonts/DejaVuSans-LICENSE.txt.
Imagens Petita/PET Saude/UFCG: origem e autorizacao de uso devem ser
confirmadas pelos responsaveis institucionais. Sua presenca nos assets
nao prova cessao ou titularidade.

6. APROVACAO PENDENTE
Revisar e confirmar junto ao NITT: nome dos criadores, vinculos,
contribuicoes relevantes, titular ou cotitulares, autorizaçao de
assets institucionais e escopo do codigo-fonte representativo.
Nenhuma assinatura, cedencia ou protocolo foi gerado por esta rotina.
"""

def build_zip(files: dict[str, bytes], readme: str, notice: str) -> Path:
    path = OUT / f"{NAME}_codigo_fonte_completo_NITT.zip"
    with zipfile.ZipFile(path, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for p, data in sorted(files.items()):
            archive.writestr(p, data)
        archive.writestr("NITT_LEIA_PRIMEIRO.txt", readme.encode("utf-8"))
        archive.writestr("NITT_AUTORIA_TERCEIROS.txt", notice.encode("utf-8"))
    with zipfile.ZipFile(path) as archive:
        corrupted = archive.testzip()
        if corrupted:
            raise RuntimeError("ZIP corrompido: " + corrupted)
    return path

def make_pdf(files: dict[str, bytes]) -> Path:
    pdf = OUT / f"{NAME}_codigo_fonte_representativo_NITT.pdf"
    page_w, page_h = A4
    pad = 37
    head_y, foot_y = page_h - 40, 29
    font_path = Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")
    if font_path.is_file():
        pdfmetrics.registerFont(TTFont("PetitaMono", str(font_path)))
        font_name = "PetitaMono"
    else:
        # A representacao exata dos bytes permanece no ZIP.
        pdfmetrics.registerFont(TTFont("PetitaSans", io.BytesIO(files["assets/fonts/DejaVuSans.ttf"])))
        font_name = "PetitaSans"
    font_size, line_h = 6.85, 9.4
    mono_width = pdfmetrics.stringWidth("M", font_name, font_size)
    cols = max(50, int((page_w - 2 * pad) / mono_width))
    cv = canvas.Canvas(str(pdf), pagesize=A4, pageCompression=1)
    cv.setTitle("Petita 0.3.0 — Codigo-fonte representativo NITT")
    cv.setAuthor("Projeto Petita — PET Saude/UFCG (autoria formal a confirmar)")
    page = 0
    y = 0.0

    def new_page() -> None:
        nonlocal page, y
        if page:
            cv.setFont("Helvetica", 8)
            cv.setFillColor(colors.grey)
            cv.drawRightString(page_w - pad, foot_y, f"{page}")
            cv.showPage()
        page += 1
        cv.setFillColor(colors.black)
        y = head_y

    new_page()
    for filepath in PDF_SOURCE_FILES:
        code = files[filepath].decode("utf-8")
        if y < 75:
            new_page()
        cv.setFont("Helvetica-Bold", 8.5)
        cv.drawString(pad, y, "ARQUIVO: " + filepath)
        y -= 16
        for raw_line in code.splitlines():
            expanded = raw_line.expandtabs(2)
            chunks = textwrap.wrap(expanded, width=cols, replace_whitespace=False,
                                   drop_whitespace=False, break_long_words=True,
                                   break_on_hyphens=False)
            if not chunks:
                chunks = [""]
            for segment in chunks:
                if y < 44:
                    new_page()
                cv.setFont(font_name, font_size)
                cv.setFillColor(colors.black)
                cv.drawString(pad, y, segment)
                y -= line_h
        y -= 16
    cv.setFont("Helvetica", 8)
    cv.setFillColor(colors.grey)
    cv.drawRightString(page_w - pad, foot_y, f"{page}")
    cv.save()
    print(f"PDF fonte gerado ({page} paginas): {pdf}")
    return pdf

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = source_snapshot()
    inspect_secrets(files)
    readme = doc_readme(len(files))
    notice = third_party_note()
    zip_path = build_zip(files, readme, notice)
    pdf_path = make_pdf(files)
    (OUT / "NITT_LEIA_PRIMEIRO.txt").write_text(readme, encoding="utf-8")
    (OUT / "NITT_AUTORIA_TERCEIROS.txt").write_text(notice, encoding="utf-8")
    for p in (zip_path, pdf_path):
        if p.stat().st_size < 1000:
            raise RuntimeError("Artefato vazio: " + str(p))
        print("PREPARADO", p.name, "bytes", p.stat().st_size)
    print("SEM ENVIO EXTERNO, SEM HASH NOVO, SEM DEPLOY")

if __name__ == "__main__":
    main()
