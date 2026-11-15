import 'package:flutter/material.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class MataKuliah {
  String nama;
  Color warna;
  IconData icon;
  String deskripsi;

  MataKuliah({
    required this.nama,
    required this.warna,
    required this.icon,
    this.deskripsi = '',
  });
}

// ─── Halaman Tambah Mata Kuliah ───────────────────────────────────────────────

class TambahMataKuliahScreen extends StatefulWidget {
  const TambahMataKuliahScreen({super.key});

  @override
  State<TambahMataKuliahScreen> createState() => _TambahMataKuliahScreenState();
}

class _TambahMataKuliahScreenState extends State<TambahMataKuliahScreen> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

  // Pilihan warna
  final List<Color> _warnaList = [
    const Color(0xFF2196F3), // biru
    const Color(0xFFE53935), // merah
    const Color(0xFF43A047), // hijau
    const Color(0xFFFFB300), // kuning
    const Color(0xFF8E24AA), // ungu
    const Color(0xFFFF7043), // oranye
  ];
  Color _selectedWarna = const Color(0xFF2196F3);

  // Pilihan icon
  final List<IconData> _iconList = [
    Icons.folder,
    Icons.menu_book,
    Icons.computer,
    Icons.science,
    Icons.calculate,
  ];
  IconData _selectedIcon = Icons.folder;

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama mata kuliah tidak boleh kosong!')),
      );
      return;
    }
    final mk = MataKuliah(
      nama: _namaController.text.trim(),
      warna: _selectedWarna,
      icon: _selectedIcon,
      deskripsi: _deskripsiController.text.trim(),
    );
    Navigator.pop(context, mk);
  }

  void _hapus() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, null);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),

      // ── AppBar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFF5BB8E8),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                'Head\nNote',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5BB8E8),
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            // Tombol back
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 8),
            // Search bar
            Expanded(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TextField(
                  style: TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '',
                    suffixIcon:
                    Icon(Icons.search, color: Colors.grey, size: 18),
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.add, color: Colors.white, size: 26),
          ],
        ),
      ),

      // ── Body ──────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Sub-header biru
          Container(
            width: double.infinity,
            color: const Color(0xFF3A9FD6),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Text(
              'Tambah Mata Kuliah',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Nama Mata Kuliah ──────────────────────────────
                  const Text(
                    'Nama mata kuliah',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Basis Data',
                      hintStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: Color(0xFF5BB8E8), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: Color(0xFF3A9FD6), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Pilih Warna Icon ──────────────────────────────
                  const Text(
                    'Pilih Warna Icon',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _warnaList.map((warna) {
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
                                color: Colors.black54, width: 2.5)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Pilih Icon ────────────────────────────────────
                  const Text(
                    'Pilih Icon',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _iconList.map((iconData) {
                      final isSelected = _selectedIcon == iconData;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIcon = iconData),
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _selectedWarna.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                color: _selectedWarna, width: 2)
                                : null,
                          ),
                          child: Icon(iconData,
                              color: _selectedWarna, size: 28),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Deskripsi ─────────────────────────────────────
                  const Text(
                    'Deskripsi (opsional)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deskripsiController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF5BB8E8), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF3A9FD6), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Tombol Simpan ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BB8E8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Tombol Hapus ──────────────────────────────────
                  GestureDetector(
                    onTap: _hapus,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline,
                            color: Colors.black54, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Hapus',
                          style: TextStyle(
                              color: Colors.black54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: const Color(0xFF5BB8E8),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.checklist), label: 'To do List'),
        ],
      ),
    );
  }
}

// ─── Entry point (untuk preview mandiri) ─────────────────────────────────────

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TambahMataKuliahScreen(),
  ));
}