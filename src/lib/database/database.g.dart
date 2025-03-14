// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $InvestmentsTable extends Investments
    with TableInfo<$InvestmentsTable, Investment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
      'date', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _assets0Meta =
      const VerificationMeta('assets0');
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      assets0 = GeneratedColumn<String>('assets0', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, dynamic>>(
              $InvestmentsTable.$converterassets0);
  static const VerificationMeta _assetsMeta = const VerificationMeta('assets');
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      assets = GeneratedColumn<String>('assets', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, dynamic>>(
              $InvestmentsTable.$converterassets);
  static const VerificationMeta _stopMeta = const VerificationMeta('stop');
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      stop = GeneratedColumn<String>('stop', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, dynamic>>(
              $InvestmentsTable.$converterstop);
  static const VerificationMeta _pricesMeta = const VerificationMeta('prices');
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      prices = GeneratedColumn<String>('prices', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, dynamic>>(
              $InvestmentsTable.$converterprices);
  @override
  List<GeneratedColumn> get $columns => [date, assets0, assets, stop, prices];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investments';
  @override
  VerificationContext validateIntegrity(Insertable<Investment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    }
    context.handle(_assets0Meta, const VerificationResult.success());
    context.handle(_assetsMeta, const VerificationResult.success());
    context.handle(_stopMeta, const VerificationResult.success());
    context.handle(_pricesMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  Investment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Investment(
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}date'])!,
      assets0: $InvestmentsTable.$converterassets0.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assets0'])!),
      assets: $InvestmentsTable.$converterassets.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assets'])!),
      stop: $InvestmentsTable.$converterstop.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stop'])!),
      prices: $InvestmentsTable.$converterprices.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prices'])!),
    );
  }

  @override
  $InvestmentsTable createAlias(String alias) {
    return $InvestmentsTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>, String> $converterassets0 =
      const JsonConverter();
  static TypeConverter<Map<String, dynamic>, String> $converterassets =
      const JsonConverter();
  static TypeConverter<Map<String, dynamic>, String> $converterstop =
      const JsonConverter();
  static TypeConverter<Map<String, dynamic>, String> $converterprices =
      const JsonConverter();
}

class Investment extends DataClass implements Insertable<Investment> {
  final int date;
  final Map<String, dynamic> assets0;
  final Map<String, dynamic> assets;
  final Map<String, dynamic> stop;
  final Map<String, dynamic> prices;
  const Investment(
      {required this.date,
      required this.assets0,
      required this.assets,
      required this.stop,
      required this.prices});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<int>(date);
    {
      map['assets0'] =
          Variable<String>($InvestmentsTable.$converterassets0.toSql(assets0));
    }
    {
      map['assets'] =
          Variable<String>($InvestmentsTable.$converterassets.toSql(assets));
    }
    {
      map['stop'] =
          Variable<String>($InvestmentsTable.$converterstop.toSql(stop));
    }
    {
      map['prices'] =
          Variable<String>($InvestmentsTable.$converterprices.toSql(prices));
    }
    return map;
  }

  InvestmentsCompanion toCompanion(bool nullToAbsent) {
    return InvestmentsCompanion(
      date: Value(date),
      assets0: Value(assets0),
      assets: Value(assets),
      stop: Value(stop),
      prices: Value(prices),
    );
  }

  factory Investment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Investment(
      date: serializer.fromJson<int>(json['date']),
      assets0: serializer.fromJson<Map<String, dynamic>>(json['assets0']),
      assets: serializer.fromJson<Map<String, dynamic>>(json['assets']),
      stop: serializer.fromJson<Map<String, dynamic>>(json['stop']),
      prices: serializer.fromJson<Map<String, dynamic>>(json['prices']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<int>(date),
      'assets0': serializer.toJson<Map<String, dynamic>>(assets0),
      'assets': serializer.toJson<Map<String, dynamic>>(assets),
      'stop': serializer.toJson<Map<String, dynamic>>(stop),
      'prices': serializer.toJson<Map<String, dynamic>>(prices),
    };
  }

  Investment copyWith(
          {int? date,
          Map<String, dynamic>? assets0,
          Map<String, dynamic>? assets,
          Map<String, dynamic>? stop,
          Map<String, dynamic>? prices}) =>
      Investment(
        date: date ?? this.date,
        assets0: assets0 ?? this.assets0,
        assets: assets ?? this.assets,
        stop: stop ?? this.stop,
        prices: prices ?? this.prices,
      );
  Investment copyWithCompanion(InvestmentsCompanion data) {
    return Investment(
      date: data.date.present ? data.date.value : this.date,
      assets0: data.assets0.present ? data.assets0.value : this.assets0,
      assets: data.assets.present ? data.assets.value : this.assets,
      stop: data.stop.present ? data.stop.value : this.stop,
      prices: data.prices.present ? data.prices.value : this.prices,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Investment(')
          ..write('date: $date, ')
          ..write('assets0: $assets0, ')
          ..write('assets: $assets, ')
          ..write('stop: $stop, ')
          ..write('prices: $prices')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, assets0, assets, stop, prices);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Investment &&
          other.date == this.date &&
          other.assets0 == this.assets0 &&
          other.assets == this.assets &&
          other.stop == this.stop &&
          other.prices == this.prices);
}

class InvestmentsCompanion extends UpdateCompanion<Investment> {
  final Value<int> date;
  final Value<Map<String, dynamic>> assets0;
  final Value<Map<String, dynamic>> assets;
  final Value<Map<String, dynamic>> stop;
  final Value<Map<String, dynamic>> prices;
  const InvestmentsCompanion({
    this.date = const Value.absent(),
    this.assets0 = const Value.absent(),
    this.assets = const Value.absent(),
    this.stop = const Value.absent(),
    this.prices = const Value.absent(),
  });
  InvestmentsCompanion.insert({
    this.date = const Value.absent(),
    required Map<String, dynamic> assets0,
    required Map<String, dynamic> assets,
    required Map<String, dynamic> stop,
    required Map<String, dynamic> prices,
  })  : assets0 = Value(assets0),
        assets = Value(assets),
        stop = Value(stop),
        prices = Value(prices);
  static Insertable<Investment> custom({
    Expression<int>? date,
    Expression<String>? assets0,
    Expression<String>? assets,
    Expression<String>? stop,
    Expression<String>? prices,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (assets0 != null) 'assets0': assets0,
      if (assets != null) 'assets': assets,
      if (stop != null) 'stop': stop,
      if (prices != null) 'prices': prices,
    });
  }

  InvestmentsCompanion copyWith(
      {Value<int>? date,
      Value<Map<String, dynamic>>? assets0,
      Value<Map<String, dynamic>>? assets,
      Value<Map<String, dynamic>>? stop,
      Value<Map<String, dynamic>>? prices}) {
    return InvestmentsCompanion(
      date: date ?? this.date,
      assets0: assets0 ?? this.assets0,
      assets: assets ?? this.assets,
      stop: stop ?? this.stop,
      prices: prices ?? this.prices,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (assets0.present) {
      map['assets0'] = Variable<String>(
          $InvestmentsTable.$converterassets0.toSql(assets0.value));
    }
    if (assets.present) {
      map['assets'] = Variable<String>(
          $InvestmentsTable.$converterassets.toSql(assets.value));
    }
    if (stop.present) {
      map['stop'] =
          Variable<String>($InvestmentsTable.$converterstop.toSql(stop.value));
    }
    if (prices.present) {
      map['prices'] = Variable<String>(
          $InvestmentsTable.$converterprices.toSql(prices.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentsCompanion(')
          ..write('date: $date, ')
          ..write('assets0: $assets0, ')
          ..write('assets: $assets, ')
          ..write('stop: $stop, ')
          ..write('prices: $prices')
          ..write(')'))
        .toString();
  }
}

abstract class _$OvermindDb extends GeneratedDatabase {
  _$OvermindDb(QueryExecutor e) : super(e);
  $OvermindDbManager get managers => $OvermindDbManager(this);
  late final $InvestmentsTable investments = $InvestmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [investments];
}

typedef $$InvestmentsTableCreateCompanionBuilder = InvestmentsCompanion
    Function({
  Value<int> date,
  required Map<String, dynamic> assets0,
  required Map<String, dynamic> assets,
  required Map<String, dynamic> stop,
  required Map<String, dynamic> prices,
});
typedef $$InvestmentsTableUpdateCompanionBuilder = InvestmentsCompanion
    Function({
  Value<int> date,
  Value<Map<String, dynamic>> assets0,
  Value<Map<String, dynamic>> assets,
  Value<Map<String, dynamic>> stop,
  Value<Map<String, dynamic>> prices,
});

class $$InvestmentsTableFilterComposer
    extends Composer<_$OvermindDb, $InvestmentsTable> {
  $$InvestmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get assets0 => $composableBuilder(
          column: $table.assets0,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get assets => $composableBuilder(
          column: $table.assets,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get stop => $composableBuilder(
          column: $table.stop,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get prices => $composableBuilder(
          column: $table.prices,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$InvestmentsTableOrderingComposer
    extends Composer<_$OvermindDb, $InvestmentsTable> {
  $$InvestmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assets0 => $composableBuilder(
      column: $table.assets0, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assets => $composableBuilder(
      column: $table.assets, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stop => $composableBuilder(
      column: $table.stop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prices => $composableBuilder(
      column: $table.prices, builder: (column) => ColumnOrderings(column));
}

class $$InvestmentsTableAnnotationComposer
    extends Composer<_$OvermindDb, $InvestmentsTable> {
  $$InvestmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get assets0 =>
      $composableBuilder(column: $table.assets0, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get assets =>
      $composableBuilder(column: $table.assets, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get stop =>
      $composableBuilder(column: $table.stop, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get prices =>
      $composableBuilder(column: $table.prices, builder: (column) => column);
}

class $$InvestmentsTableTableManager extends RootTableManager<
    _$OvermindDb,
    $InvestmentsTable,
    Investment,
    $$InvestmentsTableFilterComposer,
    $$InvestmentsTableOrderingComposer,
    $$InvestmentsTableAnnotationComposer,
    $$InvestmentsTableCreateCompanionBuilder,
    $$InvestmentsTableUpdateCompanionBuilder,
    (Investment, BaseReferences<_$OvermindDb, $InvestmentsTable, Investment>),
    Investment,
    PrefetchHooks Function()> {
  $$InvestmentsTableTableManager(_$OvermindDb db, $InvestmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvestmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvestmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> date = const Value.absent(),
            Value<Map<String, dynamic>> assets0 = const Value.absent(),
            Value<Map<String, dynamic>> assets = const Value.absent(),
            Value<Map<String, dynamic>> stop = const Value.absent(),
            Value<Map<String, dynamic>> prices = const Value.absent(),
          }) =>
              InvestmentsCompanion(
            date: date,
            assets0: assets0,
            assets: assets,
            stop: stop,
            prices: prices,
          ),
          createCompanionCallback: ({
            Value<int> date = const Value.absent(),
            required Map<String, dynamic> assets0,
            required Map<String, dynamic> assets,
            required Map<String, dynamic> stop,
            required Map<String, dynamic> prices,
          }) =>
              InvestmentsCompanion.insert(
            date: date,
            assets0: assets0,
            assets: assets,
            stop: stop,
            prices: prices,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InvestmentsTableProcessedTableManager = ProcessedTableManager<
    _$OvermindDb,
    $InvestmentsTable,
    Investment,
    $$InvestmentsTableFilterComposer,
    $$InvestmentsTableOrderingComposer,
    $$InvestmentsTableAnnotationComposer,
    $$InvestmentsTableCreateCompanionBuilder,
    $$InvestmentsTableUpdateCompanionBuilder,
    (Investment, BaseReferences<_$OvermindDb, $InvestmentsTable, Investment>),
    Investment,
    PrefetchHooks Function()>;

class $OvermindDbManager {
  final _$OvermindDb _db;
  $OvermindDbManager(this._db);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db, _db.investments);
}
