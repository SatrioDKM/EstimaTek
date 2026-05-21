import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../quotation/data/repositories/material_repository.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> with SingleTickerProviderStateMixin {
  final MaterialRepository _repository = MaterialRepository();
  late TabController _tabController;
  List<MaterialModel> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final list = await _repository.getMaterials();
    setState(() {
      _materials = list;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Harga (Rp / ${item.unit})',
            labelStyle: const TextStyle(color: Colors.white54),
            suffixText: 'per ${item.unit}',
            suffixStyle: const TextStyle(color: Colors.white30),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
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
                await _repository.updateMaterialPrice(item.id, newPrice);
                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Katalog Harga', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6D00),
          labelColor: const Color(0xFFFF6D00),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Aluminium'),
            Tab(text: 'Kaca'),
            Tab(text: 'Aksesoris'),
            Tab(text: 'Jasa'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList('aluminium', currFmt),
                _buildCategoryList('glass', currFmt),
                _buildCategoryList('accessories', currFmt),
                _buildCategoryList('labor', currFmt),
              ],
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
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6D00)),
              onPressed: () => _editPrice(item),
            ),
          ),
        );
      },
    );
  }
}
