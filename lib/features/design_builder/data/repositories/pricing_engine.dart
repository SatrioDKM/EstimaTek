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
    final dbMaterials = await _materialRepo.getMaterials();
    
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

    final brand = design.brand.isNotEmpty ? design.brand : 'Inkalum';
    final kusenSize = design.kusenSize.isNotEmpty ? design.kusenSize : '3 inch';
    final daunJendelaProfil = design.daunJendelaProfil.isNotEmpty ? design.daunJendelaProfil : '2 Profil';
    final slidingWindowType = design.slidingWindowType.isNotEmpty ? design.slidingWindowType : 'Ekonomis';

    // Core materials
    final matKusen = findMaterial('aluminium', '$brand Kusen $kusenSize', 120000);
    final matJendelaDaun = findMaterial('aluminium', '$brand Jendela $daunJendelaProfil', 450000);
    final matSlidingWin = findMaterial('aluminium', '$brand Sliding Window $slidingWindowType', 400000);
    
    final matKaca = findMaterial('glass', 'Kaca Polos 5mm', 180000);
    final matEngselCasement = findMaterial('accessories', 'Engsel Casement', 35000);
    final matRodaSliding = findMaterial('accessories', 'Roda Sliding', 45000);
    final matJasa = findMaterial('labor', 'Jasa Pasang', 50000);

    // Accessories
    final matEngselPintu = findMaterial('accessories', 'Engsel Pintu', 75000);
    final matKunciSwing = findMaterial('accessories', 'Kunci Pintu Swing', 150000);
    final matKunciSliding = findMaterial('accessories', 'Kunci Sliding', 60000);
    final matAksesorisLipat = findMaterial('accessories', 'Aksesoris Lipat', 300000);

    double totalKusenMeters = 0;
    double totalMullionMeters = 0;
    double totalGlassSqm = 0;

    int countJendelaDaun = 0;
    int countSlidingWinDaun = 0;

    int countEngselCasement = 0;
    int countRodaSliding = 0;
    int countEngselPintu = 0;
    int countKunciSwing = 0;
    int countKunciSliding = 0;
    int countAksesorisLipat = 0;

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
          final ot = leaf.openingType;

          // Glass area for windows
          final isWindowGlass = ot == OpeningType.fixed ||
                                ot == OpeningType.casement ||
                                ot == OpeningType.slidingLeftRight ||
                                ot == OpeningType.slidingUpDown;
          if (isWindowGlass) {
            totalGlassSqm += areaSqm;
          }

          // Count leaves
          if (ot == OpeningType.casement) {
            countJendelaDaun += 1;
            countEngselCasement += 1; // 1 pair
          } else if (ot == OpeningType.slidingLeftRight || ot == OpeningType.slidingUpDown) {
            countSlidingWinDaun += 1;
            countRodaSliding += 1;
            countKunciSliding += 1;
          }

          // Doors Classification (Standar vs Besar)
          // Standar: width <= 100cm AND height <= 210cm
          final isStd = w <= 100.0 && h <= 210.0;
          final sizeClass = isStd ? 'Standar' : 'Besar';

          String? doorTypeKey;
          switch (ot) {
            case OpeningType.glassSingle: doorTypeKey = 'Pintu Kaca Single'; break;
            case OpeningType.glassDouble: doorTypeKey = 'Pintu Kaca Double'; break;
            case OpeningType.acpSingle: doorTypeKey = 'Pintu ACP Single'; break;
            case OpeningType.acpDouble: doorTypeKey = 'Pintu ACP Double'; break;
            case OpeningType.panelSingle: doorTypeKey = 'Pintu Panel Single'; break;
            case OpeningType.panelDouble: doorTypeKey = 'Pintu Panel Double'; break;
            default: break;
          }

          if (doorTypeKey != null) {
            final doorMatName = '$brand $doorTypeKey $sizeClass';
            final doorMat = findMaterial('aluminium', doorMatName, 1200000);
            doorItems.putIfAbsent(doorMatName, () => _DoorPricingItem(doorMat.name, doorMat.price, 0)).count++;

            // Count door accessories
            final isDouble = doorTypeKey.contains('Double');
            countEngselPintu += isDouble ? 6 : 3;
            countKunciSwing += 1;
          } else if (ot == OpeningType.folding3 || ot == OpeningType.folding4) {
            final leafCount = ot == OpeningType.folding3 ? 3 : 4;
            final foldMatName = '$brand Pintu Lipat per Daun';
            final foldMat = findMaterial('aluminium', foldMatName, 1100000);
            doorItems.putIfAbsent(foldMatName, () => _DoorPricingItem(foldMat.name, foldMat.price, 0)).count += leafCount;

            countAksesorisLipat += 1;
          } else if (ot == OpeningType.sliding2Daun || ot == OpeningType.sliding3Daun || ot == OpeningType.sliding4Daun) {
            final leafCount = ot == OpeningType.sliding2Daun ? 2 : (ot == OpeningType.sliding3Daun ? 3 : 4);
            final slideMatName = '$brand Pintu Geser per Daun';
            final slideMat = findMaterial('aluminium', slideMatName, 900000);
            doorItems.putIfAbsent(slideMatName, () => _DoorPricingItem(slideMat.name, slideMat.price, 0)).count += leafCount;

            countRodaSliding += leafCount * 2;
            countKunciSliding += 1;
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
    if (countJendelaDaun > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: '${matJendelaDaun.name} (Daun Casement)',
        quantity: countJendelaDaun.toDouble(),
        unit: 'unit',
        unitPrice: matJendelaDaun.price,
        subtotal: countJendelaDaun * matJendelaDaun.price,
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

    // 6. Accessories
    if (countEngselCasement > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matEngselCasement.name,
        quantity: countEngselCasement.toDouble(),
        unit: 'psg',
        unitPrice: matEngselCasement.price,
        subtotal: countEngselCasement * matEngselCasement.price,
      ));
    }
    if (countRodaSliding > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matRodaSliding.name,
        quantity: countRodaSliding.toDouble(),
        unit: 'set',
        unitPrice: matRodaSliding.price,
        subtotal: countRodaSliding * matRodaSliding.price,
      ));
    }
    if (countEngselPintu > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matEngselPintu.name,
        quantity: countEngselPintu.toDouble(),
        unit: 'pcs',
        unitPrice: matEngselPintu.price,
        subtotal: countEngselPintu * matEngselPintu.price,
      ));
    }
    if (countKunciSwing > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matKunciSwing.name,
        quantity: countKunciSwing.toDouble(),
        unit: 'set',
        unitPrice: matKunciSwing.price,
        subtotal: countKunciSwing * matKunciSwing.price,
      ));
    }
    if (countKunciSliding > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matKunciSliding.name,
        quantity: countKunciSliding.toDouble(),
        unit: 'set',
        unitPrice: matKunciSliding.price,
        subtotal: countKunciSliding * matKunciSliding.price,
      ));
    }
    if (countAksesorisLipat > 0) {
      breakdownItems.add(PricingItemBreakdown(
        name: matAksesorisLipat.name,
        quantity: countAksesorisLipat.toDouble(),
        unit: 'set',
        unitPrice: matAksesorisLipat.price,
        subtotal: countAksesorisLipat * matAksesorisLipat.price,
      ));
    }

    // 7. Labor (Jasa Pasang)
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
