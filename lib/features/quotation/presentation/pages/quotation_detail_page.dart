import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../data/models/quotation_model.dart';
import '../../data/repositories/quotation_repository.dart';
import '../../../design_builder/data/models/design_models.dart';
import '../../../design_builder/presentation/pages/design_builder_page.dart';
import '../../../design_builder/presentation/pages/design_canvas.dart';
import '../../../design_builder/data/repositories/pricing_engine.dart';
import '../../../pdf/presentation/pdf_generator.dart';

class QuotationDetailPage extends StatefulWidget {
  final QuotationModel quotation;

  const QuotationDetailPage({super.key, required this.quotation});

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  final QuotationRepository _repository = QuotationRepository();
  final PricingEngine _pricingEngine = PricingEngine();
  
  late QuotationModel _quotation;
  List<QuotationItemModel> _items = [];
  bool _isLoading = true;
  final Map<String, DesignPricingBreakdown> _breakdowns = {};
  final Map<String, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _quotation = widget.quotation;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await _repository.getQuotationItems(_quotation.id);
    
    // Fetch breakdown for all items
    _breakdowns.clear();
    for (final item in items) {
      try {
        final project = DesignCanvasModel.fromJson(item.designJson);
        final breakdown = await _pricingEngine.calculateDesignPrice(project);
        _breakdowns[item.id] = breakdown;
      } catch (e) {
        // ignore
      }
    }

    final quotations = await _repository.getQuotations();
    final updatedQuote = quotations.firstWhere(
        (q) => q.id == _quotation.id,
        orElse: () => _quotation);

    setState(() {
      _items = items;
      _quotation = updatedQuote;
      _isLoading = false;
    });
  }

  Future<void> _adjustPrice(QuotationItemModel item, double adjustedPrice) async {
    // Update item total in database
    await _repository.updateQuotationItemTotal(item.id, adjustedPrice);
    
    // Recalculate quotation grand total
    final updatedItems = await _repository.getQuotationItems(_quotation.id);
    double newGrandTotal = updatedItems.fold(0.0, (sum, i) => sum + i.itemTotal);
    await _repository.updateQuotationGrandTotal(_quotation.id, newGrandTotal);

    _loadItems();
  }

  void _showAdjustDialog(QuotationItemModel item, DesignPricingBreakdown? breakdown, NumberFormat currencyFormatter) {
    final defaultPrice = breakdown?.grandTotal ?? item.itemTotal;
    final controller = TextEditingController(text: item.itemTotal.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Sesuaikan Harga Item',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (breakdown != null) ...[
              Text(
                'Estimasi CAD: ${currencyFormatter.format(defaultPrice)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Harga Akhir (Rp)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '*Masukkan harga nego/final untuk item desain ini.',
              style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                Navigator.pop(context);
                _adjustPrice(item, newPrice);
              }
            },
            child: const Text('SIMPAN', style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Hapus Desain?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Desain terpilih akan dihapus permanen dari quotation ini.', style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('HAPUS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteQuotationItem(id, _quotation.id);
      
      // Recalculate quotation grand total
      final updatedItems = await _repository.getQuotationItems(_quotation.id);
      double newGrandTotal = updatedItems.fold(0.0, (sum, i) => sum + i.itemTotal);
      await _repository.updateQuotationGrandTotal(_quotation.id, newGrandTotal);

      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: Text(_quotation.customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Generate PDF',
            onPressed: () async {
              if (_items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Tambahkan item terlebih dahulu.')),
                );
                return;
              }
              final pdfBytes = await PdfGenerator.generateQuotationPdf(
                  _quotation, _items);
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdfBytes,
                name: 'Penawaran_${_quotation.customerName}.pdf',
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Customer info header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(_quotation.customerPhone,
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_quotation.projectAddress,
                                    style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                            Text(
                              currencyFormatter.format(_quotation.grandTotal),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4CAF50),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Item header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'DESAIN (${_items.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Items list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _items.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.architecture_rounded,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada desain.\nTap + untuk mulai menggambar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _items[index];
                              return _buildItemCard(
                                  item, index, currencyFormatter);
                            },
                            childCount: _items.length,
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DesignBuilderPage(quotationId: _quotation.id),
            ),
          );
          if (result == true) {
            _loadItems();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Desain'),
        backgroundColor: const Color(0xFFFF6D00),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildItemCard(
      QuotationItemModel item, int index, NumberFormat formatter) {
    DesignCanvasModel? project;
    try {
      project = DesignCanvasModel.fromJson(item.designJson);
    } catch (e) {
      // ignore
    }

    final isExpanded = _expandedItems[item.id] ?? false;
    final breakdown = _breakdowns[item.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isExpanded ? 0 : 12),
              bottomRight: Radius.circular(isExpanded ? 0 : 12),
            ),
            onTap: () {
              setState(() {
                _expandedItems[item.id] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: project != null
                        ? DesignCanvas(project: project)
                        : const Icon(Icons.window_rounded, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Item #${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (project != null) ...[
                          const SizedBox(height: 4),
                          Text('${project.frames.length} frame  •  ${project.totalPanels} panel',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          if (project.frames.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              project.frames.first.rootPanel.allLeaves.map((l) => l.opening.shortLabel).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatter.format(item.itemTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF4CAF50), fontFamily: 'monospace')),
                      Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.grey, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.black12),
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFFBFBF9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BREAKDOWN MATERIAL', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2
                  )),
                  const SizedBox(height: 8),
                  if (breakdown != null) ...[
                    ...breakdown.items.map((bItem) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${bItem.name} (${bItem.quantity.toStringAsFixed(1)} ${bItem.unit})',
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ),
                          Text(
                            formatter.format(bItem.subtotal),
                            style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    )),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total CAD Terhitung', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(formatter.format(breakdown.grandTotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ],
                    ),
                    if (item.itemTotal != breakdown.grandTotal) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Harga Penyesuaian (Nego)', style: TextStyle(fontSize: 11, color: Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
                          Text(formatter.format(item.itemTotal), style: const TextStyle(fontSize: 11, color: Color(0xFFFF6D00), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ] else ...[
                    const Text('Material breakdown tidak tersedia.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _deleteItem(item.id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DesignBuilderPage(
                                quotationId: _quotation.id,
                                existingItem: item,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadItems();
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Gambar', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAdjustDialog(item, breakdown, formatter),
                        icon: const Icon(Icons.settings_outlined, size: 16, color: Colors.white),
                        label: const Text('Adjust Harga', style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6D00),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
