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
            return Positioned(
              left: rx,
              top: ry,
              width: frame.renderWidth,
              height: frame.renderHeight,
              child: _buildFramePreview(frame),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFramePreview(FrameNode frame) {
    final frameColor = const Color(0xFF1A1A1A);
    final borderWidth = 1.0;

    return Container(
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
      child: _buildPanelTree(frame.rootPanel),
    );
  }

  Widget _buildPanelTree(PanelNode panel) {
    if (panel.isLeaf) {
      return Container(
        decoration: BoxDecoration(
          color: _getPanelColor(panel.openingType),
          border: Border.all(color: const Color(0xFF1A1A1A), width: 0.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(0.5),
                child: CustomPaint(painter: _SimpleOpeningPainter(panel.openingType)),
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

  static Color _getPanelColor(OpeningType type) {
    switch (type) {
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

class _SimpleOpeningPainter extends CustomPainter {
  final OpeningType type;
  _SimpleOpeningPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A).withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    switch (type) {
      case OpeningType.fixed:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        break;
      case OpeningType.casement:
        final path = Path()..moveTo(0, 0)..lineTo(size.width, size.height / 2)..lineTo(0, size.height);
        canvas.drawPath(path, paint);
        break;
      case OpeningType.slidingLeftRight:
      case OpeningType.sliding2Daun:
      case OpeningType.sliding3Daun:
      case OpeningType.sliding4Daun:
        final cy = size.height / 2;
        canvas.drawLine(Offset(size.width * 0.2, cy), Offset(size.width * 0.8, cy), paint);
        break;
      case OpeningType.slidingUpDown:
        final cx = size.width / 2;
        canvas.drawLine(Offset(cx, size.height * 0.2), Offset(cx, size.height * 0.8), paint);
        break;
      case OpeningType.glassSingle:
      case OpeningType.acpSingle:
      case OpeningType.panelSingle:
        final r = min(size.width, size.height) * 0.8;
        canvas.drawArc(Rect.fromCircle(center: Offset(0, size.height), radius: r), -pi / 2, pi / 2, false, paint);
        break;
      case OpeningType.glassDouble:
      case OpeningType.acpDouble:
      case OpeningType.panelDouble:
        final r = (size.width / 2) * 0.8;
        canvas.drawArc(Rect.fromCircle(center: Offset(0, size.height), radius: r), -pi / 2, pi / 2, false, paint);
        canvas.drawArc(Rect.fromCircle(center: Offset(size.width, size.height), radius: r), pi, -pi / 2, false, paint);
        break;
      case OpeningType.folding3:
      case OpeningType.folding4:
        for (int i = 1; i < 3; i++) {
          final x = size.width * i / 3;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
      case OpeningType.louvre:
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
