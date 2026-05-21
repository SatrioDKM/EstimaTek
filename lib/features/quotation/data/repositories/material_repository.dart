import '../../../../core/database/database_helper.dart';

class MaterialModel {
  final String id;
  final String category;
  final String name;
  final double price;
  final String unit;
  final String rules;

  MaterialModel({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    required this.unit,
    this.rules = '{}',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'price': price,
      'unit': unit,
      'rules': rules,
    };
  }

  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: map['id'],
      category: map['category'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      unit: map['unit'],
      rules: map['rules'] ?? '{}',
    );
  }
}

class MaterialRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<MaterialModel>> getMaterials() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('materials', orderBy: 'category, name');
    return List.generate(maps.length, (i) => MaterialModel.fromMap(maps[i]));
  }

  Future<void> updateMaterialPrice(String id, double newPrice) async {
    final db = await _dbHelper.database;
    await db.update(
      'materials',
      {'price': newPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
