import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../quotation/data/repositories/material_repository.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> with SingleTickerProviderStateMixin {
  final MaterialRepository _repository = MaterialRepository();
  TabController? _tabController;
  List<String> _categories = [];
  List<MaterialModel> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final list = await _repository.getMaterials();
    final cats = list.map((m) => m.category).toSet().toList();
    if (cats.isEmpty) cats.add('Kusen');
    
    // Sort categories based on predefined order
    final predefinedOrder = [
      'Kusen', 'Daun Pintu', 'Daun Jendela', 'Sliding Door', 'Sliding Set', 'Sliding Door / Window set jumbo & ekonomis', 'Kaca', 'Aksesoris', 'Jasa'
    ];
    cats.sort((a, b) {
      int idxA = predefinedOrder.indexOf(a);
      int idxB = predefinedOrder.indexOf(b);
      if (idxA == -1 && idxB == -1) return a.compareTo(b);
      if (idxA == -1) return 1;
      if (idxB == -1) return -1;
      return idxA.compareTo(idxB);
    });

    setState(() {
      _materials = list;
      _categories = cats;
      if (_tabController == null || _tabController!.length != _categories.length) {
        _tabController?.dispose();
        _tabController = TabController(length: _categories.length, vsync: this);
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<MaterialModel> _getCategoryItems(String category) {
    return _materials.where((m) => m.category.toLowerCase() == category.toLowerCase()).toList();
  }

  void _editPrice(MaterialModel item) {
    final controller = TextEditingController(text: item.price.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Edit Harga: ${item.name}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.black87, fontFamily: 'monospace'),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Harga (Rp / ${item.unit})',
            labelStyle: const TextStyle(color: Colors.black54),
            hintText: 'Masukkan harga baru',
            hintStyle: const TextStyle(color: Colors.black38),
            suffixText: 'per ${item.unit}',
            suffixStyle: const TextStyle(color: Colors.black45),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                final nav = Navigator.of(context);
                await _repository.updateMaterialPrice(item.id, newPrice);
                if (!mounted) return;
                nav.pop();
                _loadMaterials();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Harga tidak valid.')),
                );
              }
            },
            child: const Text('SIMPAN', style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String selectedCategory = 'Kusen';
        bool isCustomCategory = false;
        final customCategoryController = TextEditingController();
        String selectedUnit = 'm1';
        final nameController = TextEditingController();
        final priceController = TextEditingController();

        final predefinedCategories = [
          'Kusen', 'Daun Pintu', 'Daun Jendela', 'Sliding Set', 'Kaca', 'Aksesoris', 'Jasa', '+ Tulis Kategori Kustom'
        ];

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text(
                'Tambah Katalog Baru',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: predefinedCategories.contains(selectedCategory) ? selectedCategory : '+ Tulis Kategori Kustom',
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        labelStyle: TextStyle(color: Colors.black54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: predefinedCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.black87)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateModal(() {
                            if (val == '+ Tulis Kategori Kustom') {
                              isCustomCategory = true;
                              selectedCategory = customCategoryController.text;
                            } else {
                              isCustomCategory = false;
                              selectedCategory = val;
                            }
                          });
                        }
                      },
                    ),
                    if (isCustomCategory) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customCategoryController,
                        style: const TextStyle(color: Colors.black87),
                        onChanged: (val) {
                          selectedCategory = val;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Kategori Kustom',
                          labelStyle: TextStyle(color: Colors.black54),
                          hintText: 'Masukkan nama kategori baru',
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Nama / Merk',
                        labelStyle: TextStyle(color: Colors.black54),
                        hintText: 'Masukkan nama item atau merk',
                        hintStyle: TextStyle(color: Colors.black38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black87, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        labelText: 'Harga (Rp)',
                        labelStyle: TextStyle(color: Colors.black54),
                        hintText: 'Contoh: 150000',
                        hintStyle: TextStyle(color: Colors.black38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        labelStyle: TextStyle(color: Colors.black54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'm1', child: Text('m1 (Meter Lari)', style: TextStyle(color: Colors.black87))),
                        DropdownMenuItem(value: 'm2', child: Text('m² (Meter Persegi)', style: TextStyle(color: Colors.black87))),
                        DropdownMenuItem(value: 'unit', child: Text('unit (Per Unit)', style: TextStyle(color: Colors.black87))),
                        DropdownMenuItem(value: 'set', child: Text('set (Per Set)', style: TextStyle(color: Colors.black87))),
                        DropdownMenuItem(value: 'psg', child: Text('psg (Sepasang)', style: TextStyle(color: Colors.black87))),
                        DropdownMenuItem(value: 'pcs', child: Text('pcs (Keping/Buah)', style: TextStyle(color: Colors.black87))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateModal(() {
                            selectedUnit = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BATAL', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final priceVal = double.tryParse(priceController.text);
                    if (isCustomCategory) {
                      selectedCategory = customCategoryController.text.trim();
                    }
                    if (selectedCategory.isEmpty || selectedCategory == '+ Tulis Kategori Kustom') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kategori tidak boleh kosong.')),
                      );
                      return;
                    }
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama item tidak boleh kosong.')),
                      );
                      return;
                    }
                    if (priceVal == null || priceVal < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Harga tidak valid.')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    final newMaterial = MaterialModel(
                      id: const Uuid().v4(),
                      category: selectedCategory,
                      name: name,
                      price: priceVal,
                      unit: selectedUnit,
                    );

                    await _repository.insertMaterial(newMaterial);
                    if (!mounted) return;
                    nav.pop();
                    _loadMaterials();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Katalog baru berhasil ditambahkan')),
                    );
                  },
                  child: const Text('SIMPAN', style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(MaterialModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Hapus Item Katalog?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${item.name}" dari katalog?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              await _repository.deleteMaterial(item.id);
              if (!mounted) return;
              nav.pop();
              _loadMaterials();
              messenger.showSnackBar(
                const SnackBar(content: Text('Item katalog berhasil dihapus')),
              );
            },
            child: const Text('HAPUS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Katalog Harga', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: _tabController == null ? null : TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6D00),
          labelColor: const Color(0xFFFF6D00),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: _isLoading || _tabController == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00)))
          : TabBarView(
              controller: _tabController,
              children: _categories.map((c) => _buildCategoryList(c, currFmt)).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMaterialDialog,
        backgroundColor: const Color(0xFFFF6D00),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoryList(String category, NumberFormat currFmt) {
    final items = _getCategoryItems(category);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data untuk kategori ini.',
          style: TextStyle(color: Colors.white.withAlpha(80)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${currFmt.format(item.price)} / ${item.unit}',
              style: const TextStyle(color: Color(0xFF4CAF50), fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6D00)),
                  onPressed: () => _editPrice(item),
                  tooltip: 'Edit Harga',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(item),
                  tooltip: 'Hapus Item',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
