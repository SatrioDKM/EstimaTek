import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'estimatek_v3.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Clear old materials and re-insert new ones for V2
      await db.delete('materials');
      await _insertDefaultMaterials(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE materials ADD COLUMN is_deleted INTEGER DEFAULT 0');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 4) {
      // Data migrations for existing users
      // 1. Rename Daun Jendela profiles
      await db.execute("UPDATE materials SET name = REPLACE(name, '3 Profil', '2 Profil') WHERE category = 'Daun Jendela' AND name LIKE '%3 Profil%'");
      await db.execute("UPDATE materials SET name = REPLACE(name, '4 Profil', '3 Profil') WHERE category = 'Daun Jendela' AND name LIKE '%4 Profil%'");
      
      // 2. Soft delete old Accessories
      try {
        await db.execute("UPDATE materials SET is_deleted = 1 WHERE category = 'Aksesoris'");
      } catch (e) {
        // Ignore if fails
      }

      // 3. Insert Ornament Kaca
      await db.execute("INSERT OR IGNORE INTO materials (id, category, name, price, unit, rules, is_deleted) VALUES ('o_kaca_1', 'Ornament', 'Ornament Kaca', 20000.0, 'm', '{}', 0)");
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE quotations (
        id TEXT PRIMARY KEY,
        customerName TEXT,
        customerPhone TEXT,
        projectAddress TEXT,
        notes TEXT,
        createdAt INTEGER,
        subtotal REAL,
        grandTotal REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE quotation_items (
        id TEXT PRIMARY KEY,
        quotationId TEXT,
        designJson TEXT,
        itemTotal REAL,
        FOREIGN KEY (quotationId) REFERENCES quotations (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE materials (
        id TEXT PRIMARY KEY,
        category TEXT,
        name TEXT,
        price REAL,
        unit TEXT,
        rules TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // Insert some default materials
    await _insertDefaultMaterials(db);
  }

  Future<void> _insertDefaultMaterials(Database db) async {
    final defaultMaterials = [
      // === KUSEN ===
      {'id': 'k_ink_3', 'category': 'Kusen', 'name': 'Inkalum Kusen 3 inch', 'price': 110000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'k_ink_4', 'category': 'Kusen', 'name': 'Inkalum Kusen 4 inch', 'price': 130000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'k_ale_3', 'category': 'Kusen', 'name': 'Alexindo Kusen 3 inch', 'price': 130000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'k_ale_4', 'category': 'Kusen', 'name': 'Alexindo Kusen 4 inch', 'price': 150000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'k_ykk_3', 'category': 'Kusen', 'name': 'YKK Kusen 3 inch', 'price': 150000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'k_ykk_4', 'category': 'Kusen', 'name': 'YKK Kusen 4 inch', 'price': 170000.0, 'unit': 'm1', 'rules': '{}'},

      // === DAUN JENDELA ===
      {'id': 'j_ink_3', 'category': 'Daun Jendela', 'name': 'Inkalum Jendela 2 Profil', 'price': 195000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'j_ink_4', 'category': 'Daun Jendela', 'name': 'Inkalum Jendela 3 Profil', 'price': 225000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'j_ale_3', 'category': 'Daun Jendela', 'name': 'Alexindo Jendela 2 Profil', 'price': 220000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'j_ale_4', 'category': 'Daun Jendela', 'name': 'Alexindo Jendela 3 Profil', 'price': 250000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'j_ykk_3', 'category': 'Daun Jendela', 'name': 'YKK Jendela 2 Profil', 'price': 250000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'j_ykk_4', 'category': 'Daun Jendela', 'name': 'YKK Jendela 3 Profil', 'price': 275000.0, 'unit': 'm1', 'rules': '{}'},

      // === SLIDING SET ===
      {'id': 'sw_ink_eko', 'category': 'Sliding Set', 'name': 'Inkalum Sliding Window Ekonomis', 'price': 315000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'sw_ink_jum', 'category': 'Sliding Set', 'name': 'Inkalum Sliding Window Jumbo', 'price': 335000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'sw_ale_eko', 'category': 'Sliding Set', 'name': 'Alexindo Sliding Window Ekonomis', 'price': 330000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'sw_ale_jum', 'category': 'Sliding Set', 'name': 'Alexindo Sliding Window Jumbo', 'price': 350000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'sw_ykk_eko', 'category': 'Sliding Set', 'name': 'YKK Sliding Window Ekonomis', 'price': 345000.0, 'unit': 'm1', 'rules': '{}'},
      {'id': 'sw_ykk_jum', 'category': 'Sliding Set', 'name': 'YKK Sliding Window Jumbo', 'price': 365000.0, 'unit': 'm1', 'rules': '{}'},

      // === DAUN PINTU (Standar / Besar) ===
      {'id': 'dp_pan_ink_std', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu Panel Standar', 'price': 2200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pan_ink_bes', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu Panel Besar', 'price': 3000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_acp_ink_std', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu ACP Standar', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_acp_ink_bes', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu ACP Besar', 'price': 2700000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kac_ink_std', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu Kaca Standar', 'price': 1600000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kac_ink_bes', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu Kaca Besar', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},

      {'id': 'dp_pan_ale_std', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu Panel Standar', 'price': 2500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pan_ale_bes', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu Panel Besar', 'price': 3300000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_acp_ale_std', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu ACP Standar', 'price': 2300000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_acp_ale_bes', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu ACP Besar', 'price': 3000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kac_ale_std', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu Kaca Standar', 'price': 1800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kac_ale_bes', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu Kaca Besar', 'price': 2300000.0, 'unit': 'unit', 'rules': '{}'},

      {'id': 'dp_pan_ykk_std', 'category': 'Daun Pintu', 'name': 'YKK Pintu Panel Standar', 'price': 2800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pan_ykk_bes', 'category': 'Daun Pintu', 'name': 'YKK Pintu Panel Besar', 'price': 3600000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_acp_ykk_std', 'category': 'Daun Pintu', 'name': 'YKK Pintu ACP Standar', 'price': 2500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_acp_ykk_bes', 'category': 'Daun Pintu', 'name': 'YKK Pintu ACP Besar', 'price': 3200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kac_ykk_std', 'category': 'Daun Pintu', 'name': 'YKK Pintu Kaca Standar', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kac_ykk_bes', 'category': 'Daun Pintu', 'name': 'YKK Pintu Kaca Besar', 'price': 2500000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU SLIDING / FOLDING (Fallback / Additional) ===
      {'id': 'dp_lip_ink', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu Lipat per Daun', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_lip_ale', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu Lipat per Daun', 'price': 2300000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_lip_ykk', 'category': 'Daun Pintu', 'name': 'YKK Pintu Lipat per Daun', 'price': 2800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ges_ink', 'category': 'Daun Pintu', 'name': 'Inkalum Pintu Geser per Daun', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ges_ale', 'category': 'Daun Pintu', 'name': 'Alexindo Pintu Geser per Daun', 'price': 2300000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ges_ykk', 'category': 'Daun Pintu', 'name': 'YKK Pintu Geser per Daun', 'price': 2800000.0, 'unit': 'unit', 'rules': '{}'},

      // === KACA ===
      {'id': 'g_polo_5', 'category': 'Kaca', 'name': 'Kaca Polos 5mm', 'price': 220000.0, 'unit': 'm2', 'rules': '{}'},
      {'id': 'g_polo_6', 'category': 'Kaca', 'name': 'Kaca Polos 6mm', 'price': 270000.0, 'unit': 'm2', 'rules': '{}'},
      {'id': 'g_ryb_5', 'category': 'Kaca', 'name': 'Kaca Ryben 5mm', 'price': 240000.0, 'unit': 'm2', 'rules': '{}'},

      // === ORNAMENT ===
      {'id': 'o_kaca_1', 'category': 'Ornament', 'name': 'Ornament Kaca', 'price': 20000.0, 'unit': 'm', 'rules': '{}'},

      // === JASA ===
      {'id': 'l_pasang', 'category': 'Jasa', 'name': 'Jasa Pasang', 'price': 50000.0, 'unit': 'm2', 'rules': '{}'},
    ];

    for (var material in defaultMaterials) {
      await db.insert('materials', material);
    }
  }
}
