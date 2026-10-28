import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_info.dart';
import '../models/birth_plan_answer.dart';
import '../models/birth_plan_question.dart';
import '../models/treatment_preferences.dart';

enum BirthPlanPdfFormat { declaracao, resumoVisual }

class BirthPlanPdfTooLongException extends StateError {
  BirthPlanPdfTooLongException() : super(
    'Seu plano tem mais conteúdo do que cabe em uma página com boa leitura. '
    'Você pode resumir as respostas ou escolher "Resumo visual e registro completo" para guardar tudo. '
    'Suas respostas continuam salvas.',
  );
}

class PdfService {
  // O PDF não usa glyphs de ícones/emoji. Os marcadores e ícones são vetoriais
  // ou imagens de assets para evitar quadrados/erros de fonte na exportação.
  static final PdfColor _pink = PdfColor.fromHex('#F05A7E');
  static final PdfColor _softPink = PdfColor.fromHex('#FFF7F8');
  static final PdfColor _borderPink = PdfColor.fromHex('#F6A6B8');
  static final PdfColor _darkBlue = PdfColor.fromHex('#143D63');
  static final PdfColor _petBlue = PdfColor.fromHex('#49A3D8');
  static final PdfColor _petOrange = PdfColor.fromHex('#F04B1C');
  static final PdfColor _text = PdfColor.fromHex('#1F2D3D');

  Future<void> shareBirthPlanPdf({
    required List<BirthPlanQuestion> questions,
    required List<BirthPlanAnswer> answers,
    BirthPlanPdfFormat format = BirthPlanPdfFormat.declaracao,
    TreatmentPreferences? treatment,
  }) async {
    final bytes = await buildBirthPlanPdf(
      questions: questions, answers: answers, format: format, treatment: treatment,
    );
    final filename = format == BirthPlanPdfFormat.resumoVisual ? 'plano_de_parto_resumo_pet_saude.pdf' : 'plano_de_parto_declaracao_pet_saude.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  Future<Uint8List> buildBirthPlanPdf({
    required List<BirthPlanQuestion> questions,
    required List<BirthPlanAnswer> answers,
    BirthPlanPdfFormat format = BirthPlanPdfFormat.declaracao,
    TreatmentPreferences? treatment,
  }) async {
    // Embed both weights of one family; never rely on reader substitutions or
    // switch families for punctuation in the middle of a paragraph.
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final theme = pw.ThemeData.withFont(
      base: regular, bold: bold, italic: regular, boldItalic: bold,
      fontFallback: const [],
    // pdf treats wordSpacing as a multiplier: 1 preserves natural spaces.
    ).copyWith(defaultTextStyle: const pw.TextStyle(letterSpacing: 0, wordSpacing: 1));
    final doc = pw.Document(theme: theme);
    // A mascote também é usada na interface e deve integrar o bundle. Em
    // publicações Web antigas um logotipo ausente impedia todo o PDF.
    // Se uma marca opcional não carregar, mantenha o documento acessível.
    final petita = pw.MemoryImage(
      (await rootBundle.load('assets/images/petita.png')).buffer.asUint8List(),
    );
    final logoPet = await _loadLogoOrMascot('assets/images/pet_saude_logo.png', petita);
    final logoPetAvatar = await _loadLogoOrMascot('assets/images/pet_saude_avatar.png', petita);
    final logoUfcg = await _loadLogoOrMascot('assets/images/ufcg_logo.png', petita);
    final map = {for (final a in answers) a.questionId: a.values};

    if (format == BirthPlanPdfFormat.resumoVisual) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 12),
        build: (context) => _singlePage(
          logoUfcg: logoUfcg,
          logoPet: logoPet,
          logoPetAvatar: logoPetAvatar,
          petita: petita,
          map: map,
          treatment: treatment,
        ),
      ));
      // Preserve the legacy overview and include the full saved record on
      // following pages: its fixed cards intentionally summarize the content.
      if (answers.isNotEmpty) {
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (_) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text('Registro completo das respostas',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _darkBlue)),
          ),
          build: (_) => [
            for (final question in questions.where((question) => map.containsKey(question.id))) ...[
              pw.NewPage(freeSpace: 70),
              pw.Text(question.question, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _darkBlue, lineSpacing: 1.5)),
              pw.SizedBox(height: 4),
              pw.Text(map[question.id]!.join(', '), style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5), overflow: pw.TextOverflow.span),
              pw.SizedBox(height: 12),
            ],
          ],
        ));
      }
      return doc.save();
    }

    final paragraphs = _declarationParagraphs(map, treatment);
    // Keep a readable, fixed 10 pt body. Oversized declarations must use the
    // complete report rather than reducing the font until the text fits.
    try {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 25, 30, 24),
        build: (context) => _declarationPage(
          logoUfcg: logoUfcg,
          logoPet: logoPet,
          logoPetAvatar: logoPetAvatar,
          petita: petita,
          paragraphs: paragraphs,
          fontSize: 10,
        ),
      ));
      return await doc.save();
    } on StateError {
      throw BirthPlanPdfTooLongException();
    }
  }

  Future<pw.MemoryImage> _loadLogoOrMascot(String path, pw.MemoryImage fallback) async {
    try {
      return pw.MemoryImage((await rootBundle.load(path)).buffer.asUint8List());
    } catch (_) {
      // Nunca descartar respostas clínicas por ausência do asset de marca.
      return fallback;
    }
  }

  pw.Widget _declarationPage({
    required pw.MemoryImage logoUfcg,
    required pw.MemoryImage logoPet,
    required pw.MemoryImage logoPetAvatar,
    required pw.MemoryImage petita,
    required List<String> paragraphs,
    required double fontSize,
  }) {
    return _SinglePageColumn(
      children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Image(logoUfcg, height: 39, width: 90, fit: pw.BoxFit.contain),
          pw.Column(children: [
            pw.Text('PLANO DE PARTO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _darkBlue)),
            pw.Text('Declaração de preferências da gestante', style: pw.TextStyle(fontSize: 9, color: _text)),
          ]),
          pw.Image(logoPet, height: 39, width: 90, fit: pw.BoxFit.contain),
        ]),
        pw.SizedBox(height: 9),
        pw.Container(height: 1, color: _borderPink),
        pw.SizedBox(height: 14),
        ...paragraphs.map((paragraph) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            paragraph,
            textAlign: pw.TextAlign.left,
            style: pw.TextStyle(fontSize: fontSize, color: _text, lineSpacing: 2),
          ),
        )),
        pw.SizedBox(height: 5),
        pw.Text(
          'Este plano expressa minhas preferências e não substitui o diálogo, o consentimento informado para procedimentos ou a avaliação clínica. Solicito que qualquer mudança necessária seja explicada e discutida comigo, sempre que possível.',
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(fontSize: fontSize, color: _darkBlue, lineSpacing: 1.5),
        ),
        pw.Spacer(),
        pw.Text('Local: ____________________________________    Data: ____/____/________',
          style: pw.TextStyle(fontSize: 9, color: _text)),
        pw.SizedBox(height: 31),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _signature('Assinatura da gestante'),
          _signature('Assinatura do(a) profissional de saúde'),
        ]),
        pw.SizedBox(height: 16),
        _footer(logoPetAvatar),
      ],
    );
  }

  List<String> _declarationParagraphs(
    Map<String, List<String>> map,
    TreatmentPreferences? treatment,
  ) {
    final name = _selected(map, 'nome_gestante');
    final opening = StringBuffer('Eu, ${name == null || name.toLowerCase().contains('prefiro não informar') ? '________________________________' : name}, por meio deste Plano de Parto, manifesto minhas preferências para o trabalho de parto, o nascimento e os cuidados iniciais com meu bebê.');
    final dpp = _selected(map, 'dpp');
    final ubs = _selected(map, 'ubs_referencia');
    if (dpp != null) opening.write(' Minha data provável do parto é $dpp.');
    if (ubs != null) opening.write(' Minha unidade de referência é $ubs.');
    if (treatment != null && treatment.includeInPdf && treatment.hasPronouns) {
      opening.write(' Peço que a equipe se refira a mim desta forma: ${treatment.pronouns}.');
    }
    final semanas = _selected(map, 'semanas_gestacao');
    if (semanas != null) opening.write(' Idade gestacional informada: $semanas.');
    final paragraphs = <String>[opening.toString()];

    void add(String intro, List<List<String>> fields) {
      final parts = <String>[];
      for (final field in fields) {
        final value = _selected(map, field[0]);
        if (value != null && value.isNotEmpty) parts.add('${field[1]}: $value');
      }
      if (parts.isNotEmpty) paragraphs.add('$intro ${parts.join('; ')}.');
    }

    add('Sobre o acompanhamento e a comunicação com a equipe, registro as seguintes escolhas:', [
      ['acompanhante_principal', 'acompanhante'],
      ['doula', 'apoio de doula'],
      ['acompanhamento_continuo', 'presença durante o trabalho de parto'],
      ['apoio_comunicacao', 'apoio desejado'],
      ['comunicacao_equipe', 'forma de comunicação'],
    ]);
    add('Durante o trabalho de parto, minhas preferências são:', [
      ['movimentacao', 'movimentação'],
      ['posicao_contracoes', 'posições durante as contrações'],
      ['alimentacao', 'alimentação e líquidos'],
      ['ambiente', 'ambiente'],
      ['alivio_dor', 'alívio da dor'],
      ['informacao_procedimentos', 'informações sobre procedimentos'],
    ]);
    add('No momento do nascimento, manifesto minhas decisões e preferências:', [
      ['cenario_parto', 'possibilidade de parto'],
      ['posicao_nascimento', 'posição para o nascimento'],
      ['episiotomia', 'episiotomia'],
      ['toque_vaginal', 'exames de toque'],
      ['kristeller', 'manobra de Kristeller'],
      ['cordao_umbilical', 'clampeamento do cordão'],
      ['cesarea', 'em caso de cesárea'],
    ]);
    add('Após o nascimento, em relação ao meu bebê e ao pós-parto, desejo:', [
      ['bebe_primeira_hora', 'primeira hora'],
      ['cuidados_nao_urgentes', 'cuidados não urgentes'],
      ['alojamento_conjunto', 'permanência com meu bebê'],
      ['orientacoes_posparto', 'orientações antes da alta'],
    ]);
    add('Também registro estas preferências pessoais:', [
      ['privacidade', 'privacidade'],
      ['registros_fotograficos', 'fotografias'],
      ['preferencias_culturais', 'preferências culturais ou religiosas'],
      ['prioridade_parto', 'prioridades'],
      ['observacoes_finais', 'observações adicionais'],
    ]);
    return paragraphs;
  }

  pw.Widget _singlePage({
    required pw.MemoryImage logoUfcg,
    required pw.MemoryImage logoPet,
    required pw.MemoryImage logoPetAvatar,
    required pw.MemoryImage petita,
    required Map<String, List<String>> map,
    TreatmentPreferences? treatment,
  }) {
    final nome = _value(map, 'nome_gestante', 'Não informado');
    final dpp = _value(map, 'dpp', 'Não informada');
    final ubs = _value(map, 'ubs_referencia', 'Não informada');
    final acompanhante = _value(map, 'acompanhante_principal', 'Não informado');
    final data = _todayPtBr();

    return _SinglePageColumn(
      children: [
        _header(logoUfcg: logoUfcg, logoPet: logoPet, petita: petita),
        pw.SizedBox(height: 5),
        _dataBox(nome: nome, dpp: dpp, ubs: ubs, acompanhante: acompanhante, data: data),
        if (treatment != null && treatment.includeInPdf && treatment.hasPronouns) ...[
          pw.SizedBox(height: 5),
          pw.Text('Preferência de tratamento para a equipe: ${treatment.pronouns}',
            style: pw.TextStyle(fontSize: 9, color: _darkBlue, fontWeight: pw.FontWeight.bold)),
        ],
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionCard(number: 2, title: 'Acompanhante e apoio', bullets: _acompanhanteBullets(map, acompanhante)),
            pw.SizedBox(width: 8),
            _sectionCard(number: 3, title: 'Trabalho de parto', bullets: _trabalhoBullets(map)),
            pw.SizedBox(width: 8),
            _sectionCard(number: 4, title: 'Alívio da dor', bullets: _alivioBullets(map)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionCard(number: 5, title: 'Nascimento', bullets: _nascimentoBullets(map)),
            pw.SizedBox(width: 8),
            _sectionCard(number: 6, title: 'Cuidados com o bebê', bullets: _bebeBullets(map)),
            pw.SizedBox(width: 8),
            _sectionCard(number: 7, title: 'Em caso de cesárea', bullets: _cesareaBullets(map)),
          ],
        ),
        pw.SizedBox(height: 8),
        _observationsBox(map),
        pw.SizedBox(height: 7),
        _noteBox(),
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [_signature('Gestante'), _signature('Profissional/Equipe')],
        ),
        pw.Spacer(),
        _footer(logoPetAvatar),
      ],
    );
  }

  pw.Widget _header({required pw.MemoryImage logoUfcg, required pw.MemoryImage logoPet, required pw.MemoryImage petita}) {
    return pw.Column(children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(
            width: 112,
            child: pw.Image(logoUfcg, height: 58, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(
            width: 306,
            child: pw.Column(children: [
              pw.Text('Plano de Parto', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 29, fontWeight: pw.FontWeight.bold, color: _darkBlue)),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'PET ', style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold, color: _petOrange)),
                pw.TextSpan(text: 'Saúde', style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold, color: _petBlue)),
              ])),
              pw.SizedBox(height: 3),
              pw.Text(
                'Documento de preferências para o trabalho de parto,\nparto, pós-parto imediato e cuidados com o recém-nascido',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9.1, color: _text),
              ),
            ]),
          ),
          pw.SizedBox(width: 112, child: pw.Image(logoPet, height: 62, fit: pw.BoxFit.contain)),
        ],
      ),
      pw.SizedBox(height: 7),
      _dividerWithDot(),
      pw.SizedBox(height: 5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('Gerado pelo aplicativo Plano de Parto ', style: pw.TextStyle(fontSize: 8.5, color: _text)),
          pw.Text('PET ', style: pw.TextStyle(fontSize: 8.5, color: _petOrange, fontWeight: pw.FontWeight.bold)),
          pw.Text('Saúde', style: pw.TextStyle(fontSize: 8.5, color: _petBlue, fontWeight: pw.FontWeight.bold)),
          pw.Text('  -  Assistente virtual Petita', style: pw.TextStyle(fontSize: 8.5, color: _text)),
        ],
      ),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(petita, height: 42, fit: pw.BoxFit.contain)),
    ]);
  }

  pw.Widget _dataBox({required String nome, required String dpp, required String ubs, required String acompanhante, required String data}) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderPink, width: 0.9), borderRadius: pw.BorderRadius.circular(10), color: PdfColors.white),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _sectionHeader('1) Dados da gestante'),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(12, 7, 12, 8),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(children: [
              _dataLine('Nome:', nome),
              _thinDivider(),
              _dataLine('DPP:', dpp),
              _thinDivider(),
              _dataLine('UBS de referência:', ubs),
            ])),
            pw.Container(width: 0.7, height: 62, color: _borderPink, margin: const pw.EdgeInsets.symmetric(horizontal: 10)),
            pw.Expanded(child: pw.Column(children: [
              _dataLine('Acompanhante principal:', acompanhante),
              _thinDivider(),
              _dataLine('Data de geração:', data),
            ])),
          ]),
        ),
      ]),
    );
  }

  pw.Widget _dataLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.8),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _smallSquare(),
          pw.SizedBox(width: 6),
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _darkBlue, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _previewText(value, limit: 80, style: pw.TextStyle(fontSize: 9, color: _text))),
        ]),
      );

  pw.Widget _sectionCard({required int number, required String title, required List<String> bullets}) {
    return pw.Expanded(
      child: pw.Container(
        height: 148,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderPink, width: 0.75), borderRadius: pw.BorderRadius.circular(9), color: PdfColors.white),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(color: _softPink, borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(9), topRight: pw.Radius.circular(9))),
            child: pw.Row(children: [
              _sectionBadge(number),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text('$number) $title', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pink))),
            ]),
          ),
          pw.Container(height: 0.65, color: _borderPink),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 7, 8, 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: bullets.take(4).map((text) => _bullet(text)).toList()),
          ),
        ]),
      ),
    );
  }

  pw.Widget _sectionHeader(String title) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(color: _softPink, borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(10), topRight: pw.Radius.circular(10))),
        child: pw.Row(children: [
          _sectionBadge(1),
          pw.SizedBox(width: 7),
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pink)),
        ]),
      );

  pw.Widget _bullet(String text, {int limit = 90}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 3.5, height: 3.5, margin: const pw.EdgeInsets.only(top: 4), decoration: pw.BoxDecoration(color: _pink, shape: pw.BoxShape.circle)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: _previewText(text, limit: limit, style: pw.TextStyle(fontSize: 9, color: _text, lineSpacing: 1.25))),
        ]),
      );

  pw.Widget _observationsBox(Map<String, List<String>> map) {
    final items = <String>[];
    final obs = _selected(map, 'observacoes_finais');
    if (obs != null) items.add(obs);
    final cultura = _selected(map, 'preferencias_culturais');
    if (cultura != null) items.add('Preferência cultural/religiosa: $cultura');
    final fotos = _selected(map, 'registros_fotograficos');
    if (fotos != null) items.add('Fotografias: $fotos');
    if (items.isEmpty) items.add('Nenhuma observação final registrada.');
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderPink, width: 0.75), borderRadius: pw.BorderRadius.circular(9), color: PdfColors.white),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: pw.BoxDecoration(color: _softPink, borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(9), topRight: pw.Radius.circular(9))),
          child: pw.Row(children: [
            _sectionBadge(8),
            pw.SizedBox(width: 6),
            pw.Text('8) Observações finais', style: pw.TextStyle(fontSize: 9.4, fontWeight: pw.FontWeight.bold, color: _pink)),
          ]),
        ),
        pw.Container(height: 0.65, color: _borderPink),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: items.take(3).map((text) => _bullet(text, limit: 180)).toList(),
          ),
        ),
      ]),
    );
  }

  pw.Widget _noteBox() => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFFDFD'), border: pw.Border.all(color: _borderPink, width: 0.75), borderRadius: pw.BorderRadius.circular(9)),
        child: pw.Row(children: [
          _clipboardIcon(),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Text('Este documento resume preferências registradas pela gestante. Consulte o registro no aplicativo e converse com a equipe sobre suas escolhas, sempre que clinicamente possível.', style: pw.TextStyle(fontSize: 8.8, color: _darkBlue, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  pw.Widget _signature(String label) => pw.Column(children: [
        pw.Container(width: 170, height: 0.8, color: _pink),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _darkBlue, fontWeight: pw.FontWeight.bold)),
      ]);

  pw.Widget _footer(pw.MemoryImage logoPetAvatar) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(child: pw.Column(children: [
          _dividerWithDot(),
          pw.SizedBox(height: 6),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Plano de Parto PET Saúde - ', style: pw.TextStyle(fontSize: 8.5, color: _text)),
            pw.TextSpan(text: 'PET ', style: pw.TextStyle(fontSize: 8.5, color: _petOrange, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: 'Saúde UFCG - Versão ${AppInfo.version}', style: pw.TextStyle(fontSize: 8.5, color: _text)),
          ])),
        ])),
        pw.SizedBox(width: 8),
        pw.Container(width: 32, height: 32, decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderPink), shape: pw.BoxShape.circle), child: pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Image(logoPetAvatar, fit: pw.BoxFit.contain))),
      ]);

  pw.Widget _dividerWithDot() => pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 0.7, color: _borderPink)),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8), child: pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: _pink, shape: pw.BoxShape.circle))),
        pw.Expanded(child: pw.Container(height: 0.7, color: _borderPink)),
      ]);

  pw.Widget _sectionBadge(int number) => pw.Container(
        width: 12,
        height: 12,
        decoration: pw.BoxDecoration(color: _pink, shape: pw.BoxShape.circle),
        alignment: pw.Alignment.center,
        child: pw.Text(number.toString(), style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _smallSquare() => pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(border: pw.Border.all(color: _pink, width: 1), borderRadius: pw.BorderRadius.circular(2)));

  pw.Widget _clipboardIcon() => pw.Container(
        width: 28,
        height: 28,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _pink, width: 1.2), borderRadius: pw.BorderRadius.circular(5)),
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            pw.Container(height: 1.2, color: _pink),
            pw.Container(height: 1.2, color: _pink),
            pw.Container(height: 1.2, color: _pink),
          ]),
        ),
      );

  pw.Widget _thinDivider() => pw.Container(height: 0.5, color: PdfColor.fromHex('#FDECEF'));

  String _value(Map<String, List<String>> map, String id, String fallback) {
    final selected = _selected(map, id);
    return selected ?? fallback;
  }

  // Measure the actual embedded font at its fixed readable size. Shorten only
  // the overview preview, never clip text or shrink it to fit a fixed card.
  pw.Widget _previewText(String text, {required int limit, required pw.TextStyle style}) =>
      pw.LayoutBuilder(builder: (context, constraints) {
        var budget = limit;
        while (budget > 28) {
          final candidate = pw.Text(_preview(text, budget), style: style);
          candidate.layout(context, pw.BoxConstraints(maxWidth: constraints!.maxWidth), parentUsesSize: true);
          if (candidate.box!.height <= 28) return candidate;
          budget -= 4;
        }
        return pw.Text('Ver registro completo', style: style);
      });

  // Only the fixed first-page overview is abbreviated. The following pages
  // always receive the original, complete answers.
  String _preview(String text, int limit) {
    if (text.runes.length <= limit) return text;
    const suffix = '... [ver registro completo]';
    var prefix = String.fromCharCodes(text.runes.take(limit - suffix.length));
    final space = prefix.lastIndexOf(' ');
    if (space > prefix.length ~/ 2) prefix = prefix.substring(0, space);
    return '${prefix.trimRight()}$suffix';
  }

  String? _selected(Map<String, List<String>> map, String id) {
    final list = map[id];
    if (list == null || list.isEmpty) return null;
    final cleaned = list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return cleaned.isEmpty ? null : cleaned.join(', ');
  }

  List<String> _values(Map<String, List<String>> map, String id, List<String> fallback) {
    final values = map[id];
    if (values == null || values.isEmpty) return [];
    return values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.toLowerCase().contains('não desejo registrar'))
        .toList();
  }

  List<String> _filled(List<String> bullets) =>
      bullets.isEmpty ? ['Nenhuma preferência registrada nesta seção.'] : bullets;

  List<String> _acompanhanteBullets(Map<String, List<String>> map, String acompanhante) {
    final bullets = <String>[];
    if (acompanhante != 'Não informado') bullets.add('Acompanhante: $acompanhante.');
    for (final entry in [
      ['doula', 'Doula'],
      ['acompanhamento_continuo', 'Permanência do acompanhante'],
      ['apoio_comunicacao', 'Apoio'],
      ['comunicacao_equipe', 'Comunicação com a equipe'],
    ]) {
      final text = _selected(map, entry[0]);
      if (text != null) bullets.add('${entry[1]}: $text.');
    }
    return _filled(bullets).take(4).toList();
  }

  List<String> _trabalhoBullets(Map<String, List<String>> map) {
    final bullets = <String>[];
    for (final entry in [
      ['movimentacao', 'Movimentação'],
      ['alimentacao', 'Alimentação e líquidos'],
      ['posicao_contracoes', 'Posições nas contrações'],
      ['ambiente', 'Ambiente'],
      ['informacao_procedimentos', 'Informação antes dos procedimentos'],
      ['privacidade', 'Privacidade'],
    ]) {
      final text = _selected(map, entry[0]);
      if (text != null) bullets.add('${entry[1]}: $text.');
    }
    return _filled(bullets).take(4).toList();
  }

  List<String> _alivioBullets(Map<String, List<String>> map) {
    final list = _values(map, 'alivio_dor', []);
    return _filled(list.map(_sentence).toList()).take(5).toList();
  }

  List<String> _nascimentoBullets(Map<String, List<String>> map) {
    final bullets = <String>[];
    for (final entry in [
      ['posicao_nascimento', 'Posição do parto'],
      ['episiotomia', 'Episiotomia'],
      ['toque_vaginal', 'Exames de toque'],
      ['kristeller', 'Manobra de Kristeller'],
      ['cordao_umbilical', 'Clampeamento do cordão'],
    ]) {
      final text = _selected(map, entry[0]);
      if (text != null) bullets.add('${entry[1]}: $text.');
    }
    return _filled(bullets).take(5).toList();
  }

  List<String> _bebeBullets(Map<String, List<String>> map) {
    final bullets = <String>[];
    final primeira = _values(map, 'bebe_primeira_hora', []);
    if (primeira.isNotEmpty) bullets.add('Primeiros cuidados: ${primeira.join(', ')}.');
    for (final entry in [
      ['cuidados_nao_urgentes', 'Cuidados não urgentes'],
      ['alojamento_conjunto', 'Permanência com o bebê'],
      ['orientacoes_posparto', 'Orientações antes da alta'],
    ]) {
      final text = _selected(map, entry[0]);
      if (text != null) bullets.add('${entry[1]}: $text.');
    }
    return _filled(bullets).take(4).toList();
  }

  List<String> _cesareaBullets(Map<String, List<String>> map) {
    final list = _values(map, 'cesarea', []);
    return _filled(list.map(_sentence).toList()).take(4).toList();
  }

  String _sentence(String value) =>
      value.trim().endsWith('.') ? value.trim() : '${value.trim()}.';

  String _todayPtBr() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year}';
  }
}

// Page/Column can silently omit children once the page height is exceeded.
// Reject the page with a visible size error instead of exporting missing
// text/signatures or reducing the fixed, readable body font.
class _SinglePageColumn extends pw.Column {
  _SinglePageColumn({required super.children})
      : super(crossAxisAlignment: pw.CrossAxisAlignment.stretch);

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);
    if (children.any((child) => child.box == null ||
        child.box!.bottom < -0.1 || child.box!.top > box!.height + 0.1)) {
      throw StateError('O conteúdo excedeu a altura disponível da página.');
    }
  }
}
