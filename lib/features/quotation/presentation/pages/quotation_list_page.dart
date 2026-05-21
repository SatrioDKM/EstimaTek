import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/quotation_model.dart';
import '../../data/repositories/quotation_repository.dart';
import 'create_quotation_page.dart';
import 'quotation_detail_page.dart';

class QuotationListPage extends StatefulWidget {
  const QuotationListPage({super.key});

  @override
  State<QuotationListPage> createState() => _QuotationListPageState();
}

class _QuotationListPageState extends State<QuotationListPage> {
  final QuotationRepository _repository = QuotationRepository();
  List<QuotationModel> _quotations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    final quotations = await _repository.getQuotations();
    setState(() {
      _quotations = quotations;
      _isLoading = false;
    });
  }

  Future<void> _confirmDelete(QuotationModel quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Hapus Penawaran?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus penawaran untuk "${quote.customerName}"? Data ini akan dihapus permanen.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteQuotation(quote.id);
      _loadQuotations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penawaran berhasil dihapus')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final filteredQuotations = _quotations.where((quote) {
      final nameMatches = quote.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final addressMatches = quote.projectAddress.toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatches || addressMatches;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Daftar Penawaran', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E1E1E),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari customer atau alamat...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white30),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white30),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFF6D00), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00)))
                : filteredQuotations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.request_quote_outlined, size: 80, color: Colors.white.withAlpha(50)),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'Belum ada penawaran.' : 'Tidak ditemukan kecocokan.',
                              style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredQuotations.length,
                        itemBuilder: (context, index) {
                          final quote = filteredQuotations[index];
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                quote.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.white30),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          quote.projectAddress,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(quote.createdAt),
                                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Total', style: TextStyle(fontSize: 10, color: Colors.white30)),
                                      Text(
                                        currencyFormatter.format(quote.grandTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4CAF50),
                                          fontSize: 14,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () => _confirmDelete(quote),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QuotationDetailPage(quotation: quote),
                                  ),
                                );
                                _loadQuotations(); // Refresh after return
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateQuotationPage()),
          );
          if (result == true) {
            _loadQuotations();
          }
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Buat Penawaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFFF6D00),
      ),
    );
  }
}
