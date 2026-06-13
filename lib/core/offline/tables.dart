import 'package:drift/drift.dart';

class CachedWashTypes extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  RealColumn get basePrice => real()();
  IntColumn get durationMinutes => integer()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedUsers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get avatarUrl => text().nullable()();
}

class CachedAppointments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get ownerUsername => text()();
  DateTimeColumn get dateTime => super.dateTime()();
  TextColumn get status => text()();
  TextColumn get dataJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedShifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get date => text()();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
