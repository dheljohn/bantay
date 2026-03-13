import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/emergency_contact.dart';

class ContactsDatabase {
  static final ContactsDatabase instance = ContactsDatabase._init();
  static Database? _database;

  ContactsDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bantay_contacts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE emergency_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        is_primary INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> updateContact(EmergencyContact contact) async {
    final db = await database;
    return await db.update(
      'emergency_contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<EmergencyContact> insertContact(EmergencyContact contact) async {
    final db = await database;

    // If this is primary, unset other primary contacts
    if (contact.isPrimary) {
      await db.update('emergency_contacts', {'is_primary': 0});
    }

    final id = await db.insert('emergency_contacts', contact.toMap());
    return contact.copyWith(id: id);
  }

  Future<List<EmergencyContact>> getAllContacts() async {
    final db = await database;
    final result = await db.query(
      'emergency_contacts',
      orderBy: 'is_primary DESC, name ASC',
    );
    return result.map((map) => EmergencyContact.fromMap(map)).toList();
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return await db.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getContactsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emergency_contacts',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

extension EmergencyContactExtension on EmergencyContact {
  EmergencyContact copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
