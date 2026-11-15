import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'word_builder.dart';

class DetailCatatanPage extends StatefulWidget {
  final Map<String, dynamic> note;
  final int index;

  const DetailCatatanPage({
    super.key,
    required this.note,
    required this.index,
  });

  @override
  State<DetailCatatanPage> createState() => _DetailCatatanPageState();
}

class _DetailCatatanPageState extends State<DetailCatatanPage> {
  late TextEditingController _judulController;
  late TextEditingController _isiController;
  late String _tanggal;

  // ── Groq API Config ───────────────────────────────────────────────────────
static const String _groqApiKey = String.fromEnvironment('GROQ_API_KEY');  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  // ── Riwayat versi catatan (untuk Coba Lagi / undo) ───────────────────────
  final List<Map<String, String>> _history = [];
  int _historyIndex = -1;
  bool _isSaved = true;

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(text: widget.note['judul'] ?? '');
    _isiController   = TextEditingController(text: widget.note['isi']   ?? '');

    final rawDate = widget.note['tanggal'];
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate);
        _tanggal = DateFormat('d MMM yyyy').format(parsed);
      } catch (_) {
        _tanggal = rawDate.toString();
      }
    } else {
      _tanggal = DateFormat('d MMM yyyy').format(DateTime.now());
    }

    _pushHistory();

    _judulController.addListener(_onChanged);
    _isiController.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _isSaved = false);

  // ── History ───────────────────────────────────────────────────────────────

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add({
      'judul': _judulController.text,
      'isi':   _isiController.text,
    });
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    _applyHistory(_history[_historyIndex]);
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex++;
    _applyHistory(_history[_historyIndex]);
  }

  void _applyHistory(Map<String, String> snap) {
    _judulController.removeListener(_onChanged);
    _isiController.removeListener(_onChanged);
    _judulController.text = snap['judul'] ?? '';
    _isiController.text   = snap['isi']   ?? '';
    _judulController.addListener(_onChanged);
    _isiController.addListener(_onChanged);
    setState(() => _isSaved = false);
  }

  // ── Salin ─────────────────────────────────────────────────────────────────

  void _salinJudul() {
    final text = _judulController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Judul disalin!', Icons.copy_rounded, Colors.blueGrey);
  }

  void _salinIsi() {
    final text = _isiController.text.trim();
    if (text.isEmpty) {
      _showSnack('Isi catatan masih kosong.', Icons.info_outline, Colors.grey);
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Isi catatan disalin!', Icons.copy_rounded, Colors.blueGrey);
  }

  void _salinSemua() {
    final judul = _judulController.text.trim();
    final isi   = _isiController.text.trim();
    final full  = 'Judul: $judul\n\n$isi';
    Clipboard.setData(ClipboardData(text: full));
    _showSnack('Catatan disalin!', Icons.copy_all_rounded, Colors.blueGrey);
  }

  void _showCopyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            _sheetTile(ctx,
                icon: Icons.title_rounded,
                label: 'Salin Judul',
                color: const Color(0xFF2563EB),
                onTap: _salinJudul),
            const Divider(height: 1),
            _sheetTile(ctx,
                icon: Icons.article_outlined,
                label: 'Salin Isi Catatan',
                color: const Color(0xFF2563EB),
                onTap: _salinIsi),
            const Divider(height: 1),
            _sheetTile(ctx,
                icon: Icons.copy_all_rounded,
                label: 'Salin Semua (Judul + Isi)',
                color: const Color(0xFF2563EB),
                onTap: _salinSemua),
          ],
        ),
      ),
    );
  }

  void _showHistoryOptions() {
    _pushHistory();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 10),
                    const Text('Riwayat Perubahan',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.undo_rounded,
                          color: _historyIndex > 0
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade300),
                      onPressed: _historyIndex > 0
                          ? () { Navigator.pop(ctx); _undo(); }
                          : null,
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      icon: Icon(Icons.redo_rounded,
                          color: _historyIndex < _history.length - 1
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade300),
                      onPressed: _historyIndex < _history.length - 1
                          ? () { Navigator.pop(ctx); _redo(); }
                          : null,
                      tooltip: 'Redo',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                    child: Text('Belum ada riwayat.',
                        style: TextStyle(color: Colors.grey.shade400)))
                    : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final snap = _history[_history.length - 1 - i];
                    final isCurrent = (_history.length - 1 - i) == _historyIndex;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _historyIndex = _history.length - 1 - i;
                          _applyHistory(snap);
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF2563EB).withOpacity(0.08)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(color: const Color(0xFF2563EB).withOpacity(0.3))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 18,
                              color: isCurrent ? const Color(0xFF2563EB) : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    snap['judul']!.isNotEmpty ? snap['judul']! : '(tanpa judul)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent ? const Color(0xFF2563EB) : Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    snap['isi']!.isNotEmpty
                                        ? snap['isi']!.replaceAll('\n', ' ').substring(
                                        0, snap['isi']!.length > 60 ? 60 : snap['isi']!.length)
                                        : '(kosong)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'v${_history.length - i}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isCurrent ? const Color(0xFF2563EB) : Colors.grey.shade400,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            _sheetTile(ctx,
                icon: Icons.copy_all_rounded,
                label: 'Salin Catatan',
                color: const Color(0xFF2563EB),
                onTap: _showCopyOptions),
            const Divider(height: 1),
            _sheetTile(ctx,
                icon: Icons.undo_rounded,
                label: 'Undo Perubahan',
                color: Colors.orange.shade700,
                onTap: _historyIndex > 0 ? () { Navigator.pop(ctx); _undo(); } : null),
            const Divider(height: 1),
            _sheetTile(ctx,
                icon: Icons.redo_rounded,
                label: 'Redo Perubahan',
                color: Colors.orange.shade700,
                onTap: _historyIndex < _history.length - 1
                    ? () { Navigator.pop(ctx); _redo(); }
                    : null),
            const Divider(height: 1),
            _sheetTile(ctx,
                icon: Icons.history_rounded,
                label: 'Riwayat Versi Catatan',
                color: Colors.green.shade700,
                onTap: () { Navigator.pop(ctx); _showHistoryOptions(); }),
            const Divider(height: 1),
            _sheetTile(ctx,
                icon: Icons.restore_rounded,
                label: 'Kembalikan ke Versi Awal',
                color: Colors.red.shade400,
                onTap: _history.isNotEmpty
                    ? () {
                  Navigator.pop(ctx);
                  _historyIndex = 0;
                  _applyHistory(_history[0]);
                  _showSnack('Dikembalikan ke versi awal.', Icons.restore_rounded, Colors.orange);
                }
                    : null),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
      BuildContext ctx, {
        required IconData icon,
        required String label,
        required Color color,
        VoidCallback? onTap,
      }) {
    final enabled = onTap != null;
    return ListTile(
      enabled: enabled,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: enabled ? color : Colors.grey.shade400)),
      onTap: enabled ? () { Navigator.pop(ctx); onTap(); } : null,
    );
  }

  // ── AI Assistant ──────────────────────────────────────────────────────────

  void _bukaAiAssistant() {
    final judul = _judulController.text.trim();
    final isi   = _isiController.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiCatatanSheet(
        judulCatatan: judul,
        isiCatatan: isi,
        tanggal: _tanggal,
        groqApiKey: _groqApiKey,
        groqApiUrl: _groqApiUrl,
        model: _model,
      ),
    );
  }

  // ── Word ──────────────────────────────────────────────────────────────────

  void _buatWord() {
    final judul = _judulController.text.trim();
    final isi   = _isiController.text.trim();
    showDialog(
      context: context,
      builder: (_) => WordDialog(
        initialTitle:   judul.isNotEmpty ? judul : 'Catatan',
        initialContent: isi,
        existingImagePaths: const [],
      ),
    );
  }

  // ── Simpan / Hapus ────────────────────────────────────────────────────────

  void _simpan() {
    final judul = _judulController.text.trim();
    if (judul.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong!')),
      );
      return;
    }
    _pushHistory();
    final updatedNote = {
      ...widget.note,
      'judul': judul,
      'isi':   _isiController.text.trim(),
      'tanggal': widget.note['tanggal'] ?? DateTime.now().toIso8601String(),
    };
    setState(() => _isSaved = true);
    Navigator.pop(context, {'action': 'simpan', 'note': updatedNote});
  }

  void _hapus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text('Apakah Anda yakin ingin menghapus catatan ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {'action': 'hapus'});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    _judulController.removeListener(_onChanged);
    _isiController.removeListener(_onChanged);
    _judulController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF29ABE2);
    const darkBar = Color(0xFF1A2A3A);

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: darkBar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Detail 🗒️',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isSaved) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Belum Simpan',
                  style: TextStyle(fontSize: 9, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.undo_rounded,
                color: _historyIndex > 0 ? Colors.white : Colors.white38),
            tooltip: 'Undo',
            onPressed: _historyIndex > 0 ? _undo : null,
          ),
          IconButton(
            icon: Icon(Icons.redo_rounded,
                color: _historyIndex < _history.length - 1
                    ? Colors.white
                    : Colors.white38),
            tooltip: 'Redo',
            onPressed: _historyIndex < _history.length - 1 ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Opsi lainnya',
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banner AI + Word ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _bukaAiAssistant,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF29ABE2), Color(0xFF6C63FF)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF29ABE2).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tanya AI',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        Text('Bantuan cerdas',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _buatWord,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.blue.shade400
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.description_outlined,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Buat Word',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        Text('Ekspor ke .docx',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Judul ─────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Text('Judul:  ',
                            style: TextStyle(
                                fontSize: 15, color: Colors.black54)),
                        Expanded(
                          child: TextField(
                            controller: _judulController,
                            style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _salinJudul,
                          child: Icon(Icons.copy_rounded,
                              size: 18, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),

                  // ── Isi Catatan ───────────────────────────────────────
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Isi Catatan:',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black54)),
                              const Spacer(),
                              GestureDetector(
                                onTap: _salinIsi,
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded,
                                        size: 14,
                                        color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text('Salin',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: TextField(
                              controller: _isiController,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tanggal + 2 tombol aksi (Hapus & Salin) ───────────────
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_tanggal,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bottomAction(
                      icon: Icons.delete_outline,
                      label: 'Hapus',
                      color: Colors.black54,
                      onTap: _hapus,
                    ),
                    _bottomAction(
                      icon: Icons.copy_all_rounded,
                      label: 'Salin',
                      color: Colors.blueGrey,
                      onTap: _showCopyOptions,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Riwayat + Simpan ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showHistoryOptions,
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Riwayat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _simpan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    child: Text(
                      _isSaved ? 'Tersimpan ✓' : 'Simpan',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Bottom Sheet untuk Catatan ─────────────────────────────────────────────

class _AiCatatanSheet extends StatefulWidget {
  final String judulCatatan;
  final String isiCatatan;
  final String tanggal;
  final String groqApiKey;
  final String groqApiUrl;
  final String model;

  const _AiCatatanSheet({
    required this.judulCatatan,
    required this.isiCatatan,
    required this.tanggal,
    required this.groqApiKey,
    required this.groqApiUrl,
    required this.model,
  });

  @override
  State<_AiCatatanSheet> createState() => _AiCatatanSheetState();
}

class _AiCatatanSheetState extends State<_AiCatatanSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final List<Map<String, String>> _history = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kirimPesanAwal();
  }

  String _buatKonteksCatatan() {
    String konteks =
        'Judul Catatan: ${widget.judulCatatan.isNotEmpty ? widget.judulCatatan : "(tanpa judul)"}';
    konteks += '\nTanggal: ${widget.tanggal}';
    if (widget.isiCatatan.isNotEmpty) {
      konteks += '\nIsi Catatan:\n${widget.isiCatatan}';
    } else {
      konteks += '\nIsi Catatan: (kosong)';
    }
    return konteks;
  }

  Future<void> _kirimPesanAwal() async {
    final konteks = _buatKonteksCatatan();
    final systemPrompt =
        'Kamu adalah HeadNote AI, asisten dalam aplikasi catatan HeadNote. '
        'Pengguna sedang membuka detail catatan berikut:\n$konteks\n\n'
        'Sambut pengguna dengan ramah, tampilkan ringkasan catatan ini, '
        'lalu tawarkan bantuan seperti: merangkum catatan, mengembangkan isi catatan, '
        'memperbaiki tata bahasa/ejaan, membuat poin-poin penting, '
        'atau pertanyaan apapun soal catatan ini. '
        'Jawab dalam Bahasa Indonesia, singkat dan mudah dipahami.';

    _history.clear();
    _history.add({'role': 'system', 'content': systemPrompt});
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(widget.groqApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.groqApiKey}',
        },
        body: jsonEncode({
          'model': widget.model,
          'messages': _history,
          'max_tokens': 512,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiText =
            data['choices'][0]['message']['content'] as String? ?? '';
        _history.add({'role': 'assistant', 'content': aiText});
        setState(() {
          _messages.add({'role': 'ai', 'text': aiText});
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _kirimPesan() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _inputController.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();
    _history.add({'role': 'user', 'content': text});

    try {
      final response = await http.post(
        Uri.parse(widget.groqApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.groqApiKey}',
        },
        body: jsonEncode({
          'model': widget.model,
          'messages': _history,
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiText =
            data['choices'][0]['message']['content'] as String? ?? '';
        _history.add({'role': 'assistant', 'content': aiText});
        setState(() {
          _messages.add({'role': 'ai', 'text': aiText});
          _isLoading = false;
        });
      } else {
        _history.removeLast();
        setState(() {
          _messages
              .add({'role': 'error', 'text': 'Gagal terhubung. Coba lagi.'});
          _isLoading = false;
        });
      }
    } catch (_) {
      _history.removeLast();
      setState(() {
        _messages
            .add({'role': 'error', 'text': 'Tidak ada koneksi internet.'});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),

            // ── Header ────────────────────────────────────────────────
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF29ABE2), Color(0xFF6C63FF)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HeadNote AI',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          widget.judulCatatan.isNotEmpty
                              ? widget.judulCatatan
                              : '(tanpa judul)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Quick Suggestions ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  '📝 Rangkum catatan',
                  '✍️ Kembangkan isi',
                  '💡 Buat poin penting',
                  '🔤 Perbaiki ejaan',
                  '❓ Buat pertanyaan',
                ].map((q) {
                  return GestureDetector(
                    onTap: () {
                      _inputController.text = q.substring(3);
                      _kirimPesan();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFF29ABE2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF29ABE2)
                                .withOpacity(0.3)),
                      ),
                      child: Text(q,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF29ABE2),
                              fontWeight: FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Chat Messages ─────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length) return _buildTypingIndicator();
                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';
                  final isError = msg['role'] == 'error';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isUser)
                          Container(
                            width: 32,
                            height: 32,
                            margin:
                            const EdgeInsets.only(right: 6, bottom: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Color(0xFF29ABE2),
                                Color(0xFF6C63FF)
                              ]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 16),
                          )
                        else
                          const SizedBox(width: 38),

                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFF29ABE2)
                                  : isError
                                  ? Colors.red.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isUser
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                                bottomRight: isUser
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                              border: isError
                                  ? Border.all(color: Colors.red.shade200)
                                  : null,
                            ),
                            child: SelectableText(
                              msg['text'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: isUser
                                    ? Colors.white
                                    : isError
                                    ? Colors.red
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),

                        if (isUser) const SizedBox(width: 6),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Input Bar ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2))
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _inputController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Tanya AI tentang catatan ini...',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.black38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _kirimPesan(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isLoading ? null : _kirimPesan,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? null
                              : const LinearGradient(colors: [
                            Color(0xFF29ABE2),
                            Color(0xFF6C63FF)
                          ]),
                          color: _isLoading ? Colors.grey.shade300 : null,
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF29ABE2)),
                        )
                            : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 6, bottom: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF29ABE2), Color(0xFF6C63FF)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                    (i) => Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: _TypingDotSimple(delay: i * 200),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Dot Animation ──────────────────────────────────────────────────────

class _TypingDotSimple extends StatefulWidget {
  final int delay;
  const _TypingDotSimple({required this.delay});
  @override
  State<_TypingDotSimple> createState() => _TypingDotSimpleState();
}

class _TypingDotSimpleState extends State<_TypingDotSimple>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              color: Color(0xFF29ABE2), shape: BoxShape.circle),
        ),
      ),
    );
  }
}