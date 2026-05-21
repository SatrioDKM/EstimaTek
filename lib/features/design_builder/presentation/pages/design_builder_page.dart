import 'package:flutter/material.dart';
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
  HitResult(this.object, {this.handleId, this.isWidthLabel = false, this.isHeightLabel = false});
}

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
      
      _addPanelObjects(frame.rootPanel, frameRect, frameObj.children);
      list.add(frameObj);
    }
    
    return list;
  }

  void _addPanelObjects(PanelNode panel, Rect rect, List<DesignObject> targetList) {
    if (panel.isLeaf) {
      final panelObj = DesignObject(
        id: panel.id,
        bounds: rect,
        position: rect.topLeft,
        type: ObjectType.panel,
        openingType: panel.openingType,
        swingDirection: panel.swingDirection,
        label: panel.label,
      );
      
      late final ObjectType opType;
      switch (panel.openingType) {
        case OpeningType.fixed: opType = ObjectType.fixedGlass; break;
        case OpeningType.casement: opType = ObjectType.casement; break;
        case OpeningType.louvre: opType = ObjectType.louvre; break;
        case OpeningType.glassSingle:
        case OpeningType.glassDouble:
        case OpeningType.acpSingle:
        case OpeningType.acpDouble:
        case OpeningType.panelSingle:
        case OpeningType.panelDouble:
        case OpeningType.folding3:
        case OpeningType.folding4:
          opType = ObjectType.swingDoor;
          break;
        case OpeningType.slidingLeftRight:
        case OpeningType.slidingUpDown:
        case OpeningType.sliding2Daun:
        case OpeningType.sliding3Daun:
        case OpeningType.sliding4Daun:
          opType = ObjectType.sliding;
          break;
      }
      
      final insetRect = rect.deflate(8.0);
      panelObj.children.add(DesignObject(
        id: '${panel.id}_opening',
        bounds: insetRect,
        position: insetRect.topLeft,
        type: opType,
        openingType: panel.openingType,
        swingDirection: panel.swingDirection,
      ));
      
      targetList.add(panelObj);
      return;
    }
    
    final isH = panel.splitDirection == SplitDirection.horizontal;
    final totalSize = isH ? rect.width : rect.height;
    final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
    if (totalFlex <= 0) return;
    
    double offset = 0;
    for (int i = 0; i < panel.children.length; i++) {
      final flex = panel.childFlex.length > i ? panel.childFlex[i] : 1.0;
      final size = totalSize * (flex / totalFlex);
      
      Rect childRect;
      if (isH) {
        childRect = Rect.fromLTWH(rect.left + offset, rect.top, size, rect.height);
      } else {
        childRect = Rect.fromLTWH(rect.left, rect.top + offset, rect.width, size);
      }
      
      _addPanelObjects(panel.children[i], childRect, targetList);
      
      if (i < panel.children.length - 1) {
        final divPos = offset + size;
        const hitThickness = 16.0;
        Rect mullionRect;
        if (isH) {
          mullionRect = Rect.fromLTWH(
            rect.left + divPos - (hitThickness / 2),
            rect.top,
            hitThickness,
            rect.height,
          );
        } else {
          mullionRect = Rect.fromLTWH(
            rect.left,
            rect.top + divPos - (hitThickness / 2),
            rect.width,
            hitThickness,
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
      }
      offset += size;
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

        final dragHandleRect = Rect.fromLTWH(frame.x, frame.y - 24, frame.renderWidth, 24);
        if (dragHandleRect.contains(canvasPoint)) {
          final frameObj = DesignObject(
            id: frame.id,
            bounds: Rect.fromLTWH(frame.x, frame.y, frame.renderWidth, frame.renderHeight),
            position: Offset(frame.x, frame.y),
            type: ObjectType.frame,
          );
          return HitResult(frameObj, handleId: 'drag_frame');
        }

        // Width label click bounds
        final wLabelRect = Rect.fromLTWH(
          frame.x + (frame.renderWidth - 80) / 2,
          frame.y - 46,
          80,
          26,
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

        // Height label click bounds
        final hLabelRect = Rect.fromLTWH(
          frame.x - 46,
          frame.y + (frame.renderHeight - 26) / 2,
          46,
          26,
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
    const handleSize = 24.0;
    final hs = handleSize / 2;
    final fw = frame.renderWidth;
    final fh = frame.renderHeight;
    final fx = frame.x;
    final fy = frame.y;

    Rect rect(double left, double top) => Rect.fromLTWH(left - hs, top - hs, handleSize, handleSize);

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

            return Padding(
              padding: const EdgeInsets.all(20),
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
                  dropdown('Merk / Brand Aluminium', _project.brand, ['Inkalum', 'Alexindo', 'YKK'], (val) {
                    setState(() {
                      _project.brand = val;
                    });
                    _updateEstimatedPrice();
                  }),
                  dropdown('Ukuran Kusen', _project.kusenSize, ['3 inch', '4 inch'], (val) {
                    setState(() {
                      _project.kusenSize = val;
                    });
                    _updateEstimatedPrice();
                  }),
                  dropdown('Profil Daun Jendela', _project.daunJendelaProfil, ['2 Profil', '3 Profil'], (val) {
                    setState(() {
                      _project.daunJendelaProfil = val;
                    });
                    _updateEstimatedPrice();
                  }),
                  dropdown('Profil Sliding Window', _project.slidingWindowType, ['Ekonomis', 'Jumbo'], (val) {
                    setState(() {
                      _project.slidingWindowType = val;
                    });
                    _updateEstimatedPrice();
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
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
            frame.x += delta.dx;
            frame.y += delta.dy;
            _applySnapping(frame, isDrag: true);
          });
        }
      } else if (_interactionType == _CanvasInteraction.resizeFrame && _resizeHandle != null) {
        final frame = _getFrameById(_draggedObject!.id);
        if (frame != null) {
          final cmPerPx = 1 / FrameNode.pxPerCm;
          setState(() {
            final handle = _resizeHandle!;
            if (handle.contains('r')) {
              frame.widthCm = (frame.widthCm + delta.dx * cmPerPx).clamp(30, 500);
            }
            if (handle.contains('l')) {
              final newW = (frame.widthCm - delta.dx * cmPerPx).clamp(30.0, 500.0);
              frame.x += (frame.widthCm - newW) * FrameNode.pxPerCm;
              frame.widthCm = newW;
            }
            if (handle.contains('b')) {
              frame.heightCm = (frame.heightCm + delta.dy * cmPerPx).clamp(30, 500);
            }
            if (handle.contains('t')) {
              final newH = (frame.heightCm - delta.dy * cmPerPx).clamp(30.0, 500.0);
              frame.y += (frame.heightCm - newH) * FrameNode.pxPerCm;
              frame.heightCm = newH;
            }
            _applySnapping(frame, isDrag: false, handle: handle);
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
          );
          _project.frames.add(frame);
          _selectedFrameId = frame.id;
          _activeMainTool = ToolMode.select;
          _activeSubTool = 'edit';
        });
        _updateEstimatedPrice();
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
    }
    
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

    final hitObj = hit.object;
    
    if (_activeMainTool == ToolMode.mullion) {
      if (hitObj.type == ObjectType.panel) {
        final panel = _getSelectedPanelById(hitObj.id);
        if (panel != null && panel.isLeaf) {
          _saveToHistory();
          setState(() {
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
            panel.openingType = _activeSubTool == 'casement' ? OpeningType.casement : OpeningType.fixed;
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
              case 'glassSingle': panel.openingType = OpeningType.glassSingle; break;
              case 'glassDouble': panel.openingType = OpeningType.glassDouble; break;
              case 'acpSingle': panel.openingType = OpeningType.acpSingle; break;
              case 'acpDouble': panel.openingType = OpeningType.acpDouble; break;
              case 'panelSingle': panel.openingType = OpeningType.panelSingle; break;
              case 'panelDouble': panel.openingType = OpeningType.panelDouble; break;
              case 'folding3': panel.openingType = OpeningType.folding3; break;
              case 'folding4': panel.openingType = OpeningType.folding4; break;
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
              case 'slidingUpDown': panel.openingType = OpeningType.slidingUpDown; break;
              case 'slidingLeftRight': panel.openingType = OpeningType.slidingLeftRight; break;
              case 'sliding2Daun': panel.openingType = OpeningType.sliding2Daun; break;
              case 'sliding3Daun': panel.openingType = OpeningType.sliding3Daun; break;
              case 'sliding4Daun': panel.openingType = OpeningType.sliding4Daun; break;
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
  void _applySnapping(FrameNode current, {required bool isDrag, String? handle}) {
    _vSnapLines.clear();
    _hSnapLines.clear();
    const snapThreshold = 12.0;

    double cx = current.x;
    double cy = current.y;
    double cw = current.renderWidth;
    double ch = current.renderHeight;

    for (final other in _project.frames) {
      if (other.id == current.id) continue;

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
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'Masukkan ukuran...',
            hintStyle: TextStyle(color: Colors.white30),
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
                  if (isWidth) {
                    frame.widthCm = val;
                  } else {
                    frame.heightCm = val;
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

  // Helper to find all frames snapped (touching) to a starting frame using BFS
  List<FrameNode> _getConnectedFrames(FrameNode startFrame) {
    List<FrameNode> connected = [startFrame];
    List<FrameNode> queue = [startFrame];
    Set<String> visited = {startFrame.id};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final cx = current.x;
      final cy = current.y;
      final cw = current.renderWidth;
      final ch = current.renderHeight;

      for (final other in _project.frames) {
        if (visited.contains(other.id)) continue;

        final ox = other.x;
        final oy = other.y;
        final ow = other.renderWidth;
        final oh = other.renderHeight;

        bool touching = false;

        // Horizontal touching check with 1.5px tolerance
        final hTouch1 = (cx - (ox + ow)).abs() < 1.5;
        final hTouch2 = ((cx + cw) - ox).abs() < 1.5;
        final vOverlap = (cy < oy + oh) && (cy + ch > oy);

        if ((hTouch1 || hTouch2) && vOverlap) {
          touching = true;
        }

        // Vertical touching check with 1.5px tolerance
        final vTouch1 = (cy - (oy + oh)).abs() < 1.5;
        final vTouch2 = ((cy + ch) - oy).abs() < 1.5;
        final hOverlap = (cx < ox + ow) && (cx + cw > ox);

        if ((vTouch1 || vTouch2) && hOverlap) {
          touching = true;
        }

        if (touching) {
          visited.add(other.id);
          connected.add(other);
          queue.add(other);
        }
      }
    }
    return connected;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
        children.add(const Text('SELECT: Tap & Drag objek untuk memodifikasi.', style: TextStyle(color: Colors.white70, fontSize: 11)));
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    // Grid background
                    Positioned.fill(child: CustomPaint(painter: _GridPainter())),

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
                          return Positioned(
                            left: frame.x,
                            top: frame.y,
                            child: IgnorePointer(
                              child: FrameWidget(
                                frame: frame,
                                isSelected: frame.id == _selectedFrameId,
                                selectedPanelId: _selectedPanelId,
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

    final hasSwing = panel.openingType == OpeningType.casement ||
                     panel.openingType == OpeningType.glassSingle ||
                     panel.openingType == OpeningType.acpSingle ||
                     panel.openingType == OpeningType.panelSingle;

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
                if (hasSwing) ...[
                  _toolbarSection('BUKAAN / ARAH SWING', [
                    _tSwingBtn(panel, 'left', Icons.arrow_back_rounded, 'Kiri'),
                    _tSwingBtn(panel, 'right', Icons.arrow_forward_rounded, 'Kanan'),
                    if (panel.openingType == OpeningType.casement) ...[
                      _tSwingBtn(panel, 'top', Icons.arrow_upward_rounded, 'Atas'),
                      _tSwingBtn(panel, 'bottom', Icons.arrow_downward_rounded, 'Bawah'),
                    ],
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
    final active = panel.swingDirection == direction;
    final color = active ? const Color(0xFFFF6D00) : Colors.white70;
    final bg = active ? const Color(0xFFFF6D00).withAlpha(45) : Colors.white.withAlpha(12);
    
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () {
          _saveToHistory();
          setState(() {
            panel.swingDirection = direction;
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Minor grid (every 20px = 5cm)
    final minor = Paint()..color = const Color(0xFFE0E0D8)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    // Major grid (every 200px = 50cm)
    final major = Paint()..color = const Color(0xFFCCCCC4)..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 200) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = 0; y < size.height; y += 200) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
    // Origin crosshair
    final origin = Paint()..color = const Color(0xFFB0B0A8)..strokeWidth = 1.5;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), origin);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), origin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
