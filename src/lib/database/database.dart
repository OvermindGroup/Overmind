import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

part 'database.g.dart';

class Investments extends Table {
  IntColumn get date => integer().named('date')();
  TextColumn get assets0 => text().map(const JsonConverter()).named('assets0')();
  TextColumn get assets => text().map(const JsonConverter()).named('assets')();
  TextColumn get stop => text().map(const JsonConverter()).named('stop')();
  TextColumn get prices => text().map(const JsonConverter()).named('prices')();

  @override
  Set<Column> get primaryKey => {date};
}

class JsonConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) =>
      fromDb.isEmpty ? {} : jsonDecode(fromDb) as Map<String, dynamic>;

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await _getDatabaseFolder();
    final file = File(p.join(dbFolder, 'overmind.sqlite'));
    return NativeDatabase(file);
  });
}

Future<String> _getDatabaseFolder() async {
  if (Platform.isAndroid || Platform.isIOS) {
    final folder = await getApplicationDocumentsDirectory();
    return folder.path;
  }
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    final folder = await getApplicationSupportDirectory();
    return folder.path;
  }
  return '.';
}

@DriftDatabase(tables: [Investments])
class OvermindDb extends _$OvermindDb {
  OvermindDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertInvestment(InvestmentsCompanion data) => into(investments).insert(data);
  Future<List<Investment>> getAllInvestments() => select(investments).get();

  Future<Investment?> getLatestInvestment() {
    final query = select(investments)
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(1);
    return query.getSingleOrNull();
  }
}
