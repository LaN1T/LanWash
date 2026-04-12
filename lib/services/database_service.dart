import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  static DatabaseService get instance => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    // На macOS/Linux/Windows используем FFI реализацию
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lanwash.db');

    return openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS extra_favorites (
          username    TEXT NOT NULL,
          serviceName TEXT NOT NULL,
          PRIMARY KEY (username, serviceName)
        )
      ''');
    }
    if (oldVersion < 3) {
      // Таблица избранных услуг (каталог) per-user
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_favorites (
          username  TEXT NOT NULL,
          serviceId TEXT NOT NULL,
          PRIMARY KEY (username, serviceId)
        )
      ''');
      // Колонка фактической цены записи
      await db.execute(
          'ALTER TABLE appointments ADD COLUMN paidPrice INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      final now = DateTime.now().toIso8601String();
      final promoData = [
        {'id':'promo_1','name':'Акция недели: комплекс + ароматизация','description':'Комплексная мойка и ароматизация салона по специальной цене недели.','price':1600,'durationMinutes':75,'category':'Акции','isFavorite':0,'isFromApi':1,'updatedAt':now},
        {'id':'promo_2','name':'Весенняя акция: мойка + воск','description':'Базовая мойка кузова + нанесение защитного воска. Специальная цена до конца месяца.','price':1500,'durationMinutes':50,'category':'Акции','isFavorite':0,'isFromApi':1,'updatedAt':now},
        {'id':'promo_3','name':'Выходной пакет: комплексная мойка -20%','description':'Комплексная мойка кузова со скидкой 20%. Только по выходным — суббота и воскресенье.','price':1200,'durationMinutes':60,'category':'Акции','isFavorite':0,'isFromApi':1,'updatedAt':now},
        {'id':'promo_4','name':'Пакет для внедорожников','description':'Полный уход для крупных автомобилей: внедорожников и минивэнов. Тщательная мойка колёс и арок.','price':2000,'durationMinutes':80,'category':'Акции','isFavorite':0,'isFromApi':1,'updatedAt':now},
      ];
      // Вставляем в services (isFromApi=1)
      for (final p in promoData) {
        await db.insert('services', p,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // Синхронизируем таблицу promos (кэш)
      for (final p in promoData) {
        await db.insert('promos', {
          'id': p['id'],
          'serviceId': p['id'],
          'name': p['name'],
          'description': p['description'],
          'price': p['price'],
          'duration': p['durationMinutes'],
          'fetchedAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS logs (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          username  TEXT NOT NULL,
          action    TEXT NOT NULL,
          details   TEXT NOT NULL DEFAULT '',
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE appointments ADD COLUMN isModifiedByAdmin INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 7) {
      await db.execute(
          'ALTER TABLE appointments ADD COLUMN assignedWashers TEXT NOT NULL DEFAULT "[]"');
    }
    if (oldVersion < 8) {
      // Обновляем цену акции promo_3
      await db.execute("UPDATE services SET price = 1200 WHERE id = 'promo_3'");
      await db.execute("UPDATE promos SET price = 1200 WHERE id = 'promo_3'");
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS consumables (
          id    TEXT PRIMARY KEY,
          name  TEXT NOT NULL,
          unit  TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_consumables (
          serviceId            TEXT NOT NULL,
          consumableId         TEXT NOT NULL,
          quantity_per_service REAL NOT NULL,
          PRIMARY KEY (serviceId, consumableId),
          FOREIGN KEY (serviceId)    REFERENCES services(id)    ON DELETE CASCADE,
          FOREIGN KEY (consumableId) REFERENCES consumables(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS consumable_usage_log (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          appointmentId TEXT NOT NULL,
          consumableId  TEXT NOT NULL,
          quantityUsed  REAL NOT NULL,
          timestamp     TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS washer_notes (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          username  TEXT    NOT NULL,
          title     TEXT    NOT NULL,
          message   TEXT    NOT NULL DEFAULT '',
          category  TEXT    NOT NULL DEFAULT 'general',
          isRead    INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT    NOT NULL
        )
      ''');
      try {
        await db.execute(
            'ALTER TABLE appointments ADD COLUMN originalPrice INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE appointments ADD COLUMN assignedWasher TEXT NOT NULL DEFAULT ""');
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ─── Таблица пользователей ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT    NOT NULL UNIQUE,
        passwordHash  TEXT    NOT NULL,
        role          TEXT    NOT NULL DEFAULT 'client',
        displayName   TEXT    NOT NULL,
        phone         TEXT    NOT NULL DEFAULT '',
        carModel      TEXT    NOT NULL DEFAULT '',
        carNumber     TEXT    NOT NULL DEFAULT '',
        createdAt     TEXT    NOT NULL,
        isFavoriteAdmin INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ─── Таблица записей ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE appointments (
        id                  TEXT    PRIMARY KEY,
        userId              INTEGER,
        clientName          TEXT    NOT NULL,
        carModel            TEXT    NOT NULL,
        carNumber           TEXT    NOT NULL,
        dateTime            TEXT    NOT NULL,
        washType            TEXT    NOT NULL,
        additionalServices  TEXT    NOT NULL DEFAULT '[]',
        status              TEXT    NOT NULL DEFAULT 'scheduled',
        notes               TEXT    NOT NULL DEFAULT '',
        isFavorite          INTEGER NOT NULL DEFAULT 0,
        ownerUsername       TEXT    NOT NULL DEFAULT '',
        promoPrice          INTEGER NOT NULL DEFAULT 0,
        paidPrice           INTEGER NOT NULL DEFAULT 0,
        isModifiedByAdmin   INTEGER NOT NULL DEFAULT 0,
        originalPrice       INTEGER NOT NULL DEFAULT 0,
        assignedWasher      TEXT    NOT NULL DEFAULT '',
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    // ─── Таблица услуг ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE services (
        id              TEXT    PRIMARY KEY,
        name            TEXT    NOT NULL,
        description     TEXT    NOT NULL DEFAULT '',
        price           INTEGER NOT NULL DEFAULT 0,
        durationMinutes INTEGER NOT NULL DEFAULT 30,
        category        TEXT    NOT NULL DEFAULT '',
        isFavorite      INTEGER NOT NULL DEFAULT 0,
        isFromApi       INTEGER NOT NULL DEFAULT 0,
        updatedAt       TEXT    NOT NULL
      )
    ''');

    // ─── Таблица акций (кэш из API) ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE promos (
        id          TEXT    PRIMARY KEY,
        serviceId   TEXT    NOT NULL,
        name        TEXT    NOT NULL,
        description TEXT    NOT NULL DEFAULT '',
        price       INTEGER NOT NULL DEFAULT 0,
        duration    INTEGER NOT NULL DEFAULT 30,
        fetchedAt   TEXT    NOT NULL,
        FOREIGN KEY (serviceId) REFERENCES services(id) ON DELETE CASCADE
      )
    ''');

    // ─── Таблица логов ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE logs (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        username  TEXT NOT NULL,
        action    TEXT NOT NULL,
        details   TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL
      )
    ''');

    // ─── Избранные услуги каталога (по пользователю) ────────────────────────────
    await db.execute('''
      CREATE TABLE service_favorites (
        username  TEXT NOT NULL,
        serviceId TEXT NOT NULL,
        PRIMARY KEY (username, serviceId)
      )
    ''');

    // ─── Избранные доп. услуги (по пользователю) ────────────────────────────
    await db.execute('''
      CREATE TABLE extra_favorites (
        username    TEXT NOT NULL,
        serviceName TEXT NOT NULL,
        PRIMARY KEY (username, serviceName)
      )
    ''');

    // ─── Расходники ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE consumables (
        id    TEXT PRIMARY KEY,
        name  TEXT NOT NULL,
        unit  TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE service_consumables (
        serviceId            TEXT NOT NULL,
        consumableId         TEXT NOT NULL,
        quantity_per_service REAL NOT NULL,
        PRIMARY KEY (serviceId, consumableId),
        FOREIGN KEY (serviceId)    REFERENCES services(id)     ON DELETE CASCADE,
        FOREIGN KEY (consumableId) REFERENCES consumables(id)  ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE consumable_usage_log (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        appointmentId TEXT NOT NULL,
        consumableId  TEXT NOT NULL,
        quantityUsed  REAL NOT NULL,
        timestamp     TEXT NOT NULL,
        FOREIGN KEY (appointmentId) REFERENCES appointments(id),
        FOREIGN KEY (consumableId)  REFERENCES consumables(id)
      )
    ''');

    // ─── Заметки мойщика ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE washer_notes (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        username  TEXT    NOT NULL,
        title     TEXT    NOT NULL,
        message   TEXT    NOT NULL DEFAULT '',
        category  TEXT    NOT NULL DEFAULT 'general',
        isRead    INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT    NOT NULL
      )
    ''');

    // ─── Заполняем начальные данные ─────────────────────────────────────────
    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Пользователи по умолчанию
    await db.insert('users', {
      'username': 'admin',
      'passwordHash': User.hashPassword('admin'),
      'role': 'admin',
      'displayName': 'Администратор',
      'phone': '',
      'carModel': '',
      'carNumber': '',
      'createdAt': now,
      'isFavoriteAdmin': 0,
    });

    // Услуги из каталога
    final services = _seedServices();
    for (final s in services) {
      await db.insert('services', {...s, 'updatedAt': now});
    }

    // Акции (isFromApi = 1) — в services и в promos
    final promos = _seedPromos();
    for (final p in promos) {
      await db.insert('services', {...p, 'updatedAt': now});
      await db.insert('promos', {
        'id': p['id'],
        'serviceId': p['id'],
        'name': p['name'],
        'description': p['description'],
        'price': p['price'],
        'duration': p['durationMinutes'],
        'fetchedAt': now,
      });
    }
  }

  List<Map<String, dynamic>> _seedPromos() => [
    {'id':'promo_1','name':'Акция недели: комплекс + ароматизация','description':'Комплексная мойка и ароматизация салона по специальной цене недели.','price':1600,'durationMinutes':75,'category':'Акции','isFavorite':0,'isFromApi':1},
    {'id':'promo_2','name':'Весенняя акция: мойка + воск','description':'Базовая мойка кузова + нанесение защитного воска. Специальная цена до конца месяца.','price':1500,'durationMinutes':50,'category':'Акции','isFavorite':0,'isFromApi':1},
    {'id':'promo_3','name':'Выходной пакет: комплексная мойка -20%','description':'Комплексная мойка кузова со скидкой 20%. Только по выходным — суббота и воскресенье.','price':1200,'durationMinutes':60,'category':'Акции','isFavorite':0,'isFromApi':1},
    {'id':'promo_4','name':'Пакет для внедорожников','description':'Полный уход для крупных автомобилей: внедорожников и минивэнов. Тщательная мойка колёс и арок.','price':2000,'durationMinutes':80,'category':'Акции','isFavorite':0,'isFromApi':1},
  ];

  List<Map<String, dynamic>> _seedServices() => [
    {'id':'s1','name':'Базовая мойка кузова','description':'Предварительная обработка, ручная мойка с профессиональными средствами, полоскание, очистка дисков и арок, сушка.','price':800,'durationMinutes':30,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
    {'id':'s2','name':'Комплексная мойка + салон','description':'Внешняя мойка кузова плюс полная уборка салона: пылесосная обработка, влажная уборка всех поверхностей, чистка стёкол изнутри.','price':1500,'durationMinutes':60,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
    {'id':'s3','name':'Экспресс-мойка','description':'Быстрая наружная мойка без детальной обработки. Идеально для поддержания ежедневной чистоты.','price':500,'durationMinutes':15,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
    {'id':'s4','name':'Обработка арок','description':'Глубокая очистка колесных арок с применением специализированного состава. Удаляет дорожный битум, стойкие загрязнения,'
    'тормозную пыль и реагенты. Предотвращает коррозию металла и придает деталям подвески ухоженный вид.','price':600,'durationMinutes':20,'category':'Специальные услуги','isFavorite':0,'isFromApi':0},
    {'id':'s5','name':'Мойка двигателя','description':'Профессиональная очистка двигательного отсека от масла и грязи.','price':1500,'durationMinutes':60,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
    {'id':'s6','name':'Полировка стёкол снаружи','description':'Финальная полировка наружных стёкол для максимальной прозрачности и блеска.','price':500,'durationMinutes':20,'category':'Обработка стёкол','isFavorite':0,'isFromApi':0},
    {'id':'s7','name':'Антидождь на стёкла','description':'Нанесение гидрофобного состава на стёкла, обеспечивающего отталкивание воды.','price':600,'durationMinutes':25,'category':'Обработка стёкол','isFavorite':0,'isFromApi':0},
    {'id':'s8','name':'Нанесение защитного воска','description':'Нанесение профессионального защитного воска на кузов для защиты ЛКП.','price':1200,'durationMinutes':45,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
    {'id':'s9','name':'Нанесение силанта','description':'Нанесение силантового покрытия для долговременной защиты кузова. Срок действия до 6 месяцев.','price':2000,'durationMinutes':90,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
    {'id':'s10','name':'Керамическое покрытие','description':'Профессиональное нанесение керамического покрытия. Максимальная защита ЛКП сроком до 2 лет.','price':15000,'durationMinutes':480,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
    {'id':'s11','name':'Нанесение тефлона','description':'Нанесение тефлонового покрытия для защиты кузова и стойкого блеска.','price':3000,'durationMinutes':120,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
    {'id':'s12','name':'Удаление битума и смол','description':'Профессиональное удаление следов битума, смолы, насекомых с кузова.','price':700,'durationMinutes':30,'category':'Специальные услуги','isFavorite':0,'isFromApi':0},
    {'id':'s13','name':'Чернение шин','description':'Нанесение специального состава на боковины шин — восстанавливает чёрный цвет и глянцевый блеск.','price':300,'durationMinutes':15,'category':'Специальные услуги','isFavorite':0,'isFromApi':0},
    {'id':'s14','name':'Пылесосная уборка салона','description':'Тщательная пылесосная обработка салона: сиденья, напольные покрытия, багажник.','price':500,'durationMinutes':25,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
    {'id':'s15','name':'Химчистка салона','description':'Глубокая чистка тканевых и кожаных поверхностей профессиональной химией.','price':3500,'durationMinutes':180,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
    {'id':'s16','name':'Химчистка кожи','description':'Специализированная очистка и кондиционирование кожаного салона.','price':5000,'durationMinutes':240,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
    {'id':'s17','name':'Ароматизация салона','description':'Нанесение стойкого ароматизатора. Широкий выбор ароматов.','price':300,'durationMinutes':15,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
    {'id':'s18','name':'Озонирование салона','description':'Обработка салона озоном для полного устранения запахов и дезинфекции.','price':1000,'durationMinutes':60,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
    {'id':'s19','name':'Детейлинг кузова','description':'Полный комплекс детальной обработки: полировка кузова, нанесение защитного покрытия.','price':8000,'durationMinutes':360,'category':'Детейлинг','isFavorite':0,'isFromApi':0},
    {'id':'s20','name':'Полировка кузова','description':'Машинная полировка ЛКП для устранения мелких царапин и восстановления блеска.','price':5000,'durationMinutes':240,'category':'Детейлинг','isFavorite':0,'isFromApi':0},
  ];
}