import 'package:flutter/material.dart';
import 'Todo_list_page.dart';

// Model untuk Mata Kuliah
class MataKuliah {
  final String id;
  String nama;
  Color warnaIcon;
  String icon;
  String deskripsi;

  MataKuliah({
    required this.id,
    required this.nama,
    required this.warnaIcon,
    required this.icon,
    this.deskripsi = '',
  });
}

// Halaman Daftar Mata Kuliah
class DaftarMataKuliahPage extends StatefulWidget {
  const DaftarMataKuliahPage({super.key});

  @override
  State<DaftarMataKuliahPage> createState() => _DaftarMataKuliahPageState();
}

class _DaftarMataKuliahPageState extends State<DaftarMataKuliahPage> {
  List<Map<String, dynamic>> _tasks = [];

  final List<MataKuliah> _daftarMataKuliah = [
    MataKuliah(
      id: '1',
      nama: 'Basis Data',
      warnaIcon: const Color(0xFF2196F3),
      icon: '📁',
      deskripsi: 'Mata kuliah tentang manajemen basis data',
    ),
    MataKuliah(
      id: '2',
      nama: 'Pemrograman Web',
      warnaIcon: const Color(0xFF4CAF50),
      icon: '🖥️',
      deskripsi: 'Belajar HTML, CSS, dan JavaScript',
    ),
    MataKuliah(
      id: '3',
      nama: 'Algoritma',
      warnaIcon: const Color(0xFFFF5722),
      icon: '📊',
      deskripsi: '',
    ),
  ];

  Future<void> _navigateToTodoList() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TodoListPage(
          initialTasks: _tasks,
          onTasksChanged: (updatedTasks) async {
            setState(() => _tasks = updatedTasks);
          },
        ),
      ),
    );
  }

  // ✅ FIX baris 321: Tambah async + pastikan return void eksplisit
  Future<void> _tambahAtauEditMataKuliah({MataKuliah? mataKuliah}) async {
    final result = await Navigator.push<MataKuliah>(
      context,
      MaterialPageRoute(
        builder: (_) => TambahMataKuliahPage(mataKuliah: mataKuliah),
      ),
    );

    if (result != null) {
      setState(() {
        if (mataKuliah != null) {
          final index =
          _daftarMataKuliah.indexWhere((m) => m.id == mataKuliah.id);
          if (index != -1) _daftarMataKuliah[index] = result;
        } else {
          _daftarMataKuliah.add(result);
        }
      });
    }
  }

  void _hapusMataKuliah(String id) {
    setState(() => _daftarMataKuliah.removeWhere((m) => m.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF29ABE2),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('📓', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Cari mata kuliah...',
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () => _tambahAtauEditMataKuliah(),
          ),
        ],
      ),
      body: _daftarMataKuliah.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📚', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'Belum ada mata kuliah',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tekan + untuk menambahkan',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _daftarMataKuliah.length,
        itemBuilder: (context, index) {
          final mk = _daftarMataKuliah[index];
          return _MataKuliahCard(
            mataKuliah: mk,
            onEdit: () => _tambahAtauEditMataKuliah(mataKuliah: mk),
            onHapus: () => _hapusMataKuliah(mk.id),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF29ABE2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            label: 'To do List',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            _navigateToTodoList();
          }
        },
      ),
    );
  }
}

// Card Mata Kuliah
class _MataKuliahCard extends StatelessWidget {
  final MataKuliah mataKuliah;
  final VoidCallback onEdit;
  final VoidCallback onHapus;

  const _MataKuliahCard({
    required this.mataKuliah,
    required this.onEdit,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: mataKuliah.warnaIcon.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child:
            Text(mataKuliah.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          mataKuliah.nama,
          style:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: mataKuliah.deskripsi.isNotEmpty
            ? Text(
          mataKuliah.deskripsi,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFF29ABE2)),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              onPressed: onHapus,
            ),
          ],
        ),
      ),
    );
  }
}

// Halaman Tambah/Edit Mata Kuliah
class TambahMataKuliahPage extends StatefulWidget {
  final MataKuliah? mataKuliah;
  const TambahMataKuliahPage({super.key, this.mataKuliah});

  @override
  State<TambahMataKuliahPage> createState() => _TambahMataKuliahPageState();
}

class _TambahMataKuliahPageState extends State<TambahMataKuliahPage> {
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();

  final List<Color> _warnaOptions = [
    const Color(0xFF2196F3),
    const Color(0xFFE53935),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFFFF5722),
  ];

  final List<String> _iconOptions = ['📁', '🖥️', '📊', '📐', '📝'];

  Color _selectedWarna = const Color(0xFF2196F3);
  String _selectedIcon = '📁';
  bool get _isEdit => widget.mataKuliah != null;

  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _namaController.text = widget.mataKuliah!.nama;
      _deskripsiController.text = widget.mataKuliah!.deskripsi;
      _selectedWarna = widget.mataKuliah!.warnaIcon;
      _selectedIcon = widget.mataKuliah!.icon;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _navigateToTodoList() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TodoListPage(
          initialTasks: _tasks,
          onTasksChanged: (updatedTasks) async {
            setState(() => _tasks = updatedTasks);
          },
        ),
      ),
    );
  }

  void _simpan() {
    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama mata kuliah tidak boleh kosong!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final result = MataKuliah(
      id: _isEdit
          ? widget.mataKuliah!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      nama: _namaController.text.trim(),
      warnaIcon: _selectedWarna,
      icon: _selectedIcon,
      deskripsi: _deskripsiController.text.trim(),
    );
    Navigator.pop(context, result);
  }

  Future<void> _hapus() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Mata Kuliah'),
        content:
        Text('Yakin ingin menghapus "${widget.mataKuliah!.nama}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child:
            const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF29ABE2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Cari...',
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF29ABE2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                _isEdit ? 'Edit Mata Kuliah' : 'Tambah Mata Kuliah',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nama mata kuliah',
                      style:
                      TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Basis Data',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF29ABE2),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF29ABE2),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih Warna Icon',
                      style:
                      TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _warnaOptions.map((warna) {
                      final isSelected = _selectedWarna == warna;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedWarna = warna),
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(horizontal: 5),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: warna,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                color: Colors.black, width: 2.5)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih Icon',
                      style:
                      TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _iconOptions.map((icon) {
                      final isSelected = _selectedIcon == icon;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIcon = icon),
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(horizontal: 5),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _selectedWarna.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                color: _selectedWarna, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Deskripsi (opsional)',
                      style:
                      TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deskripsiController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF29ABE2),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF29ABE2),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF29ABE2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _hapus,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                        size: 20,
                      ),
                      label: const Text(
                        'Hapus',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF29ABE2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            label: 'To do List',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            _navigateToTodoList();
          } else if (index == 0) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}