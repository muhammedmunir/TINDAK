// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tindak_database.dart';

// ignore_for_file: type=lint
class $MemoriesTable extends Memories
    with TableInfo<$MemoriesTable, MemoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intakeSourceMeta = const VerificationMeta(
    'intakeSource',
  );
  @override
  late final GeneratedColumn<String> intakeSource = GeneratedColumn<String>(
    'intake_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAppMeta = const VerificationMeta(
    'sourceApp',
  );
  @override
  late final GeneratedColumn<String> sourceApp = GeneratedColumn<String>(
    'source_app',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> serverUpdatedAt = GeneratedColumn<int>(
    'server_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    intakeSource,
    sourceApp,
    createdAt,
    updatedAt,
    deletedAt,
    ownerUserId,
    syncStatus,
    serverUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('intake_source')) {
      context.handle(
        _intakeSourceMeta,
        intakeSource.isAcceptableOrUnknown(
          data['intake_source']!,
          _intakeSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intakeSourceMeta);
    }
    if (data.containsKey('source_app')) {
      context.handle(
        _sourceAppMeta,
        sourceApp.isAcceptableOrUnknown(data['source_app']!, _sourceAppMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_syncStatusMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      intakeSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intake_source'],
      )!,
      sourceApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_app'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_updated_at'],
      ),
    );
  }

  @override
  $MemoriesTable createAlias(String alias) {
    return $MemoriesTable(attachedDatabase, alias);
  }
}

class MemoryRow extends DataClass implements Insertable<MemoryRow> {
  /// Client-generated UUIDv4, assigned at save and never reassigned.
  final String id;

  /// The user's text exactly as it arrived. Never a normalised
  /// reconstruction; normalised values live on [MemoryEntities].
  final String content;

  /// `share` or `paste` (PD-033).
  final String intakeSource;

  /// The sending package, when Android disclosed it. Never trusted.
  final String? sourceApp;

  /// Epoch milliseconds, UTC.
  final int createdAt;
  final int updatedAt;

  /// A sync tombstone (PD-021): set when an account item is deleted, removed
  /// once the cloud has the deletion. Guest items are deleted outright. Every
  /// read ignores rows where it is set.
  final int? deletedAt;

  /// Null means guest-owned. Set by a signed-in save, a pull, or the explicit
  /// guest migration (PD-044) — never by sign-in alone.
  final String? ownerUserId;

  /// `local_only` (guest), `pending` (account, not yet acknowledged) or
  /// `synced`.
  final String syncStatus;

  /// The server's `updated_at` from the last successful push or pull, epoch ms
  /// UTC. NULL means the server has never acknowledged this row — so deleting
  /// it can be a local hard delete, with no tombstone to send (schema v2).
  final int? serverUpdatedAt;
  const MemoryRow({
    required this.id,
    required this.content,
    required this.intakeSource,
    this.sourceApp,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.ownerUserId,
    required this.syncStatus,
    this.serverUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content'] = Variable<String>(content);
    map['intake_source'] = Variable<String>(intakeSource);
    if (!nullToAbsent || sourceApp != null) {
      map['source_app'] = Variable<String>(sourceApp);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<int>(serverUpdatedAt);
    }
    return map;
  }

  MemoriesCompanion toCompanion(bool nullToAbsent) {
    return MemoriesCompanion(
      id: Value(id),
      content: Value(content),
      intakeSource: Value(intakeSource),
      sourceApp: sourceApp == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceApp),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      syncStatus: Value(syncStatus),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
    );
  }

  factory MemoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryRow(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      intakeSource: serializer.fromJson<String>(json['intakeSource']),
      sourceApp: serializer.fromJson<String?>(json['sourceApp']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverUpdatedAt: serializer.fromJson<int?>(json['serverUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'intakeSource': serializer.toJson<String>(intakeSource),
      'sourceApp': serializer.toJson<String?>(sourceApp),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverUpdatedAt': serializer.toJson<int?>(serverUpdatedAt),
    };
  }

  MemoryRow copyWith({
    String? id,
    String? content,
    String? intakeSource,
    Value<String?> sourceApp = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    Value<String?> ownerUserId = const Value.absent(),
    String? syncStatus,
    Value<int?> serverUpdatedAt = const Value.absent(),
  }) => MemoryRow(
    id: id ?? this.id,
    content: content ?? this.content,
    intakeSource: intakeSource ?? this.intakeSource,
    sourceApp: sourceApp.present ? sourceApp.value : this.sourceApp,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    syncStatus: syncStatus ?? this.syncStatus,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
  );
  MemoryRow copyWithCompanion(MemoriesCompanion data) {
    return MemoryRow(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      intakeSource: data.intakeSource.present
          ? data.intakeSource.value
          : this.intakeSource,
      sourceApp: data.sourceApp.present ? data.sourceApp.value : this.sourceApp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryRow(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('intakeSource: $intakeSource, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverUpdatedAt: $serverUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    intakeSource,
    sourceApp,
    createdAt,
    updatedAt,
    deletedAt,
    ownerUserId,
    syncStatus,
    serverUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryRow &&
          other.id == this.id &&
          other.content == this.content &&
          other.intakeSource == this.intakeSource &&
          other.sourceApp == this.sourceApp &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ownerUserId == this.ownerUserId &&
          other.syncStatus == this.syncStatus &&
          other.serverUpdatedAt == this.serverUpdatedAt);
}

class MemoriesCompanion extends UpdateCompanion<MemoryRow> {
  final Value<String> id;
  final Value<String> content;
  final Value<String> intakeSource;
  final Value<String?> sourceApp;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String?> ownerUserId;
  final Value<String> syncStatus;
  final Value<int?> serverUpdatedAt;
  final Value<int> rowid;
  const MemoriesCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.intakeSource = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoriesCompanion.insert({
    required String id,
    required String content,
    required String intakeSource,
    this.sourceApp = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    required String syncStatus,
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       intakeSource = Value(intakeSource),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       syncStatus = Value(syncStatus);
  static Insertable<MemoryRow> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<String>? intakeSource,
    Expression<String>? sourceApp,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? ownerUserId,
    Expression<String>? syncStatus,
    Expression<int>? serverUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (intakeSource != null) 'intake_source': intakeSource,
      if (sourceApp != null) 'source_app': sourceApp,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? content,
    Value<String>? intakeSource,
    Value<String?>? sourceApp,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String?>? ownerUserId,
    Value<String>? syncStatus,
    Value<int?>? serverUpdatedAt,
    Value<int>? rowid,
  }) {
    return MemoriesCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      intakeSource: intakeSource ?? this.intakeSource,
      sourceApp: sourceApp ?? this.sourceApp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      syncStatus: syncStatus ?? this.syncStatus,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (intakeSource.present) {
      map['intake_source'] = Variable<String>(intakeSource.value);
    }
    if (sourceApp.present) {
      map['source_app'] = Variable<String>(sourceApp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<int>(serverUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoriesCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('intakeSource: $intakeSource, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEntitiesTable extends MemoryEntities
    with TableInfo<$MemoryEntitiesTable, MemoryEntityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoryIdMeta = const VerificationMeta(
    'memoryId',
  );
  @override
  late final GeneratedColumn<String> memoryId = GeneratedColumn<String>(
    'memory_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawValueMeta = const VerificationMeta(
    'rawValue',
  );
  @override
  late final GeneratedColumn<String> rawValue = GeneratedColumn<String>(
    'raw_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedValueMeta = const VerificationMeta(
    'normalizedValue',
  );
  @override
  late final GeneratedColumn<String> normalizedValue = GeneratedColumn<String>(
    'normalized_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchValueMeta = const VerificationMeta(
    'searchValue',
  );
  @override
  late final GeneratedColumn<String> searchValue = GeneratedColumn<String>(
    'search_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memoryId,
    type,
    rawValue,
    normalizedValue,
    searchValue,
    confidence,
    startOffset,
    endOffset,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEntityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('memory_id')) {
      context.handle(
        _memoryIdMeta,
        memoryId.isAcceptableOrUnknown(data['memory_id']!, _memoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoryIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('raw_value')) {
      context.handle(
        _rawValueMeta,
        rawValue.isAcceptableOrUnknown(data['raw_value']!, _rawValueMeta),
      );
    } else if (isInserting) {
      context.missing(_rawValueMeta);
    }
    if (data.containsKey('normalized_value')) {
      context.handle(
        _normalizedValueMeta,
        normalizedValue.isAcceptableOrUnknown(
          data['normalized_value']!,
          _normalizedValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedValueMeta);
    }
    if (data.containsKey('search_value')) {
      context.handle(
        _searchValueMeta,
        searchValue.isAcceptableOrUnknown(
          data['search_value']!,
          _searchValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_searchValueMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryEntityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEntityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      rawValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_value'],
      )!,
      normalizedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_value'],
      )!,
      searchValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_value'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoryEntitiesTable createAlias(String alias) {
    return $MemoryEntitiesTable(attachedDatabase, alias);
  }
}

class MemoryEntityRow extends DataClass implements Insertable<MemoryEntityRow> {
  final String id;
  final String memoryId;

  /// Stored as text, not constrained to today's types, so M6 can add money
  /// and date without rebuilding this table. Unknown values are skipped on
  /// read rather than trusted.
  final String type;

  /// The matched characters from the normalised text.
  final String rawValue;

  /// Canonical value: E.164 phone, lowercased-host URL.
  final String normalizedValue;

  /// Lowercased forms a person would type when searching, e.g. both
  /// `0123456789` and `60123456789` for a phone. Local-only and derived.
  final String searchValue;
  final double confidence;
  final int startOffset;
  final int endOffset;
  final int createdAt;
  const MemoryEntityRow({
    required this.id,
    required this.memoryId,
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
    required this.searchValue,
    required this.confidence,
    required this.startOffset,
    required this.endOffset,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['memory_id'] = Variable<String>(memoryId);
    map['type'] = Variable<String>(type);
    map['raw_value'] = Variable<String>(rawValue);
    map['normalized_value'] = Variable<String>(normalizedValue);
    map['search_value'] = Variable<String>(searchValue);
    map['confidence'] = Variable<double>(confidence);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MemoryEntitiesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEntitiesCompanion(
      id: Value(id),
      memoryId: Value(memoryId),
      type: Value(type),
      rawValue: Value(rawValue),
      normalizedValue: Value(normalizedValue),
      searchValue: Value(searchValue),
      confidence: Value(confidence),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryEntityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEntityRow(
      id: serializer.fromJson<String>(json['id']),
      memoryId: serializer.fromJson<String>(json['memoryId']),
      type: serializer.fromJson<String>(json['type']),
      rawValue: serializer.fromJson<String>(json['rawValue']),
      normalizedValue: serializer.fromJson<String>(json['normalizedValue']),
      searchValue: serializer.fromJson<String>(json['searchValue']),
      confidence: serializer.fromJson<double>(json['confidence']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memoryId': serializer.toJson<String>(memoryId),
      'type': serializer.toJson<String>(type),
      'rawValue': serializer.toJson<String>(rawValue),
      'normalizedValue': serializer.toJson<String>(normalizedValue),
      'searchValue': serializer.toJson<String>(searchValue),
      'confidence': serializer.toJson<double>(confidence),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MemoryEntityRow copyWith({
    String? id,
    String? memoryId,
    String? type,
    String? rawValue,
    String? normalizedValue,
    String? searchValue,
    double? confidence,
    int? startOffset,
    int? endOffset,
    int? createdAt,
  }) => MemoryEntityRow(
    id: id ?? this.id,
    memoryId: memoryId ?? this.memoryId,
    type: type ?? this.type,
    rawValue: rawValue ?? this.rawValue,
    normalizedValue: normalizedValue ?? this.normalizedValue,
    searchValue: searchValue ?? this.searchValue,
    confidence: confidence ?? this.confidence,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryEntityRow copyWithCompanion(MemoryEntitiesCompanion data) {
    return MemoryEntityRow(
      id: data.id.present ? data.id.value : this.id,
      memoryId: data.memoryId.present ? data.memoryId.value : this.memoryId,
      type: data.type.present ? data.type.value : this.type,
      rawValue: data.rawValue.present ? data.rawValue.value : this.rawValue,
      normalizedValue: data.normalizedValue.present
          ? data.normalizedValue.value
          : this.normalizedValue,
      searchValue: data.searchValue.present
          ? data.searchValue.value
          : this.searchValue,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntityRow(')
          ..write('id: $id, ')
          ..write('memoryId: $memoryId, ')
          ..write('type: $type, ')
          ..write('rawValue: $rawValue, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('searchValue: $searchValue, ')
          ..write('confidence: $confidence, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    memoryId,
    type,
    rawValue,
    normalizedValue,
    searchValue,
    confidence,
    startOffset,
    endOffset,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEntityRow &&
          other.id == this.id &&
          other.memoryId == this.memoryId &&
          other.type == this.type &&
          other.rawValue == this.rawValue &&
          other.normalizedValue == this.normalizedValue &&
          other.searchValue == this.searchValue &&
          other.confidence == this.confidence &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.createdAt == this.createdAt);
}

class MemoryEntitiesCompanion extends UpdateCompanion<MemoryEntityRow> {
  final Value<String> id;
  final Value<String> memoryId;
  final Value<String> type;
  final Value<String> rawValue;
  final Value<String> normalizedValue;
  final Value<String> searchValue;
  final Value<double> confidence;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MemoryEntitiesCompanion({
    this.id = const Value.absent(),
    this.memoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.rawValue = const Value.absent(),
    this.normalizedValue = const Value.absent(),
    this.searchValue = const Value.absent(),
    this.confidence = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEntitiesCompanion.insert({
    required String id,
    required String memoryId,
    required String type,
    required String rawValue,
    required String normalizedValue,
    required String searchValue,
    required double confidence,
    required int startOffset,
    required int endOffset,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       memoryId = Value(memoryId),
       type = Value(type),
       rawValue = Value(rawValue),
       normalizedValue = Value(normalizedValue),
       searchValue = Value(searchValue),
       confidence = Value(confidence),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       createdAt = Value(createdAt);
  static Insertable<MemoryEntityRow> custom({
    Expression<String>? id,
    Expression<String>? memoryId,
    Expression<String>? type,
    Expression<String>? rawValue,
    Expression<String>? normalizedValue,
    Expression<String>? searchValue,
    Expression<double>? confidence,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memoryId != null) 'memory_id': memoryId,
      if (type != null) 'type': type,
      if (rawValue != null) 'raw_value': rawValue,
      if (normalizedValue != null) 'normalized_value': normalizedValue,
      if (searchValue != null) 'search_value': searchValue,
      if (confidence != null) 'confidence': confidence,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEntitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? memoryId,
    Value<String>? type,
    Value<String>? rawValue,
    Value<String>? normalizedValue,
    Value<String>? searchValue,
    Value<double>? confidence,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoryEntitiesCompanion(
      id: id ?? this.id,
      memoryId: memoryId ?? this.memoryId,
      type: type ?? this.type,
      rawValue: rawValue ?? this.rawValue,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      searchValue: searchValue ?? this.searchValue,
      confidence: confidence ?? this.confidence,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memoryId.present) {
      map['memory_id'] = Variable<String>(memoryId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (rawValue.present) {
      map['raw_value'] = Variable<String>(rawValue.value);
    }
    if (normalizedValue.present) {
      map['normalized_value'] = Variable<String>(normalizedValue.value);
    }
    if (searchValue.present) {
      map['search_value'] = Variable<String>(searchValue.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntitiesCompanion(')
          ..write('id: $id, ')
          ..write('memoryId: $memoryId, ')
          ..write('type: $type, ')
          ..write('rawValue: $rawValue, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('searchValue: $searchValue, ')
          ..write('confidence: $confidence, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaRow extends DataClass implements Insertable<SyncMetaRow> {
  final String key;
  final String value;
  const SyncMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaRow copyWith({String? key, String? value}) =>
      SyncMetaRow(key: key ?? this.key, value: value ?? this.value);
  SyncMetaRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoryIdMeta = const VerificationMeta(
    'memoryId',
  );
  @override
  late final GeneratedColumn<String> memoryId = GeneratedColumn<String>(
    'memory_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localTimeMeta = const VerificationMeta(
    'localTime',
  );
  @override
  late final GeneratedColumn<String> localTime = GeneratedColumn<String>(
    'local_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<int> remindAt = GeneratedColumn<int>(
    'remind_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<int> scheduledAt = GeneratedColumn<int>(
    'scheduled_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memoryId,
    ownerUserId,
    localDate,
    localTime,
    timeZone,
    remindAt,
    scheduledAt,
    status,
    notificationId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('memory_id')) {
      context.handle(
        _memoryIdMeta,
        memoryId.isAcceptableOrUnknown(data['memory_id']!, _memoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoryIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('local_time')) {
      context.handle(
        _localTimeMeta,
        localTime.isAcceptableOrUnknown(data['local_time']!, _localTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_localTimeMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    } else if (isInserting) {
      context.missing(_remindAtMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {notificationId};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      localTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_time'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_at'],
      )!,
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  /// Client-generated UUIDv4.
  final String id;
  final String memoryId;

  /// Null means the memory is guest-owned. Follows its memory.
  final String? ownerUserId;

  /// What the user chose: `YYYY-MM-DD` and `HH:MM`, plus the zone they were in
  /// when they chose it — kept for diagnostics, not for scheduling.
  final String localDate;
  final String localTime;
  final String timeZone;

  /// The resolved instant, epoch milliseconds UTC. Derived from the columns
  /// above; the scheduler uses it, the user never sees it.
  final int remindAt;

  /// The instant last handed to the device scheduler, epoch ms, or null when
  /// nothing has been scheduled yet.
  ///
  /// Android can say *which* alarms it holds but not *when* they will fire, so
  /// without this a reminder moved to a new time would keep its old alarm and
  /// alert at the moment the user changed away from.
  final int? scheduledAt;

  /// `scheduled` (active), `fired` (has alerted — history, B-4) or
  /// `cancelled`. Only `scheduled` occupies a memory's single active slot.
  final String status;

  /// The Android notification id. Device-local and stable for the life of the
  /// reminder, so rescheduling replaces an alarm instead of adding one.
  final int notificationId;
  final int createdAt;
  final int updatedAt;
  const ReminderRow({
    required this.id,
    required this.memoryId,
    this.ownerUserId,
    required this.localDate,
    required this.localTime,
    required this.timeZone,
    required this.remindAt,
    this.scheduledAt,
    required this.status,
    required this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['memory_id'] = Variable<String>(memoryId);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['local_date'] = Variable<String>(localDate);
    map['local_time'] = Variable<String>(localTime);
    map['time_zone'] = Variable<String>(timeZone);
    map['remind_at'] = Variable<int>(remindAt);
    if (!nullToAbsent || scheduledAt != null) {
      map['scheduled_at'] = Variable<int>(scheduledAt);
    }
    map['status'] = Variable<String>(status);
    map['notification_id'] = Variable<int>(notificationId);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      memoryId: Value(memoryId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      localDate: Value(localDate),
      localTime: Value(localTime),
      timeZone: Value(timeZone),
      remindAt: Value(remindAt),
      scheduledAt: scheduledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledAt),
      status: Value(status),
      notificationId: Value(notificationId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<String>(json['id']),
      memoryId: serializer.fromJson<String>(json['memoryId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      localDate: serializer.fromJson<String>(json['localDate']),
      localTime: serializer.fromJson<String>(json['localTime']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      remindAt: serializer.fromJson<int>(json['remindAt']),
      scheduledAt: serializer.fromJson<int?>(json['scheduledAt']),
      status: serializer.fromJson<String>(json['status']),
      notificationId: serializer.fromJson<int>(json['notificationId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memoryId': serializer.toJson<String>(memoryId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'localDate': serializer.toJson<String>(localDate),
      'localTime': serializer.toJson<String>(localTime),
      'timeZone': serializer.toJson<String>(timeZone),
      'remindAt': serializer.toJson<int>(remindAt),
      'scheduledAt': serializer.toJson<int?>(scheduledAt),
      'status': serializer.toJson<String>(status),
      'notificationId': serializer.toJson<int>(notificationId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReminderRow copyWith({
    String? id,
    String? memoryId,
    Value<String?> ownerUserId = const Value.absent(),
    String? localDate,
    String? localTime,
    String? timeZone,
    int? remindAt,
    Value<int?> scheduledAt = const Value.absent(),
    String? status,
    int? notificationId,
    int? createdAt,
    int? updatedAt,
  }) => ReminderRow(
    id: id ?? this.id,
    memoryId: memoryId ?? this.memoryId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    localDate: localDate ?? this.localDate,
    localTime: localTime ?? this.localTime,
    timeZone: timeZone ?? this.timeZone,
    remindAt: remindAt ?? this.remindAt,
    scheduledAt: scheduledAt.present ? scheduledAt.value : this.scheduledAt,
    status: status ?? this.status,
    notificationId: notificationId ?? this.notificationId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      memoryId: data.memoryId.present ? data.memoryId.value : this.memoryId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      localTime: data.localTime.present ? data.localTime.value : this.localTime,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
      status: data.status.present ? data.status.value : this.status,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('memoryId: $memoryId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('localDate: $localDate, ')
          ..write('localTime: $localTime, ')
          ..write('timeZone: $timeZone, ')
          ..write('remindAt: $remindAt, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('status: $status, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    memoryId,
    ownerUserId,
    localDate,
    localTime,
    timeZone,
    remindAt,
    scheduledAt,
    status,
    notificationId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.memoryId == this.memoryId &&
          other.ownerUserId == this.ownerUserId &&
          other.localDate == this.localDate &&
          other.localTime == this.localTime &&
          other.timeZone == this.timeZone &&
          other.remindAt == this.remindAt &&
          other.scheduledAt == this.scheduledAt &&
          other.status == this.status &&
          other.notificationId == this.notificationId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> id;
  final Value<String> memoryId;
  final Value<String?> ownerUserId;
  final Value<String> localDate;
  final Value<String> localTime;
  final Value<String> timeZone;
  final Value<int> remindAt;
  final Value<int?> scheduledAt;
  final Value<String> status;
  final Value<int> notificationId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.memoryId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.localDate = const Value.absent(),
    this.localTime = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.status = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String memoryId,
    this.ownerUserId = const Value.absent(),
    required String localDate,
    required String localTime,
    required String timeZone,
    required int remindAt,
    this.scheduledAt = const Value.absent(),
    required String status,
    this.notificationId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : id = Value(id),
       memoryId = Value(memoryId),
       localDate = Value(localDate),
       localTime = Value(localTime),
       timeZone = Value(timeZone),
       remindAt = Value(remindAt),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReminderRow> custom({
    Expression<String>? id,
    Expression<String>? memoryId,
    Expression<String>? ownerUserId,
    Expression<String>? localDate,
    Expression<String>? localTime,
    Expression<String>? timeZone,
    Expression<int>? remindAt,
    Expression<int>? scheduledAt,
    Expression<String>? status,
    Expression<int>? notificationId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memoryId != null) 'memory_id': memoryId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (localDate != null) 'local_date': localDate,
      if (localTime != null) 'local_time': localTime,
      if (timeZone != null) 'time_zone': timeZone,
      if (remindAt != null) 'remind_at': remindAt,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (status != null) 'status': status,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? memoryId,
    Value<String?>? ownerUserId,
    Value<String>? localDate,
    Value<String>? localTime,
    Value<String>? timeZone,
    Value<int>? remindAt,
    Value<int?>? scheduledAt,
    Value<String>? status,
    Value<int>? notificationId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      memoryId: memoryId ?? this.memoryId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      localDate: localDate ?? this.localDate,
      localTime: localTime ?? this.localTime,
      timeZone: timeZone ?? this.timeZone,
      remindAt: remindAt ?? this.remindAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memoryId.present) {
      map['memory_id'] = Variable<String>(memoryId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (localTime.present) {
      map['local_time'] = Variable<String>(localTime.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<int>(remindAt.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<int>(scheduledAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('memoryId: $memoryId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('localDate: $localDate, ')
          ..write('localTime: $localTime, ')
          ..write('timeZone: $timeZone, ')
          ..write('remindAt: $remindAt, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('status: $status, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$TindakDatabase extends GeneratedDatabase {
  _$TindakDatabase(QueryExecutor e) : super(e);
  $TindakDatabaseManager get managers => $TindakDatabaseManager(this);
  late final $MemoriesTable memories = $MemoriesTable(this);
  late final $MemoryEntitiesTable memoryEntities = $MemoryEntitiesTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final Index memoriesVisibleCreatedIdx = Index(
    'memories_visible_created_idx',
    'CREATE INDEX memories_visible_created_idx ON memories (deleted_at, created_at)',
  );
  late final Index memoryEntitiesMemoryIdx = Index(
    'memory_entities_memory_idx',
    'CREATE INDEX memory_entities_memory_idx ON memory_entities (memory_id)',
  );
  late final Index memoryEntitiesSearchIdx = Index(
    'memory_entities_search_idx',
    'CREATE INDEX memory_entities_search_idx ON memory_entities (search_value)',
  );
  late final Index remindersMemoryIdx = Index(
    'reminders_memory_idx',
    'CREATE INDEX reminders_memory_idx ON reminders (memory_id)',
  );
  late final Index remindersRemindAtIdx = Index(
    'reminders_remind_at_idx',
    'CREATE INDEX reminders_remind_at_idx ON reminders (remind_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    memories,
    memoryEntities,
    syncMeta,
    reminders,
    memoriesVisibleCreatedIdx,
    memoryEntitiesMemoryIdx,
    memoryEntitiesSearchIdx,
    remindersMemoryIdx,
    remindersRemindAtIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'memories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('memory_entities', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'memories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MemoriesTableCreateCompanionBuilder =
    MemoriesCompanion Function({
      required String id,
      required String content,
      required String intakeSource,
      Value<String?> sourceApp,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<String?> ownerUserId,
      required String syncStatus,
      Value<int?> serverUpdatedAt,
      Value<int> rowid,
    });
typedef $$MemoriesTableUpdateCompanionBuilder =
    MemoriesCompanion Function({
      Value<String> id,
      Value<String> content,
      Value<String> intakeSource,
      Value<String?> sourceApp,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<int?> serverUpdatedAt,
      Value<int> rowid,
    });

final class $$MemoriesTableReferences
    extends BaseReferences<_$TindakDatabase, $MemoriesTable, MemoryRow> {
  $$MemoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemoryEntitiesTable, List<MemoryEntityRow>>
  _memoryEntitiesRefsTable(_$TindakDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.memoryEntities,
        aliasName: $_aliasNameGenerator(
          db.memories.id,
          db.memoryEntities.memoryId,
        ),
      );

  $$MemoryEntitiesTableProcessedTableManager get memoryEntitiesRefs {
    final manager = $$MemoryEntitiesTableTableManager(
      $_db,
      $_db.memoryEntities,
    ).filter((f) => f.memoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryEntitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$TindakDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(db.memories.id, db.reminders.memoryId),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.memoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemoriesTableFilterComposer
    extends Composer<_$TindakDatabase, $MemoriesTable> {
  $$MemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intakeSource => $composableBuilder(
    column: $table.intakeSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memoryEntitiesRefs(
    Expression<bool> Function($$MemoryEntitiesTableFilterComposer f) f,
  ) {
    final $$MemoryEntitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryEntities,
      getReferencedColumn: (t) => t.memoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryEntitiesTableFilterComposer(
            $db: $db,
            $table: $db.memoryEntities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.memoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemoriesTableOrderingComposer
    extends Composer<_$TindakDatabase, $MemoriesTable> {
  $$MemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intakeSource => $composableBuilder(
    column: $table.intakeSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoriesTableAnnotationComposer
    extends Composer<_$TindakDatabase, $MemoriesTable> {
  $$MemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get intakeSource => $composableBuilder(
    column: $table.intakeSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceApp =>
      $composableBuilder(column: $table.sourceApp, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  Expression<T> memoryEntitiesRefs<T extends Object>(
    Expression<T> Function($$MemoryEntitiesTableAnnotationComposer a) f,
  ) {
    final $$MemoryEntitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryEntities,
      getReferencedColumn: (t) => t.memoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryEntitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryEntities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.memoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemoriesTableTableManager
    extends
        RootTableManager<
          _$TindakDatabase,
          $MemoriesTable,
          MemoryRow,
          $$MemoriesTableFilterComposer,
          $$MemoriesTableOrderingComposer,
          $$MemoriesTableAnnotationComposer,
          $$MemoriesTableCreateCompanionBuilder,
          $$MemoriesTableUpdateCompanionBuilder,
          (MemoryRow, $$MemoriesTableReferences),
          MemoryRow,
          PrefetchHooks Function({bool memoryEntitiesRefs, bool remindersRefs})
        > {
  $$MemoriesTableTableManager(_$TindakDatabase db, $MemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> intakeSource = const Value.absent(),
                Value<String?> sourceApp = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoriesCompanion(
                id: id,
                content: content,
                intakeSource: intakeSource,
                sourceApp: sourceApp,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String content,
                required String intakeSource,
                Value<String?> sourceApp = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                required String syncStatus,
                Value<int?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoriesCompanion.insert(
                id: id,
                content: content,
                intakeSource: intakeSource,
                sourceApp: sourceApp,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({memoryEntitiesRefs = false, remindersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memoryEntitiesRefs) db.memoryEntities,
                    if (remindersRefs) db.reminders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memoryEntitiesRefs)
                        await $_getPrefetchedData<
                          MemoryRow,
                          $MemoriesTable,
                          MemoryEntityRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoriesTableReferences
                              ._memoryEntitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryEntitiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          MemoryRow,
                          $MemoriesTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoriesTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$TindakDatabase,
      $MemoriesTable,
      MemoryRow,
      $$MemoriesTableFilterComposer,
      $$MemoriesTableOrderingComposer,
      $$MemoriesTableAnnotationComposer,
      $$MemoriesTableCreateCompanionBuilder,
      $$MemoriesTableUpdateCompanionBuilder,
      (MemoryRow, $$MemoriesTableReferences),
      MemoryRow,
      PrefetchHooks Function({bool memoryEntitiesRefs, bool remindersRefs})
    >;
typedef $$MemoryEntitiesTableCreateCompanionBuilder =
    MemoryEntitiesCompanion Function({
      required String id,
      required String memoryId,
      required String type,
      required String rawValue,
      required String normalizedValue,
      required String searchValue,
      required double confidence,
      required int startOffset,
      required int endOffset,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MemoryEntitiesTableUpdateCompanionBuilder =
    MemoryEntitiesCompanion Function({
      Value<String> id,
      Value<String> memoryId,
      Value<String> type,
      Value<String> rawValue,
      Value<String> normalizedValue,
      Value<String> searchValue,
      Value<double> confidence,
      Value<int> startOffset,
      Value<int> endOffset,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$MemoryEntitiesTableReferences
    extends
        BaseReferences<
          _$TindakDatabase,
          $MemoryEntitiesTable,
          MemoryEntityRow
        > {
  $$MemoryEntitiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemoriesTable _memoryIdTable(_$TindakDatabase db) =>
      db.memories.createAlias(
        $_aliasNameGenerator(db.memoryEntities.memoryId, db.memories.id),
      );

  $$MemoriesTableProcessedTableManager get memoryId {
    final $_column = $_itemColumn<String>('memory_id')!;

    final manager = $$MemoriesTableTableManager(
      $_db,
      $_db.memories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryEntitiesTableFilterComposer
    extends Composer<_$TindakDatabase, $MemoryEntitiesTable> {
  $$MemoryEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawValue => $composableBuilder(
    column: $table.rawValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchValue => $composableBuilder(
    column: $table.searchValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoriesTableFilterComposer get memoryId {
    final $$MemoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoryId,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableFilterComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryEntitiesTableOrderingComposer
    extends Composer<_$TindakDatabase, $MemoryEntitiesTable> {
  $$MemoryEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawValue => $composableBuilder(
    column: $table.rawValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchValue => $composableBuilder(
    column: $table.searchValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoriesTableOrderingComposer get memoryId {
    final $$MemoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoryId,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableOrderingComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryEntitiesTableAnnotationComposer
    extends Composer<_$TindakDatabase, $MemoryEntitiesTable> {
  $$MemoryEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get rawValue =>
      $composableBuilder(column: $table.rawValue, builder: (column) => column);

  GeneratedColumn<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchValue => $composableBuilder(
    column: $table.searchValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MemoriesTableAnnotationComposer get memoryId {
    final $$MemoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoryId,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryEntitiesTableTableManager
    extends
        RootTableManager<
          _$TindakDatabase,
          $MemoryEntitiesTable,
          MemoryEntityRow,
          $$MemoryEntitiesTableFilterComposer,
          $$MemoryEntitiesTableOrderingComposer,
          $$MemoryEntitiesTableAnnotationComposer,
          $$MemoryEntitiesTableCreateCompanionBuilder,
          $$MemoryEntitiesTableUpdateCompanionBuilder,
          (MemoryEntityRow, $$MemoryEntitiesTableReferences),
          MemoryEntityRow,
          PrefetchHooks Function({bool memoryId})
        > {
  $$MemoryEntitiesTableTableManager(
    _$TindakDatabase db,
    $MemoryEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memoryId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> rawValue = const Value.absent(),
                Value<String> normalizedValue = const Value.absent(),
                Value<String> searchValue = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntitiesCompanion(
                id: id,
                memoryId: memoryId,
                type: type,
                rawValue: rawValue,
                normalizedValue: normalizedValue,
                searchValue: searchValue,
                confidence: confidence,
                startOffset: startOffset,
                endOffset: endOffset,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memoryId,
                required String type,
                required String rawValue,
                required String normalizedValue,
                required String searchValue,
                required double confidence,
                required int startOffset,
                required int endOffset,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntitiesCompanion.insert(
                id: id,
                memoryId: memoryId,
                type: type,
                rawValue: rawValue,
                normalizedValue: normalizedValue,
                searchValue: searchValue,
                confidence: confidence,
                startOffset: startOffset,
                endOffset: endOffset,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryEntitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (memoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memoryId,
                                referencedTable: $$MemoryEntitiesTableReferences
                                    ._memoryIdTable(db),
                                referencedColumn:
                                    $$MemoryEntitiesTableReferences
                                        ._memoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemoryEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$TindakDatabase,
      $MemoryEntitiesTable,
      MemoryEntityRow,
      $$MemoryEntitiesTableFilterComposer,
      $$MemoryEntitiesTableOrderingComposer,
      $$MemoryEntitiesTableAnnotationComposer,
      $$MemoryEntitiesTableCreateCompanionBuilder,
      $$MemoryEntitiesTableUpdateCompanionBuilder,
      (MemoryEntityRow, $$MemoryEntitiesTableReferences),
      MemoryEntityRow,
      PrefetchHooks Function({bool memoryId})
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$TindakDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$TindakDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$TindakDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$TindakDatabase,
          $SyncMetaTable,
          SyncMetaRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaRow,
            BaseReferences<_$TindakDatabase, $SyncMetaTable, SyncMetaRow>,
          ),
          SyncMetaRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$TindakDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$TindakDatabase,
      $SyncMetaTable,
      SyncMetaRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaRow,
        BaseReferences<_$TindakDatabase, $SyncMetaTable, SyncMetaRow>,
      ),
      SyncMetaRow,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String memoryId,
      Value<String?> ownerUserId,
      required String localDate,
      required String localTime,
      required String timeZone,
      required int remindAt,
      Value<int?> scheduledAt,
      required String status,
      Value<int> notificationId,
      required int createdAt,
      required int updatedAt,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> memoryId,
      Value<String?> ownerUserId,
      Value<String> localDate,
      Value<String> localTime,
      Value<String> timeZone,
      Value<int> remindAt,
      Value<int?> scheduledAt,
      Value<String> status,
      Value<int> notificationId,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

final class $$RemindersTableReferences
    extends BaseReferences<_$TindakDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemoriesTable _memoryIdTable(_$TindakDatabase db) => db.memories
      .createAlias($_aliasNameGenerator(db.reminders.memoryId, db.memories.id));

  $$MemoriesTableProcessedTableManager get memoryId {
    final $_column = $_itemColumn<String>('memory_id')!;

    final manager = $$MemoriesTableTableManager(
      $_db,
      $_db.memories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$TindakDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localTime => $composableBuilder(
    column: $table.localTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoriesTableFilterComposer get memoryId {
    final $$MemoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoryId,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableFilterComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$TindakDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localTime => $composableBuilder(
    column: $table.localTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoriesTableOrderingComposer get memoryId {
    final $$MemoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoryId,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableOrderingComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$TindakDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get localTime =>
      $composableBuilder(column: $table.localTime, builder: (column) => column);

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<int> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<int> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MemoriesTableAnnotationComposer get memoryId {
    final $$MemoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoryId,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$TindakDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({bool memoryId})
        > {
  $$RemindersTableTableManager(_$TindakDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memoryId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<String> localTime = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<int> remindAt = const Value.absent(),
                Value<int?> scheduledAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> notificationId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                memoryId: memoryId,
                ownerUserId: ownerUserId,
                localDate: localDate,
                localTime: localTime,
                timeZone: timeZone,
                remindAt: remindAt,
                scheduledAt: scheduledAt,
                status: status,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memoryId,
                Value<String?> ownerUserId = const Value.absent(),
                required String localDate,
                required String localTime,
                required String timeZone,
                required int remindAt,
                Value<int?> scheduledAt = const Value.absent(),
                required String status,
                Value<int> notificationId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => RemindersCompanion.insert(
                id: id,
                memoryId: memoryId,
                ownerUserId: ownerUserId,
                localDate: localDate,
                localTime: localTime,
                timeZone: timeZone,
                remindAt: remindAt,
                scheduledAt: scheduledAt,
                status: status,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (memoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memoryId,
                                referencedTable: $$RemindersTableReferences
                                    ._memoryIdTable(db),
                                referencedColumn: $$RemindersTableReferences
                                    ._memoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$TindakDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({bool memoryId})
    >;

class $TindakDatabaseManager {
  final _$TindakDatabase _db;
  $TindakDatabaseManager(this._db);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db, _db.memories);
  $$MemoryEntitiesTableTableManager get memoryEntities =>
      $$MemoryEntitiesTableTableManager(_db, _db.memoryEntities);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
}
