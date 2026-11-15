import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'Tambah_tugas_page.dart';
import 'word_builder.dart';

class DetailTugasPage extends StatefulWidget {
  final Map<String, dynamic> task;
  const DetailTugasPage({super.key, required this.task});

  @override
  State<DetailTugasPage> createState() => _DetailTugasPageState();
}

class _DetailTugasPageState extends State<DetailTugasPage> {
  // ── Warna disesuaikan dengan TodoList ──
  static const primaryColor  = Color(0xFF2563EB); // biru utama TodoList
  static const accentPurple  = Color(0xFF7C3AED); // ungu "Akan Datang" TodoList
  static const darkBlue      = Color(0xFF1D4ED8); // biru gelap "Buat Word"

  late TextEditingController _namaController;
  late TextEditingController _catatanController;
  late bool _selesai;
  late String _tipe;
  late String _prioritas;
  TimeOfDay? _waktu;
  DateTime? _tanggal;
  List<String> _imagePaths = [];

  bool _isEditing = false;
  final _notifService = NotificationService();

static const String _groqApiKey = String.fromEnvironment('GROQ_API_KEY');  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  @override
  void initState() {
    super.initState();
    _notifService.init();
    final task = widget.task;
    _namaController = TextEditingController(text: task['nama'] ?? '');
    _catatanController = TextEditingController(text: task['catatan'] ?? '');
    _selesai = task['selesai'] ?? false;
    _tipe = task['tipe'] ?? 'hariIni';
    _prioritas = task['prioritas'] ?? '';
    _imagePaths = List<String>.from(task['gambar'] ?? []);

    if (task['waktu'] is String) {
      final parts = (task['waktu'] as String).split(':');
      if (parts.length == 2) {
        _waktu = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    _tanggal = task['tanggal'] is DateTime ? task['tanggal'] : null;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _buatWord() {
    final nama = _namaController.text.trim();
    final catatan = _catatanController.text.trim();

    final buffer = StringBuffer();
    buffer.writeln('Nama Tugas:');
    buffer.writeln(nama.isNotEmpty ? nama : '-');
    buffer.writeln();

    if (_prioritas.isNotEmpty) {
      buffer.writeln('Prioritas:');
      buffer.writeln(_prioritas);
      buffer.writeln();
    }

    buffer.writeln('Jadwal:');
    if (_tipe == 'hariIni') {
      buffer.writeln(
          'Hari Ini${_waktu != null ? ' — ${_waktu!.hour.toString().padLeft(2, '0')}:${_waktu!.minute.toString().padLeft(2, '0')}' : ''}');
    } else {
      buffer.writeln(
          'Akan Datang${_tanggal != null ? ' — ${DateFormat('d MMM yyyy').format(_tanggal!)}' : ''}');
    }
    buffer.writeln();

    buffer.writeln('Status:');
    buffer.writeln(_selesai ? 'Selesai ✓' : 'Belum Selesai');
    buffer.writeln();

    if (catatan.isNotEmpty) {
      buffer.writeln('Catatan:');
      buffer.writeln(catatan);
    }

    showDialog(
      context: context,
      builder: (_) => WordDialog(
        initialTitle: nama.isNotEmpty ? nama : 'Detail Tugas',
        initialContent: buffer.toString().trim(),
        existingImagePaths: _imagePaths,
      ),
    );
  }

  void _bukaAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiTugasSheet(
        namaTask: _namaController.text,
        catatan: _catatanController.text,
        prioritas: _prioritas,
        tipe: _tipe,
        waktu: _waktu,
        tanggal: _tanggal,
        imagePaths: _imagePaths,
        groqApiKey: _groqApiKey,
        groqApiUrl: _groqApiUrl,
        model: _model,
      ),
    );
  }

  Future<void> _pilihWaktu() async {
    final picked = await showTimePicker(
        context: context, initialTime: _waktu ?? TimeOfDay.now());
    if (picked != null) setState(() => _waktu = picked);
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _tambahGambar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Sumber Gambar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt, color: primaryColor)),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library, color: primaryColor)),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _imagePaths.add(picked.path));
  }

  void _hapusGambar(int i) => setState(() => _imagePaths.removeAt(i));

  void _simpan() async {
    final nama = _namaController.text.trim();
    final updatedTask = {
      ...widget.task,
      'nama': nama,
      'catatan': _catatanController.text.trim(),
      'selesai': _selesai,
      'tipe': _tipe,
      'prioritas': _prioritas,
      'gambar': _imagePaths,
      if (_tipe == 'hariIni' && _waktu != null)
        'waktu':
        '${_waktu!.hour.toString().padLeft(2, '0')}:${_waktu!.minute.toString().padLeft(2, '0')}',
      if (_tipe == 'akanDatang' && _tanggal != null) 'tanggal': _tanggal,
    };

    if (!_selesai) {
      await _notifService.jadwalkanNotifikasi(
        id: nama.hashCode.abs() % 100000,
        namaTugas: nama,
        tipe: _tipe,
        waktu: _waktu,
        tanggal: _tanggal,
      );
    } else {
      await _notifService.batalkanNotifikasi(nama.hashCode.abs() % 100000);
    }

    if (mounted) {
      Navigator.pop(context, {'action': 'simpan', 'task': updatedTask});
    }
  }

  void _hapusTugas() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Tugas?'),
        content: const Text('Tugas ini akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (konfirmasi == true) {
      await _notifService
          .batalkanNotifikasi(_namaController.text.hashCode.abs() % 100000);
      if (mounted) Navigator.pop(context, {'action': 'hapus'});
    }
  }

  Color _warnaPrioritas(String p) {
    if (p == 'Tinggi') return const Color(0xFFDC2626);
    if (p == 'Sedang') return const Color(0xFFD97706);
    if (p == 'Rendah') return const Color(0xFF059669);
    return Colors.grey;
  }

  Color _bgPrioritas(String p) {
    if (p == 'Tinggi') return const Color(0xFFFEF2F2);
    if (p == 'Sedang') return const Color(0xFFFFFBEB);
    if (p == 'Rendah') return const Color(0xFFF0FDF4);
    return Colors.grey.shade100;
  }

  // Warna accent per tipe — sama dengan TodoList
  Color get _accentColor =>
      _tipe == 'hariIni' ? primaryColor : accentPurple;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        // ── AppBar biru utama TodoList ──
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Detail Tugas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Buat Dokumen Word',
            onPressed: _buatWord,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Minta Bantuan AI',
            onPressed: _bukaAiAssistant,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
            tooltip: _isEditing ? 'Batalkan Edit' : 'Edit',
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _simpan,
              tooltip: 'Simpan',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner AI + Word ──────────────────────────────────────
            Row(
              children: [
                // Tanya AI — gradien biru→ungu (TodoList accent)
                Expanded(
                  child: GestureDetector(
                    onTap: _bukaAiAssistant,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryColor, accentPurple],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
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
                                        color: Colors.white70, fontSize: 10)),
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
                // Buat Word — biru gelap TodoList
                Expanded(
                  child: GestureDetector(
                    onTap: _buatWord,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: darkBlue,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: darkBlue.withOpacity(0.3),
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
                                        color: Colors.white70, fontSize: 10)),
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
            const SizedBox(height: 12),

            // ── Status & Nama ──────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _isEditing
                            ? () => setState(() => _selesai = !_selesai)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _selesai ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selesai
                                  ? primaryColor
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: _selesai
                              ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selesai ? 'Selesai' : 'Belum Selesai',
                        style: TextStyle(
                          color: _selesai ? primaryColor : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _Label('NAMA TUGAS'),
                  const SizedBox(height: 6),
                  _isEditing
                      ? TextField(
                    controller: _namaController,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: _inputDecoration('Nama tugas'),
                  )
                      : Text(
                    _namaController.text,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                      decoration: _selesai
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Jadwal ─────────────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('JADWAL'),
                  const SizedBox(height: 10),
                  if (_isEditing)
                    Row(
                      children: ['hariIni', 'akanDatang'].map((t) {
                        final label =
                        t == 'hariIni' ? '📌 Hari Ini' : '🗓️ Akan Datang';
                        final selected = _tipe == t;
                        final color = t == 'hariIni' ? primaryColor : accentPurple;
                        return GestureDetector(
                          onTap: () => setState(() => _tipe = t),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? color : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? color : Colors.grey.shade300,
                              ),
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
                    )
                  else
                    _InfoChip(
                      icon: _tipe == 'hariIni' ? '📌' : '🗓️',
                      label: _tipe == 'hariIni' ? 'Hari Ini' : 'Akan Datang',
                      color: _accentColor,
                    ),

                  const SizedBox(height: 12),

                  if (_tipe == 'hariIni')
                    _isEditing
                        ? _TapFieldDetail(
                      icon: Icons.access_time,
                      label: _waktu != null
                          ? _waktu!.format(context)
                          : 'Pilih Waktu',
                      onTap: _pilihWaktu,
                    )
                        : _InfoRow(
                      icon: Icons.access_time,
                      text: _waktu != null
                          ? '⏰ ${_waktu!.format(context)}'
                          : '-',
                    )
                  else
                    _isEditing
                        ? _TapFieldDetail(
                      icon: Icons.calendar_today,
                      label: _tanggal != null
                          ? DateFormat('d MMM yyyy').format(_tanggal!)
                          : 'Pilih Tanggal',
                      onTap: _pilihTanggal,
                    )
                        : _InfoRow(
                      icon: Icons.calendar_today,
                      text: _tanggal != null
                          ? '🗓️ ${DateFormat('d MMM yyyy').format(_tanggal!)}'
                          : '-',
                    ),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _selesai
                          ? Colors.grey.shade100
                          : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selesai
                            ? Colors.grey.shade300
                            : Colors.amber.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selesai
                              ? Icons.notifications_off
                              : Icons.notifications_active,
                          color: _selesai ? Colors.grey : Colors.amber,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selesai
                                ? 'Notifikasi dimatikan (tugas selesai)'
                                : 'Notifikasi aktif • 1 jam sebelum deadline',
                            style: TextStyle(
                              fontSize: 11,
                              color: _selesai ? Colors.grey : Colors.brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Prioritas ──────────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('PRIORITAS'),
                  const SizedBox(height: 10),
                  _isEditing
                      ? Wrap(
                    spacing: 8,
                    children:
                    ['Tinggi', 'Sedang', 'Rendah', ''].map((p) {
                      final label = p.isEmpty ? 'Tidak Ada' : p;
                      final selected = _prioritas == p;
                      final warna = _warnaPrioritas(p);
                      return GestureDetector(
                        onTap: () => setState(() => _prioritas = p),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? _bgPrioritas(p)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? warna
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: selected
                                      ? warna
                                      : Colors.black45,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  )
                      : _prioritas.isNotEmpty
                      ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _bgPrioritas(_prioritas),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _warnaPrioritas(_prioritas)
                              .withOpacity(0.3),
                          width: 1.5),
                    ),
                    child: Text(_prioritas,
                        style: TextStyle(
                            fontSize: 13,
                            color: _warnaPrioritas(_prioritas),
                            fontWeight: FontWeight.bold)),
                  )
                      : const Text('Tidak ada prioritas',
                      style:
                      TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Catatan ────────────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('CATATAN'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? TextField(
                    controller: _catatanController,
                    maxLines: 5,
                    decoration:
                    _inputDecoration('Tulis catatan di sini...'),
                  )
                      : _catatanController.text.isNotEmpty
                      ? Text(_catatanController.text,
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.6))
                      : const Text('Tidak ada catatan.',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Lampiran Gambar ────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _Label('LAMPIRAN GAMBAR'),
                      Row(
                        children: [
                          if (_imagePaths.isNotEmpty)
                            GestureDetector(
                              onTap: _buatWord,
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: darkBlue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.description_outlined,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('ke Word',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          if (_isEditing)
                            GestureDetector(
                              onTap: _tambahGambar,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_photo_alternate,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Tambah',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _imagePaths.isEmpty
                      ? GestureDetector(
                    onTap: _isEditing ? _tambahGambar : null,
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              color: Colors.grey.shade400, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _isEditing
                                ? 'Tap untuk tambah gambar'
                                : 'Tidak ada gambar',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                      : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _isEditing
                        ? _imagePaths.length + 1
                        : _imagePaths.length,
                    itemBuilder: (_, i) {
                      if (_isEditing && i == _imagePaths.length) {
                        return GestureDetector(
                          onTap: _tambahGambar,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.shade300),
                            ),
                            child: const Icon(
                                Icons.add_photo_alternate,
                                color: Colors.grey),
                          ),
                        );
                      }
                      return GestureDetector(
                        onTap: () => _lihatGambar(i),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_imagePaths[i]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                            if (_isEditing)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _hapusGambar(i),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Tombol Hapus ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _hapusTugas,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Hapus Tugas',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
        onPressed: _simpan,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Simpan',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      )
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FAB Word — biru gelap
          FloatingActionButton(
            heroTag: 'fab_word',
            onPressed: _buatWord,
            backgroundColor: darkBlue,
            mini: true,
            child: const Icon(Icons.description_outlined,
                color: Colors.white),
          ),
          const SizedBox(width: 10),
          // FAB AI — ungu (warna Akan Datang TodoList)
          FloatingActionButton.extended(
            heroTag: 'fab_ai',
            onPressed: _bukaAiAssistant,
            backgroundColor: accentPurple,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Tanya AI',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _lihatGambar(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GambarViewer(
          imagePaths: _imagePaths,
          initialIndex: startIndex,
        ),
      ),
    );
  }
}

// ── AI Bottom Sheet ────────────────────────────────────────────────────────────

class _AiTugasSheet extends StatefulWidget {
  final String namaTask;
  final String catatan;
  final String prioritas;
  final String tipe;
  final TimeOfDay? waktu;
  final DateTime? tanggal;
  final List<String> imagePaths;
  final String groqApiKey;
  final String groqApiUrl;
  final String model;

  const _AiTugasSheet({
    required this.namaTask,
    required this.catatan,
    required this.prioritas,
    required this.tipe,
    required this.waktu,
    required this.tanggal,
    required this.imagePaths,
    required this.groqApiKey,
    required this.groqApiUrl,
    required this.model,
  });

  @override
  State<_AiTugasSheet> createState() => _AiTugasSheetState();
}

class _AiTugasSheetState extends State<_AiTugasSheet> {
  static const primaryColor = Color(0xFF2563EB);
  static const accentPurple = Color(0xFF7C3AED);

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

  String _buatKonteksTugas() {
    String konteks = 'Tugas: ${widget.namaTask}';
    if (widget.catatan.isNotEmpty) konteks += '\nCatatan: ${widget.catatan}';
    if (widget.prioritas.isNotEmpty)
      konteks += '\nPrioritas: ${widget.prioritas}';
    konteks +=
    '\nTipe: ${widget.tipe == 'hariIni' ? 'Hari Ini' : 'Akan Datang'}';
    if (widget.tipe == 'hariIni' && widget.waktu != null) {
      konteks +=
      '\nWaktu: ${widget.waktu!.hour.toString().padLeft(2, '0')}:${widget.waktu!.minute.toString().padLeft(2, '0')}';
    }
    if (widget.tipe == 'akanDatang' && widget.tanggal != null) {
      konteks +=
      '\nTanggal: ${DateFormat('d MMM yyyy').format(widget.tanggal!)}';
    }
    if (widget.imagePaths.isNotEmpty) {
      konteks += '\nLampiran Gambar: ${widget.imagePaths.length} gambar';
    }
    return konteks;
  }

  Future<void> _kirimPesanAwal() async {
    final konteks = _buatKonteksTugas();
    final systemPrompt =
        'Kamu adalah HeadNote AI, asisten dalam aplikasi catatan HeadNote. '
        'Pengguna sedang membuka detail tugas berikut:\n$konteks\n\n'
        'Sambut pengguna dengan ramah, tampilkan ringkasan tugas ini, '
        'lalu tawarkan bantuan seperti: rencana langkah-langkah pengerjaan, '
        'tips menyelesaikan tugas, atau pertanyaan apapun soal tugas ini. '
        'Jawab dalam Bahasa Indonesia, singkat dan mudah dipahami.';

    _history.clear();
    _history.add({'role': 'system', 'content': systemPrompt});
    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
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
      )
          .timeout(const Duration(seconds: 30));

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
      final response = await http
          .post(
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
      )
          .timeout(const Duration(seconds: 30));

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
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Avatar AI — gradien biru→ungu TodoList
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, accentPurple],
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
                          widget.namaTask,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500),
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
            // Quick prompts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  '📋 Buat langkah pengerjaan',
                  '⏱️ Estimasi waktu',
                  '💡 Kasih tips',
                  '✅ Cara mulai',
                ].map((q) {
                  final label = q.substring(3);
                  return GestureDetector(
                    onTap: () {
                      _inputController.text = label;
                      _kirimPesan();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: primaryColor.withOpacity(0.25)),
                      ),
                      child: Text(q,
                          style: const TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
            ),
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
                            margin: const EdgeInsets.only(right: 6, bottom: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, accentPurple],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
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
                                  ? primaryColor
                                  : isError
                                  ? Colors.red.shade50
                                  : const Color(0xFFF1F5F9),
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
                                    : const Color(0xFF1E293B),
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
            // Input area
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _inputController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Tanya AI tentang tugas ini...',
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
                              : const LinearGradient(
                              colors: [primaryColor, accentPurple]),
                          color: _isLoading ? Colors.grey.shade300 : null,
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: primaryColor),
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
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
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

// ─── Helper Widgets ────────────────────────────────────────────────────────────

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
              color: Color(0xFF2563EB), shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.grey.shade400),
      const SizedBox(width: 6),
      Text(text,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF64748B))),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text('$icon $label',
        style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600)),
  );
}

class _TapFieldDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TapFieldDetail(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF1E293B))),
          const Spacer(),
          const Icon(Icons.chevron_right,
              color: Colors.grey, size: 18),
        ],
      ),
    ),
  );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Colors.black38),
  filled: true,
  fillColor: const Color(0xFFF8FAFC),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
  ),
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
);

class _GambarViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  const _GambarViewer(
      {required this.imagePaths, required this.initialIndex});
  @override
  State<_GambarViewer> createState() => _GambarViewerState();
}

class _GambarViewerState extends State<_GambarViewer> {
  late PageController _pageController;
  late int _current;
  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Gambar ${_current + 1} / ${widget.imagePaths.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.file(
              File(widget.imagePaths[i]),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image,
                    color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}