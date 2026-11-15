import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Model Catatan
class Catatan {
  final String id;
  String judul;
  String isi;
  DateTime updatedAt;
  List<String> gambarPaths;

  Catatan({
    required this.id,
    required this.judul,
    required this.isi,
    required this.updatedAt,
    this.gambarPaths = const [],
  });
}

// ─────────────────────────────────────────────
// Halaman Daftar Catatan
// ─────────────────────────────────────────────
class DaftarCatatanPage extends StatefulWidget {
  const DaftarCatatanPage({super.key});

  @override
  State<DaftarCatatanPage> createState() => _DaftarCatatanPageState();
}

class _DaftarCatatanPageState extends State<DaftarCatatanPage> {
  final List<Catatan> _daftarCatatan = [
    Catatan(
      id: '1',
      judul: 'Per 1',
      isi: 'Catatan pertemuan pertama...',
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Catatan(
      id: '2',
      judul: 'Resume Bab 2',
      isi: 'Isi resume bab dua...',
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  void _bukaForm({Catatan? catatan}) async {
    final result = await Navigator.push<Catatan>(
      context,
      MaterialPageRoute(
        builder: (_) => TambahCatatanPage(catatan: catatan),
      ),
    );

    if (result != null) {
      setState(() {
        final idx = _daftarCatatan.indexWhere((c) => c.id == result.id);
        if (idx != -1) {
          _daftarCatatan[idx] = result;
        } else {
          _daftarCatatan.insert(0, result);
        }
      });
    }
  }

  void _hapus(String id) {
    setState(() => _daftarCatatan.removeWhere((c) => c.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: _daftarCatatan.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📝', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Belum ada catatan',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tekan + untuk membuat catatan baru',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _daftarCatatan.length,
        itemBuilder: (_, i) => _CatatanCard(
          catatan: _daftarCatatan[i],
          onTap: () => _bukaForm(catatan: _daftarCatatan[i]),
          onHapus: () => _hapus(_daftarCatatan[i].id),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFF29ABE2),
    elevation: 0,
    leading: Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: const Center(
            child: Text('📓', style: TextStyle(fontSize: 18))),
      ),
    ),
    title: Container(
      height: 36,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Cari catatan...',
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () => _bukaForm(),
      ),
    ],
  );

  BottomNavigationBar _buildBottomNav() => BottomNavigationBar(
    selectedItemColor: const Color(0xFF29ABE2),
    unselectedItemColor: Colors.grey,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(
          icon: Icon(Icons.check_box_outlined), label: 'To do List'),
    ],
  );
}

// Card ringkasan catatan
class _CatatanCard extends StatelessWidget {
  final Catatan catatan;
  final VoidCallback onTap;
  final VoidCallback onHapus;

  const _CatatanCard(
      {required this.catatan,
        required this.onTap,
        required this.onHapus});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(catatan.judul,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(catatan.isi,
                      style:
                      const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: onHapus,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Halaman Tambah / Edit Catatan
// ─────────────────────────────────────────────
class TambahCatatanPage extends StatefulWidget {
  final Catatan? catatan;
  const TambahCatatanPage({super.key, this.catatan});

  @override
  State<TambahCatatanPage> createState() => _TambahCatatanPageState();
}

class _TambahCatatanPageState extends State<TambahCatatanPage> {
  final _judulController = TextEditingController();
  final _isiController = TextEditingController();
  final _isiFocusNode = FocusNode();

  // Format state
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;

  // Gambar
  final List<XFile> _gambar = [];
  final _picker = ImagePicker();

  bool get _isEdit => widget.catatan != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _judulController.text = widget.catatan!.judul;
      _isiController.text = widget.catatan!.isi;
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _isiController.dispose();
    _isiFocusNode.dispose();
    super.dispose();
  }

  // ── Toolbar aksi ──────────────────────────
  void _toggleBold() => setState(() => _isBold = !_isBold);
  void _toggleItalic() => setState(() => _isItalic = !_isItalic);
  void _toggleUnderline() => setState(() => _isUnderline = !_isUnderline);

  void _insertLink() {
    final linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan Link'),
        content: TextField(
          controller: linkController,
          decoration:
          const InputDecoration(hintText: 'https://contoh.com'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final link = linkController.text.trim();
              if (link.isNotEmpty) {
                final sel = _isiController.selection;
                final text = _isiController.text;
                final before = text.substring(0, sel.start < 0 ? 0 : sel.start);
                final after = text.substring(sel.end < 0 ? 0 : sel.end);
                _isiController.text = '$before[$link]$after';
              }
              Navigator.pop(ctx);
            },
            child: const Text('Sisipkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _pilihFoto() async {
    final picked =
    await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _gambar.add(picked));
  }

  // ── Simpan ────────────────────────────────
  void _simpan() {
    if (_judulController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul catatan tidak boleh kosong!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final result = Catatan(
      id: _isEdit
          ? widget.catatan!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      judul: _judulController.text.trim(),
      isi: _isiController.text.trim(),
      updatedAt: DateTime.now(),
      gambarPaths: _gambar.map((f) => f.path).toList(),
    );

    Navigator.pop(context, result);
  }

  // ── Hapus ─────────────────────────────────
  void _hapus() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: Text(
            'Yakin ingin menghapus "${widget.catatan!.judul}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
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

  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Header biru dengan judul halaman
          Container(
            width: double.infinity,
            color: const Color(0xFF29ABE2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isEdit ? 'Edit Catatan' : 'Tambah Catatan',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const Text('🗒️', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),

          // Body form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Judul ──
                  const Text('Judul catatan',
                      style: TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _judulController,
                    decoration: _inputDecoration('Contoh: Per 1'),
                  ),
                  const SizedBox(height: 20),

                  // ── Isi catatan ──
                  const Text('Isi catatan',
                      style: TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _isiController,
                    focusNode: _isiFocusNode,
                    maxLines: 8,
                    style: TextStyle(
                      fontWeight:
                      _isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle:
                      _isItalic ? FontStyle.italic : FontStyle.normal,
                      decoration: _isUnderline
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF29ABE2), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF29ABE2), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Toolbar Format ──
                  const Text('Toolbar Format:',
                      style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 8),
                  _buildToolbar(),
                  const SizedBox(height: 16),

                  // ── Preview gambar ──
                  if (_gambar.isNotEmpty) ...[
                    const Text('Foto:',
                        style:
                        TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _gambar.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_gambar[i].path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _gambar.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Tombol Simpan ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF29ABE2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Simpan',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  // ── Tombol Hapus (edit saja) ──
                  if (_isEdit) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _hapus,
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.grey, size: 20),
                        label: const Text('Hapus',
                            style:
                            TextStyle(color: Colors.grey, fontSize: 15)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Toolbar widget ─────────────────────────
  Widget _buildToolbar() {
    return Row(
      children: [
        _ToolbarButton(
          label: 'B',
          isActive: _isBold,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          onTap: _toggleBold,
        ),
        const SizedBox(width: 8),
        _ToolbarButton(
          label: 'I',
          isActive: _isItalic,
          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
          onTap: _toggleItalic,
        ),
        const SizedBox(width: 8),
        _ToolbarButton(
          label: 'U',
          isActive: _isUnderline,
          style: const TextStyle(
              decoration: TextDecoration.underline, fontSize: 16),
          onTap: _toggleUnderline,
        ),
        const SizedBox(width: 8),
        // Tombol Link
        GestureDetector(
          onTap: _insertLink,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF29ABE2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
                child: Text('🔗', style: TextStyle(fontSize: 18))),
          ),
        ),
        const SizedBox(width: 8),
        // Tombol Foto
        GestureDetector(
          onTap: _pilihFoto,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF29ABE2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
                child: Text('🖼️', style: TextStyle(fontSize: 18))),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:
      const BorderSide(color: Color(0xFF29ABE2), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF29ABE2), width: 2),
    ),
  );

  AppBar _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFF29ABE2),
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
    title: Container(
      height: 36,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
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
  );

  BottomNavigationBar _buildBottomNav() => BottomNavigationBar(
    selectedItemColor: const Color(0xFF29ABE2),
    unselectedItemColor: Colors.grey,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(
          icon: Icon(Icons.check_box_outlined), label: 'To do List'),
    ],
  );
}

// ── Tombol format teks ─────────────────────────
class _ToolbarButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final TextStyle style;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.label,
    required this.isActive,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF29ABE2)
              : Colors.white,
          border: Border.all(color: const Color(0xFF29ABE2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: style.copyWith(
              color: isActive ? Colors.white : const Color(0xFF29ABE2),
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Entry point ───────────────────────────────
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeadNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
        ColorScheme.fromSeed(seedColor: const Color(0xFF29ABE2)),
        useMaterial3: true,
      ),
      home: const DaftarCatatanPage(),
    );
  }
}