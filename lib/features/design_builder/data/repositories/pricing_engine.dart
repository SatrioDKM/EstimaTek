import '../../data/models/design_models.dart';
import '../../../quotation/data/repositories/material_repository.dart';

class PricingItemBreakdown {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double subtotal;

  PricingItemBreakdown({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
  });
}

class DesignPricingBreakdown {
  final List<PricingItemBreakdown> items;
  final double grandTotal;

  DesignPricingBreakdown({
    required this.items,
    required this.grandTotal,
  });
}

class _DoorPricingItem {
  final String name;
  final double price;
  int count;
  _DoorPricingItem(this.name, this.price, this.count);
}

class PricingEngine {
  final MaterialRepository _materialRepo = MaterialRepository();

  Future<DesignPricingBreakdown> calculateDesignPrice(DesignCanvasModel design) async {
    final dbMaterials = await _materialRepo.getMaterials(includeDeleted: true);
    
    // Helper to find price by key or fallback to category default
    MaterialModel findMaterial(String category, String nameContains, double fallbackPrice) {
      try {
        return dbMaterials.firstWhere(
          (m) => m.category.toLowerCase() == category.toLowerCase() &&
                 m.name.toLowerCase().contains(nameContains.toLowerCase())
        );
      } catch (_) {
        try {
          return dbMaterials.firstWhere((m) => m.category.toLowerCase() == category.toLowerCase());
        } catch (_) {
          return MaterialModel(id: 'temp', category: category, name: nameContains, price: fallbackPrice, unit: 'pcs');
        }
      }
    }

    final brand = design.activeBrand.isNotEmpty ? design.activeBrand : 'Inkalum';
    final kusenSize = design.activeSeriesId == '4_inch' ? '4 inch' : '3 inch';
    const daunJendelaProfil = '2 Profil';
    const slidingWindowType = 'Ekonomis';

    // Core materials
    final matKusen = findMaterial('Kusen', '$brand Kusen $kusenSize', 110000);
    final matJendelaDaun = findMaterial('Daun Jendela', '$brand Jendela $daunJendelaProfil', 195000);
    final matSlidingWin = findMaterial('Sliding Set', '$brand Sliding Window $slidingWindowType', 345000);
    
    final matKaca = findMaterial('Kaca', 'Kaca Polos 5mm', 220000);
    final matJasa = findMaterial('Jasa', 'Jasa Pasang', 50000);

    double totalKusenMeters = 0;
    double totalMullionMeters = 0;
    double totalGlassSqm = 0;

    int countJendelaDaun = 0;
    double totalDaunJendelaMeters = 0;
    int countSlidingWinDaun = 0;

    final Map<String, _DoorPricingItem> doorItems = {};

    for (final frame in design.frames) {
      // 1. Kusen Outer Perimeter
      double perimeterCm = 0;
      if (frame.type == FrameType.pintu) {
        perimeterCm = frame.widthCm + (2 * frame.heightCm); // Open bottom door frame
      } else {
        perimeterCm = 2 * (frame.widthCm + frame.heightCm);
      }
      totalKusenMeters += perimeterCm / 100;

      // 2. Mullions and Panels
      _analyzePanelTree(
        frame.rootPanel,
        frame.widthCm,
        frame.heightCm,
        onMullionAdded: (lengthCm) {
          totalMullionMeters += lengthCm / 100;
        },
        onLeafAnalyzed: (leaf, w, h) {
          final areaSqm = (w / 100) * (h / 100);
          final ot = leaf.opening; // OpeningTypeNode

          // Glass area for windows
          final isWindowGlass = ot.type == 'fixed' ||
                                ot.type == 'casement' ||
                                (ot.type == 'sliding' && ot.category == 'window');
          if (isWindowGlass) {
            totalGlassSqm += areaSqm;
          }

          // Count window leaves
          if (ot.type == 'casement') {
            countJendelaDaun += 1;
            totalDaunJendelaMeters += (2 * (w / 100)) + (2 * (h / 100));
          } else if (ot.type == 'sliding' && ot.category == 'window') {
            countSlidingWinDaun += 1;
          }

          // Doors Classification (Standar vs Besar)
          final isStd = w <= 100.0 && h <= 210.0;
          final sizeClass = isStd ? 'Standar' : 'Besar';

          if (ot.type == 'swing' && ot.category == 'door') {
            final matLabel = ot.material == 'acp'
                ? 'ACP'
                : ot.material == 'panel'
                    ? 'Panel'
                    : 'Kaca';
            final leafType = ot.leafCount >= 2 ? 'Double' : 'Single';
            final doorTypeKey = 'Pintu $matLabel $leafType';
            final doorMatName = '$brand $doorTypeKey $sizeClass';
            final doorMat = findMaterial('Daun Pintu', doorMatName, 1600000);
            doorItems.putIfAbsent(doorMatName, () => _DoorPricingItem(doorMat.name, doorMat.price, 0)).count++;
          } else if (ot.type == 'folding' && ot.category == 'door') {
            final leafCount = ot.leafCount.clamp(2, 6);
            final foldMatName = '$brand Pintu Lipat per Daun';
            final foldMat = findMaterial('Daun Pintu', foldMatName, 1600000);
            doorItems.putIfAbsent(foldMatName, () => _DoorPricingItem(foldMat.name, foldMat.price, 0)).count += leafCount;
          } else if (ot.type == 'sliding' && ot.category == 'door') {
            final leafCount = ot.leafCount.clamp(2, 6);
            final slideMatName = '$brand Pintu Geser per Daun';
            final slideMat = findMaterial('Daun Pintu', slideMatName, 1600000);
            doorItems.putIfAbsent(slideMatName, () => _DoorPricingItem(slideMat.name, slideMat.price, 0)).count += leafCount;
          }
        }
      );
    }

    final breakdownItems = <PricingItemBreakdown>[];

    // 1. Kusen (Aluminium)
    final double totAluminiumMeters = totalKusenMeters + totalMullionMeters;
    if (totAluminiumMeters > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: '${matKusen.name} (Kusen & Mullion)',
        quantity: totAluminiumMeters,
        unit: 'm',
        unitPrice: matKusen.price,
        subtotal: totAluminiumMeters * matKusen.price,
      ));
    }

    // 2. Daun Jendela (Casement)
    if (totalDaunJendelaMeters > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: '${matJendelaDaun.name} (Daun Casement)',
        quantity: totalDaunJendelaMeters,
        unit: 'm1',
        unitPrice: matJendelaDaun.price,
        subtotal: totalDaunJendelaMeters * matJendelaDaun.price,
      ));
    }

    // 3. Daun Sliding Window
    if (countSlidingWinDaun > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: '${matSlidingWin.name} (Daun Sliding Window)',
        quantity: countSlidingWinDaun.toDouble(),
        unit: 'unit',
        unitPrice: matSlidingWin.price,
        subtotal: countSlidingWinDaun * matSlidingWin.price,
      ));
    }

    // 4. Daun Pintu (Swing/Sliding/Folding)
    for (final entry in doorItems.entries) {
      final item = entry.value;
      breakdownItems.add(PricingItemBreakdown(
        name: item.name,
        quantity: item.count.toDouble(),
        unit: 'unit',
        unitPrice: item.price,
        subtotal: item.count * item.price,
      ));
    }

    // 5. Glass (Kaca Polos)
    if (totalGlassSqm > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matKaca.name,
        quantity: totalGlassSqm,
        unit: 'm2',
        unitPrice: matKaca.price,
        subtotal: totalGlassSqm * matKaca.price,
      ));
    }

    // 6. Labor (Jasa Pasang)
    final double totalAreaSqm = design.frames.fold(0.0, (sum, f) => sum + (f.widthCm / 100 * f.heightCm / 100));
    if (totalAreaSqm > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matJasa.name,
        quantity: totalAreaSqm,
        unit: 'm2',
        unitPrice: matJasa.price,
        subtotal: totalAreaSqm * matJasa.price,
      ));
    }

    final double grandTotal = breakdownItems.fold(0.0, (sum, item) => sum + item.subtotal);

    return DesignPricingBreakdown(
      items: breakdownItems,
      grandTotal: grandTotal,
    );
  }

  void _analyzePanelTree(
    PanelNode panel,
    double w,
    double h, {
    required Function(double) onMullionAdded,
    required Function(PanelNode, double, double) onLeafAnalyzed,
  }) {
    if (panel.isLeaf) {
      onLeafAnalyzed(panel, w, h);
      return;
    }

    final isH = panel.splitDirection == SplitDirection.horizontal;
    final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
    final count = panel.children.length;

    // Add divider lines
    if (count > 1) {
      final dividers = count - 1;
      final dividerLength = isH ? h : w; // vertical splits add vertical lines (h), horizontal splits add horizontal lines (w)
      onMullionAdded(dividers * dividerLength);
    }

    for (int i = 0; i < count; i++) {
      final flex = panel.childFlex.length > i ? panel.childFlex[i] : 1.0;
      final ratio = totalFlex > 0 ? flex / totalFlex : 1.0 / count;

      if (isH) {
        _analyzePanelTree(panel.children[i], w * ratio, h, onMullionAdded: onMullionAdded, onLeafAnalyzed: onLeafAnalyzed);
      } else {
        _analyzePanelTree(panel.children[i], w, h * ratio, onMullionAdded: onMullionAdded, onLeafAnalyzed: onLeafAnalyzed);
      }
    }
  }
}
