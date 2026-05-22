import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../quotation/data/models/quotation_model.dart';
import '../../design_builder/data/models/design_models.dart';
import '../../design_builder/data/repositories/pricing_engine.dart';

class PdfGenerator {
  static Future<Uint8List> generateQuotationPdf(
      QuotationModel quotation, List<QuotationItemModel> items) async {
    final pdf = pw.Document();
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMMM yyyy');
    final pricingEngine = PricingEngine();

    // Resolve breakdowns upfront before starting build
    final breakdowns = <String, DesignPricingBreakdown>{};
    for (final item in items) {
      try {
        final project = DesignCanvasModel.fromJson(item.designJson);
        breakdowns[item.id] = await pricingEngine.calculateDesignPrice(project);
      } catch (e) {
        // ignore
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            _buildHeader(quotation, dateFormatter),
            pw.SizedBox(height: 20),
            _buildCustomerInfo(quotation),
            pw.SizedBox(height: 20),
            _buildItemsList(items, breakdowns, currencyFormatter),
            pw.SizedBox(height: 20),
            _buildTotal(quotation, currencyFormatter),
            pw.SizedBox(height: 40),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
      QuotationModel quotation, DateFormat dateFormatter) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PENAWARAN HARGA (QUOTATION)',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('EstimaTek Aluminium & Kaca',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Software Estimator Kusen & Kaca CAD Profesional',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Tanggal: ${dateFormatter.format(quotation.createdAt)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('No: ${quotation.id.substring(0, 8).toUpperCase()}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(QuotationModel quotation) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Kepada Yth:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text(quotation.customerName,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text(quotation.customerPhone, style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Proyek/Alamat: ${quotation.projectAddress}', style: const pw.TextStyle(fontSize: 9)),
          if (quotation.notes.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Catatan: ${quotation.notes}',
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8, color: PdfColors.grey800)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildItemsList(
      List<QuotationItemModel> items,
      Map<String, DesignPricingBreakdown> breakdowns,
      NumberFormat formatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Spesifikasi Pekerjaan:',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...List.generate(items.length, (index) {
          final item = items[index];
          DesignCanvasModel? project;
          try {
            project = DesignCanvasModel.fromJson(item.designJson);
          } catch (e) {
            // ignore
          }

          final breakdown = breakdowns[item.id];

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // CAD Vector Drawing Thumbnail
                pw.Container(
                  width: 100,
                  height: 100,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: project != null
                      ? _buildDesignCanvasDrawing(project)
                      : pw.Text('N/A', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.SizedBox(width: 12),
                
                // Details and Material Breakdown
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Item #${index + 1}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 3),
                      if (project != null) ...[
                        pw.Text('Jumlah: ${project.frames.length} Frame, ${project.totalPanels} Panel',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('Breakdown Material Utama:',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        if (breakdown != null) ...[
                          ...breakdown.items.map((b) => pw.Text(
                            '- ${b.name}: ${b.quantity.toStringAsFixed(1)} ${b.unit} @ ${formatter.format(b.unitPrice)}',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                          )),
                        ],
                      ],
                    ],
                  ),
                ),
                
                // Pricing
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(formatter.format(item.itemTotal),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black)),
                    if (breakdown != null && item.itemTotal != breakdown.grandTotal) ...[
                      pw.Text('CAD: ${formatter.format(breakdown.grandTotal)}',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, decoration: pw.TextDecoration.lineThrough)),
                      pw.Text('(Nego)',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.orange, fontWeight: pw.FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildDesignCanvasDrawing(DesignCanvasModel project) {
    if (project.frames.isEmpty) {
      return pw.Center(child: pw.Text('Empty', style: const pw.TextStyle(fontSize: 8)));
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final frame in project.frames) {
      if (frame.x < minX) minX = frame.x;
      if (frame.y < minY) minY = frame.y;
      final fx = frame.x + frame.renderWidth;
      final fy = frame.y + frame.renderHeight;
      if (fx > maxX) maxX = fx;
      if (fy > maxY) maxY = fy;
    }

    final w = (maxX - minX).clamp(100.0, 10000.0);
    final h = (maxY - minY).clamp(100.0, 10000.0);

    final maxD = max(w, h);
    final scale = 80.0 / maxD;

    return pw.Container(
      width: w * scale + 20,
      height: h * scale + 20,
      child: pw.Stack(
        children: project.frames.map<pw.Widget>((frame) {
          final rx = (frame.x - minX) * scale + 10;
          final ry = (frame.y - minY) * scale + 10;
          final rw = frame.renderWidth * scale;
          final rh = frame.renderHeight * scale;

          bool hideLeft = false;
          bool hideRight = false;
          bool hideTop = false;
          bool hideBottom = false;

          const double borderThreshold = 3.0;
          for (final other in project.frames) {
            if (other.id == frame.id) continue;
            
            final wA = frame.renderWidth;
            final hA = frame.renderHeight;
            final wB = other.renderWidth;
            final hB = other.renderHeight;
            
            // Left border touches other's right
            if ((frame.x - (other.x + wB)).abs() < borderThreshold) {
              final overlap = min(frame.y + hA, other.y + hB) - max(frame.y, other.y);
              if (overlap > 1.0) hideLeft = true;
            }
            // Right border touches other's left
            if (((frame.x + wA) - other.x).abs() < borderThreshold) {
              final overlap = min(frame.y + hA, other.y + hB) - max(frame.y, other.y);
              if (overlap > 1.0) hideRight = true;
            }
            // Top border touches other's bottom
            if ((frame.y - (other.y + hB)).abs() < borderThreshold) {
              final overlap = min(frame.x + wA, other.x + wB) - max(frame.x, other.x);
              if (overlap > 1.0) hideTop = true;
            }
            // Bottom border touches other's top
            if (((frame.y + hA) - other.y).abs() < borderThreshold) {
              final overlap = min(frame.x + wA, other.x + wB) - max(frame.x, other.x);
              if (overlap > 1.0) hideBottom = true;
            }
          }

          return pw.Positioned(
            left: rx,
            top: ry,
            child: pw.Stack(
              children: [
                pw.SizedBox(
                  width: rw,
                  height: rh,
                  child: _buildFrameDrawing(
                    frame,
                    scale,
                    hideLeft: hideLeft,
                    hideRight: hideRight,
                    hideTop: hideTop,
                    hideBottom: hideBottom,
                  ),
                ),
                if (!hideTop)
                  pw.Positioned(
                    top: -6,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Text(
                        frame.renderWidth.toStringAsFixed(0),
                        style: pw.TextStyle(fontSize: 4, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)
                      )
                    )
                  ),
                if (!hideLeft)
                  pw.Positioned(
                    top: 0,
                    bottom: 0,
                    left: -12,
                    child: pw.Center(
                      child: pw.Text(
                        frame.renderHeight.toStringAsFixed(0),
                        style: pw.TextStyle(fontSize: 4, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)
                      )
                    )
                  ),
              ]
            )
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildFrameDrawing(
    FrameNode frame,
    double scale, {
    bool hideLeft = false,
    bool hideRight = false,
    bool hideTop = false,
    bool hideBottom = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: hideLeft
              ? pw.BorderSide.none
              : const pw.BorderSide(color: PdfColors.black, width: 0.8),
          right: hideRight
              ? pw.BorderSide.none
              : const pw.BorderSide(color: PdfColors.black, width: 0.8),
          top: hideTop
              ? pw.BorderSide.none
              : const pw.BorderSide(color: PdfColors.black, width: 0.8),
          bottom: hideBottom
              ? pw.BorderSide.none
              : (frame.type == FrameType.pintu
                  ? const pw.BorderSide(color: PdfColors.grey500, width: 0.8, style: pw.BorderStyle.dashed)
                  : const pw.BorderSide(color: PdfColors.black, width: 0.8)),
        ),
      ),
      child: _buildPanelDrawing(frame.rootPanel, scale),
    );
  }

  static pw.Widget _getOpeningSvg(OpeningTypeNode type) {
    String svg = '';
    final stroke = 'stroke="rgba(0,0,0,0.5)" stroke-width="2" fill="none"';
    switch (type.type) {
      case 'fixed':
        svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><line x1="0" y1="0" x2="100" y2="100" $stroke/><line x1="100" y1="0" x2="0" y2="100" $stroke/></svg>';
        break;
      case 'casement':
        svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><path d="M 0 0 L 100 50 L 0 100" $stroke/></svg>';
        break;
      case 'sliding':
        svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><line x1="20" y1="50" x2="80" y2="50" $stroke/></svg>';
        break;
      case 'swing':
        if (type.direction == 'double') {
           svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><path d="M 0 100 A 40 80 0 0 1 50 20" $stroke/><path d="M 100 100 A 40 80 0 0 0 50 20" $stroke/></svg>';
        } else {
           svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><path d="M 0 100 A 80 80 0 0 1 80 20" $stroke/></svg>';
        }
        break;
      case 'folding':
        String lines = '';
        for (int i = 1; i < type.leafCount; i++) {
          final x = 100 * i / type.leafCount;
          lines += '<line x1="$x" y1="0" x2="$x" y2="100" $stroke/>';
        }
        svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none">$lines</svg>';
        break;
      case 'louvre':
        String lines = '';
        for (int i = 1; i < 6; i++) {
          final y = 100 * i / 6;
          lines += '<line x1="0" y1="$y" x2="100" y2="$y" $stroke/>';
        }
        svg = '<svg viewBox="0 0 100 100" preserveAspectRatio="none">$lines</svg>';
        break;
    }
    if (svg.isEmpty) return pw.SizedBox();
    return pw.SvgImage(svg: svg);
  }

  static pw.Widget _buildPanelDrawing(PanelNode panel, double scale) {
    if (panel.isLeaf) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.4),
          color: _getPanelPdfColor(panel.opening),
        ),
        child: pw.Stack(
          fit: pw.StackFit.expand,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(1),
              child: _getOpeningSvg(panel.opening)
            ),
            pw.Center(
              child: pw.Text(
                panel.opening.shortLabel,
                style: pw.TextStyle(fontSize: 3, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              ),
            ),
          ],
        ),
      );
    }

    final isH = panel.splitDirection == SplitDirection.horizontal;
    final children = panel.children.map((c) => pw.Expanded(child: _buildPanelDrawing(c, scale))).toList();

    return isH ? pw.Row(children: children) : pw.Column(children: children);
  }

  static PdfColor _getPanelPdfColor(OpeningTypeNode opening) {
    switch (opening.type) {
      case 'fixed':    return PdfColor.fromHex('#E8F4FD');
      case 'casement': return PdfColor.fromHex('#FFF8E1');
      case 'louvre':   return PdfColor.fromHex('#EFEBE9');
      case 'folding':  return PdfColor.fromHex('#F3E5F5');
      case 'sliding':
        return opening.category == 'door'
            ? PdfColor.fromHex('#E8F5E9')
            : PdfColor.fromHex('#E0F7FA');
      case 'swing':    return PdfColor.fromHex('#FCE4EC');
      default:         return PdfColor.fromHex('#F5F5F5');
    }
  }

  static pw.Widget _buildTotal(
      QuotationModel quotation, NumberFormat formatter) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('Grand Total: ',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              formatter.format(quotation.grandTotal),
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Hormat Kami,', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 48),
            pw.Text('( .................................... )', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Disetujui Oleh,', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 48),
            pw.Text('( Customer )', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
