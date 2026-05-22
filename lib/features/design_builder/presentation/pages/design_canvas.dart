import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/design_models.dart';

/// Simple non-interactive preview of a DesignCanvasModel tree of frames.
/// Used in quotation detail page for item thumbnails.
class DesignCanvas extends StatelessWidget {
  final DesignCanvasModel project;

  const DesignCanvas({
    super.key,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    if (project.frames.isEmpty) {
      return const Center(child: Icon(Icons.window_rounded, color: Colors.grey));
    }

    // Find bounding box to fit all frames in the box
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

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: project.frames.map((frame) {
            final rx = frame.x - minX;
            final ry = frame.y - minY;

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

            return Positioned(
              left: rx,
              top: ry,
              width: frame.renderWidth,
              height: frame.renderHeight,
              child: _buildFramePreview(
                frame,
                hideLeft: hideLeft,
                hideRight: hideRight,
                hideTop: hideTop,
                hideBottom: hideBottom,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFramePreview(
    FrameNode frame, {
    bool hideLeft = false,
    bool hideRight = false,
    bool hideTop = false,
    bool hideBottom = false,
  }) {
    final frameColor = const Color(0xFF1A1A1A);
    final borderWidth = 1.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: hideLeft ? BorderSide.none : BorderSide(color: frameColor, width: borderWidth),
          right: hideRight ? BorderSide.none : BorderSide(color: frameColor, width: borderWidth),
          top: hideTop ? BorderSide.none : BorderSide(color: frameColor, width: borderWidth),
          bottom: hideBottom
              ? BorderSide.none
              : (frame.type == FrameType.pintu
                  ? BorderSide(color: frameColor.withAlpha(80), width: borderWidth)
                  : BorderSide(color: frameColor, width: borderWidth)),
        ),
      ),
      child: _buildPanelTree(frame.rootPanel),
    );
  }

  Widget _buildPanelTree(PanelNode panel) {
    if (panel.isLeaf) {
      return Container(
        decoration: BoxDecoration(
          color: _getPanelColor(panel.opening),
          border: Border.all(color: const Color(0xFF1A1A1A), width: 0.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(0.5),
                child: CustomPaint(painter: _SimpleOpeningPainter(panel.opening)),
              ),
            ),
          ],
        ),
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
          offset += size;
        }

        return Stack(children: items);
      },
    );
  }

  static Color _getPanelColor(OpeningTypeNode type) {
    switch (type.type) {
      case 'fixed': return const Color(0xFFE8F4FD);
      case 'casement': return const Color(0xFFFFF8E1);
      case 'louvre': return const Color(0xFFEFEBE9);
      case 'folding': return const Color(0xFFF3E5F5);
      case 'sliding': return const Color(0xFFE8F5E9);
      default: return const Color(0xFFFCE4EC); // Swing doors
    }
  }
}

class _SimpleOpeningPainter extends CustomPainter {
  final OpeningTypeNode type;
  _SimpleOpeningPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A).withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    switch (type.type) {
      case 'fixed':
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        break;
      case 'casement':
        final path = Path()..moveTo(0, 0)..lineTo(size.width, size.height / 2)..lineTo(0, size.height);
        canvas.drawPath(path, paint);
        break;
      case 'sliding':
        final cy = size.height / 2;
        canvas.drawLine(Offset(size.width * 0.2, cy), Offset(size.width * 0.8, cy), paint);
        break;
      case 'swing':
        if (type.direction == 'double') {
            final r = (size.width / 2) * 0.8;
            canvas.drawArc(Rect.fromCircle(center: Offset(0, size.height), radius: r), -3.14159 / 2, 3.14159 / 2, false, paint);
            canvas.drawArc(Rect.fromCircle(center: Offset(size.width, size.height), radius: r), 3.14159, -3.14159 / 2, false, paint);
        } else {
            final r = min(size.width, size.height) * 0.8;
            canvas.drawArc(Rect.fromCircle(center: Offset(0, size.height), radius: r), -3.14159 / 2, 3.14159 / 2, false, paint);
        }
        break;
      case 'folding':
        for (int i = 1; i < type.leafCount; i++) {
          final x = size.width * i / type.leafCount;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
      case 'louvre':
        for (int i = 1; i < 6; i++) {
          final y = size.height * i / 6;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleOpeningPainter old) => old.type != type;
}
