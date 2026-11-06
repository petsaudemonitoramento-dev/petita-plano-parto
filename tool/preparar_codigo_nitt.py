#!/usr/bin/env python3
"""Preparar PDF de código-fonte e ZIP complementar para revisão pelo NITT/UFCG.

Entrada: checkout fixado do fonte auditado (d34f4a3), inventário de dependências
da auditoria e nota humana. Não gera resumo digital/hash nem contata serviços.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import textwrap
import zipfile
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

COMMIT_FONTE = "d34f4a33e8e9e098ec87730a08feff28218661da"
VERSAO = "0.3.0 / build 21"

def ler_texto(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")

def selecionar_arquivos(raiz: Path) -> tuple[list[Path], list[Path]]:
    pdf = set()
    complementares = set()
    for padrao in (
        "lib/**/*.dart",
        "supabase/functions/**/*.ts",
        "documentos/**/*.sql",
        "infra/neon/**/*.sql",
        "assets/data/*.json",
        "assets/legal/*.md",
        "web/index.html",
        "pubspec.yaml",
    ):
        pdf.update(p for p in raiz.glob(padrao) if p.is_file())
    for padrao in (
        "test/**/*.dart",
        "test/**/*.mjs",
        "tool/*.py",
        "tool/*.sh",
        "tool/*.mjs",
        "tool/*.dart",
        "assets/fonts/*LICENSE*.txt",
        "assets/branding/README.md",
        "README.md",
        "pubspec.lock",
    ):
        complementares.update(p for p in raiz.glob(padrao) if p.is_file())
    tudo = sorted(pdf | complementares, key=lambda p: p.relative_to(raiz).as_posix())
    principal = sorted(pdf, key=lambda p: p.relative_to(raiz).as_posix())
    assert principal and tudo
    for p in tudo:
        rel = p.relative_to(raiz).as_posix()
        if any(fragment in rel for fragment in ("/.temp/", ".env", ".p12", ".pem", ".key", "/build/", "/.git/")):
            raise ValueError("Caminho proibido na seleção: " + rel)
        if p.suffix.lower() in (".ttf", ".otf", ".png", ".jpg", ".jpeg", ".pdf", ".zip"):
            raise ValueError("Arquivo binário não permitido: " + rel)
        if p.stat().st_size > 650_000:
            raise ValueError("Arquivo de texto grande demais para a revisão: " + rel)
        ler_texto(p)
    return principal, tudo

def preflight_segredos(arquivos: list[Path]) -> None:
    perigos = [
        ("material de chave privada", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
        ("credencial de Postgres na URL", re.compile(r"postgres(?:ql)?://[^:/\s]+:[^@\s]{4,}@[^\s'\"<>]+")),
        ("token privado comercial", re.compile(r"(?:sk_live_|sk_test_|ghp_|github_pat_)[A-Za-z0-9_]{16,}")),
        ("campo private_key não vazio", re.compile(r"""["']private_key["']\s*:\s*["']-----BEGIN""")),
    ]
    problemas = []
    for p in arquivos:
        texto = ler_texto(p)
        for nome, rx in perigos:
            if rx.search(texto):
                problemas.append((p.name, nome))
    if problemas:
        for nome, motivo in problemas:
            print("SEGURANCA: potencial segredo; conferir arquivo: " + nome + " (" + motivo + ")", file=sys.stderr)
        raise RuntimeError("Pacote interrompido para revisar potenciais segredos; nenhum valor foi exibido")

def preparar_inventario(path: Path, saida: Path) -> dict:
    dados = json.loads(ler_texto(path))
    pacotes = dados.get("packages", [])
    limpos = []
    for pacote in pacotes:
        limpos.append({
            "nome": pacote.get("name"),
            "versao": pacote.get("version"),
            "tipo": pacote.get("scope"),
            "origem": pacote.get("source"),
            "licenca_revisao": pacote.get("license_status", "pendente"),
        })
    produto = {
        "produto": "Petita - Plano de Parto PET Saude",
        "versao": VERSAO,
        "fonte_commit": COMMIT_FONTE,
        "total_pacotes": len(limpos),
        "esclarecimento": (
            "Dependencias externas nao sao codigo de autoria original da Petita. "
            "Referencias a licencas sao um inventario tecnico; revisar avisos e "
            "direitos de redistribuicao antes de incluir arquivos de terceiros."
        ),
        "pacotes": limpos,
    }
    saida.write_text(json.dumps(produto, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return produto

def texto_pdf(s: str) -> str:
    # Converte caracteres fora do plano basico (por ex. emojis) para escapes
    # legiveis no PDF. O ZIP complementar preserva integralmente os bytes UTF-8.
    out = []
    for ch in s.expandtabs(4):
        cp = ord(ch)
        if cp > 0xFFFF:
            out.append("\\U%08X" % cp)
        elif cp in (0x200D, 0xFE0F) or (cp < 32 and ch not in ("\t", " ")):
            out.append("\\u%04X" % cp)
        else:
            out.append(ch)
    return "".join(out)

def registrar_fonte_mono() -> str:
    candidatos = (
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        Path("/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf"),
    )
    for p in candidatos:
        if p.exists():
            pdfmetrics.registerFont(TTFont("FonteCodigo", str(p)))
            return "FonteCodigo"
    raise RuntimeError("Fonte mono Unicode indisponivel no runner; nao gerar PDF truncado")

def escrever_pdf(raiz: Path, arquivos: list[Path], destino: Path) -> int:
    fonte = registrar_fonte_mono()
    w, h = landscape(A4)
    c = canvas.Canvas(str(destino), pagesize=(w, h), pageCompression=1)
    c.setTitle("Petita - Codigo-fonte para revisao NITT - 0.3.0 build 21")
    c.setAuthor("Preparacao tecnica para revisao institucional - autores sujeitos a confirmacao")
    c.setSubject("Fonte representativo do aplicativo Petita; nao equivale a registro INPI")
    numero_pag = 1
    margem_esq, margem_dir = 32, 32
    altura_inicio = h - 60
    linha_alt = 10.2
    x_gutter = margem_esq
    x_code = margem_esq + 51
    largura = w - margem_dir - x_code
    caracteres_max = max(100, int(largura / (pdfmetrics.stringWidth("M", fonte, 7.0) * 1.05)))
    linhas_por_pagina = int((altura_inicio - 39) // linha_alt)

    def cabecalho(titulo: str):
        c.setFillColor(colors.HexColor("#152638"))
        c.rect(0, h - 45, w, 45, stroke=0, fill=1)
        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 11)
        c.drawString(32, h - 19, "PETITA  |  DOCUMENTACAO TECNICA DE CODIGO-FONTE")
        c.setFont("Helvetica", 8)
        c.drawString(32, h - 33, titulo[:125])
        c.setFillColor(colors.HexColor("#62718A"))
        c.setFont("Helvetica", 7.8)
        c.drawString(32, 19, "Versao 0.3.0 / build 21  |  arquivo de referencia para o NITT/UFCG")
        c.drawRightString(w - 32, 19, f"Pagina {numero_pag}")

    def proxima(titulo: str):
        nonlocal numero_pag
        c.showPage()
        numero_pag += 1
        cabecalho(titulo)

    cabecalho("Capa e escopo")
    c.setFillColor(colors.HexColor("#14283C"))
    c.setFont("Helvetica-Bold", 23)
    c.drawString(35, h - 105, "Petita - Plano de Parto PET Saude")
    c.setFont("Helvetica", 13)
    c.drawString(35, h - 135, "Codigo-fonte para revisao de registro de software")
    c.setFont("Helvetica", 10.2)
    y = h - 177
    for par in (
        f"Versao escolhida: {VERSAO}",
        f"Commit de codigo auditado: {COMMIT_FONTE}",
        "Conteudo: Dart/Flutter, handlers TypeScript, SQL, JSON do fluxo e configuracao relevante.",
        "Nao inclui imagens institucionais, arquivos de fontes binarias, credenciais ou arquivos temporarios.",
        "Textos com emoji fora do BMP sao exibidos como escapes Unicode; ZIP preserva o UTF-8 original.",
        "Autoria, coautoria e titularidade patrimonial: sujeitas a confirmacao formal pelo NITT/UFCG.",
        "Uso assistencial/dados reais nao homologados: material tecnico para revisao, nao distribuicao.",
        "Esta preparacao nao gera hash, nao envia documentos e nao altera o codigo-fonte congelado.",
    ):
        c.drawString(36, y, par[:155])
        y -= 25
    c.setFont("Helvetica-Oblique", 9)
    c.drawString(36, 67, f"Arquivos-fonte textuais reproduzidos a seguir: {len(arquivos)}.")

    proxima("Indice dos arquivos incluidos")
    y = altura_inicio
    c.setFont("Helvetica-Bold", 12)
    c.setFillColor(colors.HexColor("#152638"))
    c.drawString(35, y, "Indice de arquivos")
    y -= 23
    c.setFont(fonte, 8.1)
    for idx, p in enumerate(arquivos, 1):
        if y < 48:
            proxima("Indice dos arquivos incluidos (continuacao)")
            y = altura_inicio
        rel = p.relative_to(raiz).as_posix()
        c.drawString(38, y, f"{idx:03d}. {rel}"[:155])
        y -= 12
    proxima("Inicio da listagem do codigo-fonte")

    for idx, p in enumerate(arquivos, 1):
        rel = p.relative_to(raiz).as_posix()
        texto = ler_texto(p)
        linhas = texto.splitlines()
        if idx != 1:
            proxima(f"Arquivo {idx}/{len(arquivos)}: {rel}")
        else:
            cabecalho(f"Arquivo {idx}/{len(arquivos)}: {rel}")
        anchor = "f" + str(idx)
        c.bookmarkPage(anchor)
        c.addOutlineEntry(rel[:100], anchor, level=0, closed=True)
        y = altura_inicio
        usadas = 0
        c.setFont(fonte, 7.0)
        for num, original in enumerate(linhas, 1):
            corrente = texto_pdf(original)
            partes = [corrente[i:i + caracteres_max] for i in range(0, len(corrente), caracteres_max)] or [""]
            for part_idx, parte in enumerate(partes):
                if usadas >= linhas_por_pagina:
                    proxima(f"Arquivo {idx}/{len(arquivos)}: {rel} (continuacao)")
                    y, usadas = altura_inicio, 0
                    c.setFont(fonte, 7.0)
                c.setFillColor(colors.HexColor("#8492A5"))
                c.drawRightString(x_code - 10, y, f"{num:05d}" if part_idx == 0 else "...")
                c.setFillColor(colors.HexColor("#202C39"))
                c.drawString(x_code, y, parte)
                y -= linha_alt
                usadas += 1
    c.save()
    return numero_pag

def escrever_zip(raiz: Path, arquivos: list[Path], saida: Path, complementos: list[Path]):
    with zipfile.ZipFile(saida, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=8) as z:
        for path in arquivos:
            rel = path.relative_to(raiz).as_posix()
            z.write(path, "Petita_Codigo_Fonte/" + rel)
        for path in complementos:
            z.write(path, "Petita_Documentacao_NITT/" + path.name)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fonte", type=Path, required=True)
    parser.add_argument("--inventario", type=Path, required=True)
    parser.add_argument("--nota", type=Path, required=True)
    parser.add_argument("--saida", type=Path, required=True)
    args = parser.parse_args()
    raiz = args.fonte.resolve()
    saida = args.saida.resolve()
    saida.mkdir(parents=True, exist_ok=True)
    pdf_files, zip_files = selecionar_arquivos(raiz)
    preflight_segredos(zip_files)
    versao = ler_texto(raiz / "pubspec.yaml")
    if "version: 0.3.0+21" not in versao:
        raise RuntimeError("Commit nao corresponde a versao fonte selecionada")

    inventario_path = saida / "DEPENDENCIAS_E_LICENCAS.json"
    packages = preparar_inventario(args.inventario, inventario_path)
    lista_path = saida / "LISTA_DE_ARQUIVOS_NITT.txt"
    lista = (
        "PETITA - fonte representativo para revisao NITT/UFCG\n"
        "Versao: " + VERSAO + "\n"
        "Commit de origem: " + COMMIT_FONTE + "\n"
        "Autoria e titularidade: sob confirmacao institucional\n"
        "Em PDF: arquivos centrais de codigo; o ZIP inclui testes e scripts complementares.\n"
        "Excluidos: segredos, caches, conectores temporarios, fotos/logos, fontes TTF/OTF e PDFs legados.\n"
        "NAO e um pacote completo para compilar sem os assets excluidos.\n\n"
        "ARQUIVOS NO PDF (" + str(len(pdf_files)) + ")\n"
        + "\n".join(p.relative_to(raiz).as_posix() for p in pdf_files)
        + "\n\nARQUIVOS NO ZIP (" + str(len(zip_files)) + ")\n"
        + "\n".join(p.relative_to(raiz).as_posix() for p in zip_files)
        + "\n"
    )
    lista_path.write_text(lista, encoding="utf-8")
    nota_path = saida / "NOTA_TECNICA_PARA_REVISAO.md"
    nota_path.write_text(ler_texto(args.nota), encoding="utf-8")

    pdf_path = saida / "Petita_CodigoFonte_NITT_v0.3.0_build21.pdf"
    total_paginas = escrever_pdf(raiz, pdf_files, pdf_path)
    zip_path = saida / "Petita_FonteEditavel_NITT_v0.3.0_build21.zip"
    escrever_zip(raiz, zip_files, zip_path, [nota_path, lista_path, inventario_path])

    with zipfile.ZipFile(zip_path) as z:
        arqs = z.namelist()
        if len(arqs) != len(zip_files) + 3:
            raise RuntimeError("Numero de arquivos ZIP inconsistente")
        if any("/.temp/" in n or n.lower().endswith((".ttf", ".p12", ".pem", ".otf", ".png")) for n in arqs):
            raise RuntimeError("Pacote ZIP incluiu recurso proibido")
        if z.testzip() is not None:
            raise RuntimeError("Arquivo ZIP inconsistente")
    print(f"PDF criado: {pdf_path.name}; {total_paginas} paginas; {len(pdf_files)} arquivos textuais.")
    print(f"ZIP complementar: {zip_path.name}; {len(zip_files)} fontes/testes/configuracoes.")
    print(f"Dependencias inventariadas: {packages['total_pacotes']}.")
    print("Sem resumo digital/hash gerado, sem credenciais, fontes binarias ou dados reais.")

if __name__ == "__main__":
    main()
