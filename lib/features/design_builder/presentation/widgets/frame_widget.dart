import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/design_models.dart';

/// Represents a 1D range of space along a border where it is hidden.
class BorderRange {
  final double start;
  final double end;
  const BorderRange(this.start, this.end);
}

/// Renders a single frame on canvas with panels, mullions, and resize handles.
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
  final Function(PanelNode, bool)? onSubPanelTap; // true for width, false for height
  final VoidCallback? onActionStart;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final double frameThickness;
  final double mullionThickness;
  final double currentScale;
  final bool hideLeftBorder;
  final bool hideRightBorder;
  final bool hideTopBorder;
  final bool hideBottomBorder;
  final List<BorderRange> hideLeftRanges;
  final List<BorderRange> hideRightRanges;
  final List<BorderRange> hideTopRanges;
  final List<BorderRange> hideBottomRanges;

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
    this.onSubPanelTap,
    this.onActionStart,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.frameThickness = 0.5,
    this.mullionThickness = 5.0,
    this.currentScale = 1.0,
    this.hideLeftBorder = false,
    this.hideRightBorder = false,
    this.hideTopBorder = false,
    this.hideBottomBorder = false,
    this.hideLeftRanges = const [],
    this.hideRightRanges = const [],
    this.hideTopRanges = const [],
    this.hideBottomRanges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final frameColor = isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A);
    final fThickness = frameThickness * FrameNode.pxPerCm * 0.5;
    final labelScale = (1.0 / currentScale).clamp(1.0, 5.0);

    final List<BorderRange> effectiveLeftRanges = hideLeftBorder
        ? [BorderRange(0, frame.renderHeight)]
        : hideLeftRanges;
    final List<BorderRange> effectiveRightRanges = hideRightBorder
        ? [BorderRange(0, frame.renderHeight)]
        : hideRightRanges;
    final List<BorderRange> effectiveTopRanges = hideTopBorder
        ? [BorderRange(0, frame.renderWidth)]
        : hideTopRanges;
    final List<BorderRange> effectiveBottomRanges = hideBottomBorder
        ? [BorderRange(0, frame.renderWidth)]
        : hideBottomRanges;

    Widget frameContent;
    if (frame.type == FrameType.lengkung) {
      frameContent = ClipPath(
        clipper: ArchedFrameClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              left: hideLeftBorder ? BorderSide.none : BorderSide(color: frameColor, width: fThickness),
              right: hideRightBorder ? BorderSide.none : BorderSide(color: frameColor, width: fThickness),
              bottom: hideBottomBorder ? BorderSide.none : BorderSide(color: frameColor, width: fThickness),
            ),
          ),
          child: CustomPaint(
            foregroundPainter: ArchedBorderPainter(frameColor, fThickness),
            child: _buildPanelTree(frame.rootPanel, labelScale),
          ),
        ),
      );
    } else {
      frameContent = CustomPaint(
        foregroundPainter: FrameBorderPainter(
          frameColor: frameColor,
          thickness: fThickness,
          frameType: frame.type,
          hideLeftRanges: effectiveLeftRanges,
          hideRightRanges: effectiveRightRanges,
          hideTopRanges: effectiveTopRanges,
          hideBottomRanges: effectiveBottomRanges,
        ),
        child: Container(
          color: Colors.transparent,
          child: CustomPaint(
            foregroundPainter: frame.type == FrameType.sudut ? CornerPostPainter(frameColor, fThickness) : null,
            child: _buildPanelTree(frame.rootPanel, labelScale),
          ),
        ),
      );
    }

    return SizedBox(
      width: frame.renderWidth,
      height: frame.renderHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onFrameTap,
              child: frameContent,
            ),
          ),
          _buildDimensionLabels(labelScale),
          if (isSelected) ...[
            Positioned(
              top: -37.0 * labelScale,
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
                behavior: HitTestBehavior.translucent,
                child: Container(
                  height: 48.0 * labelScale,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: Container(
                    height: 22.0 * labelScale,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4.0 * labelScale)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drag_indicator, color: Colors.white, size: 14.0 * labelScale),
                        SizedBox(width: 4.0 * labelScale),
                        Text(
                          frame.label.isNotEmpty ? frame.label : frame.type.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.0 * labelScale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ..._buildResizeHandles(),
          ],
        ],
      ),
    );
  }

  Widget _buildDimensionLabels(double labelScale) {
    final layouts = frame.getPanelLayouts(
      frameThickness: frameThickness,
      mullionThickness: mullionThickness,
    );
    final N = 1;
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

    final hasVertSplits = frame.rootPanel.hasVerticalSplit();
    final hasHorizSplits = frame.rootPanel.hasHorizontalSplit();
    final isSplit = !frame.rootPanel.isLeaf;

    final List<Widget> children = [];
    if (!isSplit) {
      children.add(
        Positioned(
          top: -54.0 * labelScale,
          left: 0,
          right: 0,
          child: CustomPaint(
            painter: DimensionLinePainter(isHorizontal: true),
            child: Center(
              child: GestureDetector(
                onTap: onWidthTap,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: 48.0 * labelScale,
                    minHeight: 48.0 * labelScale,
                  ),
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.0 * labelScale, vertical: 4.0 * labelScale),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F0),
                      border: Border.all(color: const Color(0xFFFF6D00).withAlpha(100), width: 1.0 * labelScale),
                      borderRadius: BorderRadius.circular(4.0 * labelScale),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${frame.widthCm.toStringAsFixed(0)} cm',
                          style: TextStyle(
                            fontSize: 12.0 * labelScale, fontWeight: FontWeight.w600,
                            color: const Color(0xFF424242), fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(width: 4.0 * labelScale),
                        Icon(Icons.edit_outlined, size: 12.0 * labelScale, color: const Color(0xFFFF6D00)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!isSplit) {
      children.add(
        Positioned(
          top: 0,
          bottom: 0,
          left: -48.0 * labelScale,
          child: CustomPaint(
            painter: DimensionLinePainter(isHorizontal: false),
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: GestureDetector(
                  onTap: onHeightTap,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: 48.0 * labelScale,
                      minHeight: 48.0 * labelScale,
                    ),
                    alignment: Alignment.center,
                    color: Colors.transparent,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.0 * labelScale, vertical: 4.0 * labelScale),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F0),
                        border: Border.all(color: const Color(0xFFFF6D00).withAlpha(100), width: 1.0 * labelScale),
                        borderRadius: BorderRadius.circular(4.0 * labelScale),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${frame.heightCm.toStringAsFixed(0)} cm',
                            style: TextStyle(
                              fontSize: 12.0 * labelScale, fontWeight: FontWeight.w600,
                              color: const Color(0xFF424242), fontFamily: 'monospace',
                            ),
                          ),
                          SizedBox(width: 4.0 * labelScale),
                          Icon(Icons.edit_outlined, size: 12.0 * labelScale, color: const Color(0xFFFF6D00)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final layout in layouts) {
      if (!layout.panel.isLeaf) continue;
      if (layout.panel.opening.type == 'spacer') continue;

      // 1. Vertical split height labels (rendered on the right side of the frame or along internal mullions)
      final isRightmost = (layout.rect.right - innerRect.right).abs() < 2.0;
      final showHeightLabel = (hasHorizSplits && layout.heightCm < innerHeightCm - 0.1) ||
                              (isSplit && !hasHorizSplits && isRightmost);
      if (showHeightLabel) {
        children.add(
          Positioned(
            top: layout.rect.top,
            height: layout.rect.height,
            right: isRightmost ? -48.0 * labelScale : null,
            left: isRightmost ? null : layout.rect.right - 24.0 * labelScale,
            width: 48.0 * labelScale,
            child: CustomPaint(
              painter: DimensionLinePainter(isHorizontal: false),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: GestureDetector(
                    onTap: () => onSubPanelTap?.call(layout.panel, false),
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: 48.0 * labelScale,
                        minHeight: 48.0 * labelScale,
                      ),
                      alignment: Alignment.center,
                      color: Colors.transparent,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.0 * labelScale, vertical: 3.0 * labelScale),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F0),
                          border: Border.all(color: const Color(0xFFFF6D00).withAlpha(100), width: 0.8 * labelScale),
                          borderRadius: BorderRadius.circular(3.0 * labelScale),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${layout.heightCm.toStringAsFixed(0)} cm',
                              style: TextStyle(
                                fontSize: 10.5 * labelScale, fontWeight: FontWeight.w600,
                                color: const Color(0xFF424242), fontFamily: 'monospace',
                              ),
                            ),
                            SizedBox(width: 3.0 * labelScale),
                            Icon(Icons.edit_outlined, size: 10.5 * labelScale, color: const Color(0xFFFF6D00)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // 2. Horizontal split width labels (rendered at the bottom of the frame or along internal transoms)
      final isBottommost = (layout.rect.bottom - innerRect.bottom).abs() < 2.0;
      final showWidthLabel = (hasVertSplits && layout.widthCm < innerWidthCm - 0.1) ||
                             (isSplit && !hasVertSplits && isBottommost);
      if (showWidthLabel) {
        children.add(
          Positioned(
            left: layout.rect.left,
            width: layout.rect.width,
            bottom: isBottommost ? -54.0 * labelScale : frame.renderHeight - layout.rect.bottom - 24.0 * labelScale,
            height: 48.0 * labelScale,
            child: CustomPaint(
              painter: DimensionLinePainter(isHorizontal: true),
              child: Center(
                child: GestureDetector(
                  onTap: () => onSubPanelTap?.call(layout.panel, true),
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: 48.0 * labelScale,
                      minHeight: 48.0 * labelScale,
                    ),
                    alignment: Alignment.center,
                    color: Colors.transparent,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.0 * labelScale, vertical: 3.0 * labelScale),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F0),
                        border: Border.all(color: const Color(0xFFFF6D00).withAlpha(100), width: 0.8 * labelScale),
                        borderRadius: BorderRadius.circular(3.0 * labelScale),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${layout.widthCm.toStringAsFixed(0)} cm',
                            style: TextStyle(
                              fontSize: 10.5 * labelScale, fontWeight: FontWeight.w600,
                              color: const Color(0xFF424242), fontFamily: 'monospace',
                            ),
                          ),
                          SizedBox(width: 3.0 * labelScale),
                          Icon(Icons.edit_outlined, size: 10.5 * labelScale, color: const Color(0xFFFF6D00)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: children,
    );
  }

  List<Widget> _buildResizeHandles() {
    final labelScale = (1.0 / currentScale).clamp(1.0, 5.0);
    final handleSize = 12.0 * labelScale;
    final hs = handleSize / 2;
    final hitSize = 48.0 * labelScale;
    final offsetShift = hitSize / 2;

    Widget handle(String id, double? left, double? top, double? right, double? bottom, MouseCursor cursor) {
      final double? adjustedLeft = left != null ? left - (offsetShift - hs) : null;
      final double? adjustedTop = top != null ? top - (offsetShift - hs) : null;
      final double? adjustedRight = right != null ? right - (offsetShift - hs) : null;
      final double? adjustedBottom = bottom != null ? bottom - (offsetShift - hs) : null;

      return Positioned(
        left: adjustedLeft, top: adjustedTop, right: adjustedRight, bottom: adjustedBottom,
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
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: hitSize, height: hitSize,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Container(
                width: handleSize, height: handleSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00),
                  border: Border.all(color: Colors.white, width: 1.5 * labelScale),
                  borderRadius: BorderRadius.circular(2 * labelScale),
                ),
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

  Widget _buildPanelTree(PanelNode panel, double labelScale) {
    final double visualMullionThickness = mullionThickness * 0.5; // Visual thickness is halved

    if (panel.isLeaf) {
      return _LeafPanelWidget(
        panel: panel,
        isSelected: panel.id == selectedPanelId,
        onTap: () => onPanelTap(panel),
        framePxPerCm: FrameNode.pxPerCm,
        onSlice: (dir, ratio) => onPanelSlice(panel, dir, ratio),
        labelScale: labelScale,
        profileCount: frame.profileCount,
      );
    }

    final isH = panel.splitDirection == SplitDirection.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = isH ? constraints.maxWidth : constraints.maxHeight;
        
        double totalMullionPx = panel.mullions.fold(0.0, (a, m) => a + (visualMullionThickness * FrameNode.pxPerCm));
        double availableSize = totalSize - totalMullionPx;

        final totalFlex = panel.childFlex.fold(0.0, (a, b) => a + b);
        if (totalFlex <= 0 || availableSize <= 0) return const SizedBox();

        List<Widget> items = [];
        double offset = 0;

        for (int i = 0; i < panel.children.length; i++) {
          final flex = panel.childFlex.length > i ? panel.childFlex[i] : 1.0;
          final size = availableSize * (flex / totalFlex);

          if (isH) {
            items.add(Positioned(
              left: offset, top: 0, width: size, bottom: 0,
              child: _buildPanelTree(panel.children[i], labelScale),
            ));
          } else {
            items.add(Positioned(
              left: 0, top: offset, right: 0, height: size,
              child: _buildPanelTree(panel.children[i], labelScale),
            ));
          }

          offset += size;

          if (i < panel.children.length - 1 && i < panel.mullions.length) {
            final mThickness = visualMullionThickness * FrameNode.pxPerCm;
            
            // Draw actual Mullion Object
            items.add(Positioned(
              left: isH ? offset : 0,
              top: isH ? 0 : offset,
              width: isH ? mThickness : null,
              height: isH ? null : mThickness,
              right: isH ? null : 0,
              bottom: isH ? 0 : null,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border(
                    left: isH ? const BorderSide(color: Colors.white24, width: 1) : BorderSide.none,
                    right: isH ? const BorderSide(color: Colors.white24, width: 1) : BorderSide.none,
                    top: !isH ? const BorderSide(color: Colors.white24, width: 1) : BorderSide.none,
                    bottom: !isH ? const BorderSide(color: Colors.white24, width: 1) : BorderSide.none,
                  )
                ),
              ),
            ));
            
            // Interactive Drag Overlay for Divider (Mullion Dragging)
            items.add(_buildDivider(panel, i, offset + (mThickness / 2), isH, totalSize));
            
            offset += mThickness;
          }
        }

        return Stack(children: items);
      },
    );
  }

  Widget _buildDivider(PanelNode parent, int index, double pos, bool isH, double totalSize) {
    const hitSize = 24.0;

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
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            onActionStart?.call();
            onInteractionStart?.call();
          },
          onPanUpdate: (details) => onDividerDrag(parent, index, details, isH),
          onPanEnd: (details) => onInteractionEnd?.call(),
          onPanCancel: () => onInteractionEnd?.call(),
          child: Container(
            color: Colors.transparent, // Invisible hit area
          ),
        ),
      ),
    );
  }
}

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

class CornerPostPainter extends CustomPainter {
  final Color color;
  final double width;
  CornerPostPainter(this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = width;
    final fillPaint = Paint()..color = color.withAlpha(20)..style = PaintingStyle.fill;
    final colW = 40.0;
    final rect = Rect.fromLTWH(size.width - colW, 0, colW, size.height);

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, paint);

    final linePaint = Paint()..color = color.withAlpha(120)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawLine(Offset(size.width - colW, 0), Offset(size.width, size.height), linePaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - colW, size.height), linePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class DimensionLinePainter extends CustomPainter {
  final bool isHorizontal;
  DimensionLinePainter({required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF9E9E9E)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    if (isHorizontal) {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      canvas.drawLine(Offset(0, y - 4), Offset(0, y + 4), paint);
      canvas.drawLine(Offset(size.width, y - 4), Offset(size.width, y + 4), paint);
    } else {
      final x = size.width / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(x - 4, 0), Offset(x + 4, 0), paint);
      canvas.drawLine(Offset(x - 4, size.height), Offset(x + 4, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _LeafPanelWidget extends StatefulWidget {
  final PanelNode panel;
  final bool isSelected;
  final VoidCallback onTap;
  final double framePxPerCm;
  final Function(SplitDirection, double) onSlice;
  final double labelScale;
  final int profileCount;

  const _LeafPanelWidget({
    required this.panel,
    required this.isSelected,
    required this.onTap,
    required this.framePxPerCm,
    required this.onSlice,
    required this.labelScale,
    required this.profileCount,
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
          final ratio = (_sliceStart!.dy / size.height).clamp(0.1, 0.9);
          widget.onSlice(SplitDirection.vertical, ratio);
        } else {
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
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CustomPaint(
                      painter: _OpeningPainter(
                        widget.panel.opening,
                        widget.isSelected,
                        widget.profileCount,
                      ),
                    ),
                  ),
                ),
                if (widget.panel.opening.type != 'spacer')
                Positioned(
                  bottom: 3 * widget.labelScale, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 5 * widget.labelScale, vertical: 1 * widget.labelScale),
                      decoration: BoxDecoration(
                        color: widget.isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(2 * widget.labelScale),
                      ),
                      child: Text(
                        widget.panel.label.isNotEmpty ? widget.panel.label : widget.panel.opening.shortLabel,
                        style: TextStyle(
                          fontSize: 8 * widget.labelScale, fontWeight: FontWeight.w700,
                          color: Colors.white, fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
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
    if (widget.panel.opening.type == 'spacer') return Colors.transparent;
    switch (widget.panel.opening.type) {
      case 'fixed': return const Color(0xFFE8F4FD);
      case 'casement': return const Color(0xFFFFF8E1);
      case 'louvre': return const Color(0xFFEFEBE9);
      case 'folding': return const Color(0xFFF3E5F5);
      case 'sliding': return const Color(0xFFE8F5E9);
      default: return const Color(0xFFFCE4EC); // Swing doors
    }
  }
}

class _SlicePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  _SlicePainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF6D00)..strokeWidth = 2.0..style = PaintingStyle.stroke;
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
  final OpeningTypeNode opening;
  final bool isSelected;
  final int profileCount;

  _OpeningPainter(this.opening, this.isSelected, this.profileCount);

  @override
  void paint(Canvas canvas, Size size) {
    if (opening.type == 'spacer') return;
    final frameColor = isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A);
    final outlinePaint = Paint()..color = frameColor..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final dashPaint = Paint()..color = frameColor.withAlpha(120)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final fillPaint = Paint()..color = (isSelected ? const Color(0xFFFF6D00) : const Color(0xFF1A1A1A)).withAlpha(8);
    final glassReflectPaint = Paint()..color = Colors.blue.withAlpha(20)..style = PaintingStyle.stroke..strokeWidth = 0.8;

    switch (opening.type) {
      case 'fixed':
        canvas.drawLine(Offset(size.width * 0.2, size.height * 0.2), Offset(size.width * 0.4, size.height * 0.4), glassReflectPaint);
        canvas.drawLine(Offset(size.width * 0.6, size.height * 0.6), Offset(size.width * 0.8, size.height * 0.8), glassReflectPaint);
        break;

      case 'casement':
        final sashForPath = profileCount == 3
            ? Rect.fromLTRB(14, 14, size.width - 14, size.height - 14)
            : Rect.fromLTRB(8, 8, size.width - 8, size.height - 8);

        if (profileCount == 3) {
          final outerSash = Rect.fromLTRB(6, 6, size.width - 6, size.height - 6);
          canvas.drawRect(outerSash, fillPaint);
          canvas.drawRect(outerSash, outlinePaint);
          canvas.drawRect(sashForPath, outlinePaint);
        } else {
          canvas.drawRect(sashForPath, fillPaint);
          canvas.drawRect(sashForPath, outlinePaint);
        }

        final path = Path();
        if (opening.direction == 'left') {
          // Hinge left, triangle points right
          path.moveTo(sashForPath.left, sashForPath.top);
          path.lineTo(sashForPath.right, sashForPath.center.dy);
          path.lineTo(sashForPath.left, sashForPath.bottom);
        } else if (opening.direction == 'right') {
          // Hinge right, triangle points left
          path.moveTo(sashForPath.right, sashForPath.top);
          path.lineTo(sashForPath.left, sashForPath.center.dy);
          path.lineTo(sashForPath.right, sashForPath.bottom);
        } else if (opening.direction == 'top') {
          // Hinge top, triangle points down
          path.moveTo(sashForPath.left, sashForPath.top);
          path.lineTo(sashForPath.center.dx, sashForPath.bottom);
          path.lineTo(sashForPath.right, sashForPath.top);
        } else if (opening.direction == 'bottom') {
          // Hinge bottom, triangle points up
          path.moveTo(sashForPath.left, sashForPath.bottom);
          path.lineTo(sashForPath.center.dx, sashForPath.top);
          path.lineTo(sashForPath.right, sashForPath.bottom);
        }
        _drawPathDashed(canvas, path, dashPaint);
        break;

      case 'swing':
        if (opening.direction == 'double') {
          final wHalf = size.width / 2;
          final leafL = Rect.fromLTRB(8, 8, wHalf, size.height);
          final leafR = Rect.fromLTRB(wHalf, 8, size.width - 8, size.height);
          canvas.drawRect(leafL, fillPaint);
          canvas.drawRect(leafL, outlinePaint);
          canvas.drawRect(leafR, fillPaint);
          canvas.drawRect(leafR, outlinePaint);

          if (opening.material == 'acp') {
            canvas.drawLine(Offset(leafL.left, leafL.center.dy), Offset(leafL.right, leafL.center.dy), outlinePaint..strokeWidth = 0.5);
            canvas.drawLine(Offset(leafR.left, leafR.center.dy), Offset(leafR.right, leafR.center.dy), outlinePaint..strokeWidth = 0.5);
          }

          final handlePaintD = Paint()..color = frameColor..style = PaintingStyle.fill;
          canvas.drawRect(Rect.fromLTWH(wHalf - 6, size.height / 2 - 20, 3, 40), handlePaintD);
          canvas.drawRect(Rect.fromLTWH(wHalf + 3, size.height / 2 - 20, 3, 40), handlePaintD);

          final pathL = Path()..moveTo(leafL.left, leafL.top)..lineTo(leafL.right, leafL.center.dy)..lineTo(leafL.left, leafL.bottom);
          _drawPathDashed(canvas, pathL, dashPaint);

          final pathR = Path()..moveTo(leafR.right, leafR.top)..lineTo(leafR.left, leafR.center.dy)..lineTo(leafR.right, leafR.bottom);
          _drawPathDashed(canvas, pathR, dashPaint);
        } else {
          final doorRect = Rect.fromLTRB(8, 8, size.width - 8, size.height);
          canvas.drawRect(doorRect, fillPaint);
          canvas.drawRect(doorRect, outlinePaint);

          if (opening.material == 'acp') {
            final midY = doorRect.center.dy;
            canvas.drawLine(Offset(doorRect.left, midY), Offset(doorRect.right, midY), outlinePaint..strokeWidth = 0.5);
          } else if (opening.material == 'panel') {
            for (int i = 1; i <= 3; i++) {
              final x = doorRect.left + (doorRect.width * (i / 4));
              canvas.drawLine(Offset(x, doorRect.top), Offset(x, doorRect.bottom), outlinePaint..strokeWidth = 0.5);
            }
          } else {
            canvas.drawLine(Offset(doorRect.left + 15, doorRect.top + 15), Offset(doorRect.left + 35, doorRect.top + 35), glassReflectPaint);
          }

          final isLeftHinge = opening.direction == 'left';
          final handleX = isLeftHinge ? doorRect.right - 14 : doorRect.left + 10;
          final handleRect = Rect.fromLTWH(handleX, doorRect.center.dy - 20, 4, 40);
          canvas.drawRect(handleRect, Paint()..color = frameColor..style = PaintingStyle.fill);

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
        }
        break;

      case 'sliding':
        int numPanels = opening.leafCount;
        final wPanel = size.width / numPanels;
        for (int i = 0; i < numPanels; i++) {
          final xStart = i * wPanel + (i > 0 ? -4.0 : 0.0);
          final xEnd = (i + 1) * wPanel + (i < numPanels - 1 ? 4.0 : 0.0);
          if (profileCount == 3) {
            final pRectOuter = Rect.fromLTRB(xStart + 3, 6, xEnd - 3, size.height - 6);
            final pRectInner = Rect.fromLTRB(xStart + 9, 12, xEnd - 9, size.height - 12);
            canvas.drawRect(pRectOuter, fillPaint);
            canvas.drawRect(pRectOuter, outlinePaint);
            canvas.drawRect(pRectInner, outlinePaint);
          } else {
            final pRect = Rect.fromLTRB(xStart + 4, 8, xEnd - 4, size.height - 8);
            canvas.drawRect(pRect, fillPaint);
            canvas.drawRect(pRect, outlinePaint);
          }
        }
        if (opening.direction == 'left' || opening.direction == 'right') {
           _drawHorizontalArrow(canvas, size, outlinePaint, opening.direction);
        } else if (opening.direction == 'double') {
           _drawHorizontalArrows(canvas, size, outlinePaint); // Bidirectional
        }
        break;

      case 'folding':
        _drawFolding(canvas, size, outlinePaint, opening.leafCount);
        break;

      case 'louvre':
        _drawSlats(canvas, size, outlinePaint);
        break;
    }
  }

  void _drawHorizontalArrow(Canvas canvas, Size size, Paint paint, String direction) {
    final p = Paint()..color = paint.color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    final cy = size.height / 2;
    final cx = size.width / 2;
    final a = 6.0;
    
    if (direction == 'left') {
      canvas.drawLine(Offset(cx + 20, cy), Offset(cx - 20, cy), p);
      canvas.drawLine(Offset(cx - 20, cy), Offset(cx - 20 + a, cy - a), p);
      canvas.drawLine(Offset(cx - 20, cy), Offset(cx - 20 + a, cy + a), p);
    } else {
      canvas.drawLine(Offset(cx - 20, cy), Offset(cx + 20, cy), p);
      canvas.drawLine(Offset(cx + 20, cy), Offset(cx + 20 - a, cy - a), p);
      canvas.drawLine(Offset(cx + 20, cy), Offset(cx + 20 - a, cy + a), p);
    }
  }

  void _drawHorizontalArrows(Canvas canvas, Size size, Paint paint) {
    final p = Paint()..color = paint.color..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
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
  bool shouldRepaint(covariant _OpeningPainter old) => true;
}

class FrameBorderPainter extends CustomPainter {
  final Color frameColor;
  final double thickness;
  final FrameType frameType;
  final List<BorderRange> hideLeftRanges;
  final List<BorderRange> hideRightRanges;
  final List<BorderRange> hideTopRanges;
  final List<BorderRange> hideBottomRanges;

  FrameBorderPainter({
    required this.frameColor,
    required this.thickness,
    required this.frameType,
    required this.hideLeftRanges,
    required this.hideRightRanges,
    required this.hideTopRanges,
    required this.hideBottomRanges,
  });

  List<BorderRange> _getVisibleSegments(double length, List<BorderRange> hiddenRanges) {
    List<BorderRange> visible = [BorderRange(0, length)];
    for (final hr in hiddenRanges) {
      List<BorderRange> nextVisible = [];
      for (final vr in visible) {
        if (hr.start >= vr.end || hr.end <= vr.start) {
          nextVisible.add(vr);
        } else {
          if (hr.start > vr.start) {
            nextVisible.add(BorderRange(vr.start, hr.start));
          }
          if (hr.end < vr.end) {
            nextVisible.add(BorderRange(hr.end, vr.end));
          }
        }
      }
      visible = nextVisible;
    }
    return visible;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = frameColor
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final t = thickness;
    final w = size.width;
    final h = size.height;

    // 1. Left border (drawn at x = t / 2)
    final leftVisible = _getVisibleSegments(h, hideLeftRanges);
    for (final seg in leftVisible) {
      canvas.drawLine(Offset(t / 2, seg.start), Offset(t / 2, seg.end), paint);
    }

    // 2. Right border (drawn at x = w - t / 2)
    final rightVisible = _getVisibleSegments(h, hideRightRanges);
    for (final seg in rightVisible) {
      canvas.drawLine(Offset(w - t / 2, seg.start), Offset(w - t / 2, seg.end), paint);
    }

    // 3. Top border (drawn at y = t / 2)
    final topVisible = _getVisibleSegments(w, hideTopRanges);
    for (final seg in topVisible) {
      canvas.drawLine(Offset(seg.start, t / 2), Offset(seg.end, t / 2), paint);
    }

    // 4. Bottom border (drawn at y = h - t / 2, only if not pintu)
    if (frameType != FrameType.pintu) {
      final bottomVisible = _getVisibleSegments(w, hideBottomRanges);
      for (final seg in bottomVisible) {
        canvas.drawLine(Offset(seg.start, h - t / 2), Offset(seg.end, h - t / 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FrameBorderPainter oldDelegate) {
    return oldDelegate.frameColor != frameColor ||
        oldDelegate.thickness != thickness ||
        oldDelegate.frameType != frameType ||
        oldDelegate.hideLeftRanges != hideLeftRanges ||
        oldDelegate.hideRightRanges != hideRightRanges ||
        oldDelegate.hideTopRanges != hideTopRanges ||
        oldDelegate.hideBottomRanges != hideBottomRanges;
  }
}
