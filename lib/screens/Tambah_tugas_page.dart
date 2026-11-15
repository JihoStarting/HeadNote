import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// ─── Notification Service (singleton) ────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<void> jadwalkanNotifikasi({
    required int id,
    required String namaTugas,
    required String tipe,
    TimeOfDay? waktu,
    DateTime? tanggal,
  }) async {
    await init();
    await batalkanNotifikasi(id);

    DateTime? deadline;
    final now = DateTime.now();

    if (tipe == 'hariIni' && waktu != null) {
      deadline = DateTime(now.year, now.month, now.day, waktu.hour, waktu.minute);
    } else if (tipe == 'akanDatang' && tanggal != null) {
      deadline = DateTime(tanggal.year, tanggal.month, tanggal.day, 23, 59);
    }

    if (deadline == null) return;

    final notifTime = deadline.subtract(const Duration(hours: 1));
    if (notifTime.isBefore(now)) return;

    await _plugin.zonedSchedule(
      id,
      '⏰ Deadline Kurang 1 Jam!',
      'Tugas "$namaTugas" harus dikumpulkan sebelum ${_formatDeadline(deadline)}',
      tz.TZDateTime.from(notifTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'tugas_channel',
          'Pengingat Tugas',
          channelDescription: 'Notifikasi pengingat tugas mendekati deadline',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2563EB),
          styleInformation: BigTextStyleInformation(
            'Tugas "$namaTugas" harus dikumpulkan sebelum ${_formatDeadline(deadline)}. Segera selesaikan!',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> batalkanNotifikasi(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  String _formatDeadline(DateTime dt) {
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '$jam:$menit';
  }
}

// ─── TambahTugasPage ──────────────────────────────────────────────────────────

class TambahTugasPage extends StatefulWidget {
  final Map<String, dynamic>? existingTask;

  const TambahTugasPage({super.key, this.existingTask});

  @override
  State<TambahTugasPage> createState() => _TambahTugasPageState();
}

class _TambahTugasPageState extends State<TambahTugasPage> {
  static const primaryColor  = Color(0xFF2563EB);
  static const darkBar       = Color(0xFF1A2A3A);
  static const accentPurple  = Color(0xFF7C3AED);

  final _namaController       = TextEditingController();
  final _mataKuliahController = TextEditingController();
  final _catatanController    = TextEditingController();

  String _prioritas = 'Tinggi';
  String _tipe      = 'hariIni';
  TimeOfDay? _waktu;
  DateTime?  _tanggal;
  List<String> _imagePaths = [];

  final _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifService.init();

    final task = widget.existingTask;
    if (task != null) {
      _namaController.text       = task['nama'] ?? '';
      _mataKuliahController.text = task['mataKuliah'] ?? '';
      _catatanController.text    = task['catatan'] ?? '';
      _prioritas  = task['prioritas'] ?? 'Tinggi';
      _tipe       = task['tipe'] ?? 'hariIni';
      _imagePaths = List<String>.from(task['gambar'] ?? []);

      if (task['waktu'] is String) {
        final parts = (task['waktu'] as String).split(':');
        if (parts.length == 2) {
          _waktu = TimeOfDay(
            hour:   int.tryParse(parts[0]) ?? 23,
            minute: int.tryParse(parts[1]) ?? 59,
          );
        }
      }
      if (task['tanggal'] is DateTime) _tanggal = task['tanggal'];
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _mataKuliahController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // ── Pilih waktu ────────────────────────────────────────────────────────────
  Future<void> _pilihWaktu() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _waktu ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _waktu = picked);
  }

  // ── Pilih tanggal ──────────────────────────────────────────────────────────
  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  // ── Tambah gambar ──────────────────────────────────────────────────────────
  Future<void> _tambahGambar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Sumber Gambar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.camera_alt, color: primaryColor),
              ),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.photo_library, color: primaryColor),
              ),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _imagePaths.add(picked.path));
  }

  void _hapusGambar(int i) => setState(() => _imagePaths.removeAt(i));

  // ── Simpan (dengan try-catch notifikasi) ───────────────────────────────────
  void _simpan() async {
    final nama = _namaController.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tugas tidak boleh kosong!')),
      );
      return;
    }

    if (_tipe == 'hariIni' && _waktu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih waktu deadline terlebih dahulu!')),
      );
      return;
    }
    if (_tipe == 'akanDatang' && _tanggal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal deadline terlebih dahulu!')),
      );
      return;
    }

    final taskData = <String, dynamic>{
      'nama': nama,
      'mataKuliah': _mataKuliahController.text.trim(),
      'prioritas': _prioritas,
      'catatan': _catatanController.text.trim(),
      'selesai': false,
      'tipe': _tipe,
      'gambar': _imagePaths,
      if (_tipe == 'hariIni' && _waktu != null)
        'waktu':
        '${_waktu!.hour.toString().padLeft(2, '0')}:${_waktu!.minute.toString().padLeft(2, '0')}',
      if (_tipe == 'akanDatang' && _tanggal != null)
        'tanggal': _tanggal,
    };

    // ✅ Notifikasi dibungkus try-catch — gagal pun tugas tetap tersimpan
    try {
      await _notifService.jadwalkanNotifikasi(
        id: nama.hashCode.abs() % 100000,
        namaTugas: nama,
        tipe: _tipe,
        waktu: _waktu,
        tanggal: _tanggal,
      );
    } catch (e) {
      debugPrint('Notifikasi gagal dijadwalkan: $e');
    }

    if (mounted) Navigator.pop(context, taskData);
  }

  // ── Hapus tugas ────────────────────────────────────────────────────────────
  void _hapus() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Tugas'),
        content: const Text('Apakah Anda yakin ingin menghapus tugas ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {'hapus': true});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Color _warnaPrioritas(String p) {
    if (p == 'Tinggi') return const Color(0xFFDC2626);
    if (p == 'Sedang') return const Color(0xFFD97706);
    if (p == 'Rendah') return const Color(0xFF059669);
    return Colors.grey;
  }

  Color _warnaToggle(String t) =>
      t == 'hariIni' ? primaryColor : accentPurple;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/Logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari tugas...',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sub-header
          Container(
            width: double.infinity,
            color: darkBar,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: const Center(
              child: Text(
                'Tambah Tugas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Nama Tugas ───────────────────────────────────────────
                  _FormLabel('Nama Tugas'),
                  const SizedBox(height: 8),
                  _buildTextField(_namaController, 'Contoh: Tugas Flutter'),

                  const SizedBox(height: 16),

                  // ── Mata Kuliah ──────────────────────────────────────────
                  _FormLabel('Mata Kuliah'),
                  const SizedBox(height: 8),
                  _buildTextField(
                      _mataKuliahController, 'Contoh: Pemrograman Mobile'),

                  const SizedBox(height: 16),

                  // ── Tipe Jadwal ──────────────────────────────────────────
                  _FormLabel('Jadwal'),
                  const SizedBox(height: 8),
                  Row(
                    children: ['hariIni', 'akanDatang'].map((t) {
                      final label =
                      t == 'hariIni' ? '📌 Hari Ini' : '🗓️ Akan Datang';
                      final selected = _tipe == t;
                      final color = _warnaToggle(t);
                      return GestureDetector(
                        onTap: () => setState(() => _tipe = t),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? color : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                                fontSize: 13,
                                color: selected ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // ── Waktu / Tanggal ──────────────────────────────────────
                  if (_tipe == 'hariIni') ...[
                    _FormLabel('Waktu Deadline'),
                    const SizedBox(height: 8),
                    _TapField(
                      icon: Icons.access_time,
                      label: _waktu != null
                          ? _waktu!.format(context)
                          : 'Pilih Waktu',
                      onTap: _pilihWaktu,
                    ),
                  ] else ...[
                    _FormLabel('Tanggal Deadline'),
                    const SizedBox(height: 8),
                    _TapField(
                      icon: Icons.calendar_today,
                      label: _tanggal != null
                          ? '${_tanggal!.day}/${_tanggal!.month}/${_tanggal!.year}'
                          : 'Pilih Tanggal',
                      onTap: _pilihTanggal,
                      color: accentPurple,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Info notifikasi
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active,
                            color: Colors.amber, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kamu akan mendapat notifikasi 1 jam sebelum deadline',
                            style:
                            TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Prioritas ────────────────────────────────────────────
                  _FormLabel('Prioritas'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: ['Tinggi', 'Sedang', 'Rendah'].map((p) {
                      final selected = _prioritas == p;
                      return GestureDetector(
                        onTap: () => setState(() => _prioritas = p),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _warnaPrioritas(p),
                                border: selected
                                    ? Border.all(
                                    color: Colors.black54, width: 2)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(p,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? _warnaPrioritas(p)
                                        : const Color(0xFF1E293B))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Catatan ──────────────────────────────────────────────
                  _FormLabel('Catatan (opsional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _catatanController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tulis catatan di sini...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        const BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Lampiran Gambar ──────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FormLabel('Lampiran Gambar'),
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
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _imagePaths.isEmpty
                      ? GestureDetector(
                    onTap: _tambahGambar,
                    child: Container(
                      width: double.infinity,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              color: Colors.grey.shade400, size: 32),
                          const SizedBox(height: 6),
                          Text(
                            'Tap untuk tambah gambar',
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
                    itemCount: _imagePaths.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _imagePaths.length) {
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
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_imagePaths[i]),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child:
                                const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
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
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Tombol Simpan ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton.icon(
                      onPressed: _hapus,
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFF64748B)),
                      label: const Text('Hapus',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 14)),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B)));
  }
}

class _TapField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _TapField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  color: label.contains('Pilih')
                      ? Colors.grey.shade400
                      : const Color(0xFF1E293B)),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}