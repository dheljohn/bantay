import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/saved_route.dart';

class RouteDatabase {
  // Singleton pattern - only one instance of database
  static final RouteDatabase instance = RouteDatabase._init();
  static Database? _database;

  RouteDatabase._init();

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bantay_routes.db');
    return _database!;
  }

  // Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Create database table
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER DEFAULT 0';

    await db.execute('''
      CREATE TABLE routes (
        id $idType,
        name $textType,
        points $textType,
        distance $realType,
        created_at $textType,
        times_used $intType
      )
    ''');
  }

  // CREATE - Insert new route
  Future<SavedRoute> insertRoute(SavedRoute route) async {
    final db = await database;
    final id = await db.insert('routes', route.toMap());
    return route.copyWith(id: id);
  }

  // READ - Get all routes
  Future<List<SavedRoute>> getAllRoutes() async {
    final db = await database;
    final result = await db.query('routes', orderBy: 'created_at DESC');
    return result.map((map) => SavedRoute.fromMap(map)).toList();
  }

  // READ - Get single route by id
  Future<SavedRoute?> getRoute(int id) async {
    final db = await database;
    final maps = await db.query('routes', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return SavedRoute.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // UPDATE - Update existing route
  Future<int> updateRoute(SavedRoute route) async {
    final db = await database;
    return db.update(
      'routes',
      route.toMap(),
      where: 'id = ?',
      whereArgs: [route.id],
    );
  }

  // UPDATE - Increment times used
  Future<int> incrementTimesUsed(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE routes SET times_used = times_used + 1 WHERE id = ?',
      [id],
    );
  }

  // DELETE - Delete route
  Future<int> deleteRoute(int id) async {
    final db = await database;
    return await db.delete('routes', where: 'id = ?', whereArgs: [id]);
  }

  // DELETE - Delete all routes
  Future<int> deleteAllRoutes() async {
    final db = await database;
    return await db.delete('routes');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
