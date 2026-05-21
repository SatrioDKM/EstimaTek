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
      version: 1,
      onCreate: _onCreate,
    );
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
        rules TEXT
      )
    ''');

    // Insert some default materials
    await _insertDefaultMaterials(db);
  }

  Future<void> _insertDefaultMaterials(Database db) async {
    final defaultMaterials = [
      // === KUSEN ===
      {'id': 'k_ink_3', 'category': 'aluminium', 'name': 'Inkalum Kusen 3 inch', 'price': 120000.0, 'unit': 'm', 'rules': '{}'},
      {'id': 'k_ink_4', 'category': 'aluminium', 'name': 'Inkalum Kusen 4 inch', 'price': 150000.0, 'unit': 'm', 'rules': '{}'},
      {'id': 'k_ale_3', 'category': 'aluminium', 'name': 'Alexindo Kusen 3 inch', 'price': 140000.0, 'unit': 'm', 'rules': '{}'},
      {'id': 'k_ale_4', 'category': 'aluminium', 'name': 'Alexindo Kusen 4 inch', 'price': 180000.0, 'unit': 'm', 'rules': '{}'},
      {'id': 'k_ykk_3', 'category': 'aluminium', 'name': 'YKK Kusen 3 inch', 'price': 220000.0, 'unit': 'm', 'rules': '{}'},
      {'id': 'k_ykk_4', 'category': 'aluminium', 'name': 'YKK Kusen 4 inch', 'price': 280000.0, 'unit': 'm', 'rules': '{}'},

      // === DAUN JENDELA ===
      {'id': 'j_ink_2', 'category': 'aluminium', 'name': 'Inkalum Jendela 2 Profil', 'price': 450000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'j_ink_3', 'category': 'aluminium', 'name': 'Inkalum Jendela 3 Profil', 'price': 550000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'j_ale_2', 'category': 'aluminium', 'name': 'Alexindo Jendela 2 Profil', 'price': 550000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'j_ale_3', 'category': 'aluminium', 'name': 'Alexindo Jendela 3 Profil', 'price': 680000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'j_ykk_2', 'category': 'aluminium', 'name': 'YKK Jendela 2 Profil', 'price': 900000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'j_ykk_3', 'category': 'aluminium', 'name': 'YKK Jendela 3 Profil', 'price': 1150000.0, 'unit': 'unit', 'rules': '{}'},

      // === SLIDING WINDOW ===
      {'id': 'sw_ink_eko', 'category': 'aluminium', 'name': 'Inkalum Sliding Window Ekonomis', 'price': 400000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'sw_ink_jum', 'category': 'aluminium', 'name': 'Inkalum Sliding Window Jumbo', 'price': 500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'sw_ale_eko', 'category': 'aluminium', 'name': 'Alexindo Sliding Window Ekonomis', 'price': 500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'sw_ale_jum', 'category': 'aluminium', 'name': 'Alexindo Sliding Window Jumbo', 'price': 650000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'sw_ykk_eko', 'category': 'aluminium', 'name': 'YKK Sliding Window Ekonomis', 'price': 850000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'sw_ykk_jum', 'category': 'aluminium', 'name': 'YKK Sliding Window Jumbo', 'price': 110000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU KACA SINGLE ===
      {'id': 'dp_ks_ink_std', 'category': 'aluminium', 'name': 'Inkalum Pintu Kaca Single Standar', 'price': 1200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ks_ink_bes', 'category': 'aluminium', 'name': 'Inkalum Pintu Kaca Single Besar', 'price': 1600000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ks_ale_std', 'category': 'aluminium', 'name': 'Alexindo Pintu Kaca Single Standar', 'price': 1500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ks_ale_bes', 'category': 'aluminium', 'name': 'Alexindo Pintu Kaca Single Besar', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ks_ykk_std', 'category': 'aluminium', 'name': 'YKK Pintu Kaca Single Standar', 'price': 2500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ks_ykk_bes', 'category': 'aluminium', 'name': 'YKK Pintu Kaca Single Besar', 'price': 3200000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU KACA DOUBLE ===
      {'id': 'dp_kd_ink_std', 'category': 'aluminium', 'name': 'Inkalum Pintu Kaca Double Standar', 'price': 2200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kd_ink_bes', 'category': 'aluminium', 'name': 'Inkalum Pintu Kaca Double Besar', 'price': 3000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kd_ale_std', 'category': 'aluminium', 'name': 'Alexindo Pintu Kaca Double Standar', 'price': 2800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kd_ale_bes', 'category': 'aluminium', 'name': 'Alexindo Pintu Kaca Double Besar', 'price': 3800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kd_ykk_std', 'category': 'aluminium', 'name': 'YKK Pintu Kaca Double Standar', 'price': 4800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_kd_ykk_bes', 'category': 'aluminium', 'name': 'YKK Pintu Kaca Double Besar', 'price': 6200000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU ACP SINGLE ===
      {'id': 'dp_as_ink_std', 'category': 'aluminium', 'name': 'Inkalum Pintu ACP Single Standar', 'price': 1400000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_as_ink_bes', 'category': 'aluminium', 'name': 'Inkalum Pintu ACP Single Besar', 'price': 1900000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_as_ale_std', 'category': 'aluminium', 'name': 'Alexindo Pintu ACP Single Standar', 'price': 1800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_as_ale_bes', 'category': 'aluminium', 'name': 'Alexindo Pintu ACP Single Besar', 'price': 2400000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_as_ykk_std', 'category': 'aluminium', 'name': 'YKK Pintu ACP Single Standar', 'price': 3000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_as_ykk_bes', 'category': 'aluminium', 'name': 'YKK Pintu ACP Single Besar', 'price': 4000000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU ACP DOUBLE ===
      {'id': 'dp_ad_ink_std', 'category': 'aluminium', 'name': 'Inkalum Pintu ACP Double Standar', 'price': 2600000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ad_ink_bes', 'category': 'aluminium', 'name': 'Inkalum Pintu ACP Double Besar', 'price': 3500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ad_ale_std', 'category': 'aluminium', 'name': 'Alexindo Pintu ACP Double Standar', 'price': 3200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ad_ale_bes', 'category': 'aluminium', 'name': 'Alexindo Pintu ACP Double Besar', 'price': 4400000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ad_ykk_std', 'category': 'aluminium', 'name': 'YKK Pintu ACP Double Standar', 'price': 5500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ad_ykk_bes', 'category': 'aluminium', 'name': 'YKK Pintu ACP Double Besar', 'price': 7500000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU PANEL SINGLE ===
      {'id': 'dp_ps_ink_std', 'category': 'aluminium', 'name': 'Inkalum Pintu Panel Single Standar', 'price': 1600000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ps_ink_bes', 'category': 'aluminium', 'name': 'Inkalum Pintu Panel Single Besar', 'price': 2200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ps_ale_std', 'category': 'aluminium', 'name': 'Alexindo Pintu Panel Single Standar', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ps_ale_bes', 'category': 'aluminium', 'name': 'Alexindo Pintu Panel Single Besar', 'price': 2800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ps_ykk_std', 'category': 'aluminium', 'name': 'YKK Pintu Panel Single Standar', 'price': 3500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ps_ykk_bes', 'category': 'aluminium', 'name': 'YKK Pintu Panel Single Besar', 'price': 4800000.0, 'unit': 'unit', 'rules': '{}'},

      // === DAUN PINTU PANEL DOUBLE ===
      {'id': 'dp_pd_ink_std', 'category': 'aluminium', 'name': 'Inkalum Pintu Panel Double Standar', 'price': 3000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pd_ink_bes', 'category': 'aluminium', 'name': 'Inkalum Pintu Panel Double Besar', 'price': 4000000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pd_ale_std', 'category': 'aluminium', 'name': 'Alexindo Pintu Panel Double Standar', 'price': 3800000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pd_ale_bes', 'category': 'aluminium', 'name': 'Alexindo Pintu Panel Double Besar', 'price': 5200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pd_ykk_std', 'category': 'aluminium', 'name': 'YKK Pintu Panel Double Standar', 'price': 6500000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_pd_ykk_bes', 'category': 'aluminium', 'name': 'YKK Pintu Panel Double Besar', 'price': 9000000.0, 'unit': 'unit', 'rules': '{}'},

      // === SLIDING / FOLDING DOOR DAUN ===
      {'id': 'dp_lip_ink', 'category': 'aluminium', 'name': 'Inkalum Pintu Lipat per Daun', 'price': 1100000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_lip_ale', 'category': 'aluminium', 'name': 'Alexindo Pintu Lipat per Daun', 'price': 1400000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_lip_ykk', 'category': 'aluminium', 'name': 'YKK Pintu Lipat per Daun', 'price': 2400000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ges_ink', 'category': 'aluminium', 'name': 'Inkalum Pintu Geser per Daun', 'price': 900000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ges_ale', 'category': 'aluminium', 'name': 'Alexindo Pintu Geser per Daun', 'price': 1200000.0, 'unit': 'unit', 'rules': '{}'},
      {'id': 'dp_ges_ykk', 'category': 'aluminium', 'name': 'YKK Pintu Geser per Daun', 'price': 2000000.0, 'unit': 'unit', 'rules': '{}'},

      // === KACA ===
      {'id': 'g_polo_5', 'category': 'glass', 'name': 'Kaca Polos 5mm', 'price': 180000.0, 'unit': 'm2', 'rules': '{}'},
      {'id': 'g_polo_6', 'category': 'glass', 'name': 'Kaca Polos 6mm', 'price': 220000.0, 'unit': 'm2', 'rules': '{}'},
      {'id': 'g_temp_5', 'category': 'glass', 'name': 'Kaca Tempered 5mm', 'price': 350000.0, 'unit': 'm2', 'rules': '{}'},

      // === AKSESORIS ===
      {'id': 'a_eng_cas', 'category': 'accessories', 'name': 'Engsel Casement', 'price': 35000.0, 'unit': 'psg', 'rules': '{}'},
      {'id': 'a_rod_sli', 'category': 'accessories', 'name': 'Roda Sliding', 'price': 45000.0, 'unit': 'set', 'rules': '{}'},
      {'id': 'a_eng_pin', 'category': 'accessories', 'name': 'Engsel Pintu', 'price': 75000.0, 'unit': 'pcs', 'rules': '{}'},
      {'id': 'a_kun_swi', 'category': 'accessories', 'name': 'Kunci Pintu Swing', 'price': 150000.0, 'unit': 'set', 'rules': '{}'},
      {'id': 'a_kun_sli', 'category': 'accessories', 'name': 'Kunci Sliding', 'price': 60000.0, 'unit': 'set', 'rules': '{}'},
      {'id': 'a_aks_lip', 'category': 'accessories', 'name': 'Aksesoris Lipat', 'price': 300000.0, 'unit': 'set', 'rules': '{}'},

      // === JASA ===
      {'id': 'l_pasang', 'category': 'labor', 'name': 'Jasa Pasang', 'price': 50000.0, 'unit': 'm2', 'rules': '{}'},
    ];

    for (var material in defaultMaterials) {
      await db.insert('materials', material);
    }
  }
}
