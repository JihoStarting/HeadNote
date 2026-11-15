import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Todo_list_page.dart';
import 'detail_catatan_page.dart';
import 'ai_page.dart';

class MataKuliah {
  final String id;
  final String nama;
  final Color warnaIcon;
  final String icon;
  final String deskripsi;

  const MataKuliah({
    required this.id,
    required this.nama,
    required this.warnaIcon,
    required this.icon,
    required this.deskripsi,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'warnaIcon': warnaIcon.value,
    'icon': icon,
    'deskripsi': deskripsi,
  };

  factory MataKuliah.fromJson(Map<String, dynamic> json) => MataKuliah(
    id: json['id'],
    nama: json['nama'],
    warnaIcon: Color(json['warnaIcon']),
    icon: json['icon'],
    deskripsi: json['deskripsi'],
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isLoading = true;

  List<MataKuliah> _subjects = [];
  Map<String, List<Map<String, dynamic>>> _catatanMap = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Tasks (dikelola di sini, dibagikan ke AiPage & TodoListPage) ──────────
  List<Map<String, dynamic>> _tasks = [];

  static const _keySubjects = 'subjects';
  static const _keyCatatanMap = 'catatan_map';
  static const _keyTasks = 'tasks';

  static const _primaryBlue = Color(0xFF2563EB);
  static const _bgColor = Color(0xFFF8FAFF);
  static const _navBg = Color(0xFF1E3A5F);

  // ── Load semua data termasuk tasks ────────────────────────────────────────
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load subjects
    final subjectsJson = prefs.getString(_keySubjects);
    if (subjectsJson != null) {
      final List decoded = jsonDecode(subjectsJson);
      _subjects = decoded.map((e) => MataKuliah.fromJson(e)).toList();
    } else {
      _subjects = [
        MataKuliah(
            id: '1',
            nama: 'Pemrograman Mobile',
            warnaIcon: const Color(0xFF6366F1),
            icon: '📱',
            deskripsi: 'Flutter & Dart development'),
        MataKuliah(
            id: '2',
            nama: 'Teknik Digital',
            warnaIcon: const Color(0xFF10B981),
            icon: '💡',
            deskripsi: 'Rangkaian digital & logika'),
        MataKuliah(
            id: '3',
            nama: 'Manajemen',
            warnaIcon: const Color(0xFFF59E0B),
            icon: '📊',
            deskripsi: 'Manajemen proyek & bisnis'),
        MataKuliah(
            id: '4',
            nama: 'Metode Numerik',
            warnaIcon: const Color(0xFFEF4444),
            icon: '📐',
            deskripsi: 'Komputasi & algoritma numerik'),
      ];
    }

    // Load catatan
    final catatanJson = prefs.getString(_keyCatatanMap);
    if (catatanJson != null) {
      final Map decoded = jsonDecode(catatanJson);
      _catatanMap = decoded.map(
            (key, value) =>
            MapEntry(key, List<Map<String, dynamic>>.from(value)),
      );
    }

    // Load tasks
    final tasksJson = prefs.getString(_keyTasks);
    if (tasksJson != null) {
      final List decoded = jsonDecode(tasksJson);
      _tasks = decoded.map((e) {
        final task = Map<String, dynamic>.from(e);
        if (task['tanggal'] != null && task['tanggal'] is String) {
          task['tanggal'] = DateTime.parse(task['tanggal']);
        }
        return task;
      }).toList();
    } else {
      _tasks = [];
    }

    setState(() => _isLoading = false);
  }

  // ── Save tasks ke SharedPreferences ──────────────────────────────────────
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _tasks.map((task) {
      final copy = Map<String, dynamic>.from(task);
      if (copy['tanggal'] is DateTime) {
        copy['tanggal'] = (copy['tanggal'] as DateTime).toIso8601String();
      }
      return copy;
    }).toList();
    await prefs.setString(_keyTasks, jsonEncode(encoded));
  }

  Future<void> _saveSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keySubjects,
        jsonEncode(_subjects.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveCatatanMap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCatatanMap, jsonEncode(_catatanMap));
  }

  List<MataKuliah> get _filteredSubjects {
    if (_searchQuery.isEmpty) return _subjects;
    return _subjects
        .where((mk) =>
        mk.nama.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) => setState(() => _selectedIndex = index);

  void _tambahAtauEditMataKuliah({MataKuliah? mataKuliah}) async {
    final result = await Navigator.push<MataKuliah>(
      context,
      MaterialPageRoute(
          builder: (_) => TambahMataKuliahPage(mataKuliah: mataKuliah)),
    );
    if (result != null) {
      setState(() {
        if (mataKuliah != null) {
          final index = _subjects.indexWhere((m) => m.id == mataKuliah.id);
          if (index != -1) _subjects[index] = result;
        } else {
          _subjects.add(result);
          _catatanMap[result.id] = [];
        }
      });
      await _saveSubjects();
      await _saveCatatanMap();
    }
  }

  void _hapusMataKuliah(String id) async {
    setState(() {
      _subjects.removeWhere((m) => m.id == id);
      _catatanMap.remove(id);
    });
    await _saveSubjects();
    await _saveCatatanMap();
  }

  void _bukaDetailMataKuliah(MataKuliah mk) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DaftarCatatanMataKuliahPage(
          mataKuliah: mk,
          catatan: _catatanMap[mk.id] ?? [],
          onCatatanChanged: (updatedList) async {
            setState(() => _catatanMap[mk.id] = updatedList);
            await _saveCatatanMap();
          },
        ),
      ),
    );
  }

  // ── Callback dari AiPage: simpan catatan baru ke matkul tertentu ──────────
  Future<void> _onNoteCreatedFromAI(
      String subjectId, Map<String, dynamic> note) async {
    setState(() {
      _catatanMap[subjectId] ??= [];
      _catatanMap[subjectId]!.add(note);
    });
    await _saveCatatanMap();
  }

  // ── Callback dari AiPage: tambah task baru ke to-do list ─────────────────
  Future<void> _onTaskCreatedFromAI(Map<String, dynamic> task) async {
    setState(() => _tasks.add(task));
    await _saveTasks();
  }

  // ── Callback dari TodoListPage: tasks berubah (toggle, hapus, edit, tambah)
  Future<void> _onTasksChanged(List<Map<String, dynamic>> updatedTasks) async {
    setState(() => _tasks = updatedTasks);
    await _saveTasks();
  }

  Widget _buildHomeBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryBlue),
      );
    }

    if (_subjects.isEmpty) {
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
                child: Text('📚', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada mata kuliah',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan + untuk menambahkan',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_filteredSubjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _filteredSubjects.length,
      itemBuilder: (context, index) {
        final mk = _filteredSubjects[index];
        return Dismissible(
          key: ValueKey(mk.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) => _hapusMataKuliah(mk.id),
          child: _SubjectCard(
            mataKuliah: mk,
            onTap: () => _bukaDetailMataKuliah(mk),
            onEdit: () => _tambahAtauEditMataKuliah(mataKuliah: mk),
          ),
        );
      },
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_selectedIndex != 0) return null;

    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: const BoxDecoration(
          color: _primaryBlue,
          boxShadow: [
            BoxShadow(
              color: Color(0x20000000),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/Logo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style:
                      const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cari mata kuliah...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18,
                            color: Colors.white.withOpacity(0.8)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Colors.white.withOpacity(0.8),
                              size: 18),
                          onPressed: () => _searchController.clear(),
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
                GestureDetector(
                  onTap: () => _tambahAtauEditMataKuliah(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: _primaryBlue, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _scaffoldBgColor {
    switch (_selectedIndex) {
      case 0:
        return _bgColor;
      case 2:
        return const Color(0xFFF5F7FA);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeBody(),

          // ── AiPage: kirim onTaskCreated dan onNoteCreated ─────────
          AiPage(
            subjects: _subjects,
            onNoteCreated: _onNoteCreatedFromAI,
            onTaskCreated: _onTaskCreatedFromAI,
          ),

          // ── TodoListPage: terima tasks dari luar ─────────────────
          TodoListPage(
            initialTasks: _tasks,
            onTasksChanged: _onTasksChanged,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {
        'icon': Icons.home_outlined,
        'activeIcon': Icons.home_rounded,
        'label': 'Home'
      },
      {
        'icon': Icons.auto_awesome_outlined,
        'activeIcon': Icons.auto_awesome,
        'label': 'AI'
      },
      {
        'icon': Icons.checklist_outlined,
        'activeIcon': Icons.checklist_rounded,
        'label': 'To-do List'
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _navBg,
        boxShadow: [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = _selectedIndex == index;
              final item = items[index];
              return GestureDetector(
                onTap: () => _onNavTapped(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? item['activeIcon'] as IconData
                            : item['icon'] as IconData,
                        color: isSelected ? Colors.white : Colors.white54,
                        size: 24,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color:
                          isSelected ? Colors.white : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Halaman Daftar Catatan per Mata Kuliah ───────────────────────────────────

class _DaftarCatatanMataKuliahPage extends StatefulWidget {
  final MataKuliah mataKuliah;
  final List<Map<String, dynamic>> catatan;
  final Function(List<Map<String, dynamic>>) onCatatanChanged;

  const _DaftarCatatanMataKuliahPage({
    required this.mataKuliah,
    required this.catatan,
    required this.onCatatanChanged,
  });

  @override
  State<_DaftarCatatanMataKuliahPage> createState() =>
      _DaftarCatatanMataKuliahPageState();
}

class _DaftarCatatanMataKuliahPageState
    extends State<_DaftarCatatanMataKuliahPage> {
  late List<Map<String, dynamic>> _catatan;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredCatatan {
    if (_searchQuery.isEmpty) return _catatan;
    return _catatan
        .where((note) =>
    (note['judul'] ?? '')
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()) ||
        (note['isi'] ?? '')
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _catatan = List.from(widget.catatan);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _tambahCatatan() async {
    final note = {
      'judul': 'Catatan Baru',
      'isi': '',
      'tanggal': DateTime.now().toIso8601String(),
    };
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              DetailCatatanPage(note: note, index: _catatan.length)),
    );
    if (result != null && result['action'] == 'simpan') {
      setState(() => _catatan.add(result['note']));
      widget.onCatatanChanged(_catatan);
    }
  }

  void _bukaDetail(Map<String, dynamic> note) async {
    final realIndex = _catatan.indexOf(note);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => DetailCatatanPage(note: note, index: realIndex)),
    );
    if (result != null) {
      setState(() {
        if (result['action'] == 'simpan') {
          _catatan[realIndex] = result['note'];
        } else if (result['action'] == 'hapus') {
          _catatan.removeAt(realIndex);
        }
      });
      widget.onCatatanChanged(_catatan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mk = widget.mataKuliah;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: mk.warnaIcon,
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cari catatan...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18,
                              color: Colors.white.withOpacity(0.8)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: Colors.white.withOpacity(0.8),
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _tambahCatatan,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add_rounded,
                          color: mk.warnaIcon, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: mk.warnaIcon.withOpacity(0.08),
              border: Border(
                bottom:
                BorderSide(color: mk.warnaIcon.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mk.warnaIcon.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child:
                    Text(mk.icon, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mk.nama,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (mk.deskripsi.isNotEmpty)
                        Text(
                          mk.deskripsi,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: mk.warnaIcon.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_catatan.length} catatan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mk.warnaIcon,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _catatan.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: mk.warnaIcon.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child:
                      Text('📝', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada catatan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tekan + untuk menambahkan',
                    style:
                    TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
                : _filteredCatatan.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔍',
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ditemukan:\n"$_searchQuery"',
                    style: const TextStyle(
                        fontSize: 15, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => _searchController.clear(),
                    child: Text('Hapus pencarian',
                        style:
                        TextStyle(color: mk.warnaIcon)),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _filteredCatatan.length,
              itemBuilder: (context, index) {
                final note = _filteredCatatan[index];
                final realIndex = _catatan.indexOf(note);
                return Dismissible(
                  key: ValueKey(
                      '${note['judul']}_$realIndex'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding:
                    const EdgeInsets.only(right: 20),
                    margin:
                    const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() =>
                        _catatan.removeAt(realIndex));
                    widget.onCatatanChanged(_catatan);
                  },
                  child: GestureDetector(
                    onTap: () => _bukaDetail(note),
                    child: Container(
                      margin:
                      const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(
                              color: mk.warnaIcon,
                              width: 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note['judul'] ?? '',
                                  style: const TextStyle(
                                    fontWeight:
                                    FontWeight.w600,
                                    fontSize: 15,
                                    color:
                                    Color(0xFF1E293B),
                                  ),
                                ),
                                if ((note['isi'] ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    note['isi'],
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors
                                          .grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey.shade300),
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
    );
  }
}

// ─── Subject Card ─────────────────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  final MataKuliah mataKuliah;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _SubjectCard({
    required this.mataKuliah,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: mataKuliah.warnaIcon.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 78,
                color: mataKuliah.warnaIcon,
              ),
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: mataKuliah.warnaIcon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(mataKuliah.icon,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mataKuliah.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (mataKuliah.deskripsi.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          mataKuliah.deskripsi,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: mataKuliah.warnaIcon.withOpacity(0.7),
                    size: 20),
                onPressed: onEdit,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tambah / Edit Mata Kuliah ────────────────────────────────────────────────

class TambahMataKuliahPage extends StatefulWidget {
  final MataKuliah? mataKuliah;
  const TambahMataKuliahPage({super.key, this.mataKuliah});

  @override
  State<TambahMataKuliahPage> createState() => _TambahMataKuliahPageState();
}

class _TambahMataKuliahPageState extends State<TambahMataKuliahPage> {
  late TextEditingController _namaController;
  late TextEditingController _deskripsiController;
  String _selectedIcon = '📚';
  Color _selectedColor = const Color(0xFF2563EB);

  final List<String> _icons = [
    '📚', '📱', '💡', '📊', '📐', '🔬', '💻', '🎨', '🏛️', '⚙️'
  ];
  final List<Color> _colors = [
    const Color(0xFF2563EB),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFF06B6D4),
    const Color(0xFF64748B),
  ];

  @override
  void initState() {
    super.initState();
    _namaController =
        TextEditingController(text: widget.mataKuliah?.nama ?? '');
    _deskripsiController =
        TextEditingController(text: widget.mataKuliah?.deskripsi ?? '');
    if (widget.mataKuliah != null) {
      _selectedIcon = widget.mataKuliah!.icon;
      _selectedColor = widget.mataKuliah!.warnaIcon;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_namaController.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      MataKuliah(
        id: widget.mataKuliah?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        nama: _namaController.text.trim(),
        warnaIcon: _selectedColor,
        icon: _selectedIcon,
        deskripsi: _deskripsiController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.mataKuliah != null
              ? 'Edit Mata Kuliah'
              : 'Tambah Mata Kuliah',
          style:
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _simpan,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border:
              Border.all(color: _selectedColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(_selectedIcon,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _namaController.text.isEmpty
                            ? 'Nama Mata Kuliah'
                            : _namaController.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _namaController.text.isEmpty
                              ? Colors.grey
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _deskripsiController.text.isEmpty
                            ? 'Deskripsi'
                            : _deskripsiController.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: _deskripsiController.text.isEmpty
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildInputField(
            controller: _namaController,
            label: 'Nama Mata Kuliah',
            hint: 'Contoh: Pemrograman Mobile',
            icon: Icons.book_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _deskripsiController,
            label: 'Deskripsi',
            hint: 'Deskripsi singkat mata kuliah',
            icon: Icons.notes_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pilih Icon',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _icons.map((icon) {
              final isSelected = _selectedIcon == icon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _selectedColor.withOpacity(0.1)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? _selectedColor
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: _selectedColor.withOpacity(0.2),
                        blurRadius: 6,
                      )
                    ]
                        : [],
                  ),
                  child:
                  Text(icon, style: const TextStyle(fontSize: 26)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pilih Warna',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colors.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(isSelected ? 0.5 : 0.2),
                        blurRadius: isSelected ? 8 : 4,
                        spreadRadius: isSelected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _selectedColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: _selectedColor, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle:
          TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ),
    );
  }
}