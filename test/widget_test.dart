import 'package:flutter_test/flutter_test.dart';
import 'package:estimatek/features/design_builder/data/models/design_models.dart';

void main() {
  group('CAD Model and Panel Geometry Tests', () {
    test('Should initialize with correct default sizes', () {
      final frame = FrameNode(widthCm: 120, heightCm: 150);
      expect(frame.widthCm, 120);
      expect(frame.heightCm, 150);
      expect(frame.type, FrameType.jendela);
      expect(frame.rootPanel.isLeaf, isTrue);
    });

    test('Should split panel node vertically into equal parts', () {
      final panel = PanelNode();
      expect(panel.isLeaf, isTrue);
      expect(panel.leafCount, 1);

      panel.splitEqually(SplitDirection.vertical, 3);
      expect(panel.isLeaf, isFalse);
      expect(panel.leafCount, 3);
      expect(panel.childFlex.length, 3);
      expect(panel.childFlex[0], 1/3);
    });

    test('Should calculate correct leaf nodes on nested split levels', () {
      final panel = PanelNode();
      panel.split(SplitDirection.horizontal, 0.4); // 2 panels (0.4 and 0.6 flex)
      
      expect(panel.leafCount, 2);
      
      // Split the second panel into 3 sub-panels
      panel.children[1].splitEqually(SplitDirection.vertical, 3);
      expect(panel.leafCount, 4); // panel[0] (1) + panel[1] (3) = 4 panels
    });

    test('Should support panel merge and reset to single leaf', () {
      final panel = PanelNode();
      panel.splitEqually(SplitDirection.vertical, 2);
      expect(panel.isLeaf, isFalse);

      panel.merge();
      expect(panel.isLeaf, isTrue);
      expect(panel.leafCount, 1);
    });
  });
}
