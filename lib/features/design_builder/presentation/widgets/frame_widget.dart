import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/design_models.dart';

/// Renders a single frame on canvas with panels, dividers, and resize handles.
class FrameWidget extends StatelessWidget {
  final FrameNode frame;
  final bool isSelected;
  final String? selectedPanelId;
  final VoidCallback onFrameTap;
  final Function(PanelNode) onPanelTap;
  final Function(DragUpdateDetails) onFrameDrag;
  final Function(DragUpdateDetails, String) onResize;
  final Function(PanelNode, int, DragUpdateDetails, bool) onDividerDrag;
  final Function(PanelNode, SplitDirection, double) onPanelSlice;
  final VoidCallback? onWidthTap;
  final VoidCallback? onHeightTap;
  final VoidCallback? onActionStart;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const FrameWidget({
    super.key,
    required this.frame,
    required this.isSelected,
    this.selectedPanelId,
    required this.onFrameTap,
    required this.onPanelTap,
    required this.onFrameDrag,
    required this.onResize,
    required this.onDividerDrag,
    required this.onPanelSlice,
    this.onWidthTap,
    this.onHeightTap,
    this.onActionStart,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final frameColor = isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A);
    final borderWidth = isSelected ? 3.0 : 2.0;

    Widget frameContent;
    if (frame.type == FrameType.lengkung) {
      frameContent = ClipPath(
        clipper: ArchedFrameClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              left: BorderSide(color: frameColor, width: borderWidth),
              right: BorderSide(color: frameColor, width: borderWidth),
              bottom: BorderSide(color: frameColor, width: borderWidth),
            ),
          ),
          child: CustomPaint(
            foregroundPainter: ArchedBorderPainter(frameColor, borderWidth),
            child: _buildPanelTree(frame.rootPanel),
          ),
        ),
      );
    } else {
      frameContent = Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: frameColor, width: borderWidth),
            right: BorderSide(color: frameColor, width: borderWidth),
            top: BorderSide(color: frameColor, width: borderWidth),
            bottom: frame.type == FrameType.pintu
                ? BorderSide(color: frameColor.withAlpha(80), width: borderWidth)
                : BorderSide(color: frameColor, width: borderWidth),
          ),
        ),
        child: CustomPaint(
          foregroundPainter: frame.type == FrameType.sudut ? CornerPostPainter(frameColor, borderWidth) : null,
          child: _buildPanelTree(frame.rootPanel),
        ),
      );
    }

    return SizedBox(
      width: frame.renderWidth,
      height: frame.renderHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main frame body
          Positioned.fill(
            child: GestureDetector(
              onTap: onFrameTap,
              child: frameContent,
            ),
          ),

          // Dimension labels
          _buildDimensionLabels(),

          // Drag handle (top bar for moving)
          if (isSelected) ...[
            Positioned(
              top: -24,
              left: 0,
              right: 0,
              child: GestureDetector(
                onPanStart: (d) {
                  onActionStart?.call();
                  onInteractionStart?.call();
                },
                onPanUpdate: onFrameDrag,
                onPanEnd: (d) => onInteractionEnd?.call(),
                onPanCancel: () => onInteractionEnd?.call(),
                child: Container(
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6D00),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.drag_indicator, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        frame.label.isNotEmpty ? frame.label : frame.type.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Resize handles
            ..._buildResizeHandles(),
          ],
        ],
      ),
    );
  }

  Widget _buildDimensionLabels() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Top (width) dimension line
        Positioned(
          top: -46,
          left: 0,
          right: 0,
          child: CustomPaint(
            painter: DimensionLinePainter(isHorizontal: true),
            child: Center(
              child: GestureDetector(
                onTap: onWidthTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F0),
                    border: Border.all(color: const Color(0xFFFF6D00).withAlpha(100), width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${frame.widthCm.toStringAsFixed(0)} cm',
                        style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: Color(0xFF424242), fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.edit_outlined, size: 9, color: Color(0xFFFF6D00)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Left (height) dimension line
        Positioned(
          top: 0,
          bottom: 0,
          left: -40,
          child: CustomPaint(
            painter: DimensionLinePainter(isHorizontal: false),
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: GestureDetector(
                  onTap: onHeightTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F0),
                      border: Border.all(color: const Color(0xFFFF6D00).withAlpha(100), width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${frame.heightCm.toStringAsFixed(0)} cm',
                          style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600,
                            color: Color(0xFF424242), fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.edit_outlined, size: 9, color: Color(0xFFFF6D00)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ],
    );
  }

  List<Widget> _buildResizeHandles() {
    const handleSize = 12.0;
    const hs = handleSize / 2;

    Widget handle(String id, double? left, double? top, double? right, double? bottom, MouseCursor cursor) {
      return Positioned(
        left: left, top: top, right: right, bottom: bottom,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            onPanStart: (d) {
              onActionStart?.call();
              onInteractionStart?.call();
            },
            onPanUpdate: (d) => onResize(d, id),
            onPanEnd: (d) => onInteractionEnd?.call(),
            onPanCancel: () => onInteractionEnd?.call(),
            child: Container(
              width: handleSize, height: handleSize,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00),
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    return [
      handle('tl', -hs, -hs, null, null, SystemMouseCursors.resizeUpLeft),
      handle('tr', null, -hs, -hs, null, SystemMouseCursors.resizeUpRight),
      handle('bl', -hs, null, null, -hs, SystemMouseCursors.resizeDownLeft),
      handle('br', null, null, -hs, -hs, SystemMouseCursors.resizeDownRight),
      handle('t', frame.renderWidth / 2 - hs, -hs, null, null, SystemMouseCursors.resizeUp),
      handle('b', frame.renderWidth / 2 - hs, null, null, -hs, SystemMouseCursors.resizeDown),
      handle('l', -hs, frame.renderHeight / 2 - hs, null, null, SystemMouseCursors.resizeLeft),
      handle('r', null, frame.renderHeight / 2 - hs, -hs, null, SystemMouseCursors.resizeRight),
    ];
  }

  Widget _buildPanelTree(PanelNode panel) {
    if (panel.isLeaf) {
      return _LeafPanelWidget(
        panel: panel,
        isSelected: panel.id == selectedPanelId,
        onTap: () => onPanelTap(panel),
        framePxPerCm: FrameNode.pxPerCm,
        onSlice: (dir, ratio) => onPanelSlice(panel, dir, ratio),
      );
    }

    final isH = panel.splitDirection == SplitDirection.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = isH ? constraints.maxWidth : constraints.maxHeight;
        final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
        if (totalFlex <= 0) return const SizedBox();

        List<Widget> items = [];
        double offset = 0;

        for (int i = 0; i < panel.children.length; i++) {
          final flex = panel.childFlex.length > i ? panel.childFlex[i] : 1.0;
          final size = totalSize * (flex / totalFlex);

          if (isH) {
            items.add(Positioned(
              left: offset, top: 0, width: size, bottom: 0,
              child: _buildPanelTree(panel.children[i]),
            ));
          } else {
            items.add(Positioned(
              left: 0, top: offset, right: 0, height: size,
              child: _buildPanelTree(panel.children[i]),
            ));
          }

          // Draggable divider
          if (i < panel.children.length - 1) {
            final divPos = offset + size;
            items.add(_buildDivider(panel, i, divPos, isH, totalSize));
          }
          offset += size;
        }

        return Stack(children: items);
      },
    );
  }

  Widget _buildDivider(PanelNode parent, int index, double pos, bool isH, double totalSize) {
    const hitSize = 20.0;
    const visualSize = 2.0;

    return Positioned(
      left: isH ? pos - hitSize / 2 : 0,
      top: isH ? 0 : pos - hitSize / 2,
      width: isH ? hitSize : null,
      height: isH ? null : hitSize,
      right: isH ? null : 0,
      bottom: isH ? 0 : null,
      child: MouseRegion(
        cursor: isH ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            onActionStart?.call();
            onInteractionStart?.call();
          },
          onPanUpdate: (details) => onDividerDrag(parent, index, details, isH),
          onPanEnd: (details) => onInteractionEnd?.call(),
          onPanCancel: () => onInteractionEnd?.call(),
          child: Center(
            child: Container(
              width: isH ? visualSize : double.infinity,
              height: isH ? double.infinity : visualSize,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arched clip path
class ArchedFrameClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final r = size.width / 2;
    final rectHeight = (size.height - r).clamp(0.0, size.height);
    path.moveTo(0, size.height);
    path.lineTo(0, rectHeight);
    path.arcToPoint(
      Offset(size.width, rectHeight),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Arched top border painter
class ArchedBorderPainter extends CustomPainter {
  final Color color;
  final double width;

  ArchedBorderPainter(this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final r = size.width / 2;
    final rectHeight = (size.height - r).clamp(0.0, size.height);

    final path = Path()
      ..moveTo(0, rectHeight)
      ..arcToPoint(
        Offset(size.width, rectHeight),
        radius: Radius.circular(r),
        clockwise: true,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Corner Post vertical aluminum column painter (10x10 cm -> 40px width)
class CornerPostPainter extends CustomPainter {
  final Color color;
  final double width;

  CornerPostPainter(this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final fillPaint = Paint()
      ..color = color.withAlpha(20)
      ..style = PaintingStyle.fill;

    // Draw vertical column on the right side of the frame (40px wide)
    final colW = 40.0;
    final rect = Rect.fromLTWH(size.width - colW, 0, colW, size.height);

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);

    // Cross detail lines
    final linePaint = Paint()
      ..color = color.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(size.width - colW, 0), Offset(size.width, size.height), linePaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - colW, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Renders CAD dimension helper lines
class DimensionLinePainter extends CustomPainter {
  final bool isHorizontal;

  DimensionLinePainter({required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    if (isHorizontal) {
      // Horizontal line above frame
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      // End ticks
      canvas.drawLine(Offset(0, y - 4), Offset(0, y + 4), paint);
      canvas.drawLine(Offset(size.width, y - 4), Offset(size.width, y + 4), paint);
    } else {
      // Vertical line to the left of frame
      final x = size.width / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      // End ticks
      canvas.drawLine(Offset(x - 4, 0), Offset(x + 4, 0), paint);
      canvas.drawLine(Offset(x - 4, size.height), Offset(x + 4, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Leaf panel rendering with opening symbol and swipe-to-slice
class _LeafPanelWidget extends StatefulWidget {
  final PanelNode panel;
  final bool isSelected;
  final VoidCallback onTap;
  final double framePxPerCm;
  final Function(SplitDirection, double) onSlice;

  const _LeafPanelWidget({
    required this.panel,
    required this.isSelected,
    required this.onTap,
    required this.framePxPerCm,
    required this.onSlice,
  });

  @override
  State<_LeafPanelWidget> createState() => _LeafPanelWidgetState();
}

class _LeafPanelWidgetState extends State<_LeafPanelWidget> {
  Offset? _sliceStart;
  Offset? _sliceEnd;

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _sliceStart = d.localPosition;
      _sliceEnd = d.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_sliceStart != null) {
      setState(() {
        _sliceEnd = d.localPosition;
      });
    }
  }

  void _onPanEnd(DragEndDetails d, Size size) {
    if (_sliceStart != null && _sliceEnd != null) {
      final dx = _sliceEnd!.dx - _sliceStart!.dx;
      final dy = _sliceEnd!.dy - _sliceStart!.dy;
      if (dx.abs() > 30 || dy.abs() > 30) {
        if (dx.abs() > dy.abs()) {
          // Horizontal swipe -> cut top/bottom -> SplitDirection.vertical (arranged top-to-bottom)
          final ratio = (_sliceStart!.dy / size.height).clamp(0.1, 0.9);
          widget.onSlice(SplitDirection.vertical, ratio);
        } else {
          // Vertical swipe -> cut left/right -> SplitDirection.horizontal (arranged left-to-right)
          final ratio = (_sliceStart!.dx / size.width).clamp(0.1, 0.9);
          widget.onSlice(SplitDirection.horizontal, ratio);
        }
      } else {
        widget.onTap();
      }
    }
    setState(() {
      _sliceStart = null;
      _sliceEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTap: widget.onTap,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: (d) => _onPanEnd(d, size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFFFF6D00).withAlpha(15)
                  : _getPanelColor(),
              border: Border.all(
                color: widget.isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A),
                width: widget.isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Stack(
              children: [
                // Opening symbol
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CustomPaint(
                      painter: _OpeningPainter(
                        widget.panel.openingType,
                        widget.isSelected,
                        widget.panel.swingDirection,
                      ),
                    ),
                  ),
                ),
                // Label badge
                Positioned(
                  bottom: 3, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget.isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        widget.panel.label.isNotEmpty ? widget.panel.label : widget.panel.openingType.shortLabel,
                        style: const TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w700,
                          color: Colors.white, fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                // Slice overlay
                if (_sliceStart != null && _sliceEnd != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SlicePainter(_sliceStart!, _sliceEnd!),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    );
  }

  Color _getPanelColor() {
    switch (widget.panel.openingType) {
      case OpeningType.fixed: return const Color(0xFFE8F4FD);
      case OpeningType.casement: return const Color(0xFFFFF8E1);
      case OpeningType.louvre: return const Color(0xFFEFEBE9);
      case OpeningType.folding3:
      case OpeningType.folding4:
        return const Color(0xFFF3E5F5);
      case OpeningType.slidingLeftRight:
      case OpeningType.slidingUpDown:
      case OpeningType.sliding2Daun:
      case OpeningType.sliding3Daun:
      case OpeningType.sliding4Daun:
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFFCE4EC); // Swing doors
    }
  }
}

class _SlicePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  _SlicePainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6D00)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    
    if (dx.abs() > dy.abs()) {
      _drawDashedLine(canvas, Offset(0, start.dy), Offset(size.width, start.dy), paint);
    } else {
      _drawDashedLine(canvas, Offset(start.dx, 0), Offset(start.dx, size.height), paint);
    }
  }
  
  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final ux = dx / dist, uy = dy / dist;
    var d = 0.0;
    while (d < dist) {
      final e = min(d + 4, dist);
      canvas.drawLine(Offset(a.dx + ux * d, a.dy + uy * d), Offset(a.dx + ux * e, a.dy + uy * e), paint);
      d += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _SlicePainter old) => old.start != start || old.end != end;
}

class _OpeningPainter extends CustomPainter {
  final OpeningType type;
  final bool isSelected;
  final String swingDirection;

  _OpeningPainter(this.type, this.isSelected, this.swingDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final frameColor = isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A);
    
    // Draw styles
    final outlinePaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = frameColor.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = (isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A)).withAlpha(8);

    final glassReflectPaint = Paint()
      ..color = Colors.blue.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    switch (type) {
      case OpeningType.fixed:
        // Draw cross reflections
        canvas.drawLine(Offset(size.width * 0.2, size.height * 0.2), Offset(size.width * 0.4, size.height * 0.4), glassReflectPaint);
        canvas.drawLine(Offset(size.width * 0.6, size.height * 0.6), Offset(size.width * 0.8, size.height * 0.8), glassReflectPaint);
        break;

      case OpeningType.casement:
        // 1. Draw inner sash frame (inset by 8px)
        final sashRect = Rect.fromLTRB(8, 8, size.width - 8, size.height - 8);
        canvas.drawRect(sashRect, fillPaint);
        canvas.drawRect(sashRect, outlinePaint);

        // 2. Draw dashed triangle lines depending on swingDirection
        final double left = sashRect.left;
        final double right = sashRect.right;
        final double top = sashRect.top;
        final double bottom = sashRect.bottom;
        final double midX = sashRect.center.dx;
        final double midY = sashRect.center.dy;

        final path = Path();
        if (swingDirection == 'left') {
          path.moveTo(left, top);
          path.lineTo(right, midY);
          path.lineTo(left, bottom);
        } else if (swingDirection == 'right') {
          path.moveTo(right, top);
          path.lineTo(left, midY);
          path.lineTo(right, bottom);
        } else if (swingDirection == 'top') {
          path.moveTo(left, top);
          path.lineTo(midX, bottom);
          path.lineTo(right, top);
        } else if (swingDirection == 'bottom') {
          path.moveTo(left, bottom);
          path.lineTo(midX, top);
          path.lineTo(right, bottom);
        }
        _drawPathDashed(canvas, path, dashPaint);
        break;

      case OpeningType.glassSingle:
      case OpeningType.acpSingle:
      case OpeningType.panelSingle:
        // 1. Draw inner door leaf (inset by 8px)
        final doorRect = Rect.fromLTRB(8, 8, size.width - 8, size.height);
        canvas.drawRect(doorRect, fillPaint);
        canvas.drawRect(doorRect, outlinePaint);

        // ACP or Panel fill details
        if (type == OpeningType.acpSingle) {
          final midY = doorRect.center.dy;
          canvas.drawLine(Offset(doorRect.left, midY), Offset(doorRect.right, midY), outlinePaint..strokeWidth = 0.5);
          canvas.drawLine(Offset(doorRect.left, midY - 20), Offset(doorRect.right, midY - 20), outlinePaint..strokeWidth = 0.5);
          canvas.drawLine(Offset(doorRect.left, midY + 20), Offset(doorRect.right, midY + 20), outlinePaint..strokeWidth = 0.5);
        } else if (type == OpeningType.panelSingle) {
          for (int i = 1; i <= 3; i++) {
            final x = doorRect.left + (doorRect.width * (i / 4));
            canvas.drawLine(Offset(x, doorRect.top), Offset(x, doorRect.bottom), outlinePaint..strokeWidth = 0.5);
          }
        } else {
          canvas.drawLine(Offset(doorRect.left + 15, doorRect.top + 15), Offset(doorRect.left + 35, doorRect.top + 35), glassReflectPaint);
        }

        // 2. Render vertical pull handle
        final isLeftHinge = swingDirection == 'left';
        final handleX = isLeftHinge ? doorRect.right - 14 : doorRect.left + 10;
        final handleY = doorRect.center.dy - 20;
        final handleRect = Rect.fromLTWH(handleX, handleY, 4, 40);
        
        final handlePaint = Paint()
          ..color = frameColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(handleRect, handlePaint);

        // 3. Draw swing elevation dashed lines
        final pathSwing = Path();
        if (isLeftHinge) {
          pathSwing.moveTo(doorRect.left, doorRect.top);
          pathSwing.lineTo(doorRect.right, doorRect.center.dy);
          pathSwing.lineTo(doorRect.left, doorRect.bottom);
        } else {
          pathSwing.moveTo(doorRect.right, doorRect.top);
          pathSwing.lineTo(doorRect.left, doorRect.center.dy);
          pathSwing.lineTo(doorRect.right, doorRect.bottom);
        }
        _drawPathDashed(canvas, pathSwing, dashPaint);
        break;

      case OpeningType.glassDouble:
      case OpeningType.acpDouble:
      case OpeningType.panelDouble:
        final wHalf = size.width / 2;
        
        final leafL = Rect.fromLTRB(8, 8, wHalf, size.height);
        canvas.drawRect(leafL, fillPaint);
        canvas.drawRect(leafL, outlinePaint);

        final leafR = Rect.fromLTRB(wHalf, 8, size.width - 8, size.height);
        canvas.drawRect(leafR, fillPaint);
        canvas.drawRect(leafR, outlinePaint);

        final handlePaintD = Paint()..color = frameColor..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(wHalf - 6, size.height / 2 - 20, 3, 40), handlePaintD);
        canvas.drawRect(Rect.fromLTWH(wHalf + 3, size.height / 2 - 20, 3, 40), handlePaintD);

        if (type == OpeningType.acpDouble) {
          canvas.drawLine(Offset(leafL.left, leafL.center.dy), Offset(leafL.right, leafL.center.dy), outlinePaint..strokeWidth = 0.5);
          canvas.drawLine(Offset(leafR.left, leafR.center.dy), Offset(leafR.right, leafR.center.dy), outlinePaint..strokeWidth = 0.5);
        }

        final pathL = Path()
          ..moveTo(leafL.left, leafL.top)
          ..lineTo(leafL.right, leafL.center.dy)
          ..lineTo(leafL.left, leafL.bottom);
        _drawPathDashed(canvas, pathL, dashPaint);

        final pathR = Path()
          ..moveTo(leafR.right, leafR.top)
          ..lineTo(leafR.left, leafR.center.dy)
          ..lineTo(leafR.right, leafR.bottom);
        _drawPathDashed(canvas, pathR, dashPaint);
        break;

      case OpeningType.slidingLeftRight:
      case OpeningType.sliding2Daun:
      case OpeningType.sliding3Daun:
      case OpeningType.sliding4Daun:
        int numPanels = 2;
        if (type == OpeningType.sliding3Daun) numPanels = 3;
        if (type == OpeningType.sliding4Daun) numPanels = 4;

        final wPanel = size.width / numPanels;
        for (int i = 0; i < numPanels; i++) {
          final xStart = i * wPanel + (i > 0 ? -4.0 : 0.0);
          final xEnd = (i + 1) * wPanel + (i < numPanels - 1 ? 4.0 : 0.0);
          
          final pRect = Rect.fromLTRB(xStart + 4, 8, xEnd - 4, size.height - 8);
          canvas.drawRect(pRect, fillPaint);
          canvas.drawRect(pRect, outlinePaint);
          
          canvas.drawLine(Offset(pRect.left + 8, pRect.top + 8), Offset(pRect.left + 16, pRect.top + 16), glassReflectPaint);
        }
        _drawHorizontalArrows(canvas, size, outlinePaint);
        break;

      case OpeningType.slidingUpDown:
        final hHalf = size.height / 2;
        final topRect = Rect.fromLTRB(8, 8, size.width - 8, hHalf + 3);
        final botRect = Rect.fromLTRB(8, hHalf - 3, size.width - 8, size.height - 8);
        
        canvas.drawRect(topRect, fillPaint);
        canvas.drawRect(topRect, outlinePaint);
        canvas.drawRect(botRect, fillPaint);
        canvas.drawRect(botRect, outlinePaint);
        
        _drawVerticalArrows(canvas, size, outlinePaint);
        break;

      case OpeningType.folding3:
      case OpeningType.folding4:
        _drawFolding(canvas, size, outlinePaint, type == OpeningType.folding3 ? 3 : 4);
        break;

      case OpeningType.louvre:
        _drawSlats(canvas, size, outlinePaint);
        break;
    }
  }

  void _drawHorizontalArrows(Canvas canvas, Size size, Paint paint) {
    final p = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final cy = size.height / 2;
    final m = size.width * 0.2;
    final e = size.width * 0.8;
    final a = 6.0;
    
    canvas.drawLine(Offset(m, cy), Offset(e, cy), p);
    canvas.drawLine(Offset(e, cy), Offset(e - a, cy - a), p);
    canvas.drawLine(Offset(e, cy), Offset(e - a, cy + a), p);
    canvas.drawLine(Offset(m, cy), Offset(m + a, cy - a), p);
    canvas.drawLine(Offset(m, cy), Offset(m + a, cy + a), p);
  }

  void _drawVerticalArrows(Canvas canvas, Size size, Paint paint) {
    final p = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final m = size.height * 0.2;
    final e = size.height * 0.8;
    final a = 6.0;
    
    canvas.drawLine(Offset(cx, m), Offset(cx, e), p);
    canvas.drawLine(Offset(cx, e), Offset(cx - a, e - a), p);
    canvas.drawLine(Offset(cx, e), Offset(cx + a, e - a), p);
    canvas.drawLine(Offset(cx, m), Offset(cx - a, m + a), p);
    canvas.drawLine(Offset(cx, m), Offset(cx + a, m + a), p);
  }

  void _drawFolding(Canvas canvas, Size size, Paint paint, int segs) {
    final segW = size.width / segs;
    final path = Path()..moveTo(0, size.height * 0.3);
    for (int i = 0; i < segs; i++) {
      final x1 = segW * i + segW / 2;
      final y1 = i.isEven ? size.height * 0.7 : size.height * 0.3;
      path.lineTo(x1, y1);
      if (i < segs - 1) path.lineTo(segW * (i + 1), i.isEven ? size.height * 0.3 : size.height * 0.7);
    }
    canvas.drawPath(path, paint);
  }

  void _drawSlats(Canvas canvas, Size size, Paint paint) {
    for (int i = 1; i < 8; i++) {
      final y = size.height * (i / 8);
      canvas.drawLine(Offset(4, y - 1.5), Offset(size.width - 4, y + 1.5), paint);
    }
  }

  void _drawPathDashed(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var d = 0.0;
      while (d < metric.length) {
        final len = min(4.0, metric.length - d);
        final segment = metric.extractPath(d, d + len);
        canvas.drawPath(segment, paint);
        d += 8.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OpeningPainter old) =>
      old.type != type || old.isSelected != isSelected || old.swingDirection != swingDirection;
}
