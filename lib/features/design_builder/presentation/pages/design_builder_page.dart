import 'package:flutter/material.dart';
import 'dart:math';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/design_models.dart';
import '../../data/repositories/pricing_engine.dart';
import '../../../quotation/data/models/quotation_model.dart';
import '../../../quotation/data/repositories/quotation_repository.dart';
import 'package:uuid/uuid.dart';
import '../widgets/frame_widget.dart';

class DesignBuilderPage extends StatefulWidget {
  final String quotationId;
  final QuotationItemModel? existingItem;

  const DesignBuilderPage({super.key, required this.quotationId, this.existingItem});

  @override
  State<DesignBuilderPage> createState() => _DesignBuilderPageState();
}

enum ToolMode { select, frame, mullion, window, door, sliding, delete }

enum _CanvasInteraction { none, dragFrame, resizeFrame, dragMullion }

class HitResult {
  final DesignObject object;
  final String? handleId;
  final bool isWidthLabel;
  final bool isHeightLabel;
  final PanelNode? subPanel;
  final bool? isSubPanelWidth; // true for width, false for height

  HitResult(
    this.object, {
    this.handleId,
    this.isWidthLabel = false,
    this.isHeightLabel = false,
    this.subPanel,
    this.isSubPanelWidth,
  });
}

class SnapConnection {
  final String frameId1; // Left or Top frame
  final String frameId2; // Right or Bottom frame
  final Axis axis;       // Axis.horizontal (left-right) or Axis.vertical (top-bottom)

  SnapConnection({
    required this.frameId1,
    required this.frameId2,
    required this.axis,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnapConnection &&
          runtimeType == other.runtimeType &&
          frameId1 == other.frameId1 &&
          frameId2 == other.frameId2 &&
          axis == other.axis;

  @override
  int get hashCode => frameId1.hashCode ^ frameId2.hashCode ^ axis.hashCode;
}



// ─── HARDCODED LOCAL CATALOG ───
final List<AluminumBrand> _localCatalog = [
  AluminumBrand(
    name: 'Inkalum',
    series: [
      SeriesCatalog(id: '3_inch', name: '3 Inch', items: [
        ProfileItem(category: 'Kusen', profileName: 'Kusen Open 3"', thickness: 7.62, price: 50000),
        ProfileItem(category: 'Kusen', profileName: 'Kusen M 3"', thickness: 7.62, price: 55000),
        ProfileItem(category: 'Daun Jendela', profileName: 'Casement 3"', thickness: 3.5, price: 40000),
        ProfileItem(category: 'Mullion', profileName: 'Tiang Tengah 3"', thickness: 7.62, price: 60000),
      ]),
      SeriesCatalog(id: '4_inch', name: '4 Inch', items: [
        ProfileItem(category: 'Kusen', profileName: 'Kusen Open 4"', thickness: 10.16, price: 65000),
        ProfileItem(category: 'Kusen', profileName: 'Kusen M 4"', thickness: 10.16, price: 70000),
        ProfileItem(category: 'Daun Pintu', profileName: 'Tiang Pintu', thickness: 8.0, price: 85000),
        ProfileItem(category: 'Mullion', profileName: 'Tiang Tengah 4"', thickness: 10.16, price: 75000),
      ]),
    ],
  ),
  AluminumBrand(
    name: 'Alexindo',
    series: [
      SeriesCatalog(id: '3_inch', name: '3 Inch', items: [
        ProfileItem(category: 'Kusen', profileName: 'Kusen Open 3"', thickness: 7.62, price: 70000),
        ProfileItem(category: 'Mullion', profileName: 'Tiang Tengah 3"', thickness: 7.62, price: 80000),
      ]),
      SeriesCatalog(id: '4_inch', name: '4 Inch', items: [
        ProfileItem(category: 'Kusen', profileName: 'Kusen Open 4"', thickness: 10.16, price: 90000),
        ProfileItem(category: 'Mullion', profileName: 'Tiang Tengah 4"', thickness: 10.16, price: 100000),
      ]),
    ],
  ),
  AluminumBrand(
    name: 'YKK',
    series: [
      SeriesCatalog(id: '3_inch', name: '3 Inch', items: [
        ProfileItem(category: 'Kusen', profileName: 'Kusen Open 3"', thickness: 7.62, price: 110000),
        ProfileItem(category: 'Mullion', profileName: 'Tiang Tengah 3"', thickness: 7.62, price: 120000),
      ]),
      SeriesCatalog(id: '4_inch', name: '4 Inch', items: [
        ProfileItem(category: 'Kusen', profileName: 'Kusen Open 4"', thickness: 10.16, price: 150000),
        ProfileItem(category: 'Mullion', profileName: 'Tiang Tengah 4"', thickness: 10.16, price: 160000),
      ]),
    ],
  ),
];

class _DesignBuilderPageState extends State<DesignBuilderPage> with SingleTickerProviderStateMixin {
  final QuotationRepository _repository = QuotationRepository();
  final PricingEngine _pricingEngine = PricingEngine();
  final _currFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  late DesignCanvasModel _project;
  String? _selectedFrameId;
  String? _selectedPanelId;

  ToolMode _activeMainTool = ToolMode.select;
  String _activeSubTool = '';

  final TransformationController _transformCtrl = TransformationController();
  late AnimationController _toolbarAnim;
  late Animation<double> _toolbarFade;

  static const double _canvasW = 3000;
  static const double _canvasH = 3000;

  Offset? _draftStart;
  Offset? _draftCurrent;

  Size _screenSize = Size.zero;
  bool _isFirstBuild = true;
  bool _isInteractingWithHandle = false;

  // Snapping guidelines
  final List<double> _vSnapLines = [];
  final List<double> _hSnapLines = [];
  List<SnapConnection> _activeConnections = [];

  // Custom interaction tracking
  _CanvasInteraction _interactionType = _CanvasInteraction.none;
  DesignObject? _draggedObject;
  Offset _dragStartPoint = Offset.zero;
  String? _resizeHandle;

  // Pointer tracking for manual tap/drag detection via Listener
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _isDragging = false;
  static const double _tapSlop = 18.0; // pixels threshold for tap vs drag

  // Viewport key to perform globalToLocal viewport space mapping
  final GlobalKey _canvasKey = GlobalKey();

  final List<String> _history = [];

  // Temporary price for UI preview before saving
  double _estimatedPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _toolbarAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _toolbarFade = CurvedAnimation(parent: _toolbarAnim, curve: Curves.easeOutCubic);

    if (widget.existingItem != null) {
      try {
        _project = DesignCanvasModel.fromJson(widget.existingItem!.designJson);
      } catch (e) {
        _project = DesignCanvasModel();
      }
    } else {
      _project = DesignCanvasModel();
    }

    _updateEstimatedPrice();
    _setSubToolForMainTool(ToolMode.select);

    _transformCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setSubToolForMainTool(ToolMode tool) {
    _activeMainTool = tool;
    switch (tool) {
      case ToolMode.select:
        _activeSubTool = 'edit';
        break;
      case ToolMode.frame:
        _activeSubTool = 'jendela';
        break;
      case ToolMode.mullion:
        _activeSubTool = 'bebas_v';
        break;
      case ToolMode.window:
        _activeSubTool = 'fixed';
        break;
      case ToolMode.door:
        _activeSubTool = 'glassSingle';
        break;
      case ToolMode.sliding:
        _activeSubTool = 'slidingLeftRight';
        break;
      case ToolMode.delete:
        _activeSubTool = '';
        break;
    }
  }

  // ─── CAD COORDINATE PROJECTOR ───
  Offset screenToCanvas(Offset globalPoint) {
    final RenderBox? viewportBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return globalPoint;
    
    final localViewportPoint = viewportBox.globalToLocal(globalPoint);
    
    final Matrix4 transform = _transformCtrl.value;
    final Matrix4 inverse = Matrix4.inverted(transform);
    final Vector3 position = Vector3(localViewportPoint.dx, localViewportPoint.dy, 0);
    final Vector3 transformed = inverse.transform3(position);
    return Offset(transformed.x, transformed.y);
  }

  double _getCurrentScale() {
    return _transformCtrl.value.getMaxScaleOnAxis();
  }

  void _updateScale(double newScale) {
    final RenderBox? viewportBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;

    final cx = viewportBox.size.width / 2;
    final cy = viewportBox.size.height / 2;

    final Matrix4 oldTransform = _transformCtrl.value;
    final double oldScale = oldTransform.getMaxScaleOnAxis();

    // Get current translations
    final double txOld = oldTransform.storage[12];
    final double tyOld = oldTransform.storage[13];

    // Compute canvas coordinates corresponding to viewport center
    final double px = (cx - txOld) / oldScale;
    final double py = (cy - tyOld) / oldScale;

    final clampedScale = newScale.clamp(0.2, 4.0);

    // Compute new translations
    final double txNew = cx - clampedScale * px;
    final double tyNew = cy - clampedScale * py;

    // Apply new matrix
    setState(() {
      _transformCtrl.value = Matrix4.identity()
        ..translate(txNew, tyNew)
        ..scale(clampedScale);
    });
  }

  Rect _getInnerFrameRect(FrameNode frame) {
    final double frameThickness = _project.getActiveKusenThickness(_localCatalog);
    final double fThickness = frameThickness * FrameNode.pxPerCm * 0.5; // Visual thickness is halved
    final int n = 1;
    
    final double leftInset = (2 * n - 1) * fThickness;
    final double rightInset = (2 * n - 1) * fThickness;
    final double topInset = (2 * n - 1) * fThickness;
    final double bottomInset = frame.type == FrameType.pintu
        ? n * fThickness
        : (2 * n - 1) * fThickness;
        
    return Rect.fromLTRB(
      frame.x + leftInset,
      frame.y + topInset,
      frame.x + frame.renderWidth - rightInset,
      frame.y + frame.renderHeight - bottomInset,
    );
  }

  // ─── INTERACTIVE OBJECT BUILDER ───
  List<DesignObject> _buildInteractiveObjects() {
    final List<DesignObject> list = [];
    
    for (final frame in _project.frames) {
      final frameRect = Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight);
      
      final frameObj = DesignObject(
        id: frame.id,
        bounds: frameRect,
        position: Offset(frame.x, frame.y),
        type: ObjectType.frame,
        frameType: frame.type,
        label: frame.label,
      );
      
      final innerRect = _getInnerFrameRect(frame);
      _addPanelObjects(frame.rootPanel, innerRect, frameObj.children);
      list.add(frameObj);
    }
    
    return list;
  }

  void _addPanelObjects(PanelNode panel, Rect rect, List<DesignObject> targetList) {
    final double mullionThickness = _project.getActiveMullionThickness(_localCatalog);
    final double visualMullionThickness = mullionThickness * 0.5; // Halved visually
    final double mThicknessPx = visualMullionThickness * FrameNode.pxPerCm;

    if (panel.isLeaf) {
      final panelObj = DesignObject(
        id: panel.id,
        bounds: rect,
        position: rect.topLeft,
        type: ObjectType.panel,
        opening: panel.opening,
        label: panel.label,
      );
      
      late final ObjectType opType;
      switch (panel.opening.type) {
        case 'fixed': opType = ObjectType.fixedGlass; break;
        case 'casement': opType = ObjectType.casement; break;
        case 'louvre': opType = ObjectType.louvre; break;
        case 'swing':
        case 'folding':
          opType = ObjectType.swingDoor;
          break;
        case 'sliding':
          opType = ObjectType.sliding;
          break;
        default:
          opType = ObjectType.fixedGlass;
      }
      
      final insetRect = rect.deflate(8.0);
      panelObj.children.add(DesignObject(
        id: '${panel.id}_opening',
        bounds: insetRect,
        position: insetRect.topLeft,
        type: opType,
        opening: panel.opening,
      ));
      
      targetList.add(panelObj);
      return;
    }
    
    final isH = panel.splitDirection == SplitDirection.horizontal;
    final totalSize = isH ? rect.width : rect.height;
    
    double totalMullionPx = panel.mullions.length * mThicknessPx;
    double availableSize = totalSize - totalMullionPx;
    
    final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
    if (totalFlex <= 0 || availableSize <= 0) return;
    
    double offset = 0;
    for (int i = 0; i < panel.children.length; i++) {
      final flex = panel.childFlex.length > i ? panel.childFlex[i] : 1.0;
      final size = availableSize * (flex / totalFlex);
      
      Rect childRect;
      if (isH) {
        childRect = Rect.fromLTWH(rect.left + offset, rect.top, size, rect.height);
      } else {
        childRect = Rect.fromLTWH(rect.left, rect.top + offset, rect.width, size);
      }
      
      _addPanelObjects(panel.children[i], childRect, targetList);
      
      offset += size;
      
      if (i < panel.children.length - 1) {
        Rect mullionRect;
        if (isH) {
          mullionRect = Rect.fromLTWH(
            rect.left + offset,
            rect.top,
            mThicknessPx,
            rect.height,
          );
        } else {
          mullionRect = Rect.fromLTWH(
            rect.left,
            rect.top + offset,
            rect.width,
            mThicknessPx,
          );
        }
        
        targetList.add(DesignObject(
          id: '${panel.id}_mullion_$i',
          bounds: mullionRect,
          position: mullionRect.topLeft,
          type: ObjectType.mullion,
          mullionIndex: i,
          isHorizontalMullion: isH,
          splitDirection: panel.splitDirection,
          label: panel.id,
        ));
        
        offset += mThicknessPx;
      }
    }
  }

  // ─── HIT TESTING ───
  HitResult? _hitTest(Offset canvasPoint) {
    if (_selectedFrameId != null) {
      final frame = _getSelectedFrame();
      if (frame != null) {
        final handleId = _hitTestResizeHandles(frame, canvasPoint);
        if (handleId != null) {
          final frameObj = DesignObject(
            id: frame.id,
            bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
            position: Offset(frame.x, frame.y),
            type: ObjectType.frame,
          );
          return HitResult(frameObj, handleId: handleId);
        }

        final currentScale = _getCurrentScale();
        final labelScale = (1.0 / currentScale).clamp(1.0, 5.0);

        final dragHandleRect = Rect.fromLTWH(
          frame.x,
          frame.y - 37.0 * labelScale,
          frame.renderWidth,
          48.0 * labelScale,
        );
        if (dragHandleRect.contains(canvasPoint)) {
          final frameObj = DesignObject(
            id: frame.id,
            bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
            position: Offset(frame.x, frame.y),
            type: ObjectType.frame,
          );
          return HitResult(frameObj, handleId: 'drag_frame');
        }

        final hasVertSplits = frame.rootPanel.hasVerticalSplit();
        final hasHorizSplits = frame.rootPanel.hasHorizontalSplit();
        final isSplit = !frame.rootPanel.isLeaf;

        if (!isSplit) {
          // Width label click bounds
          final double wLabelW = max(80.0 * labelScale, 48.0);
          final double wLabelH = max(48.0 * labelScale, 48.0);
          final wLabelRect = Rect.fromLTWH(
            frame.x + (frame.renderWidth - wLabelW) / 2,
            frame.y - 54.0 * labelScale,
            wLabelW,
            wLabelH,
          );
          if (wLabelRect.contains(canvasPoint)) {
            final frameObj = DesignObject(
              id: frame.id,
              bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
              position: Offset(frame.x, frame.y),
              type: ObjectType.frame,
            );
            return HitResult(frameObj, isWidthLabel: true);
          }
        }

        if (!isSplit) {
          // Height label click bounds
          final double hLabelW = max(48.0 * labelScale, 48.0);
          final double hLabelH = max(80.0 * labelScale, 48.0);
          final hLabelRect = Rect.fromLTWH(
            frame.x - 48.0 * labelScale,
            frame.y + (frame.renderHeight - hLabelH) / 2,
            hLabelW,
            hLabelH,
          );
          if (hLabelRect.contains(canvasPoint)) {
            final frameObj = DesignObject(
              id: frame.id,
              bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
              position: Offset(frame.x, frame.y),
              type: ObjectType.frame,
            );
            return HitResult(frameObj, isHeightLabel: true);
          }
        }

        // Sub-panel dimension labels hit testing
        final layouts = frame.getPanelLayouts(
          frameThickness: _project.getActiveKusenThickness(_localCatalog),
          mullionThickness: _project.getActiveMullionThickness(_localCatalog),
        );
        final N = 1;
        final double frameThickness = _project.getActiveKusenThickness(_localCatalog);
        final fThickness = frameThickness * FrameNode.pxPerCm * 0.5;
        final double leftInset = (2 * N - 1) * fThickness;
        final double rightInset = (2 * N - 1) * fThickness;
        final double topInset = (frame.type == FrameType.lengkung) ? leftInset : (2 * N - 1) * fThickness;
        final double bottomInset = (frame.type == FrameType.pintu) ? N * fThickness : (2 * N - 1) * fThickness;
        final innerRect = Rect.fromLTRB(leftInset, topInset, frame.renderWidth - rightInset, frame.renderHeight - bottomInset);

        final double leftInsetCm = (2 * N - 1) * frameThickness * 0.5;
        final double rightInsetCm = (2 * N - 1) * frameThickness * 0.5;
        final double topInsetCm = (frame.type == FrameType.lengkung) ? leftInsetCm : (2 * N - 1) * frameThickness * 0.5;
        final double bottomInsetCm = (frame.type == FrameType.pintu) ? N * frameThickness * 0.5 : (2 * N - 1) * frameThickness * 0.5;
        final innerWidthCm = frame.widthCm - leftInsetCm - rightInsetCm;
        final innerHeightCm = frame.heightCm - topInsetCm - bottomInsetCm;

        for (final layout in layouts) {
          if (!layout.panel.isLeaf) continue;
          if (layout.panel.opening.type == 'spacer') continue;

          // 1. Vertical split height labels (rendered on the right side of the frame or along internal mullions)
          final isRightmost = (layout.rect.right - innerRect.right).abs() < 2.0;
          final showHeightLabel = (hasHorizSplits && layout.heightCm < innerHeightCm - 0.1) ||
                                  (isSplit && !hasHorizSplits && isRightmost);
          if (showHeightLabel) {
            final double xMin, xMax;
            if (isRightmost) {
              xMin = frame.x + frame.renderWidth;
              xMax = frame.x + frame.renderWidth + 48.0 * labelScale;
            } else {
              xMin = frame.x + layout.rect.right - 24.0 * labelScale;
              xMax = frame.x + layout.rect.right + 24.0 * labelScale;
            }
            final centerY = frame.y + layout.rect.top + layout.rect.height / 2;
            final halfHeight = max(layout.rect.height, 48.0 * labelScale) / 2;
            final yMin = centerY - halfHeight;
            final yMax = centerY + halfHeight;

            if (canvasPoint.dx >= xMin && canvasPoint.dx <= xMax &&
                canvasPoint.dy >= yMin && canvasPoint.dy <= yMax) {
              final frameObj = DesignObject(
                id: frame.id,
                bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
                position: Offset(frame.x, frame.y),
                type: ObjectType.frame,
              );
              return HitResult(
                frameObj,
                subPanel: layout.panel,
                isSubPanelWidth: false,
              );
            }
          }

          // 2. Horizontal split width labels (rendered at the bottom of the frame or along internal transoms)
          final isBottommost = (layout.rect.bottom - innerRect.bottom).abs() < 2.0;
          final showWidthLabel = (hasVertSplits && layout.widthCm < innerWidthCm - 0.1) ||
                                 (isSplit && !hasVertSplits && isBottommost);
          if (showWidthLabel) {
            final double yMin, yMax;
            if (isBottommost) {
              yMin = frame.y + frame.renderHeight + 6.0 * labelScale;
              yMax = frame.y + frame.renderHeight + 54.0 * labelScale;
            } else {
              yMin = frame.y + layout.rect.bottom - 24.0 * labelScale;
              yMax = frame.y + layout.rect.bottom + 24.0 * labelScale;
            }
            final centerX = frame.x + layout.rect.left + layout.rect.width / 2;
            final halfWidth = max(layout.rect.width, 48.0 * labelScale) / 2;
            final xMin = centerX - halfWidth;
            final xMax = centerX + halfWidth;

            if (canvasPoint.dx >= xMin && canvasPoint.dx <= xMax &&
                canvasPoint.dy >= yMin && canvasPoint.dy <= yMax) {
              final frameObj = DesignObject(
                id: frame.id,
                bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
                position: Offset(frame.x, frame.y),
                type: ObjectType.frame,
              );
              return HitResult(
                frameObj,
                subPanel: layout.panel,
                isSubPanelWidth: true,
              );
            }
          }
        }
      }
    }

    final allObjects = _buildInteractiveObjects();

    for (final frameObj in allObjects) {
      for (final child in frameObj.children) {
        if (child.type == ObjectType.mullion && child.bounds.contains(canvasPoint)) {
          return HitResult(child);
        }
      }
    }

    for (final frameObj in allObjects) {
      for (final child in frameObj.children) {
        if (child.type == ObjectType.panel && child.bounds.contains(canvasPoint)) {
          return HitResult(child);
        }
      }
    }

    for (final frameObj in allObjects) {
      if (frameObj.bounds.contains(canvasPoint)) {
        return HitResult(frameObj);
      }
    }

    return null;
  }

  String? _hitTestResizeHandles(FrameNode frame, Offset canvasPoint) {
    final labelScale = (1.0 / _getCurrentScale()).clamp(1.0, 5.0);
    final hitSize = 48.0 * labelScale;
    final hs = hitSize / 2;
    final fw = frame.renderWidth;
    final fh = frame.renderHeight;
    final fx = frame.x;
    final fy = frame.y;

    Rect rect(double left, double top) => Rect.fromLTWH(left - hs, top - hs, hitSize, hitSize);

    final handles = {
      'tl': rect(fx, fy),
      'tr': rect(fx + fw, fy),
      'bl': rect(fx, fy + fh),
      'br': rect(fx + fw, fy + fh),
      't': rect(fx + fw / 2, fy),
      'b': rect(fx + fw / 2, fy + fh),
      'l': rect(fx, fy + fh / 2),
      'r': rect(fx + fw, fy + fh / 2),
    };

    for (final entry in handles.entries) {
      if (entry.value.contains(canvasPoint)) {
        return entry.key;
      }
    }
    return null;
  }

  PanelNode? _getSelectedPanelById(String id) {
    for (final frame in _project.frames) {
      final panel = frame.rootPanel.findById(id);
      if (panel != null) return panel;
    }
    return null;
  }

  FrameNode? _getFrameById(String id) {
    try {
      return _project.frames.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  DesignObject? _findObjectInTree(List<DesignObject> list, String id) {
    for (final obj in list) {
      if (obj.id == id) return obj;
      final found = _findObjectInTree(obj.children, id);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _updateEstimatedPrice() async {
    final breakdown = await _pricingEngine.calculateDesignPrice(_project);
    setState(() {
      _estimatedPrice = breakdown.grandTotal;
    });
  }

  void _centerCanvas() {
    if (_screenSize == Size.zero) return;
    final dx = (_canvasW - _screenSize.width) / 2;
    final dy = (_canvasH - _screenSize.height) / 2;
    _transformCtrl.value = Matrix4.identity()..translate(-dx, -dy);
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget dropdown(String title, String value, List<String> options, Function(String) onChanged) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: value,
                        dropdownColor: const Color(0xFF2C2C2C),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        items: options.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt,
                            child: Text(opt),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            onChanged(val);
                            setModalState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CANVAS SETTINGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  dropdown('Merk Aluminium', _project.activeBrand, _localCatalog.map((b) => b.name).toList(), (val) {
                    setState(() {
                      _project.activeBrand = val;
                      final brand = _localCatalog.firstWhere((b) => b.name == val);
                      if (!brand.series.any((s) => s.id == _project.activeSeriesId)) {
                        _project.activeSeriesId = brand.series.first.id;
                      }
                    });
                    _updateEstimatedPrice();
                  }),
                  dropdown('Ukuran Kusen / Seri', _localCatalog.firstWhere((b) => b.name == _project.activeBrand).series.firstWhere((s) => s.id == _project.activeSeriesId, orElse: () => _localCatalog.firstWhere((b) => b.name == _project.activeBrand).series.first).name, _localCatalog.firstWhere((b) => b.name == _project.activeBrand).series.map((s) => s.name).toList(), (val) {
                    setState(() {
                      final brand = _localCatalog.firstWhere((b) => b.name == _project.activeBrand);
                      final seri = brand.series.firstWhere((s) => s.name == val);
                      _project.activeSeriesId = seri.id;
                    });
                    _updateEstimatedPrice();
                  }),
                  const SizedBox(height: 12),
                  const Text('KATALOG PROFIL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const Divider(color: Colors.white12, height: 16),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: () {
                        final brand = _localCatalog.firstWhere((b) => b.name == _project.activeBrand);
                        final series = brand.series.firstWhere((s) => s.id == _project.activeSeriesId, orElse: () => brand.series.first);
                        final Map<String, List<ProfileItem>> grouped = {};
                        for (var item in series.items) {
                          grouped.putIfAbsent(item.category, () => []).add(item);
                        }
                        List<Widget> widgets = [];
                        grouped.forEach((category, items) {
                          widgets.add(Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(category.toUpperCase(), style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 10, fontWeight: FontWeight.bold)),
                          ));
                          for (var item in items) {
                            widgets.add(Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(item.profileName, style: const TextStyle(color: Colors.white, fontSize: 12))),
                                  Text('${item.thickness} cm', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                  const SizedBox(width: 12),
                                  Text('Rp ${item.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
                                ],
                              ),
                            ));
                          }
                        });
                        return widgets;
                      }(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                         Navigator.pop(context);
                         _showAddItemDialog();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Item', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ));
          },
        );
      },
    );
  }

  
  void _showAddItemDialog() {
    String category = 'Kusen';
    String profileName = '';
    double thickness = 0.0;
    double price = 0.0;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Tambah Profile Baru', style: TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: const Color(0xFF2C2C2C),
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Kategori',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    items: ['Kusen', 'Daun Pintu', 'Daun Jendela', 'Sliding Door', 'Sliding Window', 'Mullion', 'Kaca', 'Variasi']
                        .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(color: Colors.white)),
                        ))
                        .toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return ['Kusen', 'Daun Pintu', 'Daun Jendela', 'Sliding Door', 'Sliding Window', 'Mullion', 'Kaca', 'Variasi']
                          .map((c) => Text(c, style: const TextStyle(color: Colors.black)))
                          .toList();
                    },
                    onChanged: (v) => setStateModal(() => category = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Nama Profil',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    onChanged: (v) => profileName = v,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: const TextStyle(color: Colors.black),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Ketebalan (cm)',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    onChanged: (v) => thickness = double.tryParse(v) ?? 0.0,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: const TextStyle(color: Colors.black),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Harga (per batang/meter)',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    onChanged: (v) => price = double.tryParse(v) ?? 0.0,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (profileName.isNotEmpty) {
                      final brand = _localCatalog.firstWhere((b) => b.name == _project.activeBrand);
                      final series = brand.series.firstWhere((s) => s.id == _project.activeSeriesId);
                      setState(() {
                        series.items.add(ProfileItem(category: category, profileName: profileName, thickness: thickness, price: price));
                      });
                      _updateEstimatedPrice();
                    }
                    Navigator.pop(context);
                    _showSettingsDialog();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00)),
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _saveToHistory() {
    final jsonStr = _project.toJson();
    if (_history.isEmpty || _history.last != jsonStr) {
      _history.add(jsonStr);
      if (_history.length > 50) {
        _history.removeAt(0);
      }
    }
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        final lastState = _history.removeLast();
        _project = DesignCanvasModel.fromJson(lastState);
        _selectedFrameId = null;
        _selectedPanelId = null;
      });
      _updateEstimatedPrice();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tindakan untuk di-undo')),
      );
    }
  }

  void _newDesign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Desain Baru', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin menghapus semua gambar dan memulai dari awal?', style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveToHistory();
              setState(() {
                _project = DesignCanvasModel();
                _selectedFrameId = null;
                _selectedPanelId = null;
              });
              _updateEstimatedPrice();
            },
            child: const Text('HAPUS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 50,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _toolbarAnim.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  // ─── CANVAS INTERACTIONS (Listener-based, no GestureDetector) ───
  
  void _onPointerDown(PointerDownEvent details) {
    _pointerDownPosition = details.position;
    _pointerDownTime = DateTime.now();
    _isDragging = false;
    
    final canvasPoint = screenToCanvas(details.position);
    
    // In frame drawing mode, claim the interaction immediately
    if (_activeMainTool == ToolMode.frame) {
      _saveToHistory();
      setState(() {
        _isInteractingWithHandle = true;
        _draftStart = canvasPoint;
        _draftCurrent = canvasPoint;
      });
      return;
    }
    
    // In select mode, check if we're touching an interactive element
    if (_activeMainTool == ToolMode.select) {
      final hit = _hitTest(canvasPoint);
      if (hit != null && hit.handleId != null) {
        _saveToHistory();
        if (hit.handleId == 'drag_frame') {
          final frame = _getFrameById(hit.object.id);
          if (frame != null) {
            _activeConnections = _findAllSnapConnections();
          }
          setState(() {
            _isInteractingWithHandle = true;
            _isDragging = true;
            _draggedObject = hit.object;
            _dragStartPoint = canvasPoint;
            _interactionType = _CanvasInteraction.dragFrame;
          });
        } else {
          // Resize handle - claim immediately
          setState(() {
            _isInteractingWithHandle = true;
            _isDragging = true;
            _draggedObject = hit.object;
            _dragStartPoint = canvasPoint;
            _interactionType = _CanvasInteraction.resizeFrame;
            _resizeHandle = hit.handleId;
          });
        }
        return;
      }
      if (hit != null && hit.object.type == ObjectType.mullion) {
        // Mullion drag - claim immediately
        _saveToHistory();
        setState(() {
          _isInteractingWithHandle = true;
          _isDragging = true;
          _draggedObject = hit.object;
          _dragStartPoint = canvasPoint;
          _interactionType = _CanvasInteraction.dragMullion;
        });
        return;
      }
      // For frame/panel taps, don't claim the gesture - let InteractiveViewer
      // handle pan/zoom. We'll handle tap detection in onPointerUp.
    }
    
    // Default: don't interact, let InteractiveViewer handle it
    setState(() {
      _isInteractingWithHandle = false;
    });
  }
  
  void _onPointerMove(PointerMoveEvent details) {
    final canvasPoint = screenToCanvas(details.position);
    
    // Frame drawing mode
    if (_activeMainTool == ToolMode.frame && _draftStart != null) {
      setState(() {
        _draftCurrent = canvasPoint;
      });
      return;
    }
    
    // Active drag (resize handle or mullion only)
    if (_activeMainTool == ToolMode.select && _isDragging && _draggedObject != null) {
      final delta = canvasPoint - _dragStartPoint;
      _dragStartPoint = canvasPoint;
      
      if (_interactionType == _CanvasInteraction.dragFrame) {
        final frame = _getFrameById(_draggedObject!.id);
        if (frame != null) {
          setState(() {
            final Map<String, Offset> displacements = {frame.id: delta};
            final List<String> queue = [frame.id];
            final Set<String> visited = {frame.id};

            while (queue.isNotEmpty) {
              final currentId = queue.removeAt(0);
              final current = _getFrameById(currentId);
              if (current == null) continue;
              final currentDisp = displacements[currentId]!;

              for (final conn in _activeConnections) {
                if (conn.frameId1 == currentId || conn.frameId2 == currentId) {
                  final otherId = conn.frameId1 == currentId ? conn.frameId2 : conn.frameId1;
                  if (visited.contains(otherId)) continue;

                  final other = _getFrameById(otherId);
                  if (other == null) continue;

                  final f1 = _getFrameById(conn.frameId1)!;
                  final f2 = _getFrameById(conn.frameId2)!;

                  final otherDisp = getPropagatedDisplacement(
                    f1: f1,
                    f2: f2,
                    isHorizontal: conn.axis == Axis.horizontal,
                    currentId: currentId,
                    currentDisp: currentDisp,
                  );

                  displacements[otherId] = otherDisp;
                  visited.add(otherId);
                  queue.add(otherId);
                }
              }
            }

            // Apply calculated displacements
            displacements.forEach((fid, disp) {
              final f = _getFrameById(fid);
              if (f != null) {
                f.x += disp.dx;
                f.y += disp.dy;
              }
            });

            // Break relations where gap exceeds threshold (20.0 pixels)
            _activeConnections.removeWhere((conn) {
              final f1 = _getFrameById(conn.frameId1);
              final f2 = _getFrameById(conn.frameId2);
              if (f1 == null || f2 == null) return true;

              if (conn.axis == Axis.horizontal) {
                final double gap = f2.x - (f1.x + f1.renderWidth);
                return gap > 20.0;
              } else {
                final double gap = f2.y - (f1.y + f1.renderHeight);
                return gap > 20.0;
              }
            });

            // Apply snapping on the primarily dragged frame, ignoring others in the dragged group
            final double oldX = frame.x;
            final double oldY = frame.y;
            _applySnapping(frame, isDrag: true, ignoreIds: visited);
            final double correctionX = frame.x - oldX;
            final double correctionY = frame.y - oldY;

            if (correctionX != 0.0 || correctionY != 0.0) {
              for (final fid in visited) {
                if (fid == frame.id) continue;
                final f = _getFrameById(fid);
                if (f != null) {
                  f.x += correctionX;
                  f.y += correctionY;
                }
              }
            }
          });
        }
      } else if (_interactionType == _CanvasInteraction.resizeFrame && _resizeHandle != null) {
        final frame = _getFrameById(_draggedObject!.id);
        if (frame != null) {
          final cmPerPx = 1 / FrameNode.pxPerCm;
          setState(() {
            final handle = _resizeHandle!;
            double dx = delta.dx;
            double dy = delta.dy;

            // Record pre-resize boundaries
            final double preLeft = frame.x;
            final double preRight = frame.x + frame.renderWidth;
            final double preTop = frame.y;
            final double preBottom = frame.y + frame.renderHeight;

            // Apply size changes
            if (handle.contains('r')) {
              frame.widthCm = (frame.widthCm + dx * cmPerPx).clamp(30.0, 500.0);
            }
            if (handle.contains('l')) {
              final newW = (frame.widthCm - dx * cmPerPx).clamp(30.0, 500.0);
              frame.x += (frame.widthCm - newW) * FrameNode.pxPerCm;
              frame.widthCm = newW;
            }
            if (handle.contains('b')) {
              frame.heightCm = (frame.heightCm + dy * cmPerPx).clamp(30.0, 500.0);
            }
            if (handle.contains('t')) {
              final newH = (frame.heightCm - dy * cmPerPx).clamp(30.0, 500.0);
              frame.y += (frame.heightCm - newH) * FrameNode.pxPerCm;
              frame.heightCm = newH;
            }

            // Apply snapping on the resized frame
            _applySnapping(frame, isDrag: false, handle: handle);

            // Record post-resize boundaries
            final double postLeft = frame.x;
            final double postRight = frame.x + frame.renderWidth;
            final double postTop = frame.y;
            final double postBottom = frame.y + frame.renderHeight;

            // Calculate actual shift deltas
            final double deltaL = postLeft - preLeft;
            final double deltaR = postRight - preRight;
            final double deltaT = postTop - preTop;
            final double deltaB = postBottom - preBottom;

            // Propagate shift deltas recursively to snapped neighbors
            if (deltaR != 0.0) {
              _propagateRightShift(frame, deltaR, {frame.id});
            }
            if (deltaL != 0.0) {
              _propagateLeftShift(frame, deltaL, {frame.id});
            }
            if (deltaB != 0.0) {
              _propagateBottomShift(frame, deltaB, {frame.id});
            }
            if (deltaT != 0.0) {
              _propagateTopShift(frame, deltaT, {frame.id});
            }
          });
        }
      } else if (_interactionType == _CanvasInteraction.dragMullion) {
        final parentId = _draggedObject!.label;
        final index = _draggedObject!.mullionIndex!;
        final isH = _draggedObject!.isHorizontalMullion!;
        
        final parentPanel = _getSelectedPanelById(parentId);
        if (parentPanel != null) {
          final parentObj = _findObjectInTree(_buildInteractiveObjects(), parentId);
          if (parentObj != null) {
            final totalSize = isH ? parentObj.bounds.width : parentObj.bounds.height;
            if (totalSize > 0) {
              final dragDelta = isH ? delta.dx : delta.dy;
              final totalFlex = parentPanel.childFlex.fold(0.0, (a, b) => a + b);
              final flexDelta = (dragDelta / totalSize) * totalFlex;
              
              setState(() {
                if (parentPanel.childFlex.length > index + 1) {
                  parentPanel.childFlex[index] = (parentPanel.childFlex[index] + flexDelta).clamp(0.15, totalFlex - 0.15);
                  parentPanel.childFlex[index + 1] = (parentPanel.childFlex[index + 1] - flexDelta).clamp(0.15, totalFlex - 0.15);
                }
              });
            }
          }
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent details) {
    final canvasPoint = screenToCanvas(details.position);
    
    // Frame drawing mode - finalize the drawn frame
    if (_activeMainTool == ToolMode.frame && _draftStart != null && _draftCurrent != null) {
      final rect = Rect.fromPoints(_draftStart!, _draftCurrent!);
      if (rect.width > 20 && rect.height > 20) {
        setState(() {
          FrameType type = FrameType.jendela;
          if (_activeSubTool == 'pintu') {
            type = FrameType.pintu;
          } else if (_activeSubTool == 'sudut') {
            type = FrameType.sudut;
          } else if (_activeSubTool == 'lengkung') {
            type = FrameType.lengkung;
          }

          final frame = FrameNode(
            x: rect.left,
            y: rect.top,
            widthCm: (rect.width / FrameNode.pxPerCm).clamp(30.0, 500.0),
            heightCm: (rect.height / FrameNode.pxPerCm).clamp(30.0, 500.0),
            type: type,
            profileCount: type == FrameType.jendela ? 2 : 1,
          );
          _project.frames.add(frame);
          _selectedFrameId = frame.id;
          _activeMainTool = ToolMode.select;
          _activeSubTool = 'edit';
        });
        _updateEstimatedPrice();
        _checkAndMergeFrames();
      }
      _resetInteractionState();
      return;
    }
    
    // Was this a tap? (short duration, small movement)
    final wasTap = _pointerDownPosition != null &&
        (details.position - _pointerDownPosition!).distance < _tapSlop &&
        _pointerDownTime != null &&
        DateTime.now().difference(_pointerDownTime!).inMilliseconds < 400;
    
    if (wasTap) {
      _handleCanvasTap(canvasPoint);
    } else {
      if (_interactionType == _CanvasInteraction.dragFrame && _draggedObject != null) {
        setState(() {
          _snapBackActiveConnections(_draggedObject!.id);
        });
      }
      _checkAndMergeFrames();
    }
    
    _activeConnections.clear();
    _resetInteractionState();
  }
  
  void _onPointerCancel(PointerCancelEvent details) {
    _resetInteractionState();
  }

  void _resetInteractionState() {
    setState(() {
      _isInteractingWithHandle = false;
      _isDragging = false;
      _draggedObject = null;
      _resizeHandle = null;
      _interactionType = _CanvasInteraction.none;
      _draftStart = null;
      _draftCurrent = null;
      _pointerDownPosition = null;
      _pointerDownTime = null;
      _vSnapLines.clear();
      _hSnapLines.clear();
      _activeConnections.clear();
    });
  }

  void _handleCanvasTap(Offset canvasPoint) {
    final hit = _hitTest(canvasPoint);
    if (hit == null) {
      setState(() {
        _selectedFrameId = null;
        _selectedPanelId = null;
        _toolbarAnim.reverse();
      });
      return;
    }

    if (hit.isWidthLabel) {
      final frame = _getFrameById(hit.object.id);
      if (frame != null) {
        _showDimensionDialog(frame, true);
      }
      return;
    }

    if (hit.isHeightLabel) {
      final frame = _getFrameById(hit.object.id);
      if (frame != null) {
        _showDimensionDialog(frame, false);
      }
      return;
    }

    if (hit.subPanel != null && hit.isSubPanelWidth != null) {
      _showSubPanelDimensionDialog(hit.subPanel!, hit.isSubPanelWidth!);
      return;
    }

    final hitObj = hit.object;
    
    if (_activeMainTool == ToolMode.mullion) {
      if (hitObj.type == ObjectType.panel) {
        final panel = _getSelectedPanelById(hitObj.id);
        if (panel != null && panel.isLeaf) {
          _saveToHistory();
          setState(() {

            double getMullionThick() {
              final brand = _localCatalog.firstWhere((b) => b.name == _project.activeBrand, orElse: () => _localCatalog.first);
              final series = brand.series.firstWhere((s) => s.id == _project.activeSeriesId, orElse: () => brand.series.first);
              final item = series.items.firstWhere((i) => i.category == 'Mullion' || i.category == 'Kusen', orElse: () => ProfileItem(category: '', profileName: '', thickness: 5.0, price: 0));
              return item.thickness > 0 ? item.thickness : 5.0;
            }

            if (_activeSubTool == 'bebas_v') {
              panel.split(SplitDirection.vertical);
            } else if (_activeSubTool == 'bebas_h') {
              panel.split(SplitDirection.horizontal);
            } else if (_activeSubTool == 'equal_2') {
              panel.splitEqually(SplitDirection.vertical, 2);
            } else if (_activeSubTool == 'equal_3') {
              panel.splitEqually(SplitDirection.vertical, 3);
            } else if (_activeSubTool == 'equal_4') {
              panel.splitEqually(SplitDirection.vertical, 4);
            }
            
            for (var m in panel.mullions) {
              m.thicknessCm = getMullionThick();
            }

          });
          _updateEstimatedPrice();
        }
      }
    } else if (_activeMainTool == ToolMode.window) {
      if (hitObj.type == ObjectType.panel) {
        final panel = _getSelectedPanelById(hitObj.id);
        if (panel != null && panel.isLeaf) {
          _saveToHistory();
          setState(() {
            if (_activeSubTool == 'casement') {
              panel.opening = OpeningTypeNode(category: 'window', type: 'casement', direction: 'left', material: 'glass');
            } else {
              panel.opening = OpeningTypeNode(category: 'window', type: 'fixed', direction: 'none', material: 'glass');
            }
          });
          _updateEstimatedPrice();
        }
      }
    } else if (_activeMainTool == ToolMode.door) {
      if (hitObj.type == ObjectType.panel) {
        final panel = _getSelectedPanelById(hitObj.id);
        if (panel != null && panel.isLeaf) {
          _saveToHistory();
          setState(() {
            switch (_activeSubTool) {
              case 'glassSingle': panel.opening = OpeningTypeNode(category: 'door', type: 'swing', direction: 'left', material: 'glass'); break;
              case 'glassDouble': panel.opening = OpeningTypeNode(category: 'door', type: 'swing', direction: 'double', material: 'glass'); break;
              case 'acpSingle': panel.opening = OpeningTypeNode(category: 'door', type: 'swing', direction: 'left', material: 'acp'); break;
              case 'acpDouble': panel.opening = OpeningTypeNode(category: 'door', type: 'swing', direction: 'double', material: 'acp'); break;
              case 'panelSingle': panel.opening = OpeningTypeNode(category: 'door', type: 'swing', direction: 'left', material: 'panel'); break;
              case 'panelDouble': panel.opening = OpeningTypeNode(category: 'door', type: 'swing', direction: 'double', material: 'panel'); break;
              case 'folding3': panel.opening = OpeningTypeNode(category: 'door', type: 'folding', leafCount: 3, material: 'glass'); break;
              case 'folding4': panel.opening = OpeningTypeNode(category: 'door', type: 'folding', leafCount: 4, material: 'glass'); break;
            }
          });
          _updateEstimatedPrice();
        }
      }
    } else if (_activeMainTool == ToolMode.sliding) {
      if (hitObj.type == ObjectType.panel) {
        final panel = _getSelectedPanelById(hitObj.id);
        if (panel != null && panel.isLeaf) {
          _saveToHistory();
          setState(() {
            switch (_activeSubTool) {
              case 'slidingUpDown': panel.opening = OpeningTypeNode(category: 'window', type: 'sliding', direction: 'left', leafCount: 2); break;
              case 'slidingLeftRight': panel.opening = OpeningTypeNode(category: 'window', type: 'sliding', direction: 'left', leafCount: 2); break;
              case 'sliding2Daun': panel.opening = OpeningTypeNode(category: 'door', type: 'sliding', direction: 'double', leafCount: 2); break;
              case 'sliding3Daun': panel.opening = OpeningTypeNode(category: 'door', type: 'sliding', direction: 'left', leafCount: 3); break;
              case 'sliding4Daun': panel.opening = OpeningTypeNode(category: 'door', type: 'sliding', direction: 'double', leafCount: 4); break;
            }
          });
          _updateEstimatedPrice();
        }
      }
    } else if (_activeMainTool == ToolMode.delete) {
      if (hitObj.type == ObjectType.panel) {
        _saveToHistory();
        final panel = _getSelectedPanelById(hitObj.id);
        if (panel != null) {
          final frame = _getFrameForPanel(hitObj.id);
          if (frame != null) {
            if (frame.rootPanel.id == panel.id) {
              setState(() {
                _project.frames.removeWhere((f) => f.id == frame.id);
                _selectedFrameId = null;
                _selectedPanelId = null;
              });
            } else {
              final parent = frame.rootPanel.findParent(panel.id);
              if (parent != null) {
                setState(() {
                  parent.merge();
                });
              }
            }
            _updateEstimatedPrice();
          }
        }
      } else if (hitObj.type == ObjectType.frame) {
        _saveToHistory();
        setState(() {
          _project.frames.removeWhere((f) => f.id == hitObj.id);
          _selectedFrameId = null;
          _selectedPanelId = null;
        });
        _updateEstimatedPrice();
      }
    } else if (_activeMainTool == ToolMode.select) {
      setState(() {
        if (hitObj.type == ObjectType.panel) {
          _selectedFrameId = _getFrameForPanel(hitObj.id)?.id;
          _selectedPanelId = hitObj.id;
          _toolbarAnim.forward(from: 0);
        } else if (hitObj.type == ObjectType.frame) {
          _selectedFrameId = hitObj.id;
          _selectedPanelId = null;
          _toolbarAnim.reverse();
        }
      });
    }
  }

  // ─── MAGNETIC SNAPPING ───
  void _applySnapping(FrameNode current, {required bool isDrag, String? handle, Set<String>? ignoreIds}) {
    _vSnapLines.clear();
    _hSnapLines.clear();
    const snapThreshold = 12.0;

    double cx = current.x;
    double cy = current.y;
    double cw = current.renderWidth;
    double ch = current.renderHeight;

    for (final other in _project.frames) {
      if (other.id == current.id) continue;
      if (ignoreIds != null && ignoreIds.contains(other.id)) continue;

      double ox = other.x;
      double oy = other.y;
      double ow = other.renderWidth;
      double oh = other.renderHeight;

      // Horizontal Alignment / Snapping
      // Left edge of current aligns with Right edge of other
      if ((cx - (ox + ow)).abs() < snapThreshold) {
        current.x = ox + ow;
        _vSnapLines.add(ox + ow);
      }
      // Right edge of current aligns with Left edge of other
      else if (((cx + cw) - ox).abs() < snapThreshold) {
        if (isDrag) {
          current.x = ox - cw;
        } else if (handle != null && handle.contains('r')) {
          current.widthCm = (ox - cx) / FrameNode.pxPerCm;
        }
        _vSnapLines.add(ox);
      }
      // Left edge aligns with Left edge
      else if ((cx - ox).abs() < snapThreshold) {
        current.x = ox;
        _vSnapLines.add(ox);
      }

      // Vertical Alignment / Snapping
      // Top edge of current aligns with Bottom edge of other
      if ((cy - (oy + oh)).abs() < snapThreshold) {
        current.y = oy + oh;
        _hSnapLines.add(oy + oh);
      }
      // Bottom edge of current aligns with Top edge of other
      else if (((cy + ch) - oy).abs() < snapThreshold) {
        if (isDrag) {
          current.y = oy - ch;
        } else if (handle != null && handle.contains('b')) {
          current.heightCm = (oy - cy) / FrameNode.pxPerCm;
        }
        _hSnapLines.add(oy);
      }
      // Top edge aligns with Top edge
      else if ((cy - oy).abs() < snapThreshold) {
        current.y = oy;
        _hSnapLines.add(oy);
      }
    }
  }

  List<SnapConnection> _findAllSnapConnections() {
    final List<SnapConnection> connections = [];
    const double threshold = 3.0;

    for (int i = 0; i < _project.frames.length; i++) {
      final fa = _project.frames[i];
      final wA = fa.renderWidth;
      final hA = fa.renderHeight;

      for (int j = i + 1; j < _project.frames.length; j++) {
        final fb = _project.frames[j];
        final wB = fb.renderWidth;
        final hB = fb.renderHeight;

        // Check horizontal snap (left-right)
        // fa is left, fb is right
        if ((fa.x + wA - fb.x).abs() < threshold) {
          final overlap = min(fa.y + hA, fb.y + hB) - max(fa.y, fb.y);
          if (overlap > 1.0) {
            connections.add(SnapConnection(frameId1: fa.id, frameId2: fb.id, axis: Axis.horizontal));
          }
        }
        // fb is left, fa is right
        else if ((fb.x + wB - fa.x).abs() < threshold) {
          final overlap = min(fa.y + hA, fb.y + hB) - max(fa.y, fb.y);
          if (overlap > 1.0) {
            connections.add(SnapConnection(frameId1: fb.id, frameId2: fa.id, axis: Axis.horizontal));
          }
        }

        // Check vertical snap (top-bottom)
        // fa is top, fb is bottom
        if ((fa.y + hA - fb.y).abs() < threshold) {
          final overlap = min(fa.x + wA, fb.x + wB) - max(fa.x, fb.x);
          if (overlap > 1.0) {
            connections.add(SnapConnection(frameId1: fa.id, frameId2: fb.id, axis: Axis.vertical));
          }
        }
        // fb is top, fa is bottom
        else if ((fb.y + hB - fa.y).abs() < threshold) {
          final overlap = min(fa.x + wA, fb.x + wB) - max(fa.x, fb.x);
          if (overlap > 1.0) {
            connections.add(SnapConnection(frameId1: fb.id, frameId2: fa.id, axis: Axis.vertical));
          }
        }
      }
    }
    return connections;
  }

  Offset getPropagatedDisplacement({
    required FrameNode f1,
    required FrameNode f2,
    required bool isHorizontal,
    required String currentId,
    required Offset currentDisp,
  }) {
    double dx = 0;
    double dy = 0;

    if (isHorizontal) {
      dy = currentDisp.dy;

      final double gap = f2.x - (f1.x + f1.renderWidth);

      if (currentId == f2.id) {
        final double moveX = currentDisp.dx;
        if (moveX < 0) {
          final double closing = moveX.abs();
          if (closing > gap) {
            dx = -(closing - gap);
          } else {
            dx = 0;
          }
        } else {
          dx = 0;
        }
      } else {
        final double moveX = currentDisp.dx;
        if (moveX > 0) {
          final double closing = moveX;
          if (closing > gap) {
            dx = closing - gap;
          } else {
            dx = 0;
          }
        } else {
          dx = 0;
        }
      }
    } else {
      dx = currentDisp.dx;

      final double gap = f2.y - (f1.y + f1.renderHeight);

      if (currentId == f2.id) {
        final double moveY = currentDisp.dy;
        if (moveY < 0) {
          final double closing = moveY.abs();
          if (closing > gap) {
            dy = -(closing - gap);
          } else {
            dy = 0;
          }
        } else {
          dy = 0;
        }
      } else {
        final double moveY = currentDisp.dy;
        if (moveY > 0) {
          final double closing = moveY;
          if (closing > gap) {
            dy = closing - gap;
          } else {
            dy = 0;
          }
        } else {
          dy = 0;
        }
      }
    }

    return Offset(dx, dy);
  }

  void _snapBackActiveConnections(String anchorId) {
    final List<String> queue = [anchorId];
    final Set<String> visited = {anchorId};

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final current = _getFrameById(currentId);
      if (current == null) continue;

      for (final conn in _activeConnections) {
        if (conn.frameId1 == currentId || conn.frameId2 == currentId) {
          final otherId = conn.frameId1 == currentId ? conn.frameId2 : conn.frameId1;
          if (visited.contains(otherId)) continue;

          final other = _getFrameById(otherId);
          if (other == null) continue;

          if (conn.axis == Axis.horizontal) {
            if (currentId == conn.frameId2) {
              other.x = current.x - other.renderWidth;
            } else {
              other.x = current.x + current.renderWidth;
            }
          } else {
            if (currentId == conn.frameId2) {
              other.y = current.y - other.renderHeight;
            } else {
              other.y = current.y + current.renderHeight;
            }
          }

          visited.add(otherId);
          queue.add(otherId);
        }
      }
    }
  }

  void _checkAndMergeFrames() {
    _updateEstimatedPrice();
  }

  bool areFramesSnapped(FrameNode fa, FrameNode fb) {
    if (fa.id == fb.id) return false;
    final wA = fa.renderWidth;
    final hA = fa.renderHeight;
    final wB = fb.renderWidth;
    final hB = fb.renderHeight;

    const double threshold = 3.0; // overlap and closeness tolerance

    // Check if fa's right touches fb's left
    if ((fa.x + wA - fb.x).abs() < threshold) {
      final overlap = min(fa.y + hA, fb.y + hB) - max(fa.y, fb.y);
      if (overlap > 1.0) return true;
    }
    // Check if fb's right touches fa's left
    if ((fb.x + wB - fa.x).abs() < threshold) {
      final overlap = min(fa.y + hA, fb.y + hB) - max(fa.y, fb.y);
      if (overlap > 1.0) return true;
    }
    // Check if fa's bottom touches fb's top
    if ((fa.y + hA - fb.y).abs() < threshold) {
      final overlap = min(fa.x + wA, fb.x + wB) - max(fa.x, fb.x);
      if (overlap > 1.0) return true;
    }
    // Check if fb's bottom touches fa's top
    if ((fb.y + hB - fa.y).abs() < threshold) {
      final overlap = min(fa.x + wA, fb.x + wB) - max(fa.x, fb.x);
      if (overlap > 1.0) return true;
    }

    return false;
  }

  Set<String> getConnectedSnappedFrameIds(FrameNode startFrame) {
    final Set<String> visited = {startFrame.id};
    final List<FrameNode> queue = [startFrame];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final other in _project.frames) {
        if (!visited.contains(other.id) && areFramesSnapped(current, other)) {
          visited.add(other.id);
          queue.add(other);
        }
      }
    }
    return visited;
  }

  void _propagateRightShift(FrameNode source, double dx, Set<String> visited) {
    visited.add(source.id);
    final sourceRight = source.x + source.renderWidth;
    for (final other in _project.frames) {
      if (visited.contains(other.id)) continue;
      // If other's left edge is touching source's right edge
      if ((other.x - sourceRight).abs() < 3.0) {
        final overlap = min(source.y + source.renderHeight, other.y + other.renderHeight) - max(source.y, other.y);
        if (overlap > 1.0) {
          other.x += dx;
          _propagateRightShift(other, dx, visited);
        }
      }
    }
  }

  void _propagateLeftShift(FrameNode source, double dx, Set<String> visited) {
    visited.add(source.id);
    final sourceLeft = source.x;
    for (final other in _project.frames) {
      if (visited.contains(other.id)) continue;
      // If other's right edge is touching source's left edge
      final otherRight = other.x + other.renderWidth;
      if ((otherRight - sourceLeft).abs() < 3.0) {
        final overlap = min(source.y + source.renderHeight, other.y + other.renderHeight) - max(source.y, other.y);
        if (overlap > 1.0) {
          other.x += dx;
          _propagateLeftShift(other, dx, visited);
        }
      }
    }
  }

  void _propagateBottomShift(FrameNode source, double dy, Set<String> visited) {
    visited.add(source.id);
    final sourceBottom = source.y + source.renderHeight;
    for (final other in _project.frames) {
      if (visited.contains(other.id)) continue;
      // If other's top edge is touching source's bottom edge
      if ((other.y - sourceBottom).abs() < 3.0) {
        final overlap = min(source.x + source.renderWidth, other.x + other.renderWidth) - max(source.x, other.x);
        if (overlap > 1.0) {
          other.y += dy;
          _propagateBottomShift(other, dy, visited);
        }
      }
    }
  }

  void _propagateTopShift(FrameNode source, double dy, Set<String> visited) {
    visited.add(source.id);
    final sourceTop = source.y;
    for (final other in _project.frames) {
      if (visited.contains(other.id)) continue;
      // If other's bottom edge is touching source's top edge
      final otherBottom = other.y + other.renderHeight;
      if ((otherBottom - sourceTop).abs() < 3.0) {
        final overlap = min(source.x + source.renderWidth, other.x + other.renderWidth) - max(source.x, other.x);
        if (overlap > 1.0) {
          other.y += dy;
          _propagateTopShift(other, dy, visited);
        }
      }
    }
  }



  void _deleteSplit() {
    if (_selectedPanelId == null) return;
    final frame = _getFrameForPanel(_selectedPanelId!);
    if (frame == null) return;

    _saveToHistory();
    if (frame.rootPanel.id == _selectedPanelId && !frame.rootPanel.isLeaf) {
      setState(() {
        frame.rootPanel.merge();
        _selectedPanelId = frame.rootPanel.id;
      });
      _updateEstimatedPrice();
      return;
    }

    final parent = frame.rootPanel.findParent(_selectedPanelId!);
    if (parent != null) {
      setState(() {
        parent.merge();
        _selectedPanelId = parent.id;
      });
      _updateEstimatedPrice();
    }
  }

  void _deleteSelectedFrame() {
    if (_selectedFrameId == null) return;
    _saveToHistory();
    setState(() {
      _project.frames.removeWhere((f) => f.id == _selectedFrameId);
      _selectedFrameId = null;
      _selectedPanelId = null;
      _toolbarAnim.reverse();
    });
    _updateEstimatedPrice();
  }

  void _duplicateSelectedFrame() {
    final frame = _getSelectedFrame();
    if (frame == null) return;
    _saveToHistory();
    setState(() {
      final dup = FrameNode(
        x: frame.x + 40,
        y: frame.y + 40,
        widthCm: frame.widthCm,
        heightCm: frame.heightCm,
        type: frame.type,
        rootPanel: PanelNode.fromMap(frame.rootPanel.toMap()),
        label: '${frame.label} copy',
      );
      _project.frames.add(dup);
      _selectedFrameId = dup.id;
    });
    _updateEstimatedPrice();
  }

  FrameNode? _getSelectedFrame() {
    if (_selectedFrameId == null) return null;
    try {
      return _project.frames.firstWhere((f) => f.id == _selectedFrameId);
    } catch (_) {
      return null;
    }
  }

  PanelNode? _getSelectedPanel() {
    if (_selectedPanelId == null) return null;
    for (final frame in _project.frames) {
      final panel = frame.rootPanel.findById(_selectedPanelId!);
      if (panel != null) return panel;
    }
    return null;
  }

  FrameNode? _getFrameForPanel(String panelId) {
    for (final frame in _project.frames) {
      if (frame.rootPanel.findById(panelId) != null) return frame;
    }
    return null;
  }

  void _showDimensionDialog(FrameNode frame, bool isWidth) {
    final controller = TextEditingController(
      text: (isWidth ? frame.widthCm : frame.heightCm).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isWidth ? 'Ubah Lebar (cm)' : 'Ubah Tinggi (cm)',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.black, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Masukkan ukuran...',
            hintStyle: TextStyle(color: Colors.black38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 30 && val <= 500) {
                _saveToHistory();
                setState(() {
                  // Record pre-resize boundaries
                  final double preRight = frame.x + frame.renderWidth;
                  final double preBottom = frame.y + frame.renderHeight;

                  if (isWidth) {
                    frame.widthCm = val;
                  } else {
                    frame.heightCm = val;
                  }

                  // Apply snapping after typed dimensions (resize direction is right or bottom)
                  _applySnapping(frame, isDrag: false, handle: isWidth ? 'r' : 'b');

                  // Record post-resize boundaries
                  final double postRight = frame.x + frame.renderWidth;
                  final double postBottom = frame.y + frame.renderHeight;

                  // Calculate actual shift deltas
                  final double deltaR = postRight - preRight;
                  final double deltaB = postBottom - preBottom;

                  // Clear guidelines
                  _vSnapLines.clear();
                  _hSnapLines.clear();

                  // Propagate shift deltas recursively to snapped neighbors
                  if (isWidth && deltaR != 0.0) {
                    _propagateRightShift(frame, deltaR, {frame.id});
                  }
                  if (!isWidth && deltaB != 0.0) {
                    _propagateBottomShift(frame, deltaB, {frame.id});
                  }
                });
                Navigator.pop(context);
                _updateEstimatedPrice();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Masukkan angka valid antara 30 - 500 cm'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('SIMPAN', style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSubPanelDimensionDialog(PanelNode subPanel, bool isWidth) {
    final frame = _getSelectedFrame();
    if (frame == null) return;

    final parent = frame.rootPanel.findParent(subPanel.id);
    if (parent == null) return;

    final double frameThickness = _project.getActiveKusenThickness(_localCatalog);
    final double mullionThickness = _project.getActiveMullionThickness(_localCatalog);

    final layouts = frame.getPanelLayouts(
      frameThickness: frameThickness,
      mullionThickness: mullionThickness,
    );

    final parentLayout = layouts.firstWhere(
      (l) => l.panel.id == parent.id,
      orElse: () => PanelLayoutInfo(panel: parent, rect: Rect.zero, widthCm: frame.widthCm, heightCm: frame.heightCm),
    );
    final parentSizeCm = isWidth ? parentLayout.widthCm : parentLayout.heightCm;

    final availableCm = parentSizeCm;

    // Get current size in cm for this sub-panel
    final subLayout = layouts.firstWhere(
      (l) => l.panel.id == subPanel.id,
      orElse: () => PanelLayoutInfo(panel: subPanel, rect: Rect.zero, widthCm: 0, heightCm: 0),
    );
    final currentCm = isWidth ? subLayout.widthCm : subLayout.heightCm;

    final controller = TextEditingController(
      text: currentCm.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isWidth ? 'Ubah Lebar Sub-Panel (cm)' : 'Ubah Tinggi Sub-Panel (cm)',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.black, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Masukkan ukuran...',
            hintStyle: TextStyle(color: Colors.black38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6D00))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              final double minSubPanelSize = 2.0;

              if (val == null || val < minSubPanelSize) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ukuran minimal panel adalah $minSubPanelSize cm'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final double minRequiredRemSpace = minSubPanelSize * (parent.children.length - 1);
              final remSpace = availableCm - val;

              if (remSpace < minRequiredRemSpace) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ukuran terlalu besar. Sisa ruang untuk panel lain tidak mencukupi (minimal ${minRequiredRemSpace.toStringAsFixed(1)} cm)'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              _saveToHistory();
              setState(() {
                final totalFlex = parent.childFlex.fold(0.0, (a, b) => a + b);
                final targetIndex = parent.children.indexOf(subPanel);
                if (targetIndex != -1) {
                  final oldFlexC = parent.childFlex[targetIndex];
                  final sumOfOtherFlexes = totalFlex - oldFlexC;

                  final List<double> newFlex = List.from(parent.childFlex);
                  if (sumOfOtherFlexes > 0) {
                    for (int i = 0; i < parent.children.length; i++) {
                      if (i == targetIndex) {
                        newFlex[i] = val;
                      } else {
                        newFlex[i] = (parent.childFlex[i] / sumOfOtherFlexes) * remSpace;
                      }
                    }
                  } else {
                    final share = remSpace / (parent.children.length - 1);
                    for (int i = 0; i < parent.children.length; i++) {
                      if (i == targetIndex) {
                        newFlex[i] = val;
                      } else {
                        newFlex[i] = share;
                      }
                    }
                  }
                  parent.childFlex = newFlex;
                }
              });
              Navigator.pop(context);
              _updateEstimatedPrice();
            },
            child: const Text('SIMPAN', style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  // ─── SAVE DESIGN ───
  void _saveDesign() async {
    final jsonStr = _project.toJson();
    if (widget.existingItem != null) {
      await _repository.deleteQuotationItem(widget.existingItem!.id, widget.quotationId);
    }
    
    // Recalculate price through engine
    final breakdown = await _pricingEngine.calculateDesignPrice(_project);

    final item = QuotationItemModel(
      id: widget.existingItem?.id ?? const Uuid().v4(),
      quotationId: widget.quotationId,
      designJson: jsonStr,
      itemTotal: breakdown.grandTotal,
    );
    await _repository.addQuotationItem(item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    if (_isFirstBuild) {
      _isFirstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerCanvas();
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F0),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildSubToolbar(),
              Expanded(child: _buildCanvas()),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const Text('DESIGN BUILDER', style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, fontFamily: 'monospace',
          )),
          const Spacer(),
          _topBtn(Icons.settings_rounded, 'SETTING', _showSettingsDialog),
          const SizedBox(width: 6),
          _topBtn(Icons.check_rounded, 'SIMPAN', _saveDesign, primary: true),
        ],
      ),
    );
  }

  Widget _topBtn(IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
    return Material(
      color: primary ? const Color(0xFFFF6D00) : Colors.white.withAlpha(15),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSubToolbar() {
    final List<Widget> children = [];
    switch (_activeMainTool) {
      case ToolMode.select:
        break;
      case ToolMode.frame:
        children.addAll([
          _subToolBtn('jendela', 'Kusen Jendela'),
          _subToolBtn('pintu', 'Kusen Pintu'),
          _subToolBtn('sudut', 'Kusen Sudut'),
          _subToolBtn('lengkung', 'Kusen Lengkung'),
        ]);
        break;
      case ToolMode.mullion:
        children.addAll([
          _subToolBtn('bebas_v', 'Split V'),
          _subToolBtn('bebas_h', 'Split H'),
          _subToolBtn('equal_2', 'Equal Split 2'),
          _subToolBtn('equal_3', 'Equal Split 3'),
          _subToolBtn('equal_4', 'Equal Split 4'),
        ]);
        break;
      case ToolMode.window:
        children.addAll([
          _subToolBtn('fixed', 'Fixed Glass'),
          _subToolBtn('casement', 'Casement Window'),
        ]);
        break;
      case ToolMode.door:
        children.addAll([
          _subToolBtn('glassSingle', 'Glass Single'),
          _subToolBtn('glassDouble', 'Glass Double'),
          _subToolBtn('acpSingle', 'ACP Single'),
          _subToolBtn('acpDouble', 'ACP Double'),
          _subToolBtn('panelSingle', 'Panel Single'),
          _subToolBtn('panelDouble', 'Panel Double'),
          _subToolBtn('folding3', 'Folding 3'),
          _subToolBtn('folding4', 'Folding 4'),
        ]);
        break;
      case ToolMode.sliding:
        children.addAll([
          _subToolBtn('slidingLeftRight', 'Sliding Horizontal'),
          _subToolBtn('slidingUpDown', 'Sliding Vertical'),
          _subToolBtn('sliding2Daun', 'Sliding 2 Daun'),
          _subToolBtn('sliding3Daun', 'Sliding 3 Daun'),
          _subToolBtn('sliding4Daun', 'Sliding 4 Daun'),
        ]);
        break;
      case ToolMode.delete:
        children.add(const Text('DELETE: Tap panel atau frame untuk menghapus.', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)));
        break;
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFF2C2C2C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: children,
        ),
      ),
    );
  }

  Widget _subToolBtn(String id, String label) {
    final active = _activeSubTool == id;
    return GestureDetector(
      onTap: () => setState(() => _activeSubTool = id),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF6D00) : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Stack(
      key: _canvasKey,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            constrained: false,
            panEnabled: !_isInteractingWithHandle,
            scaleEnabled: !_isInteractingWithHandle,
            minScale: 0.2,
            maxScale: 4.0,
            child: SizedBox(
                width: _canvasW,
                height: _canvasH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Canvas background (grid lines removed)

                    // Alignment Snapping Guidelines
                    ..._vSnapLines.map((x) => Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1.5,
                            color: Colors.blueAccent.withAlpha(200),
                          ),
                        )),
                    ..._hSnapLines.map((y) => Positioned(
                          left: 0,
                          right: 0,
                          top: y,
                          child: Container(
                            height: 1.5,
                            color: Colors.blueAccent.withAlpha(200),
                          ),
                        )),

                    // Frame nodes wrapped in RepaintBoundary & IgnorePointer
                    RepaintBoundary(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _project.frames.map((frame) {
                          final List<BorderRange> leftRanges = [];
                          final List<BorderRange> rightRanges = [];
                          final List<BorderRange> topRanges = [];
                          final List<BorderRange> bottomRanges = [];

                          const double borderThreshold = 3.0;
                          final wA = frame.renderWidth;
                          final hA = frame.renderHeight;

                          for (final other in _project.frames) {
                            if (other.id == frame.id) continue;
                            
                            final wB = other.renderWidth;
                            final hB = other.renderHeight;
                            final bool frameIsPintu = frame.type == FrameType.pintu;
                            final bool otherIsPintu = other.type == FrameType.pintu;
                            
                            // Left border touches other's right
                            if ((frame.x - (other.x + wB)).abs() < borderThreshold) {
                              final startY = max(frame.y, other.y);
                              final endY = min(frame.y + hA, other.y + hB);
                              final overlap = endY - startY;
                              if (overlap > 1.0) {
                                bool shouldHide = false;
                                if (otherIsPintu && !frameIsPintu) {
                                  shouldHide = true;
                                } else if (!otherIsPintu && frameIsPintu) {
                                  shouldHide = false;
                                } else {
                                  shouldHide = false; // same priority: left/top are not hidden
                                }
                                if (shouldHide) {
                                  leftRanges.add(BorderRange(startY - frame.y, endY - frame.y));
                                }
                              }
                            }
                            // Right border touches other's left
                            if (((frame.x + wA) - other.x).abs() < borderThreshold) {
                              final startY = max(frame.y, other.y);
                              final endY = min(frame.y + hA, other.y + hB);
                              final overlap = endY - startY;
                              if (overlap > 1.0) {
                                bool shouldHide = false;
                                if (otherIsPintu && !frameIsPintu) {
                                  shouldHide = true;
                                } else if (!otherIsPintu && frameIsPintu) {
                                  shouldHide = false;
                                } else {
                                  shouldHide = true; // same priority: right/bottom are hidden
                                }
                                if (shouldHide) {
                                  rightRanges.add(BorderRange(startY - frame.y, endY - frame.y));
                                }
                              }
                            }
                            // Top border touches other's bottom
                            if ((frame.y - (other.y + hB)).abs() < borderThreshold) {
                              final startX = max(frame.x, other.x);
                              final endX = min(frame.x + wA, other.x + wB);
                              final overlap = endX - startX;
                              if (overlap > 1.0) {
                                bool shouldHide = false;
                                if (otherIsPintu && !frameIsPintu) {
                                  shouldHide = true;
                                } else if (!otherIsPintu && frameIsPintu) {
                                  shouldHide = false;
                                } else {
                                  shouldHide = false; // same priority: left/top are not hidden
                                }
                                if (shouldHide) {
                                  topRanges.add(BorderRange(startX - frame.x, endX - frame.x));
                                }
                              }
                            }
                            // Bottom border touches other's top
                            if (((frame.y + hA) - other.y).abs() < borderThreshold) {
                              final startX = max(frame.x, other.x);
                              final endX = min(frame.x + wA, other.x + wB);
                              final overlap = endX - startX;
                              if (overlap > 1.0) {
                                bool shouldHide = false;
                                if (otherIsPintu && !frameIsPintu) {
                                  shouldHide = true;
                                } else if (!otherIsPintu && frameIsPintu) {
                                  shouldHide = false;
                                } else {
                                  shouldHide = true; // same priority: right/bottom are hidden
                                }
                                if (shouldHide) {
                                  bottomRanges.add(BorderRange(startX - frame.x, endX - frame.x));
                                }
                              }
                            }
                          }

                          final bool hideLeft = leftRanges.any((r) => r.start <= 1.0 && r.end >= hA - 1.0);
                          final bool hideRight = rightRanges.any((r) => r.start <= 1.0 && r.end >= hA - 1.0);
                          final bool hideTop = topRanges.any((r) => r.start <= 1.0 && r.end >= wA - 1.0);
                          final bool hideBottom = bottomRanges.any((r) => r.start <= 1.0 && r.end >= wA - 1.0);

                          return Positioned(
                            left: frame.x,
                            top: frame.y,
                            child: IgnorePointer(
                              child: FrameWidget(
                                frame: frame,
                                isSelected: frame.id == _selectedFrameId,
                                selectedPanelId: _selectedPanelId,
                                frameThickness: _project.getActiveKusenThickness(_localCatalog),
                                mullionThickness: _project.getActiveMullionThickness(_localCatalog),
                                currentScale: _getCurrentScale(),
                                hideLeftBorder: hideLeft,
                                hideRightBorder: hideRight,
                                hideTopBorder: hideTop,
                                hideBottomBorder: hideBottom,
                                hideLeftRanges: leftRanges,
                                hideRightRanges: rightRanges,
                                hideTopRanges: topRanges,
                                hideBottomRanges: bottomRanges,
                                onFrameTap: () {},
                                onPanelTap: (_) {},
                                onFrameDrag: (_) {},
                                onResize: (_, __) {},
                                onDividerDrag: (_, __, ___, ____) {},
                                onPanelSlice: (_, __, ___) {},
                                onWidthTap: () {},
                                onHeightTap: () {},
                                onActionStart: () {},
                                onInteractionStart: () {},
                                onInteractionEnd: () {},
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Drag draft preview (Bingkai tool drawing)
                    if (_draftStart != null && _draftCurrent != null)
                      Positioned.fromRect(
                        rect: Rect.fromPoints(_draftStart!, _draftCurrent!),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6D00).withAlpha(40),
                            border: Border.all(
                              color: const Color(0xFFFF6D00),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // Floating action buttons (Create, Undo, New Design)
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CREATE (Toggle Draw Frame tool)
              _actionBtn(
                'CREATE',
                Icons.add_box_rounded,
                _activeMainTool == ToolMode.frame ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A).withAlpha(200),
                () {
                  setState(() {
                    if (_activeMainTool == ToolMode.frame) {
                      _setSubToolForMainTool(ToolMode.select);
                    } else {
                      _setSubToolForMainTool(ToolMode.frame);
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              // UNDO
              _actionBtn(
                'UNDO',
                Icons.undo_rounded,
                _history.isNotEmpty ? const Color(0xFF1A1A1A).withAlpha(200) : const Color(0xFF1A1A1A).withAlpha(80),
                _history.isNotEmpty ? _undo : () {},
              ),
              const SizedBox(height: 8),
              // NEW DESIGN
              _actionBtn(
                'NEW',
                Icons.refresh_rounded,
                const Color(0xFF1A1A1A).withAlpha(200),
                _newDesign,
              ),
            ],
          ),
        ),

        // Selected panel options (Float toolbar)
        if (_selectedPanelId != null) _buildFloatingToolbar(),
      ],
    );
  }

  Widget _buildFloatingToolbar() {
    final panel = _getSelectedPanel();
    if (panel == null) return const SizedBox();
    final isLeaf = panel.isLeaf;
    final frame = _getFrameForPanel(panel.id);
    final isDouble = panel.opening.direction == 'double' || panel.opening.leafCount > 1;

    return Positioned(
      bottom: 70,
      left: 8, right: 8,
      child: FadeTransition(
        opacity: _toolbarFade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_toolbarFade),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withAlpha(245),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 16, spreadRadius: 1)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLeaf || (frame != null && frame.rootPanel.findParent(panel.id) != null)) ...[
                  _tBtn(
                    isLeaf ? Icons.delete_outline_rounded : Icons.merge_rounded,
                    isLeaf ? 'Hapus Split' : 'Gabung Panel',
                    _deleteSplit,
                    color: const Color(0xFFEF5350),
                    full: true,
                  ),
                  const Divider(color: Colors.white12, height: 12),
                ],
                
                // Door options
                if (panel.opening.category == 'door') ...[
                  _toolbarSection('KONFIGURASI PINTU', [
                    _tDoorConfigBtn(panel, false, 'Single Door'),
                    _tDoorConfigBtn(panel, true, 'Double Door'),
                  ]),
                  const Divider(color: Colors.white12, height: 12),
                  
                  if (isDouble) ...[
                    _toolbarSection('BUKAAN PINTU DOUBLE', [
                      _tDoubleDoorOpeningBtn(panel, 'swing', 'Swing'),
                      _tDoubleDoorOpeningBtn(panel, 'sliding', 'Sliding'),
                    ]),
                    const Divider(color: Colors.white12, height: 12),
                  ] else ...[
                    _toolbarSection('BUKAAN PINTU SINGLE', [
                      _tSingleDoorOpeningBtn(panel, 'swing', 'left', 'Swing Kiri'),
                      _tSingleDoorOpeningBtn(panel, 'swing', 'right', 'Swing Kanan'),
                      _tSingleDoorOpeningBtn(panel, 'sliding', 'left', 'Sliding Kiri'),
                      _tSingleDoorOpeningBtn(panel, 'sliding', 'right', 'Sliding Kanan'),
                    ]),
                    const Divider(color: Colors.white12, height: 12),
                  ]
                ],

                // Window swing direction
                if (panel.opening.category == 'window' && panel.opening.type == 'casement') ...[
                  _toolbarSection('ARAH BUKAAN JENDELA', [
                    _tSwingBtn(panel, 'left', Icons.arrow_back_rounded, 'Kiri'),
                    _tSwingBtn(panel, 'right', Icons.arrow_forward_rounded, 'Kanan'),
                    _tSwingBtn(panel, 'top', Icons.arrow_upward_rounded, 'Atas'),
                    _tSwingBtn(panel, 'bottom', Icons.arrow_downward_rounded, 'Bawah'),
                  ]),
                  const Divider(color: Colors.white12, height: 12),
                ],

                // Window frame profile counts
                if (frame != null && (frame.type == FrameType.jendela || panel.opening.category == 'window')) ...[
                  _toolbarSection('PROFIL BINGKAI JENDELA', [
                    _tProfileBtn(frame, 2, '2 Profil'),
                    _tProfileBtn(frame, 3, '3 Profil'),
                  ]),
                  const Divider(color: Colors.white12, height: 12),
                ],

                _toolbarSection('FRAME', [
                  _tBtn(Icons.copy_rounded, 'Duplikat', _duplicateSelectedFrame),
                  _tBtn(Icons.delete_forever_rounded, 'Hapus Frame', _deleteSelectedFrame, color: const Color(0xFFEF5350)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tSwingBtn(PanelNode panel, String direction, IconData icon, String label) {
    final active = panel.opening.direction == direction;
    final color = active ? const Color(0xFFFF6D00) : Colors.white70;
    final bg = active ? const Color(0xFFFF6D00).withAlpha(45) : Colors.white.withAlpha(12);
    
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () {
          _saveToHistory();
          setState(() {
            panel.opening.direction = direction;
          });
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tDoorConfigBtn(PanelNode panel, bool isDouble, String label) {
    final currentIsDouble = panel.opening.direction == 'double' || panel.opening.leafCount > 1;
    final active = currentIsDouble == isDouble;
    final color = active ? const Color(0xFFFF6D00) : Colors.white70;
    final bg = active ? const Color(0xFFFF6D00).withAlpha(45) : Colors.white.withAlpha(12);
    
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () {
          _saveToHistory();
          setState(() {
            if (isDouble) {
              panel.opening.direction = 'double';
              panel.opening.leafCount = 2;
            } else {
              panel.opening.direction = 'left';
              panel.opening.leafCount = 1;
            }
          });
          _updateEstimatedPrice();
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _tDoubleDoorOpeningBtn(PanelNode panel, String type, String label) {
    final active = panel.opening.type == type;
    final color = active ? const Color(0xFFFF6D00) : Colors.white70;
    final bg = active ? const Color(0xFFFF6D00).withAlpha(45) : Colors.white.withAlpha(12);
    
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () {
          _saveToHistory();
          setState(() {
            panel.opening.type = type;
            panel.opening.direction = 'double';
            panel.opening.leafCount = 2;
          });
          _updateEstimatedPrice();
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _tSingleDoorOpeningBtn(PanelNode panel, String type, String direction, String label) {
    final active = panel.opening.type == type && panel.opening.direction == direction;
    final color = active ? const Color(0xFFFF6D00) : Colors.white70;
    final bg = active ? const Color(0xFFFF6D00).withAlpha(45) : Colors.white.withAlpha(12);
    
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () {
          _saveToHistory();
          setState(() {
            panel.opening.type = type;
            panel.opening.direction = direction;
            panel.opening.leafCount = 1;
          });
          _updateEstimatedPrice();
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _tProfileBtn(FrameNode frame, int count, String label) {
    final active = frame.profileCount == count;
    final color = active ? const Color(0xFFFF6D00) : Colors.white70;
    final bg = active ? const Color(0xFFFF6D00).withAlpha(45) : Colors.white.withAlpha(12);
    
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () {
          _saveToHistory();
          setState(() {
            frame.profileCount = count;
          });
          _updateEstimatedPrice();
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _toolbarSection(String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(label, style: const TextStyle(
            color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5,
          )),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: children.map((c) => Padding(
              padding: const EdgeInsets.only(right: 5),
              child: c,
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _tBtn(IconData icon, String label, VoidCallback onTap, {Color? color, bool full = false}) {
    final bg = color?.withAlpha(30) ?? Colors.white.withAlpha(12);
    final fg = color ?? Colors.white70;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: full ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: full ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: const Color(0xFF111111),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '${_project.frames.length} frame  •  ${_project.totalPanels} panel',
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ESTIMASI CAD', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      Text(
                        _currFmt.format(_estimatedPrice),
                        style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Slide horizontal toolbar
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  _toolBtn(ToolMode.select, Icons.ads_click_rounded, 'SELECT'),
                  const VerticalDivider(color: Colors.white12, width: 16, indent: 8, endIndent: 8),
                  _toolBtn(ToolMode.frame, Icons.crop_square_rounded, 'BINGKAI'),
                  const VerticalDivider(color: Colors.white12, width: 16, indent: 8, endIndent: 8),
                  _toolBtn(ToolMode.mullion, Icons.vertical_split_rounded, 'MULLION'),
                  const VerticalDivider(color: Colors.white12, width: 16, indent: 8, endIndent: 8),
                  _toolBtn(ToolMode.window, Icons.window_outlined, 'DAUN JENDELA'),
                  _toolBtn(ToolMode.door, Icons.door_front_door_outlined, 'DAUN PINTU'),
                  _toolBtn(ToolMode.sliding, Icons.swap_horiz_rounded, 'SLIDING'),
                  const VerticalDivider(color: Colors.white12, width: 16, indent: 8, endIndent: 8),
                  _toolBtn(ToolMode.delete, Icons.delete_forever_rounded, 'HAPUS'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(ToolMode tool, IconData icon, String label) {
    final active = _activeMainTool == tool;
    return GestureDetector(
      onTap: () {
        setState(() {
          _setSubToolForMainTool(tool);
          if (tool != ToolMode.select) {
            _selectedFrameId = null;
            _selectedPanelId = null;
            _toolbarAnim.reverse();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF6D00) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.white : Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 8,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
