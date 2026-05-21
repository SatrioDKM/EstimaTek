import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:uuid/uuid.dart';

enum SplitDirection { none, horizontal, vertical }

enum FrameType { jendela, pintu, sudut, lengkung }

enum OpeningType {
  fixed,
  casement,
  glassSingle,
  glassDouble,
  acpSingle,
  acpDouble,
  panelSingle,
  panelDouble,
  folding3,
  folding4,
  slidingLeftRight,
  slidingUpDown,
  sliding2Daun,
  sliding3Daun,
  sliding4Daun,
  louvre
}

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

extension OpeningTypeLabel on OpeningType {
  String get label {
    switch (this) {
      case OpeningType.fixed: return 'Fixed Glass';
      case OpeningType.casement: return 'Casement';
      case OpeningType.glassSingle: return 'Pintu Kaca Single';
      case OpeningType.glassDouble: return 'Pintu Kaca Double';
      case OpeningType.acpSingle: return 'Pintu ACP Single';
      case OpeningType.acpDouble: return 'Pintu ACP Double';
      case OpeningType.panelSingle: return 'Pintu Panel Single';
      case OpeningType.panelDouble: return 'Pintu Panel Double';
      case OpeningType.folding3: return 'Lipat 3 Daun';
      case OpeningType.folding4: return 'Lipat 4 Daun';
      case OpeningType.slidingLeftRight: return 'Sliding Window Kiri-Kanan';
      case OpeningType.slidingUpDown: return 'Sliding Window Atas-Bawah';
      case OpeningType.sliding2Daun: return 'Sliding Door 2 Daun';
      case OpeningType.sliding3Daun: return 'Sliding Door 3 Daun';
      case OpeningType.sliding4Daun: return 'Sliding Door 4 Daun';
      case OpeningType.louvre: return 'Louvre';
    }
  }

  String get shortLabel {
    switch (this) {
      case OpeningType.fixed: return 'FX';
      case OpeningType.casement: return 'CS';
      case OpeningType.glassSingle: return 'DGS';
      case OpeningType.glassDouble: return 'DGD';
      case OpeningType.acpSingle: return 'DAS';
      case OpeningType.acpDouble: return 'DAD';
      case OpeningType.panelSingle: return 'DPS';
      case OpeningType.panelDouble: return 'DPD';
      case OpeningType.folding3: return 'FD3';
      case OpeningType.folding4: return 'FD4';
      case OpeningType.slidingLeftRight: return 'SW-LR';
      case OpeningType.slidingUpDown: return 'SW-UD';
      case OpeningType.sliding2Daun: return 'SD2';
      case OpeningType.sliding3Daun: return 'SD3';
      case OpeningType.sliding4Daun: return 'SD4';
      case OpeningType.louvre: return 'LV';
    }
  }

  bool get isDoor {
    return this == OpeningType.glassSingle ||
        this == OpeningType.glassDouble ||
        this == OpeningType.acpSingle ||
        this == OpeningType.acpDouble ||
        this == OpeningType.panelSingle ||
        this == OpeningType.panelDouble ||
        this == OpeningType.folding3 ||
        this == OpeningType.folding4 ||
        this == OpeningType.sliding2Daun ||
        this == OpeningType.sliding3Daun ||
        this == OpeningType.sliding4Daun;
  }
}

// ─── DESIGN CANVAS MODEL ───
class DesignCanvasModel {
  List<FrameNode> frames;
  String brand; // 'Inkalum' | 'Alexindo' | 'YKK'
  String kusenSize; // '3 inch' | '4 inch'
  String daunJendelaProfil; // '2 Profil' | '3 Profil'
  String slidingWindowType; // 'Ekonomis' | 'Jumbo'

  DesignCanvasModel({
    List<FrameNode>? frames,
    this.brand = 'Inkalum',
    this.kusenSize = '3 inch',
    this.daunJendelaProfil = '2 Profil',
    this.slidingWindowType = 'Ekonomis',
  }) : frames = frames ?? [];

  double get totalPrice => frames.fold(0.0, (sum, f) => sum + f.price);
  int get totalPanels => frames.fold(0, (sum, f) => sum + f.rootPanel.leafCount);

  Map<String, dynamic> toMap() => {
    'version': 4,
    'brand': brand,
    'kusenSize': kusenSize,
    'daunJendelaProfil': daunJendelaProfil,
    'slidingWindowType': slidingWindowType,
    'frames': frames.map((f) => f.toMap()).toList(),
  };

  factory DesignCanvasModel.fromMap(Map<String, dynamic> map) {
    return DesignCanvasModel(
      frames: (map['frames'] as List?)
          ?.map((f) => FrameNode.fromMap(f)).toList() ?? [],
      brand: map['brand'] ?? 'Inkalum',
      kusenSize: map['kusenSize'] ?? '3 inch',
      daunJendelaProfil: map['daunJendelaProfil'] ?? '2 Profil',
      slidingWindowType: map['slidingWindowType'] ?? 'Ekonomis',
    );
  }

  String toJson() => json.encode(toMap());

  factory DesignCanvasModel.fromJson(String source) {
    final decoded = json.decode(source);
    if (decoded is Map && decoded.containsKey('version')) {
      return DesignCanvasModel.fromMap(Map<String, dynamic>.from(decoded));
    }
    
    // Legacy: single panel -> wrap in frame
    final panel = PanelNode.fromMap(Map<String, dynamic>.from(decoded as Map));
    return DesignCanvasModel(frames: [
      FrameNode(
        x: 100, y: 100,
        widthCm: panel.width, heightCm: panel.height,
        rootPanel: panel,
      ),
    ]);
  }
}

// ─── FRAME NODE ───
class FrameNode {
  String id;
  double x, y; // position on canvas (logical pixels)
  double widthCm, heightCm; // physical dimensions in cm
  FrameType type;
  PanelNode rootPanel;
  String label;

  FrameNode({
    String? id,
    this.x = 100,
    this.y = 100,
    this.widthCm = 120,
    this.heightCm = 150,
    this.type = FrameType.jendela,
    PanelNode? rootPanel,
    this.label = '',
  }) : id = id ?? const Uuid().v4(),
       rootPanel = rootPanel ?? PanelNode();

  static const double pxPerCm = 4.0;

  double get renderWidth => widthCm * pxPerCm;
  double get renderHeight => heightCm * pxPerCm;

  // Simple pricing fallback used for default estimation
  double get price {
    return _calcPrice(rootPanel, widthCm, heightCm);
  }

  double _calcPrice(PanelNode panel, double wCm, double hCm) {
    if (panel.isLeaf) {
      double area = (wCm / 100) * (hCm / 100);
      double price = area * 500000;
      switch (panel.openingType) {
        case OpeningType.fixed: break;
        case OpeningType.slidingLeftRight:
        case OpeningType.slidingUpDown: price += 120000; break;
        case OpeningType.casement: price += 150000; break;
        case OpeningType.glassSingle:
        case OpeningType.acpSingle:
        case OpeningType.panelSingle: price += 300000; break;
        case OpeningType.glassDouble:
        case OpeningType.acpDouble:
        case OpeningType.panelDouble: price += 600000; break;
        case OpeningType.folding3: price += 700000; break;
        case OpeningType.folding4: price += 900000; break;
        case OpeningType.sliding2Daun: price += 240000; break;
        case OpeningType.sliding3Daun: price += 360000; break;
        case OpeningType.sliding4Daun: price += 480000; break;
        case OpeningType.louvre: price += 200000; break;
      }
      return price;
    }
    double total = 0;
    final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
    for (int i = 0; i < panel.children.length; i++) {
      final ratio = totalFlex > 0
          ? (panel.childFlex.length > i ? panel.childFlex[i] : 1.0) / totalFlex
          : 1.0 / panel.children.length;
      if (panel.splitDirection == SplitDirection.horizontal) {
        total += _calcPrice(panel.children[i], wCm * ratio, hCm);
      } else {
        total += _calcPrice(panel.children[i], wCm, hCm * ratio);
      }
    }
    return total;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'x': x, 'y': y,
    'widthCm': widthCm, 'heightCm': heightCm,
    'type': type.name,
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
      rootPanel: PanelNode.fromMap(map['rootPanel']),
      label: map['label'] ?? '',
    );
  }
}

// ─── PANEL NODE ───
class PanelNode {
  String id;
  double width; // kept for backward compat, not primary
  double height;
  SplitDirection splitDirection;
  List<PanelNode> children;
  List<double> childFlex;
  OpeningType openingType;
  String label;
  String swingDirection; // 'left' | 'right' | 'top' | 'bottom'

  PanelNode({
    String? id,
    this.width = 100,
    this.height = 150,
    this.splitDirection = SplitDirection.none,
    List<PanelNode>? children,
    this.openingType = OpeningType.fixed,
    this.label = '',
    List<double>? childFlex,
    this.swingDirection = 'left',
  }) : id = id ?? const Uuid().v4(),
       children = children ?? [],
       childFlex = childFlex ?? [];

  bool get isLeaf => children.isEmpty;

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
    'openingType': openingType.name,
    'label': label,
    'childFlex': childFlex,
    'width': width,
    'height': height,
    'swingDirection': swingDirection,
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
      openingType: OpeningType.values.firstWhere(
        (e) => e.name == map['openingType'], orElse: () => OpeningType.fixed),
      label: map['label'] ?? '',
      childFlex: (map['childFlex'] as List?)
          ?.map((e) => (e as num).toDouble()).toList() ?? [],
      swingDirection: map['swingDirection'] ?? 'left',
    );
  }

  String toJson() => json.encode(toMap());
  factory PanelNode.fromJson(String source) => PanelNode.fromMap(json.decode(source));

  void split(SplitDirection direction, [double ratio = 0.5]) {
    if (direction == SplitDirection.none) return;
    splitDirection = direction;
    children = [
      PanelNode(openingType: openingType),
      PanelNode(openingType: openingType),
    ];
    childFlex = [ratio, 1.0 - ratio];
  }

  void splitEqually(SplitDirection direction, int parts) {
    if (direction == SplitDirection.none || parts < 2) return;
    splitDirection = direction;
    children = List.generate(parts, (_) => PanelNode(openingType: openingType));
    childFlex = List.generate(parts, (_) => 1.0 / parts);
  }

  void merge() {
    splitDirection = SplitDirection.none;
    children = [];
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
  OpeningType? openingType;
  String swingDirection; // 'left' | 'right' | 'top' | 'bottom'
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
    this.openingType,
    this.swingDirection = 'left',
    this.splitDirection = SplitDirection.none,
    List<double>? childFlex,
    this.label = '',
    this.mullionIndex,
    this.isHorizontalMullion,
  }) : children = children ?? [],
       childFlex = childFlex ?? [];
}
