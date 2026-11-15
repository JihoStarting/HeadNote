import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'Tambah_tugas_page.dart';
import 'Detail_tugas_page.dart';

class TodoListPage extends StatefulWidget {
  /// Tasks yang dikelola dari HomeScreen
  final List<Map<String, dynamic>> initialTasks;

  /// Dipanggil setiap kali tasks berubah (tambah, hapus, edit, toggle)
  final Future<void> Function(List<Map<String, dynamic>>) onTasksChanged;

  const TodoListPage({
    super.key,
    required this.initialTasks,
    required this.onTasksChanged,
  });

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Salinan lokal dari tasks yang diteruskan dari HomeScreen
  late List<Map<String, dynamic>> _tasks;

  static const _primaryBlue = Color(0xFF2563EB);
  static const _bgColor = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    // Salin list agar bisa dimodifikasi secara lokal
    _tasks = List<Map<String, dynamic>>.from(widget.initialTasks);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  // Sinkronisasi ketika HomeScreen mendapat task baru dari AI
  @override
  void didUpdateWidget(covariant TodoListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika panjang tasks berubah (misal ada yang ditambahkan dari AI),
    // sinkronkan tanpa menimpa perubahan lokal yang sedang terjadi
    if (widget.initialTasks.length != _tasks.length) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(widget.initialTasks);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Getter filter ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _hariIni {
    return _tasks.where((t) {
      final cocok = t['tipe'] == 'hariIni';
      if (_searchQuery.isEmpty) return cocok;
      return cocok &&
          (t['nama'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get _akanDatang {
    return _tasks.where((t) {
      final cocok = t['tipe'] == 'akanDatang';
      if (_searchQuery.isEmpty) return cocok;
      return cocok &&
          (t['nama'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  int get _selesaiCount => _tasks.where((t) => t['selesai'] == true).length;

  bool get _adaHasilPencarian =>
      _hariIni.isNotEmpty || _akanDatang.isNotEmpty;

  // ── Aksi task ─────────────────────────────────────────────────────────────

  void _toggleSelesai(Map<String, dynamic> task) async {
    setState(() {
      final idx = _tasks.indexOf(task);
      if (idx != -1) _tasks[idx]['selesai'] = !_tasks[idx]['selesai'];
    });
    await widget.onTasksChanged(_tasks);
  }

  void _hapusTugas(Map<String, dynamic> task) async {
    setState(() => _tasks.remove(task));
    await widget.onTasksChanged(_tasks);
  }

  void _tambahTugas() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TambahTugasPage()),
    );
    if (result != null && result is Map<String, dynamic>) {
      if (result['hapus'] == true) return;
      setState(() => _tasks.add(result));
      await widget.onTasksChanged(_tasks);
    }
  }

  void _editTugas(Map<String, dynamic> task) async {
    final taskCopy = Map<String, dynamic>.from(task);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailTugasPage(task: taskCopy)),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (result['action'] == 'hapus') {
          _tasks.remove(task);
        } else if (result['action'] == 'simpan') {
          final idx = _tasks.indexOf(task);
          if (idx != -1) _tasks[idx] = result['task'];
        }
      });
      await widget.onTasksChanged(_tasks);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/Logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                // Search bar
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Cari tugas...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: Colors.grey.shade400),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Colors.grey.shade400,
                              size: 18),
                          onPressed: () =>
                              _searchController.clear(),
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Add button
                GestureDetector(
                  onTap: _tambahTugas,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Search no result
    if (!_adaHasilPencarian && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Tidak ditemukan:\n"$_searchQuery"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _searchController.clear(),
              child: const Text('Hapus pencarian',
                  style: TextStyle(color: _primaryBlue)),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('✅', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada tugas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan + untuk menambahkan\natau minta AI buatkan tugas',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Progress summary card
        _buildProgressCard(),
        const SizedBox(height: 20),

        // HARI INI section
        if (_hariIni.isNotEmpty || _searchQuery.isEmpty) ...[
          _SeksiHeader(
            icon: '📌',
            label: 'HARI INI',
            count: _hariIni.length,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 10),
          ..._hariIni.map((task) => _TaskCard(
            task: task,
            onToggle: () => _toggleSelesai(task),
            onHapus: () => _hapusTugas(task),
            onEdit: () => _editTugas(task),
            isHariIni: true,
          )),
          const SizedBox(height: 20),
        ],

        // AKAN DATANG section
        if (_akanDatang.isNotEmpty || _searchQuery.isEmpty) ...[
          _SeksiHeader(
            icon: '🗓️',
            label: 'AKAN DATANG',
            count: _akanDatang.length,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 10),
          ..._akanDatang.map((task) => _TaskCard(
            task: task,
            onToggle: () => _toggleSelesai(task),
            onHapus: () => _hapusTugas(task),
            onEdit: () => _editTugas(task),
            isHariIni: false,
          )),
        ],
      ],
    );
  }

  Widget _buildProgressCard() {
    final total = _tasks.length;
    final selesai = _selesaiCount;
    final progress = total > 0 ? selesai / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress Hari Ini',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$selesai/$total selesai',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor:
              const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress == 1.0
                ? '🎉 Semua tugas selesai!'
                : progress == 0
                ? 'Yuk mulai kerjakan tugasmu!'
                : 'Terus semangat! Hampir selesai 💪',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header Seksi ──────────────────────────────────────────────────────────────

class _SeksiHeader extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final Color color;

  const _SeksiHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggle;
  final VoidCallback onHapus;
  final VoidCallback onEdit;
  final bool isHariIni;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onHapus,
    required this.onEdit,
    required this.isHariIni,
  });

  @override
  Widget build(BuildContext context) {
    final bool selesai = task['selesai'] ?? false;

    String subtitle = '';
    if (isHariIni) {
      subtitle = task['waktu'] ?? '';
    } else {
      final tanggal = task['tanggal'];
      if (tanggal is DateTime) {
        subtitle = DateFormat('d MMM yyyy').format(tanggal);
      }
    }

    final String prioritas = task['prioritas'] ?? '';

    Color prioritasColor = Colors.transparent;
    Color prioritasBg = Colors.transparent;
    if (prioritas == 'Tinggi') {
      prioritasColor = const Color(0xFFDC2626);
      prioritasBg = const Color(0xFFFEF2F2);
    } else if (prioritas == 'Sedang') {
      prioritasColor = const Color(0xFFD97706);
      prioritasBg = const Color(0xFFFFFBEB);
    } else if (prioritas == 'Rendah') {
      prioritasColor = const Color(0xFF059669);
      prioritasBg = const Color(0xFFF0FDF4);
    }

    final accentColor =
    isHariIni ? const Color(0xFF2563EB) : const Color(0xFF7C3AED);

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onHapus(),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
            selesai ? Colors.white.withOpacity(0.7) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color:
                selesai ? Colors.grey.shade200 : accentColor,
                width: 4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                Colors.black.withOpacity(selesai ? 0.03 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selesai
                            ? accentColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selesai
                              ? accentColor
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: selesai
                          ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['nama'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selesai
                              ? Colors.grey.shade400
                              : const Color(0xFF1E293B),
                          decoration: selesai
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.grey.shade400,
                        ),
                      ),
                      if (subtitle.isNotEmpty ||
                          prioritas.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (subtitle.isNotEmpty) ...[
                              Icon(
                                isHariIni
                                    ? Icons.access_time_rounded
                                    : Icons.calendar_today_rounded,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                            if (prioritas.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: prioritasBg,
                                  borderRadius:
                                  BorderRadius.circular(6),
                                  border: Border.all(
                                      color: prioritasColor
                                          .withOpacity(0.3)),
                                ),
                                child: Text(
                                  prioritas,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: prioritasColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade300, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}