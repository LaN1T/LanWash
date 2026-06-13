import 'package:drift/drift.dart';

class CachedWashTypes extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get basePrice => integer().withDefault(const Constant(0))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedUsers extends Table {
  IntColumn get id => integer()();
  TextColumn get username => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get avatarUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedAppointments extends Table {
  TextColumn get id => text()();
  IntColumn get userId => integer()();
  TextColumn get ownerUsername => text()();
  TextColumn get dateTimeStr => text().named('date_time')();
  TextColumn get status => text()();
  TextColumn get dataJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedShifts extends Table {
  IntColumn get id => integer()();
  IntColumn get userId => integer()();
  TextColumn get date => text()();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get status => text()();
}

class PendingActions extends Table {
  TextColumn get id => text()();
  TextColumn get action => text()();
  TextColumn get endpoint => text()();
  TextColumn get method => text()();
  TextColumn get payload => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get createdAtStr => text().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
