import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:uuid/uuid.dart';


// ─── NEW: CATALOG CLASSES ───
class ProfileItem {
  final String category; // 'Kusen', 'Daun Pintu', 'Mullion', 'Kaca', etc.
  final String profileName;
  final double thickness; // in cm (e.g. 7.62 for 3 inch)
  final double price; // price per cm

  ProfileItem({
    required this.category,
    required this.profileName,
    required this.thickness,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'profileName': profileName,
    'thickness': thickness,
    'price': price,
  };

  factory ProfileItem.fromMap(Map<String, dynamic> map) {
    return ProfileItem(
      category: map['category'] ?? '',
      profileName: map['profileName'] ?? '',
      thickness: (map['thickness'] ?? 0.0).toDouble(),
      price: (map['price'] ?? 0.0).toDouble(),
    );
  }
}

class SeriesCatalog {
  final String id;
  final String name;
  final List<ProfileItem> items;

  SeriesCatalog({
    required this.id,
    required this.name,
    required this.items,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toMap()).toList(),
  };

  factory SeriesCatalog.fromMap(Map<String, dynamic> map) {
    return SeriesCatalog(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      items: (map['items'] as List?)?.map((i) => ProfileItem.fromMap(i)).toList() ?? [],
    );
  }
}

class AluminumBrand {
  final String name;
  final List<SeriesCatalog> series;

  AluminumBrand({
    required this.name,
    required this.series,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'series': series.map((s) => s.toMap()).toList(),
  };

  factory AluminumBrand.fromMap(Map<String, dynamic> map) {
    return AluminumBrand(
      name: map['name'] ?? '',
      series: (map['series'] as List?)?.map((s) => SeriesCatalog.fromMap(s)).toList() ?? [],
    );
  }
}

enum SplitDirection { none, horizontal, vertical }

enum FrameType { jendela, pintu, sudut, lengkung }

extension FrameTypeLabel on FrameType {
  String get label {
    switch (this) {
      case FrameType.jendela: return 'Kusen Jendela';
      case FrameType.pintu: return 'Kusen Pintu';
      case FrameType.sudut: return 'Kusen Sudut';
      case FrameType.lengkung: return 'Kusen Lengkung';
    }
  }
}

// ─── NEW: OPENING TYPE NODE ───
class OpeningTypeNode {
  String category; // 'window', 'door', 'fixed'
  String type; // 'casement', 'sliding', 'swing', 'louvre', 'fixed', 'folding'
  String direction; // 'left', 'right', 'double', 'none'
  String material; // 'glass', 'acp', 'panel'
  int leafCount; // 1, 2, 3, 4

  OpeningTypeNode({
    this.category = 'fixed',
    this.type = 'fixed',
    this.direction = 'none',
    this.material = 'glass',
    this.leafCount = 1,
  });

  String get label {
    if (type == 'fixed') return 'Fixed Glass';
    if (type == 'louvre') return 'Louvre';
    final dir = direction == 'left' ? 'Kiri' : direction == 'right' ? 'Kanan' : direction == 'double' ? 'Double' : '';
    return '${type[0].toUpperCase()}${type.substring(1)} $dir ($leafCount Daun) - $material';
  }

  String get shortLabel {
    if (type == 'fixed') return 'FX';
    if (type == 'louvre') return 'LV';
    if (type == 'casement') return direction == 'left' ? 'CS-L' : direction == 'right' ? 'CS-R' : 'CS';
    if (type == 'sliding') return direction == 'double' ? 'SD-Dbl' : 'SD-${direction[0].toUpperCase()}';
    if (type == 'swing') return direction == 'double' ? 'SW-Dbl' : 'SW-${direction[0].toUpperCase()}';
    if (type == 'folding') return 'FD-$leafCount';
    return 'OP';
  }

  bool get isDoor => category == 'door';

  Map<String, dynamic> toMap() => {
    'category': category,
    'type': type,
    'direction': direction,
    'material': material,
    'leafCount': leafCount,
  };

  factory OpeningTypeNode.fromMap(Map<String, dynamic> map) {
    return OpeningTypeNode(
      category: map['category'] ?? 'fixed',
      type: map['type'] ?? 'fixed',
      direction: map['direction'] ?? 'none',
      material: map['material'] ?? 'glass',
      leafCount: map['leafCount'] ?? 1,
    );
  }
}

// ─── NEW: MULLION NODE ───
class MullionNode {
  String id;
  double thicknessCm; 
  String profileType;
  
  MullionNode({
    String? id,
    this.thicknessCm = 5.0, // Default 5 cm
    this.profileType = 'Standard',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'thicknessCm': thicknessCm,
    'profileType': profileType,
  };
  
  factory MullionNode.fromMap(Map<String, dynamic> map) {
    return MullionNode(
      id: map['id'],
      thicknessCm: (map['thicknessCm'] ?? 5.0).toDouble(),
      profileType: map['profileType'] ?? 'Standard',
    );
  }
}

// ─── DESIGN CANVAS MODEL ───
class DesignCanvasModel {
  List<FrameNode> frames;
  String activeBrand;
  String activeSeriesId;

  DesignCanvasModel({
    List<FrameNode>? frames,
    this.activeBrand = 'Inkalum',
    this.activeSeriesId = '3_inch',
  }) : frames = frames ?? [];

  double getActiveKusenThickness(List<AluminumBrand> catalog) {
    try {
      final brand = catalog.firstWhere((b) => b.name == activeBrand);
      final series = brand.series.firstWhere((s) => s.id == activeSeriesId);
      final kusen = series.items.firstWhere((item) => item.category.toLowerCase() == 'kusen');
      return kusen.thickness;
    } catch (_) {
      return activeSeriesId == '4_inch' ? 10.16 : 7.62;
    }
  }

  double getActiveMullionThickness(List<AluminumBrand> catalog) {
    try {
      final brand = catalog.firstWhere((b) => b.name == activeBrand);
      final series = brand.series.firstWhere((s) => s.id == activeSeriesId);
      final mullion = series.items.firstWhere((item) => item.category.toLowerCase() == 'mullion');
      return mullion.thickness;
    } catch (_) {
      return activeSeriesId == '4_inch' ? 10.16 : 7.62;
    }
  }

  double get totalPrice => frames.fold(0.0, (sum, f) => sum + f.price);
  int get totalPanels => frames.fold(0, (sum, f) => sum + f.rootPanel.leafCount);

  Map<String, dynamic> toMap() => {
    'version': 6,
    'activeBrand': activeBrand,
    'activeSeriesId': activeSeriesId,
    'frames': frames.map((f) => f.toMap()).toList(),
  };

  factory DesignCanvasModel.fromMap(Map<String, dynamic> map) {
    return DesignCanvasModel(
      frames: (map['frames'] as List?)
          ?.map((f) => FrameNode.fromMap(f)).toList() ?? [],
      activeBrand: map['activeBrand'] ?? map['brand'] ?? 'Inkalum',
      activeSeriesId: map['activeSeriesId'] ?? (map['kusenSize'] == '4 inch' ? '4_inch' : '3_inch'),
    );
  }

  String toJson() => json.encode(toMap());

  factory DesignCanvasModel.fromJson(String source) {
    final decoded = json.decode(source);
    if (decoded is Map && decoded.containsKey('version')) {
      return DesignCanvasModel.fromMap(Map<String, dynamic>.from(decoded));
    }
    
    // Legacy fallback
    return DesignCanvasModel();
  }
}

class PanelLayoutInfo {
  final PanelNode panel;
  final Rect rect;
  final double widthCm;
  final double heightCm;

  PanelLayoutInfo({
    required this.panel,
    required this.rect,
    required this.widthCm,
    required this.heightCm,
  });
}

// ─── FRAME NODE ───
class FrameNode {
  String id;
  double x, y; // position on canvas (logical pixels)
  double widthCm, heightCm; // physical dimensions in cm
  FrameType type;
  int profileCount; // 1 for single profile, 2 for double profile, etc.
  PanelNode rootPanel;
  String label;

  FrameNode({
    String? id,
    this.x = 100,
    this.y = 100,
    this.widthCm = 120,
    this.heightCm = 150,
    this.type = FrameType.jendela,
    this.profileCount = 1,
    PanelNode? rootPanel,
    this.label = '',
  }) : id = id ?? const Uuid().v4(),
       rootPanel = rootPanel ?? PanelNode();

  static const double pxPerCm = 4.0;

  double get renderWidth => widthCm * pxPerCm;
  double get renderHeight => heightCm * pxPerCm;

  List<PanelLayoutInfo> getPanelLayouts({
    double frameThickness = 0.5,
    double mullionThickness = 5.0,
  }) {
    final List<PanelLayoutInfo> layouts = [];
    final fThickness = frameThickness * FrameNode.pxPerCm * 0.5;
    final N = 1;
    final double leftInset = (2 * N - 1) * fThickness;
    final double rightInset = (2 * N - 1) * fThickness;
    final double topInset = (type == FrameType.lengkung) ? leftInset : (2 * N - 1) * fThickness;
    final double bottomInset = (type == FrameType.pintu) ? N * fThickness : (2 * N - 1) * fThickness;

    final innerRect = Rect.fromLTRB(
      leftInset,
      topInset,
      renderWidth - rightInset,
      renderHeight - bottomInset,
    );





    void traverse(PanelNode node, Rect rect, double wCm, double hCm) {
      layouts.add(PanelLayoutInfo(
        panel: node,
        rect: rect,
        widthCm: wCm,
        heightCm: hCm,
      ));

      if (node.isLeaf) return;

      final isH = node.splitDirection == SplitDirection.horizontal;
      final double visualMullionThickness = mullionThickness * 0.5;
      final mThicknessPx = visualMullionThickness * FrameNode.pxPerCm;

      final totalMullionPx = node.mullions.length * mThicknessPx;
      final availablePx = (isH ? rect.width : rect.height) - totalMullionPx;

      final totalFlex = node.childFlex.fold(0.0, (a, b) => a + b);
      if (totalFlex <= 0 || availablePx <= 0) return;

      double offsetPx = isH ? rect.left : rect.top;

      for (int i = 0; i < node.children.length; i++) {
        final flex = node.childFlex.length > i ? node.childFlex[i] : 1.0;
        final childSizePx = availablePx * (flex / totalFlex);

        Rect childRect;
        double childWCm, childHCm;

        if (isH) {
          childRect = Rect.fromLTWH(offsetPx, rect.top, childSizePx, rect.height);
          childWCm = wCm * (flex / totalFlex);
          childHCm = hCm;
          offsetPx += childSizePx + mThicknessPx;
        } else {
          childRect = Rect.fromLTWH(rect.left, offsetPx, rect.width, childSizePx);
          childWCm = wCm;
          childHCm = hCm * (flex / totalFlex);
          offsetPx += childSizePx + mThicknessPx;
        }

        traverse(node.children[i], childRect, childWCm, childHCm);
      }
    }

    traverse(rootPanel, innerRect, widthCm, heightCm);
    return layouts;
  }

  // Simple pricing fallback used for default estimation
  double get price {
    return _calcPrice(rootPanel, widthCm, heightCm) * profileCount;
  }

  double _calcPrice(PanelNode panel, double wCm, double hCm) {
    if (panel.isLeaf) {
      double area = (wCm / 100) * (hCm / 100);
      double price = area * 500000;
      switch (panel.opening.type) {
        case 'fixed': break;
        case 'sliding': price += 120000 * panel.opening.leafCount; break;
        case 'casement': price += 150000; break;
        case 'swing': price += 300000 * panel.opening.leafCount; break;
        case 'folding': price += 300000 * panel.opening.leafCount; break;
        case 'louvre': price += 200000; break;
      }
      return price;
    }
    double total = 0;
    
    // Subtract mullion width
    double totalMullionWidth = panel.mullions.fold(0.0, (sum, m) => sum + m.thicknessCm);
    double availableWidth = wCm;
    double availableHeight = hCm;
    
    if (panel.splitDirection == SplitDirection.horizontal) {
      availableWidth -= totalMullionWidth;
    } else {
      availableHeight -= totalMullionWidth;
    }
    
    final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
    for (int i = 0; i < panel.children.length; i++) {
      final ratio = totalFlex > 0
          ? (panel.childFlex.length > i ? panel.childFlex[i] : 1.0) / totalFlex
          : 1.0 / panel.children.length;
      if (panel.splitDirection == SplitDirection.horizontal) {
        total += _calcPrice(panel.children[i], availableWidth * ratio, availableHeight);
      } else {
        total += _calcPrice(panel.children[i], availableWidth, availableHeight * ratio);
      }
    }
    
    // Add mullion prices
    for (final _ in panel.mullions) {
       total += (panel.splitDirection == SplitDirection.horizontal ? hCm : wCm) * 1500; // rough price per cm for mullion
    }
    
    return total;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'x': x, 'y': y,
    'widthCm': widthCm, 'heightCm': heightCm,
    'type': type.name,
    'profileCount': profileCount,
    'rootPanel': rootPanel.toMap(),
    'label': label,
  };

  factory FrameNode.fromMap(Map<String, dynamic> map) {
    return FrameNode(
      id: map['id'],
      x: (map['x'] ?? 100).toDouble(),
      y: (map['y'] ?? 100).toDouble(),
      widthCm: (map['widthCm'] ?? 120).toDouble(),
      heightCm: (map['heightCm'] ?? 150).toDouble(),
      type: FrameType.values.firstWhere(
        (e) => e.name == map['type'], orElse: () => FrameType.jendela),
      profileCount: map['profileCount'] ?? 1,
      rootPanel: PanelNode.fromMap(map['rootPanel']),
      label: map['label'] ?? '',
    );
  }
}

// ─── PANEL NODE ───
class PanelNode {
  String id;
  double width; // logical width fallback
  double height;
  SplitDirection splitDirection;
  List<PanelNode> children;
  List<MullionNode> mullions; // NEW: Real Mullion objects
  List<double> childFlex;
  OpeningTypeNode opening;
  String label;

  PanelNode({
    String? id,
    this.width = 100,
    this.height = 150,
    this.splitDirection = SplitDirection.none,
    List<PanelNode>? children,
    List<MullionNode>? mullions,
    OpeningTypeNode? opening,
    this.label = '',
    List<double>? childFlex,
  }) : id = id ?? const Uuid().v4(),
       children = children ?? [],
       mullions = mullions ?? [],
       childFlex = childFlex ?? [],
       opening = opening ?? OpeningTypeNode();

  bool get isLeaf => children.isEmpty;

  bool hasVerticalSplit() {
    if (splitDirection == SplitDirection.vertical) return true;
    for (final child in children) {
      if (child.hasVerticalSplit()) return true;
    }
    return false;
  }

  bool hasHorizontalSplit() {
    if (splitDirection == SplitDirection.horizontal) return true;
    for (final child in children) {
      if (child.hasHorizontalSplit()) return true;
    }
    return false;
  }

  int get leafCount {
    if (isLeaf) return 1;
    return children.fold(0, (sum, child) => sum + child.leafCount);
  }

  List<PanelNode> get allLeaves {
    if (isLeaf) return [this];
    return children.expand((c) => c.allLeaves).toList();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'splitDirection': splitDirection.name,
    'children': children.map((c) => c.toMap()).toList(),
    'mullions': mullions.map((m) => m.toMap()).toList(),
    'opening': opening.toMap(),
    'label': label,
    'childFlex': childFlex,
    'width': width,
    'height': height,
  };

  factory PanelNode.fromMap(Map<String, dynamic> map) {
    return PanelNode(
      id: map['id'],
      width: (map['width'] ?? 100).toDouble(),
      height: (map['height'] ?? 150).toDouble(),
      splitDirection: SplitDirection.values.firstWhere(
        (e) => e.name == map['splitDirection'], orElse: () => SplitDirection.none),
      children: (map['children'] as List?)
          ?.map((c) => PanelNode.fromMap(c)).toList() ?? [],
      mullions: (map['mullions'] as List?)
          ?.map((m) => MullionNode.fromMap(m)).toList() ?? [],
      opening: map.containsKey('opening') 
          ? OpeningTypeNode.fromMap(map['opening']) 
          : OpeningTypeNode(),
      label: map['label'] ?? '',
      childFlex: (map['childFlex'] as List?)
          ?.map((e) => (e as num).toDouble()).toList() ?? [],
    );
  }

  String toJson() => json.encode(toMap());
  factory PanelNode.fromJson(String source) => PanelNode.fromMap(json.decode(source));

  void split(SplitDirection direction, [double ratio = 0.5]) {
    if (direction == SplitDirection.none) return;
    splitDirection = direction;
    children = [
      PanelNode(opening: OpeningTypeNode()),
      PanelNode(opening: OpeningTypeNode()),
    ];
    mullions = [MullionNode()]; // Add a mullion between the 2 panels
    childFlex = [ratio, 1.0 - ratio];
  }

  void splitEqually(SplitDirection direction, int parts) {
    if (direction == SplitDirection.none || parts < 2) return;
    splitDirection = direction;
    children = List.generate(parts, (_) => PanelNode(opening: OpeningTypeNode()));
    mullions = List.generate(parts - 1, (_) => MullionNode());
    childFlex = List.generate(parts, (_) => 1.0 / parts);
  }

  void merge() {
    splitDirection = SplitDirection.none;
    children = [];
    mullions = [];
    childFlex = [];
  }

  PanelNode? findById(String targetId) {
    if (id == targetId) return this;
    for (final child in children) {
      final result = child.findById(targetId);
      if (result != null) return result;
    }
    return null;
  }

  PanelNode? findParent(String targetId) {
    for (final child in children) {
      if (child.id == targetId) return this;
      final result = child.findParent(targetId);
      if (result != null) return result;
    }
    return null;
  }
}

enum ObjectType {
  frame,
  mullion,
  panel,
  sliding,
  casement,
  swingDoor,
  fixedGlass,
  louvre
}

class DesignObject {
  String id;
  Rect bounds; // Bounding box relative to canvas coordinates
  Offset position; // Offset of bounds relative to parent/canvas
  ObjectType type;
  bool isSelected;
  bool isDragging;
  List<DesignObject> children;

  // Attributes for specific object types
  FrameType? frameType;
  OpeningTypeNode? opening;
  SplitDirection splitDirection;
  List<double> childFlex;
  String label;

  // Mullion specific details
  int? mullionIndex;
  bool? isHorizontalMullion;

  DesignObject({
    required this.id,
    required this.bounds,
    required this.position,
    required this.type,
    this.isSelected = false,
    this.isDragging = false,
    List<DesignObject>? children,
    this.frameType,
    this.opening,
    this.splitDirection = SplitDirection.none,
    List<double>? childFlex,
    this.label = '',
    this.mullionIndex,
    this.isHorizontalMullion,
  }) : children = children ?? [],
       childFlex = childFlex ?? [];
}
