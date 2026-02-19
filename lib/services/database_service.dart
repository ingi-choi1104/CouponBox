import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/coupon.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'coupons.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode_value TEXT NOT NULL,
        barcode_type TEXT NOT NULL,
        store_name TEXT,
        item_name TEXT,
        amount INTEGER,
        expiry_date INTEGER,
        image_path TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL,
        used_at INTEGER,
        notes TEXT,
        asset_id TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_barcode_value ON coupons(barcode_value)',
    );
    await db.execute(
      'CREATE INDEX idx_asset_id ON coupons(asset_id)',
    );
  }

  Future<int> insertCoupon(Coupon coupon) async {
    final db = await database;
    return await db.insert('coupons', coupon.toMap());
  }

  Future<List<Coupon>> getAllCoupons() async {
    final db = await database;
    final maps = await db.query('coupons', orderBy: 'added_at DESC');
    return maps.map((map) => Coupon.fromMap(map)).toList();
  }

  Future<Coupon?> getCouponByBarcodeValue(String value) async {
    final db = await database;
    final maps = await db.query(
      'coupons',
      where: 'barcode_value = ?',
      whereArgs: [value],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Coupon.fromMap(maps.first);
  }

  Future<Coupon?> getCouponByAssetId(String assetId) async {
    final db = await database;
    final maps = await db.query(
      'coupons',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Coupon.fromMap(maps.first);
  }

  Future<int> updateCoupon(Coupon coupon) async {
    final db = await database;
    return await db.update(
      'coupons',
      coupon.toMap(),
      where: 'id = ?',
      whereArgs: [coupon.id],
    );
  }

  Future<int> deleteCoupon(int id) async {
    final db = await database;
    return await db.delete(
      'coupons',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Coupon>> getExpiringSoonCoupons({int withinDays = 7}) async {
    final db = await database;
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: withinDays));
    final maps = await db.query(
      'coupons',
      where:
          'status = ? AND expiry_date IS NOT NULL AND expiry_date > ? AND expiry_date <= ?',
      whereArgs: [
        CouponStatus.active.index,
        now.millisecondsSinceEpoch,
        futureDate.millisecondsSinceEpoch,
      ],
      orderBy: 'expiry_date ASC',
    );
    return maps.map((map) => Coupon.fromMap(map)).toList();
  }

  Future<void> markExpiredCoupons() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'coupons',
      {'status': CouponStatus.expired.index},
      where:
          'status = ? AND expiry_date IS NOT NULL AND expiry_date < ?',
      whereArgs: [CouponStatus.active.index, now],
    );
  }

  Future<Map<String, int>> getStatistics() async {
    final db = await database;
    final all = await db.query('coupons');
    int active = 0, used = 0, expired = 0, expiringSoon = 0;
    final now = DateTime.now();
    final soonThreshold = now.add(const Duration(days: 7));

    for (final map in all) {
      final status = CouponStatus.values[map['status'] as int];
      final expiryTs = map['expiry_date'] as int?;
      final expiryDate =
          expiryTs != null ? DateTime.fromMillisecondsSinceEpoch(expiryTs) : null;

      if (status == CouponStatus.used) {
        used++;
      } else if (status == CouponStatus.expired ||
          (expiryDate != null && expiryDate.isBefore(now))) {
        expired++;
      } else {
        active++;
        if (expiryDate != null && expiryDate.isBefore(soonThreshold)) {
          expiringSoon++;
        }
      }
    }

    return {
      'active': active,
      'used': used,
      'expired': expired,
      'expiringSoon': expiringSoon,
    };
  }
}
