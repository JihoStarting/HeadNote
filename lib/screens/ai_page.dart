import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'home_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// History Session Model
// ─────────────────────────────────────────────────────────────────────────────

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;
  final List<Map<String, String>> apiHistory;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    required this.apiHistory,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AiPage
// ─────────────────────────────────────────────────────────────────────────────

class AiPage extends StatefulWidget {
  final String? initialNoteContext;
  final List<MataKuliah> subjects;
  final Future<void> Function(String subjectId, Map<String, dynamic> note)?
  onNoteCreated;
  final Future<void> Function(Map<String, dynamic> task)? onTaskCreated;

  const AiPage({
    super.key,
    this.initialNoteContext,
    this.subjects = const [],
    this.onNoteCreated,
    this.onTaskCreated,
  });

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // ── Edit mode ──────────────────────────────────────────────────────────────
  ChatMessage? _editingMessage;
  int? _editingIndex;

  // ── History ────────────────────────────────────────────────────────────────
  final List<ChatSession> _sessions = [];
  String _currentSessionId = '';

  final List<_AttachedImage> _attachedImages = [];
  final ImagePicker _picker = ImagePicker();

static const String _groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';
  final List<Map<String, String>> _history = [];

  static const String _systemPrompt =
      'Kamu adalah asisten AI bernama HeadNote AI dalam aplikasi catatan HeadNote. '
      'Bantu pengguna soal catatan, tugas, dan pertanyaan umum dalam Bahasa Indonesia.\n\n'
      'ATURAN PALING PENTING — WAJIB DIIKUTI:\n'
      'Untuk perintah khusus di bawah, kamu HARUS membalas HANYA dengan JSON murni. '
      'DILARANG KERAS menambahkan teks apapun sebelum atau sesudah JSON. '
      'DILARANG menggunakan markdown, backtick, komentar, atau penjelasan. '
      'Output harus langsung dimulai dengan karakter { dan diakhiri dengan }.\n\n'
      '=== PERINTAH BUAT CATATAN ===\n'
      'Trigger: kata "buatkan catatan", "buat catatan", "buatin catatan", '
      '"tolong buatkan catatan", "bikin catatan" tentang/mengenai/soal topik apapun.\n'
      'WAJIB balas HANYA JSON ini (mulai dari { langsung, tidak ada teks lain):\n'
      '{"action":"create_note","judul":"judul singkat","isi":"isi lengkap pakai \\n untuk baris baru"}\n'
      'Isi harus informatif, terstruktur, menggunakan poin-poin, siap pakai sebagai catatan kuliah.\n\n'
      '=== PERINTAH BUAT TUGAS ===\n'
      'Trigger: kata "buatkan tugas", "buat tugas", "tambahkan tugas", "tambahin tugas", '
      '"ingatkan aku", "masukkan ke to-do list" tentang topik apapun.\n'
      'WAJIB balas HANYA JSON ini (mulai dari { langsung, tidak ada teks lain):\n'
      '{"action":"create_task","nama":"nama tugas max 6 kata","catatan":"detail singkat","prioritas":"Tinggi"}\n'
      'Nilai prioritas: Tinggi (mendesak/deadline dekat), Sedang (reguler), Rendah (opsional).\n\n'
      '=== PERINTAH BUAT DOKUMEN WORD ===\n'
      'Trigger: "buat dokumen word", "buat file word", "buat docx".\n'
      'WAJIB balas HANYA JSON ini:\n'
      '{"action":"create_word","title":"judul","sections":[{"heading":"judul bagian","content":"isi"}]}\n\n'
      'Untuk pertanyaan atau permintaan lain yang bukan tiga perintah di atas, '
      'balas seperti biasa dalam Bahasa Indonesia.';

  @override
  void initState() {
    super.initState();
    _currentSessionId = _newSessionId();
    if (widget.initialNoteContext != null &&
        widget.initialNoteContext!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendWithText(
          '${widget.initialNoteContext!}\n\nTolong jelaskan dan ringkas catatan ini untukku.',
          displayText: '📄 Jelaskan catatan ini',
        );
      });
    }
  }

  String _newSessionId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  // ── Save current chat to history ─────────────────────────────────────────

  void _saveCurrentSession() {
    if (_messages.isEmpty) return;
    final title = _messages.first.text.length > 40
        ? '${_messages.first.text.substring(0, 40)}…'
        : _messages.first.text;

    final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
    final session = ChatSession(
      id: _currentSessionId,
      title: title,
      createdAt: _messages.first.timestamp,
      messages: List.from(_messages),
      apiHistory: List.from(_history),
    );

    setState(() {
      if (idx >= 0) {
        _sessions[idx] = session;
      } else {
        _sessions.insert(0, session);
      }
    });
  }

  void _startNewChat() {
    _saveCurrentSession();
    setState(() {
      _messages.clear();
      _history.clear();
      _attachedImages.clear();
      _currentSessionId = _newSessionId();
      _editingMessage = null;
      _editingIndex = null;
    });
  }

  void _loadSession(ChatSession session) {
    _saveCurrentSession();
    setState(() {
      _messages
        ..clear()
        ..addAll(session.messages);
      _history
        ..clear()
        ..addAll(session.apiHistory);
      _currentSessionId = session.id;
      _editingMessage = null;
      _editingIndex = null;
    });
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _deleteSession(String id) {
    setState(() => _sessions.removeWhere((s) => s.id == id));
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _messageController.clear();

    // Edit mode: replace old message and re-send from that point
    if (_editingMessage != null && _editingIndex != null) {
      setState(() {
        // Remove all messages from editing index onwards
        _messages.removeRange(_editingIndex!, _messages.length);
        // Trim history to match
        final userMsgsBefore = _messages.where((m) => m.isUser).length;
        if (_history.length > userMsgsBefore * 2) {
          _history.removeRange(userMsgsBefore * 2, _history.length);
        }
        _editingMessage = null;
        _editingIndex = null;
      });
    }

    String fullText = text;
    if (_attachedImages.isNotEmpty) {
      fullText +=
      '\n[Pengguna melampirkan ${_attachedImages.length} gambar untuk dimasukkan ke dokumen Word]';
    }
    await _sendWithText(fullText, displayText: text);
  }

  // ── Retry (resend last user message) ─────────────────────────────────────

  Future<void> _retryLastMessage() async {
    if (_isLoading) return;
    // Find last user message
    final lastUserIdx =
    _messages.lastIndexWhere((m) => m.isUser);
    if (lastUserIdx < 0) return;
    final lastUserMsg = _messages[lastUserIdx];

    // Remove all messages from lastUserIdx onwards
    setState(() {
      _messages.removeRange(lastUserIdx, _messages.length);
      // Also pop last user turn from history
      if (_history.isNotEmpty && _history.last['role'] == 'assistant') {
        _history.removeLast();
      }
      if (_history.isNotEmpty && _history.last['role'] == 'user') {
        _history.removeLast();
      }
    });

    await _sendWithText(lastUserMsg.text,
        displayText: lastUserMsg.text);
  }

  Future<void> _sendWithText(String text, {String? displayText}) async {
    if (_isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
          text: displayText ?? text,
          isUser: true,
          timestamp: DateTime.now(),
          attachedImages: List.from(_attachedImages)));
      _attachedImages.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    _history.add({'role': 'user', 'content': text});

    final payload = [
      {'role': 'system', 'content': _systemPrompt},
      ..._history,
    ];

    try {
      final response = await http
          .post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': payload,
          'max_tokens': 2048,
          'temperature': 0.7,
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiText =
            data['choices'][0]['message']['content'] as String? ?? '';

        _history.add({'role': 'assistant', 'content': aiText});

        final noteData = _tryParseNoteAction(aiText);
        if (noteData != null) {
          setState(() {
            _messages.add(ChatMessage(
              text:
              '📝 Catatan **"${noteData['judul']}"** siap dibuat!\nPilih mata kuliah tujuan...',
              isUser: false,
              timestamp: DateTime.now(),
            ));
            _isLoading = false;
          });
          _scrollToBottom();
          _showCreateNoteModal(noteData);
          return;
        }

        final taskData = _tryParseTaskAction(aiText);
        if (taskData != null) {
          setState(() {
            _messages.add(ChatMessage(
              text:
              '📋 Siap! Aku sudah menyiapkan tugas **"${taskData['nama']}"**.\n'
                  'Konfirmasi detail tugas di bawah ini:',
              isUser: false,
              timestamp: DateTime.now(),
            ));
            _isLoading = false;
          });
          _scrollToBottom();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showConfirmTaskDialog(taskData);
          });
          return;
        }

        final wordData = _tryParseWordAction(aiText);
        if (wordData != null) {
          setState(() {
            _messages.add(ChatMessage(
                text: '📝 Membuat dokumen Word **"${wordData['title']}"**...',
                isUser: false,
                timestamp: DateTime.now()));
            _isLoading = false;
          });
          _scrollToBottom();

          final lastUserMsg = _messages
              .lastWhere(
                (m) => m.isUser && m.attachedImages.isNotEmpty,
            orElse: () =>
                ChatMessage(text: '', isUser: true, timestamp: DateTime.now()),
          )
              .attachedImages;

          await _createWordDocument(wordData, lastUserMsg);
        } else {
          setState(() {
            _messages.add(ChatMessage(
                text: aiText, isUser: false, timestamp: DateTime.now()));
            _isLoading = false;
          });
        }
      } else {
        _history.removeLast();
        _handleError('Gagal terhubung (${response.statusCode}). Coba lagi.');
      }
    } catch (e) {
      debugPrint('Exception: $e');
      _history.removeLast();
      _handleError('Tidak ada koneksi internet. Periksa jaringanmu.');
    }

    _scrollToBottom();
    _saveCurrentSession();
  }

  // ── Copy text ─────────────────────────────────────────────────────────────

  void _copyMessage(ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Teks disalin!'),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Enter edit mode ───────────────────────────────────────────────────────

  void _startEditMessage(ChatMessage msg, int index) {
    setState(() {
      _editingMessage = msg;
      _editingIndex = index;
      _messageController.text = msg.text;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _editingIndex = null;
      _messageController.clear();
    });
  }

  // ── Bottom sheet: message actions ─────────────────────────────────────────

  void _showMessageActions(
      BuildContext context, ChatMessage msg, int index, bool isUser) {
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
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Salin
            _actionTile(
              ctx,
              icon: Icons.copy_rounded,
              label: 'Salin Pesan',
              color: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(msg);
              },
            ),
            if (isUser) ...[
              const Divider(height: 1),
              // Edit
              _actionTile(
                ctx,
                icon: Icons.edit_rounded,
                label: 'Edit & Kirim Ulang',
                color: Colors.orange.shade700,
                onTap: () {
                  Navigator.pop(ctx);
                  _startEditMessage(msg, index);
                },
              ),
              const Divider(height: 1),
              // Coba lagi (retry dari pesan ini)
              _actionTile(
                ctx,
                icon: Icons.refresh_rounded,
                label: 'Coba Lagi',
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.pop(ctx);
                  _retryFromIndex(index);
                },
              ),
            ],
            if (!isUser) ...[
              const Divider(height: 1),
              // Coba lagi AI
              _actionTile(
                ctx,
                icon: Icons.refresh_rounded,
                label: 'Regenerasi Jawaban',
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.pop(ctx);
                  _retryLastMessage();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
      BuildContext ctx, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: color)),
      onTap: onTap,
    );
  }

  Future<void> _retryFromIndex(int userMsgIndex) async {
    if (_isLoading) return;
    final userMsg = _messages[userMsgIndex];
    setState(() {
      _messages.removeRange(userMsgIndex, _messages.length);
      // Trim API history to match (each user msg = 2 history items: user+assistant)
      final historyTrimTo = userMsgIndex * 2;
      if (_history.length > historyTrimTo) {
        _history.removeRange(historyTrimTo, _history.length);
      }
    });
    await _sendWithText(userMsg.text, displayText: userMsg.text);
  }

  // ── Note Action Parser ────────────────────────────────────────────────────

  Map<String, dynamic>? _tryParseNoteAction(String text) =>
      _tryParseAction(text, 'create_note');

  void _showCreateNoteModal(Map<String, dynamic> noteData) {
    if (widget.subjects.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Text('⚠️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Belum Ada Mata Kuliah',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: const Text(
            'Tambahkan mata kuliah terlebih dahulu di halaman Home, '
                'lalu coba lagi untuk menyimpan catatan ini.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }

    final judul = noteData['judul'] as String? ?? 'Catatan Baru';
    final isi = noteData['isi'] as String? ?? '';
    final judulCtrl = TextEditingController(text: judul);
    final isiCtrl = TextEditingController(text: isi);
    String selectedMkId = widget.subjects.first.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.note_add_rounded,
                          color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tambahkan ke Catatan',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B))),
                        Text('AI membuatkan catatan untukmu',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Nama Catatan',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: judulCtrl,
                    decoration: InputDecoration(
                      hintText: 'Judul catatan...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Mata Kuliah',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.subjects.map((mk) {
                      final isSelected = selectedMkId == mk.id;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedMkId = mk.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? mk.warnaIcon.withOpacity(0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? mk.warnaIcon
                                    : Colors.grey.shade300,
                                width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(mk.icon,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(mk.nama,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? mk.warnaIcon
                                          : Colors.black45,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Isi Catatan (opsional - edit jika perlu)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: isiCtrl,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Isi catatan...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final judulFinal = judulCtrl.text.trim();
                        final isiFinal = isiCtrl.text.trim();
                        if (judulFinal.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Judul catatan tidak boleh kosong!')));
                          return;
                        }
                        final mk = widget.subjects
                            .firstWhere((m) => m.id == selectedMkId);
                        Navigator.pop(ctx);
                        await _simpanCatatanKeMatkul(mk, judulFinal, isiFinal);
                      },
                      icon: const Icon(Icons.bookmark_added_rounded,
                          color: Colors.white),
                      label: const Text('Tambahkan ke Catatan',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal',
                            style: TextStyle(color: Colors.grey))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Task Action Parser ────────────────────────────────────────────────────

  Map<String, dynamic>? _tryParseTaskAction(String text) =>
      _tryParseAction(text, 'create_task');

  Map<String, dynamic>? _tryParseAction(String text, String action) {
    try {
      String cleaned =
      text.replaceAll('```json', '').replaceAll('```', '').trim();
      int depth = 0;
      int start = -1;
      for (int i = 0; i < cleaned.length; i++) {
        if (cleaned[i] == '{') {
          if (depth == 0) start = i;
          depth++;
        } else if (cleaned[i] == '}') {
          depth--;
          if (depth == 0 && start != -1) {
            final candidate = cleaned.substring(start, i + 1);
            try {
              final Map<String, dynamic> parsed = jsonDecode(candidate);
              if (parsed['action'] == action) return parsed;
            } catch (_) {}
            start = -1;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _showConfirmTaskDialog(Map<String, dynamic> taskData) {
    final nama = taskData['nama'] as String? ?? 'Tugas Baru';
    final catatan = taskData['catatan'] as String? ?? '';
    final prioritas = taskData['prioritas'] as String? ?? 'Sedang';
    final namaCtrl = TextEditingController(text: nama);
    final catatanCtrl = TextEditingController(text: catatan);
    String selectedPrioritas = prioritas;
    String selectedTipe = 'hariIni';
    TimeOfDay? selectedWaktu;
    DateTime? selectedTanggal;

    Color warnaPrioritas(String p) {
      if (p == 'Tinggi') return Colors.red;
      if (p == 'Sedang') return Colors.orange;
      if (p == 'Rendah') return Colors.green;
      return Colors.grey;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.checklist_rounded,
                          color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tambah ke To-Do List',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B))),
                        Text('AI membuatkan tugas untukmu',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Nama Tugas',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: namaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nama tugas...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Prioritas',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Tinggi', 'Sedang', 'Rendah'].map((p) {
                      final selected = selectedPrioritas == p;
                      final color = warnaPrioritas(p);
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedPrioritas = p),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: selected
                                    ? color
                                    : Colors.grey.shade300,
                                width: 1.5),
                          ),
                          child: Text(p,
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                  selected ? color : Colors.black45,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Jadwal',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['hariIni', 'akanDatang'].map((t) {
                      final label =
                      t == 'hariIni' ? '📌 Hari Ini' : '🗓️ Akan Datang';
                      final selected = selectedTipe == t;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedTipe = t),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  if (selectedTipe == 'hariIni')
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedWaktu ?? TimeOfDay.now());
                        if (picked != null) {
                          setModalState(() => selectedWaktu = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF2563EB), width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time,
                              size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Text(
                              selectedWaktu != null
                                  ? selectedWaktu!.format(ctx)
                                  : 'Pilih Waktu Deadline',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: selectedWaktu != null
                                      ? Colors.black87
                                      : Colors.grey)),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 18),
                        ]),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedTanggal ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => selectedTanggal = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF2563EB), width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Text(
                              selectedTanggal != null
                                  ? '${selectedTanggal!.day}/${selectedTanggal!.month}/${selectedTanggal!.year}'
                                  : 'Pilih Tanggal Deadline',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: selectedTanggal != null
                                      ? Colors.black87
                                      : Colors.grey)),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 18),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text('Catatan (opsional)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: catatanCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Detail atau tips pengerjaan...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final namaFinal = namaCtrl.text.trim();
                        if (namaFinal.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content:
                              Text('Nama tugas tidak boleh kosong!')));
                          return;
                        }
                        final newTask = <String, dynamic>{
                          'nama': namaFinal,
                          'catatan': catatanCtrl.text.trim(),
                          'prioritas': selectedPrioritas,
                          'tipe': selectedTipe,
                          'selesai': false,
                          'gambar': [],
                          if (selectedTipe == 'hariIni' &&
                              selectedWaktu != null)
                            'waktu':
                            '${selectedWaktu!.hour.toString().padLeft(2, '0')}:${selectedWaktu!.minute.toString().padLeft(2, '0')}',
                          if (selectedTipe == 'akanDatang' &&
                              selectedTanggal != null)
                            'tanggal': selectedTanggal,
                        };
                        Navigator.pop(ctx);
                        if (widget.onTaskCreated != null) {
                          await widget.onTaskCreated!(newTask);
                        }
                        if (mounted) {
                          setState(() {
                            _messages.add(ChatMessage(
                              text:
                              '✅ Tugas **"$namaFinal"** berhasil ditambahkan ke To-Do List!\n\n'
                                  '📌 Prioritas: $selectedPrioritas\n'
                                  '📋 Cek di halaman To-Do List untuk lihat tugasmu.',
                              isUser: false,
                              timestamp: DateTime.now(),
                            ));
                          });
                          _scrollToBottom();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(children: [
                              const Text('✅', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text('Tugas "$namaFinal" ditambahkan!',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500))),
                            ]),
                            backgroundColor: const Color(0xFF2563EB),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 3),
                          ));
                        }
                      },
                      icon: const Icon(Icons.add_task_rounded,
                          color: Colors.white),
                      label: const Text('Tambahkan ke To-Do List',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal',
                            style: TextStyle(color: Colors.grey))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _simpanCatatanKeMatkul(
      MataKuliah mk, String judul, String isi) async {
    if (widget.onNoteCreated == null) return;
    final note = {
      'judul': judul,
      'isi': isi,
      'tanggal': DateTime.now().toIso8601String(),
    };
    try {
      await widget.onNoteCreated!(mk.id, note);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text:
            '✅ Catatan **"$judul"** berhasil disimpan ke mata kuliah **${mk.nama}**!\n\n'
                'Kamu bisa langsung lihat di halaman ${mk.icon} ${mk.nama}.',
            isUser: false,
            timestamp: DateTime.now(),
            savedToSubject: mk,
          ));
        });
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Text(mk.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Catatan disimpan ke ${mk.nama}!',
                    style: const TextStyle(fontWeight: FontWeight.w500))),
          ]),
          backgroundColor: mk.warnaIcon,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      _handleError('Gagal menyimpan catatan: $e');
    }
  }

  // ── Word Document ─────────────────────────────────────────────────────────

  Map<String, dynamic>? _tryParseWordAction(String text) =>
      _tryParseAction(text, 'create_word');

  Future<void> _createWordDocument(
      Map<String, dynamic> data, List<_AttachedImage> images) async {
    try {
      final title = data['title'] as String? ?? 'Dokumen';
      final sections =
          (data['sections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final docBytes = await _buildDocx(title, sections, images);
      final dir = await getTemporaryDirectory();
      final safeName =
      title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final file = File('${dir.path}/$safeName.docx');
      await file.writeAsBytes(docBytes);
      setState(() {
        _messages.add(ChatMessage(
          text: '✅ Dokumen **"$title.docx"** berhasil dibuat!',
          isUser: false,
          timestamp: DateTime.now(),
          wordFilePath: file.path,
          wordFileName: '$safeName.docx',
        ));
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Word error: $e');
      _handleError('Gagal membuat dokumen Word: $e');
    }
  }

  Future<Uint8List> _buildDocx(
      String title,
      List<Map<String, dynamic>> sections,
      List<_AttachedImage> images,
      ) async {
    final contentBuffer = StringBuffer();
    contentBuffer.write(_para(title, style: 'Heading1', bold: true, size: 36));
    contentBuffer.write(_para(''));
    for (final section in sections) {
      final heading = section['heading'] as String?;
      final content = section['content'] as String? ?? '';
      if (heading != null && heading.isNotEmpty && heading != 'null') {
        contentBuffer
            .write(_para(heading, style: 'Heading2', bold: true, size: 28));
      }
      for (final line in content.split('\n')) {
        if (line.trim().isNotEmpty) {
          contentBuffer.write(_para(line.trim(), size: 24));
        }
      }
      contentBuffer.write(_para(''));
    }

    final imageRelations = <String>[];
    final imageTypes = <String>[];
    final imageFiles = <MapEntry<String, Uint8List>>[];
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final rId = 'rId${i + 10}';
      final ext = img.ext;
      final mediaName = 'image${i + 1}.$ext';
      imageRelations.add(
          '<Relationship Id="$rId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$mediaName"/>');
      imageTypes.add(ext);
      imageFiles.add(MapEntry(mediaName, img.bytes));
      contentBuffer.write(
          _para('Gambar ${i + 1}: ${img.name}', size: 20, italic: true));
      const widthEmu = 5486400;
      const heightEmu = 4114800;
      contentBuffer.write('''
<w:p><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
  <wp:extent cx="$widthEmu" cy="$heightEmu"/>
  <wp:effectExtent l="0" t="0" r="0" b="0"/>
  <wp:docPr id="${i + 1}" name="Gambar ${i + 1}"/>
  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr><pic:cNvPr id="${i + 1}" name="Gambar ${i + 1}"/><pic:cNvPicPr/></pic:nvPicPr>
        <pic:blipFill><a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></pic:blipFill>
        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$widthEmu" cy="$heightEmu"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
      </pic:pic>
    </a:graphicData>
  </a:graphic>
</wp:inline></w:drawing></w:r></w:p>''');
      contentBuffer.write(_para(''));
    }

    final documentXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
        ' xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"'
        ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>${contentBuffer.toString()}'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"'
        ' w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>';

    final stylesXml = _buildStylesXml();
    final relsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '${imageRelations.join('')}</Relationships>';

    final imgContentTypes = imageTypes.toSet().map((ext) {
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      return '<Default Extension="$ext" ContentType="$mime"/>';
    }).join('');

    final contentTypesXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>$imgContentTypes'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '</Types>';

    final rootRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final archive = Archive();
    void addFile(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    void addBinary(String name, Uint8List bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addFile('[Content_Types].xml', contentTypesXml);
    addFile('_rels/.rels', rootRelsXml);
    addFile('word/document.xml', documentXml);
    addFile('word/styles.xml', stylesXml);
    addFile('word/_rels/document.xml.rels', relsXml);
    for (final entry in imageFiles) {
      addBinary('word/media/${entry.key}', entry.value);
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('Gagal encode ZIP');
    return Uint8List.fromList(encoded);
  }

  String _para(String text,
      {String? style, bool bold = false, bool italic = false, int size = 24}) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final pPr =
    style != null ? '<w:pPr><w:pStyle w:val="$style"/></w:pPr>' : '';
    final rPr = StringBuffer('<w:rPr>');
    if (bold) rPr.write('<w:b/>');
    if (italic) rPr.write('<w:i/>');
    rPr.write('<w:sz w:val="$size"/><w:szCs w:val="$size"/>');
    rPr.write('</w:rPr>');
    if (escaped.isEmpty) return '<w:p>$pPr</w:p>';
    return '<w:p>$pPr<w:r>${rPr.toString()}'
        '<w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  String _buildStylesXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
          ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<w:style w:type="paragraph" w:styleId="Normal"><w:name w:val="Normal"/>'
          '<w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:style>'
          '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/>'
          '<w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>'
          '<w:rPr><w:b/><w:sz w:val="36"/><w:szCs w:val="36"/><w:color w:val="2E4057"/></w:rPr></w:style>'
          '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/>'
          '<w:pPr><w:spacing w:before="200" w:after="80"/></w:pPr>'
          '<w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="048A81"/></w:rPr></w:style>'
          '</w:styles>';

  // ── Image Picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 1920);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final name = picked.name.isEmpty
          ? 'gambar_${_attachedImages.length + 1}'
          : picked.name;
      setState(() {
        _attachedImages.add(_AttachedImage(
            bytes: bytes, name: name, ext: ext, path: picked.path));
      });
    } catch (e) {
      _showSnack('Gagal memilih gambar: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari Galeri'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Ambil Foto'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _shareWordFile(String path, String name) async {
    try {
      await Share.shareXFiles([XFile(path)], text: 'Dokumen: $name');
    } catch (e) {
      _showSnack('Gagal membagikan file: $e');
    }
  }

  void _handleError(String msg) {
    setState(() {
      _messages.add(ChatMessage(
          text: msg, isUser: false, timestamp: DateTime.now(), isError: true));
      _isLoading = false;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Percakapan'),
        content:
        const Text('Apakah kamu yakin ingin menghapus seluruh percakapan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startNewChat();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── History Drawer ────────────────────────────────────────────────────────

  void _openHistoryDrawer() {
    _saveCurrentSession();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Header
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 10),
                    const Text('Riwayat Percakapan',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const Spacer(),
                    if (_sessions.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startNewChat();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Baru'),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _sessions.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Belum ada riwayat percakapan',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14)),
                    ],
                  ),
                )
                    : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final isActive = s.id == _currentSessionId;
                    return Dismissible(
                      key: Key(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: Colors.red.shade400),
                      ),
                      onDismissed: (_) => _deleteSession(s.id),
                      child: InkWell(
                        onTap: () => _loadSession(s),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF2563EB)
                                .withOpacity(0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: isActive
                                ? Border.all(
                                color: const Color(0xFF2563EB)
                                    .withOpacity(0.3))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF2563EB)
                                      .withOpacity(0.15)
                                      : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16,
                                    color: isActive
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade500),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title,
                                        maxLines: 1,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isActive
                                                ? const Color(
                                                0xFF2563EB)
                                                : Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${s.messages.length} pesan · ${_fmtDate(s.createdAt)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors
                                                .grey.shade500)),
                                  ],
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: const Text('Aktif',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fromNote = widget.initialNoteContext != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: fromNote,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromNote ? 'Analisis Catatan' : 'HeadNote AI',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Powered by Groq · Llama 3',
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // History button
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat percakapan',
            onPressed: _openHistoryDrawer,
          ),
          // New chat
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Percakapan baru',
            onPressed: _startNewChat,
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus percakapan',
              onPressed: _clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          if (fromNote)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.primary.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(Icons.note_outlined,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI sedang menganalisis catatan kamu. Kamu bisa lanjut bertanya di bawah.',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // Tips bar
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue.withOpacity(0.07),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '💡 Tekan lama pesan untuk Salin, Edit, atau Coba Lagi',
                    style:
                    TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),

          // Edit mode banner
          if (_editingMessage != null)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mode Edit — tulis perubahan lalu kirim',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: const Icon(Icons.close,
                        size: 18, color: Colors.orange),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(colorScheme)
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator(colorScheme);
                }
                return _buildBubble(
                    _messages[index], index, colorScheme, isDark);
              },
            ),
          ),

          if (_attachedImages.isNotEmpty)
            _buildImagePreviewBar(colorScheme),

          _buildInput(colorScheme, isDark),
        ],
      ),
    );
  }

  Widget _buildImagePreviewBar(ColorScheme colorScheme) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colorScheme.surfaceVariant.withOpacity(0.4),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _attachedImages.length,
              itemBuilder: (_, i) {
                final img = _attachedImages[i];
                return Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: MemoryImage(img.bytes),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 4,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _attachedImages.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Text(
            '${_attachedImages.length} gambar\nsiap dimasukkan',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: colorScheme.primary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    final chips = <Map<String, String>>[
      {
        'label': '✅ Buatkan tugas mengerjakan laporan',
        'prompt': 'Buatkan tugas mengerjakan laporan'
      },
      {
        'label': '✅ Buatkan tugas belajar UTS Matematika',
        'prompt': 'Buatkan tugas belajar UTS Matematika'
      },
      {
        'label': '📝 Buatkan catatan tentang OOP',
        'prompt': 'Buatkan catatan tentang OOP'
      },
      {
        'label': '📝 Buatkan catatan tentang Integral',
        'prompt': 'Buatkan catatan tentang Integral'
      },
      {'label': '💡 Bantu buat ringkasan', 'prompt': 'Bantu buat ringkasan'},
      {
        'label': '📄 Buat dokumen Word laporan',
        'prompt': 'Buat dokumen Word laporan'
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                colorScheme.primary.withOpacity(0.2),
                colorScheme.secondary.withOpacity(0.2),
              ]),
              shape: BoxShape.circle,
            ),
            child:
            Icon(Icons.auto_awesome, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text('HeadNote AI',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Tanyakan apa saja!\nAku siap membantumu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5)),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: chips
                .map((c) => _chip(c['label']!, c['prompt']!, colorScheme))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _chip(String label, String prompt, ColorScheme colorScheme) {
    return ActionChip(
      label: Text(label,
          style: TextStyle(fontSize: 12, color: colorScheme.primary)),
      backgroundColor: colorScheme.primary.withOpacity(0.08),
      side: BorderSide(color: colorScheme.primary.withOpacity(0.25)),
      onPressed: () {
        _messageController.text = prompt;
        _sendMessage();
      },
    );
  }

  Widget _buildBubble(
      ChatMessage msg, int index, ColorScheme colorScheme, bool isDark) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 16),
                ),
              Flexible(
                child: GestureDetector(
                  onLongPress: () =>
                      _showMessageActions(context, msg, index, isUser),
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? colorScheme.primary
                          : msg.isError
                          ? Colors.red.withOpacity(0.1)
                          : isDark
                          ? colorScheme.surfaceVariant
                          : colorScheme.surfaceVariant
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isUser
                            ? const Radius.circular(18)
                            : const Radius.circular(4),
                        bottomRight: isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                      border: msg.isError
                          ? Border.all(color: Colors.red.withOpacity(0.3))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          msg.text,
                          style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : msg.isError
                                ? Colors.red
                                : colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Timestamp + quick action icons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt(msg.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isUser
                                    ? Colors.white.withOpacity(0.7)
                                    : colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Copy icon
                            GestureDetector(
                              onTap: () => _copyMessage(msg),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: isUser
                                    ? Colors.white.withOpacity(0.6)
                                    : colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 6),
                              // Edit icon
                              GestureDetector(
                                onTap: () => _startEditMessage(msg, index),
                                child: Icon(Icons.edit_rounded,
                                    size: 12,
                                    color:
                                    Colors.white.withOpacity(0.6)),
                              ),
                              const SizedBox(width: 6),
                              // Retry icon
                              GestureDetector(
                                onTap: () => _retryFromIndex(index),
                                child: Icon(Icons.refresh_rounded,
                                    size: 12,
                                    color:
                                    Colors.white.withOpacity(0.6)),
                              ),
                            ],
                            if (!isUser) ...[
                              const SizedBox(width: 6),
                              // Regenerate icon for AI messages
                              GestureDetector(
                                onTap: _retryLastMessage,
                                child: Icon(Icons.refresh_rounded,
                                    size: 12,
                                    color: colorScheme.onSurface
                                        .withOpacity(0.4)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),

          if (isUser && msg.attachedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: msg.attachedImages.map((img) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(img.bytes,
                        width: 80, height: 80, fit: BoxFit.cover),
                  );
                }).toList(),
              ),
            ),

          if (!isUser && msg.savedToSubject != null)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 6),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: msg.savedToSubject!.warnaIcon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: msg.savedToSubject!.warnaIcon.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg.savedToSubject!.icon,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Tersimpan di ${msg.savedToSubject!.nama}',
                      style: TextStyle(
                          fontSize: 12,
                          color: msg.savedToSubject!.warnaIcon,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          if (!isUser && msg.wordFilePath != null)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 6),
              child: OutlinedButton.icon(
                onPressed: () =>
                    _shareWordFile(msg.wordFilePath!, msg.wordFileName!),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(msg.wordFileName ?? 'Unduh .docx',
                    style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.image_outlined),
              tooltip: 'Lampirkan gambar ke Word',
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.primary,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceVariant
                      : colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: _editingMessage != null
                          ? Colors.orange
                          : colorScheme.outline.withOpacity(0.3),
                      width: _editingMessage != null ? 1.5 : 1),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _editingMessage != null
                        ? 'Edit pesanmu...'
                        : 'Tanya atau "Buatkan tugas tentang..."',
                    hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _isLoading ? null : _sendMessage,
              backgroundColor: _isLoading
                  ? colorScheme.surfaceVariant
                  : _editingMessage != null
                  ? Colors.orange
                  : colorScheme.primary,
              elevation: 0,
              child: _isLoading
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colorScheme.primary),
              )
                  : Icon(
                  _editingMessage != null
                      ? Icons.check_rounded
                      : Icons.send_rounded,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime t) {
    final now = DateTime.now();
    if (t.day == now.day && t.month == now.month && t.year == now.year) {
      return 'Hari ini ${_fmt(t)}';
    }
    return '${t.day}/${t.month}/${t.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final List<_AttachedImage> attachedImages;
  final String? wordFilePath;
  final String? wordFileName;
  final MataKuliah? savedToSubject;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    List<_AttachedImage>? attachedImages,
    this.wordFilePath,
    this.wordFileName,
    this.savedToSubject,
  }) : attachedImages = attachedImages ?? [];
}

class _AttachedImage {
  final Uint8List bytes;
  final String name;
  final String ext;
  final String path;

  const _AttachedImage({
    required this.bytes,
    required this.name,
    required this.ext,
    required this.path,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing Dot Animation
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}