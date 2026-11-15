import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WordBuilder — helper tunggal untuk membuat & berbagi file .docx
// Dipakai oleh: AiPage, DetailCatatanPage, DetailTugasPage
// ─────────────────────────────────────────────────────────────────────────────

class WordBuilder {
  /// Buat file .docx dan kembalikan path-nya.
  /// [title]    : judul dokumen (juga nama file)
  /// [sections] : list {'heading': String?, 'content': String}
  /// [images]   : list WordImage (opsional)
  static Future<String> build({
    required String title,
    required List<Map<String, dynamic>> sections,
    List<WordImage> images = const [],
  }) async {
    final docBytes = await _buildDocx(title, sections, images);
    final dir = await getTemporaryDirectory();
    final safeName =
    title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final path = '${dir.path}/$safeName.docx';
    await File(path).writeAsBytes(docBytes);
    return path;
  }

  /// Buka sheet berbagi / simpan file.
  static Future<void> share(String filePath, String fileName) async {
    await Share.shareXFiles([XFile(filePath)], text: 'Dokumen: $fileName');
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildDocx(
      String title,
      List<Map<String, dynamic>> sections,
      List<WordImage> images,
      ) async {
    final contentBuffer = StringBuffer();

    // Judul utama
    contentBuffer.write(_para(title, style: 'Heading1', bold: true, size: 36));
    contentBuffer.write(_para(''));

    // Sections
    for (final section in sections) {
      final heading = section['heading'] as String?;
      final content = section['content'] as String? ?? '';
      if (heading != null && heading.isNotEmpty && heading != 'null') {
        contentBuffer.write(
            _para(heading, style: 'Heading2', bold: true, size: 28));
      }
      for (final line in content.split('\n')) {
        if (line.trim().isNotEmpty) {
          contentBuffer.write(_para(line.trim(), size: 24));
        }
      }
      contentBuffer.write(_para(''));
    }

    // Gambar
    final imageRelations = <String>[];
    final imageFiles = <MapEntry<String, Uint8List>>[];
    final imageExts = <String>{};

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final rId = 'rId${i + 10}';
      final ext = img.ext;
      final mediaName = 'image${i + 1}.$ext';

      imageRelations.add(
        '<Relationship Id="$rId" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            'Target="media/$mediaName"/>',
      );
      imageFiles.add(MapEntry(mediaName, img.bytes));
      imageExts.add(ext);

      contentBuffer.write(
          _para('Gambar ${i + 1}: ${img.name}', size: 20, italic: true));
      contentBuffer.write(_imageXml(rId, i + 1));
      contentBuffer.write(_para(''));
    }

    // ── XML ──────────────────────────────────────────────────────────────────

    final documentXml = _documentXml(contentBuffer.toString());
    final stylesXml = _stylesXml();

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
    Target="styles.xml"/>
  ${imageRelations.join('\n  ')}
</Relationships>''';

    final imgTypes = imageExts.map((ext) {
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      return '<Default Extension="$ext" ContentType="$mime"/>';
    }).join('\n  ');

    final contentTypesXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels"
    ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  $imgTypes
  <Override PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    const rootRelsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>
</Relationships>''';

    // ── ZIP ───────────────────────────────────────────────────────────────────

    final archive = Archive();

    void addText(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    void addBin(String name, Uint8List bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addText('[Content_Types].xml', contentTypesXml);
    addText('_rels/.rels', rootRelsXml);
    addText('word/document.xml', documentXml);
    addText('word/styles.xml', stylesXml);
    addText('word/_rels/document.xml.rels', relsXml);
    for (final e in imageFiles) {
      addBin('word/media/${e.key}', e.value);
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('Gagal encode ZIP');
    return Uint8List.fromList(encoded);
  }

  // ── XML Helpers ───────────────────────────────────────────────────────────

  static String _para(String text, {
    String? style,
    bool bold = false,
    bool italic = false,
    int size = 24,
  }) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final pPr = style != null
        ? '<w:pPr><w:pStyle w:val="$style"/></w:pPr>'
        : '';

    final rPr = StringBuffer('<w:rPr>');
    if (bold) rPr.write('<w:b/>');
    if (italic) rPr.write('<w:i/>');
    rPr.write('<w:sz w:val="$size"/><w:szCs w:val="$size"/>');
    rPr.write('</w:rPr>');

    if (escaped.isEmpty) return '<w:p>$pPr</w:p>';

    return '<w:p>$pPr<w:r>${rPr.toString()}'
        '<w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  static String _imageXml(String rId, int docPrId) {
    const widthEmu = 5486400;
    const heightEmu = 4114800;
    return '''
<w:p>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0"
        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="$widthEmu" cy="$heightEmu"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$docPrId" name="Gambar $docPrId"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="$docPrId" name="Gambar $docPrId"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$rId"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$widthEmu" cy="$heightEmu"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>''';
  }

  static String _documentXml(String body) =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"
               w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';

  static String _stylesXml() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="36"/><w:szCs w:val="36"/>
      <w:color w:val="2E4057"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:pPr><w:spacing w:before="200" w:after="80"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/>
      <w:color w:val="048A81"/></w:rPr>
  </w:style>
</w:styles>''';
}

// ── Model gambar ───────────────────────────────────────────────────────────────

class WordImage {
  final Uint8List bytes;
  final String name;
  final String ext; // 'png' atau 'jpg'

  const WordImage({
    required this.bytes,
    required this.name,
    required this.ext,
  });

  static Future<WordImage?> fromFile(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final ext = path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final name = path.split('/').last;
      return WordImage(bytes: bytes, name: name, ext: ext);
    } catch (_) {
      return null;
    }
  }
}

// ── Dialog pembantu untuk membuat Word dari mana saja ─────────────────────────

class WordDialog extends StatefulWidget {
  /// Konten awal (judul + isi yang sudah diketahui)
  final String initialTitle;
  final String initialContent;

  /// Gambar yang sudah ada (dari lampiran tugas/catatan)
  final List<String> existingImagePaths;

  const WordDialog({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    this.existingImagePaths = const [],
  });

  @override
  State<WordDialog> createState() => _WordDialogState();
}

class _WordDialogState extends State<WordDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _isCreating = false;
  bool _includeImages = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _contentCtrl = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _buat() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Judul tidak boleh kosong!')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Bagi konten menjadi sections berdasarkan baris ganda
      final rawContent = _contentCtrl.text.trim();
      final sections = <Map<String, dynamic>>[];

      // Coba deteksi baris yang diawali dengan angka/huruf besar sebagai heading
      final lines = rawContent.split('\n');
      final buffer = StringBuffer();
      String? currentHeading;

      for (final line in lines) {
        final trimmed = line.trim();
        // Heuristik: baris pendek (<= 60 karakter) yang diakhiri ':' → heading
        if (trimmed.length <= 60 &&
            trimmed.endsWith(':') &&
            trimmed.length > 3) {
          // Flush buffer ke section sebelumnya
          if (buffer.isNotEmpty) {
            sections.add({
              'heading': currentHeading,
              'content': buffer.toString().trim()
            });
            buffer.clear();
          }
          currentHeading = trimmed.replaceAll(':', '');
        } else {
          buffer.writeln(trimmed);
        }
      }
      // Sisa buffer
      if (buffer.isNotEmpty) {
        sections.add({
          'heading': currentHeading,
          'content': buffer.toString().trim()
        });
      }
      if (sections.isEmpty) {
        sections.add({'heading': null, 'content': rawContent});
      }

      // Muat gambar jika ada dan user centang
      final wordImages = <WordImage>[];
      if (_includeImages && widget.existingImagePaths.isNotEmpty) {
        for (final p in widget.existingImagePaths) {
          final img = await WordImage.fromFile(p);
          if (img != null) wordImages.add(img);
        }
      }

      final path = await WordBuilder.build(
        title: title,
        sections: sections,
        images: wordImages,
      );

      setState(() => _isCreating = false);

      if (!mounted) return;
      Navigator.pop(context);

      // Langsung bagikan
      await WordBuilder.share(path, '${title.replaceAll(' ', '_')}.docx');
    } catch (e) {
      setState(() => _isCreating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat Word: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Buat Dokumen Word',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),

            // Judul
            const Text('Judul Dokumen',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Contoh: Laporan Harian',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Isi
            const Text('Isi Dokumen',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: _contentCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Tulis isi dokumen di sini...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Toggle gambar (hanya muncul jika ada gambar lampiran)
            if (widget.existingImagePaths.isNotEmpty)
              Row(
                children: [
                  Checkbox(
                    value: _includeImages,
                    onChanged: (v) => setState(() => _includeImages = v ?? true),
                    activeColor: Colors.blue.shade700,
                  ),
                  Text(
                    'Sertakan ${widget.existingImagePaths.length} gambar lampiran',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Tip format
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: Colors.blue),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tips: Akhiri baris dengan ":" untuk dijadikan sub-judul.\nContoh: "Pendahuluan:"',
                      style: TextStyle(fontSize: 11, color: Colors.blue, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreating ? null : _buat,
                    icon: _isCreating
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(_isCreating ? 'Membuat...' : 'Buat & Simpan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}