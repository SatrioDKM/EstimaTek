import '../../../../core/database/database_helper.dart';
import '../models/quotation_model.dart';

class QuotationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<QuotationModel>> getQuotations() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('quotations', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) => QuotationModel.fromMap(maps[i]));
  }

  Future<void> createQuotation(QuotationModel quotation) async {
    final db = await _dbHelper.database;
    await db.insert('quotations', quotation.toMap());
  }

  Future<void> updateQuotation(QuotationModel quotation) async {
    final db = await _dbHelper.database;
    await db.update(
      'quotations',
      quotation.toMap(),
      where: 'id = ?',
      whereArgs: [quotation.id],
    );
  }

  Future<void> deleteQuotation(String id) async {
    final db = await _dbHelper.database;
    await db.delete('quotation_items', where: 'quotationId = ?', whereArgs: [id]);
    await db.delete('quotations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<QuotationItemModel>> getQuotationItems(String quotationId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quotation_items',
      where: 'quotationId = ?',
      whereArgs: [quotationId],
    );
    return List.generate(maps.length, (i) => QuotationItemModel.fromMap(maps[i]));
  }

  Future<void> addQuotationItem(QuotationItemModel item) async {
    final db = await _dbHelper.database;
    await db.insert('quotation_items', item.toMap());
    await _updateQuotationTotal(item.quotationId);
  }

  Future<void> deleteQuotationItem(String itemId, String quotationId) async {
    final db = await _dbHelper.database;
    await db.delete('quotation_items', where: 'id = ?', whereArgs: [itemId]);
    await _updateQuotationTotal(quotationId);
  }

  Future<void> _updateQuotationTotal(String quotationId) async {
    final db = await _dbHelper.database;
    final items = await getQuotationItems(quotationId);
    double total = 0;
    for (var item in items) {
      total += item.itemTotal;
    }
    await db.update(
      'quotations',
      {'subtotal': total, 'grandTotal': total},
      where: 'id = ?',
      whereArgs: [quotationId],
    );
  }

  Future<void> updateQuotationItemTotal(String itemId, double itemTotal) async {
    final db = await _dbHelper.database;
    await db.update(
      'quotation_items',
      {'itemTotal': itemTotal},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> updateQuotationGrandTotal(String quotationId, double grandTotal) async {
    final db = await _dbHelper.database;
    await db.update(
      'quotations',
      {'grandTotal': grandTotal, 'subtotal': grandTotal},
      where: 'id = ?',
      whereArgs: [quotationId],
    );
  }
}

