import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_info.dart';
import '../models/birth_plan_answer.dart';
import '../models/birth_plan_question.dart';

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
  }) async {
    final bytes = await buildBirthPlanPdf(questions: questions, answers: answers);
    await Printing.sharePdf(bytes: bytes, filename: 'plano_de_parto_pet_saude.pdf');
  }

  Future<Uint8List> buildBirthPlanPdf({
    required List<BirthPlanQuestion> questions,
    required List<BirthPlanAnswer> answers,
  }) async {
    final doc = pw.Document();
    final logoPet = pw.MemoryImage((await rootBundle.load('assets/images/pet_saude_logo.png')).buffer.asUint8List());
    final logoPetAvatar = pw.MemoryImage((await rootBundle.load('assets/images/pet_saude_avatar.png')).buffer.asUint8List());
    final logoUfcg = pw.MemoryImage((await rootBundle.load('assets/images/ufcg_logo.png')).buffer.asUint8List());
    final petita = pw.MemoryImage((await rootBundle.load('assets/images/petita.png')).buffer.asUint8List());
    final map = {for (final a in answers) a.questionId: a.values};

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 12),
        build: (context) => _singlePage(
          logoUfcg: logoUfcg,
          logoPet: logoPet,
          logoPetAvatar: logoPetAvatar,
          petita: petita,
          map: map,
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _singlePage({
    required pw.MemoryImage logoUfcg,
    required pw.MemoryImage logoPet,
    required pw.MemoryImage logoPetAvatar,
    required pw.MemoryImage petita,
    required Map<String, List<String>> map,
  }) {
    final nome = _value(map, 'nome_gestante', 'Laís Vitória de Sousa');
    final dpp = _value(map, 'dpp', '18/11/2026');
    final ubs = _value(map, 'ubs_referencia', 'UBS - Estação Velha');
    final acompanhante = _value(map, 'acompanhante_principal', 'Esposo/parceiro');
    final data = _todayPtBr();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(logoUfcg: logoUfcg, logoPet: logoPet, petita: petita),
        pw.SizedBox(height: 5),
        _dataBox(nome: nome, dpp: dpp, ubs: ubs, acompanhante: acompanhante, data: data),
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
        pw.SizedBox(height: 30),
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
          pw.Text('Gerado pelo aplicativo Plano de Parto ', style: pw.TextStyle(fontSize: 7.8, color: _text)),
          pw.Text('PET ', style: pw.TextStyle(fontSize: 7.8, color: _petOrange, fontWeight: pw.FontWeight.bold)),
          pw.Text('Saúde', style: pw.TextStyle(fontSize: 7.8, color: _petBlue, fontWeight: pw.FontWeight.bold)),
          pw.Text('  -  Assistente virtual Petita', style: pw.TextStyle(fontSize: 7.8, color: _text)),
        ],
      ),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Image(petita, height: 60, fit: pw.BoxFit.contain)),
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
          pw.Text(label, style: pw.TextStyle(fontSize: 8.2, color: _darkBlue, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 8.2, color: _text))),
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
              pw.Expanded(child: pw.Text('$number) $title', style: pw.TextStyle(fontSize: 9.2, fontWeight: pw.FontWeight.bold, color: _pink))),
            ]),
          ),
          pw.Container(height: 0.65, color: _borderPink),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 7, 8, 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: bullets.take(6).map(_bullet).toList()),
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

  pw.Widget _bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 3.5, height: 3.5, margin: const pw.EdgeInsets.only(top: 4), decoration: pw.BoxDecoration(color: _pink, shape: pw.BoxShape.circle)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(text, style: pw.TextStyle(fontSize: 7.15, color: _text, lineSpacing: 1.25))),
        ]),
      );

  pw.Widget _observationsBox(Map<String, List<String>> map) {
    final obs = _value(map, 'observacoes_finais', 'Desejo que minha autonomia, minhas escolhas e meu direito à informação sejam respeitados durante toda a assistência.');
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
        pw.Padding(padding: const pw.EdgeInsets.fromLTRB(12, 6, 12, 6), child: _bullet('"$obs"')),
      ]),
    );
  }

  pw.Widget _noteBox() => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFFDFD'), border: pw.Border.all(color: _borderPink, width: 0.75), borderRadius: pw.BorderRadius.circular(9)),
        child: pw.Row(children: [
          _clipboardIcon(),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Text('Este documento expressa preferências da gestante e deve ser considerado pela equipe de saúde sempre que clinicamente possível.', style: pw.TextStyle(fontSize: 8.8, color: _darkBlue, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  pw.Widget _signature(String label) => pw.Column(children: [
        pw.Container(width: 170, height: 0.8, color: _pink),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _darkBlue, fontWeight: pw.FontWeight.bold)),
      ]);

  pw.Widget _footer(pw.MemoryImage logoPetAvatar) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(child: pw.Column(children: [
          _dividerWithDot(),
          pw.SizedBox(height: 6),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Plano de Parto PET Saúde - ', style: pw.TextStyle(fontSize: 8, color: _text)),
            pw.TextSpan(text: 'PET ', style: pw.TextStyle(fontSize: 8, color: _petOrange, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: 'Saúde UFCG - Versão ${AppInfo.version}', style: pw.TextStyle(fontSize: 8, color: _text)),
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
        child: pw.Text(number.toString(), style: pw.TextStyle(fontSize: 6.4, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
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

  pw.Widget _careIcon() => pw.SizedBox(
        width: 32,
        height: 28,
        child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Container(width: 13, height: 13, decoration: pw.BoxDecoration(border: pw.Border.all(color: _pink, width: 1.2), shape: pw.BoxShape.circle)),
          pw.SizedBox(height: 2),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Container(width: 14, height: 1.2, color: _pink),
            pw.SizedBox(width: 3),
            pw.Container(width: 14, height: 1.2, color: _pink),
          ]),
        ]),
      );

  pw.Widget _thinDivider() => pw.Container(height: 0.5, color: PdfColor.fromHex('#FDECEF'));

  String _value(Map<String, List<String>> map, String id, String fallback) {
    final values = map[id];
    if (values == null || values.isEmpty) return fallback;
    final value = values.where((v) => v.trim().isNotEmpty).join(', ');
    return value.isEmpty ? fallback : value;
  }

  List<String> _values(Map<String, List<String>> map, String id, List<String> fallback) {
    final values = map[id];
    if (values == null || values.isEmpty) return fallback;
    final cleaned = values.where((v) => v.trim().isNotEmpty && !v.toLowerCase().contains('não desejo registrar')).toList();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  List<String> _acompanhanteBullets(Map<String, List<String>> map, String acompanhante) {
    final doula = _value(map, 'doula', 'Sim, desejo presença de doula, se possível');
    final apoio = _value(map, 'apoio_comunicacao', 'Sim, desejo apoio emocional, privacidade e comunicação clara');
    return [
      'Desejo ter acompanhante durante o trabalho de parto e o parto.',
      'Acompanhante preferencial: $acompanhante.',
      apoio.toLowerCase().startsWith('sim') ? 'Desejo apoio emocional, privacidade e comunicação clara durante toda a assistência.' : apoio,
      doula.toLowerCase().startsWith('sim') ? 'Desejo presença de doula, se possível.' : doula,
    ];
  }

  List<String> _trabalhoBullets(Map<String, List<String>> map) {
    final alimentacao = _values(map, 'alimentacao', ['líquidos e, se permitido, alimentação leve']).join(', ');
    final ambiente = _values(map, 'ambiente', ['ambiente calmo, acolhedor e com privacidade']).join(', ');
    return [
      _sentence(_value(map, 'movimentacao', 'Desejo livre movimentação durante o trabalho de parto.').replaceFirst('Sim, ', '')),
      'Desejo ingerir $alimentacao.',
      'Desejo $ambiente.',
      _sentence(_value(map, 'informacao_procedimentos', 'Desejo ser informada antes de qualquer procedimento.').replaceFirst('Sim, ', '')),
    ];
  }

  List<String> _alivioBullets(Map<String, List<String>> map) =>
      _values(map, 'alivio_dor', ['Preferência por métodos não farmacológicos', 'Banho morno/chuveiro', 'Massagem', 'Técnicas de respiração', 'Bola de parto', 'Analgesia, se necessário e disponível']).map(_sentence).toList();

  List<String> _nascimentoBullets(Map<String, List<String>> map) {
    final positions = _values(map, 'posicao_nascimento', ['vertical', 'semi-sentada ou cócoras']).join(', ').toLowerCase();
    final cordao = _value(map, 'cordao_umbilical', 'Sim, desejo clampeamento oportuno');
    return [
      'Posições preferidas: $positions.',
      'Desejo liberdade para escolher a posição de parir, quando clinicamente possível.',
      cordao.toLowerCase().startsWith('sim') ? 'Desejo aguardar alguns instantes antes de cortar o cordão umbilical, se mãe e bebê estiverem bem.' : _sentence(cordao),
      'Desejo contato imediato com o bebê após o nascimento, se ambos estiverem bem.',
    ];
  }

  List<String> _bebeBullets(Map<String, List<String>> map) {
    final primeiraHora = _values(map, 'bebe_primeira_hora', ['Contato pele a pele imediato', 'Amamentação na primeira hora de vida']);
    final cuidados = _value(map, 'cuidados_nao_urgentes', 'Sim, evitar procedimentos não urgentes antes do primeiro contato');
    final bullets = <String>[];
    for (final item in primeiraHora.take(2)) {
      bullets.add(_sentence(item));
    }
    bullets.add(cuidados.toLowerCase().startsWith('sim') ? 'Evitar procedimentos não urgentes antes do primeiro contato, quando possível.' : _sentence(cuidados));
    bullets.add('Presença do acompanhante nos primeiros cuidados.');
    return bullets;
  }

  List<String> _cesareaBullets(Map<String, List<String>> map) =>
      _values(map, 'cesarea', ['Ser informada sobre a indicação e participar da decisão', 'Presença do acompanhante, se possível', 'Contato pele a pele e amamentação precoce assim que houver condições']).map((e) {
        if (e == 'Contato pele a pele quando houver condições') return 'Desejo contato pele a pele e amamentação precoce assim que houver condições.';
        return _sentence(e.startsWith('Desejo') ? e : 'Desejo ${e[0].toLowerCase()}${e.substring(1)}');
      }).take(4).toList();

  String _sentence(String value) => value.trim().endsWith('.') ? value.trim() : '${value.trim()}.';

  String _todayPtBr() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year}';
  }
}
