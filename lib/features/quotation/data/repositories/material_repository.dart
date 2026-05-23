import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';

class MaterialModel {
  final String id;
  final String category;
  final String name;
  final double price;
  final String unit;
  final String rules;
  final int isDeleted;

  MaterialModel({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    required this.unit,
    this.rules = '{}',
    this.isDeleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'price': price,
      'unit': unit,
      'rules': rules,
      'is_deleted': isDeleted,
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
      isDeleted: map['is_deleted'] ?? 0,
    );
  }
}

class MaterialRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<MaterialModel>> getMaterials({bool includeDeleted = false}) async {
    final db = await _dbHelper.database;
    final where = includeDeleted ? null : 'is_deleted = 0';
    final List<Map<String, dynamic>> maps = await db.query(
      'materials',
      where: where,
      orderBy: 'category, name',
    );
    return List.generate(maps.length, (i) => MaterialModel.fromMap(maps[i]));
  }

  Future<void> updateMaterial(MaterialModel material) async {
    final db = await _dbHelper.database;
    await db.update(
      'materials',
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }

  Future<void> insertMaterial(MaterialModel material) async {
    final db = await _dbHelper.database;
    await db.insert(
      'materials',
      material.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMaterial(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'materials',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
