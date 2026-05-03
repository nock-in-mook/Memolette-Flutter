// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MemosTable extends Memos with TableInfo<$MemosTable, Memo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemosTable(this.attachedDatabase, [this._alias]);
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isMarkdownMeta = const VerificationMeta(
    'isMarkdown',
  );
  @override
  late final GeneratedColumn<bool> isMarkdown = GeneratedColumn<bool>(
    'is_markdown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_markdown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _manualSortOrderMeta = const VerificationMeta(
    'manualSortOrder',
  );
  @override
  late final GeneratedColumn<int> manualSortOrder = GeneratedColumn<int>(
    'manual_sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _viewCountMeta = const VerificationMeta(
    'viewCount',
  );
  @override
  late final GeneratedColumn<int> viewCount = GeneratedColumn<int>(
    'view_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastViewedAtMeta = const VerificationMeta(
    'lastViewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastViewedAt = GeneratedColumn<DateTime>(
    'last_viewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bgColorIndexMeta = const VerificationMeta(
    'bgColorIndex',
  );
  @override
  late final GeneratedColumn<int> bgColorIndex = GeneratedColumn<int>(
    'bg_color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    title,
    isMarkdown,
    createdAt,
    updatedAt,
    isPinned,
    manualSortOrder,
    viewCount,
    lastViewedAt,
    isLocked,
    bgColorIndex,
    eventDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Memo> instance, {
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
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('is_markdown')) {
      context.handle(
        _isMarkdownMeta,
        isMarkdown.isAcceptableOrUnknown(data['is_markdown']!, _isMarkdownMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('manual_sort_order')) {
      context.handle(
        _manualSortOrderMeta,
        manualSortOrder.isAcceptableOrUnknown(
          data['manual_sort_order']!,
          _manualSortOrderMeta,
        ),
      );
    }
    if (data.containsKey('view_count')) {
      context.handle(
        _viewCountMeta,
        viewCount.isAcceptableOrUnknown(data['view_count']!, _viewCountMeta),
      );
    }
    if (data.containsKey('last_viewed_at')) {
      context.handle(
        _lastViewedAtMeta,
        lastViewedAt.isAcceptableOrUnknown(
          data['last_viewed_at']!,
          _lastViewedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    }
    if (data.containsKey('bg_color_index')) {
      context.handle(
        _bgColorIndexMeta,
        bgColorIndex.isAcceptableOrUnknown(
          data['bg_color_index']!,
          _bgColorIndexMeta,
        ),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Memo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Memo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isMarkdown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_markdown'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      manualSortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_sort_order'],
      )!,
      viewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}view_count'],
      )!,
      lastViewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_viewed_at'],
      ),
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      bgColorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bg_color_index'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      ),
    );
  }

  @override
  $MemosTable createAlias(String alias) {
    return $MemosTable(attachedDatabase, alias);
  }
}

class Memo extends DataClass implements Insertable<Memo> {
  final String id;
  final String content;
  final String title;
  final bool isMarkdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final int manualSortOrder;
  final int viewCount;
  final DateTime? lastViewedAt;
  final bool isLocked;
  final int bgColorIndex;
  final DateTime? eventDate;
  const Memo({
    required this.id,
    required this.content,
    required this.title,
    required this.isMarkdown,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.manualSortOrder,
    required this.viewCount,
    this.lastViewedAt,
    required this.isLocked,
    required this.bgColorIndex,
    this.eventDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content'] = Variable<String>(content);
    map['title'] = Variable<String>(title);
    map['is_markdown'] = Variable<bool>(isMarkdown);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['manual_sort_order'] = Variable<int>(manualSortOrder);
    map['view_count'] = Variable<int>(viewCount);
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt);
    }
    map['is_locked'] = Variable<bool>(isLocked);
    map['bg_color_index'] = Variable<int>(bgColorIndex);
    if (!nullToAbsent || eventDate != null) {
      map['event_date'] = Variable<DateTime>(eventDate);
    }
    return map;
  }

  MemosCompanion toCompanion(bool nullToAbsent) {
    return MemosCompanion(
      id: Value(id),
      content: Value(content),
      title: Value(title),
      isMarkdown: Value(isMarkdown),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isPinned: Value(isPinned),
      manualSortOrder: Value(manualSortOrder),
      viewCount: Value(viewCount),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
      isLocked: Value(isLocked),
      bgColorIndex: Value(bgColorIndex),
      eventDate: eventDate == null && nullToAbsent
          ? const Value.absent()
          : Value(eventDate),
    );
  }

  factory Memo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Memo(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      title: serializer.fromJson<String>(json['title']),
      isMarkdown: serializer.fromJson<bool>(json['isMarkdown']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      manualSortOrder: serializer.fromJson<int>(json['manualSortOrder']),
      viewCount: serializer.fromJson<int>(json['viewCount']),
      lastViewedAt: serializer.fromJson<DateTime?>(json['lastViewedAt']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      bgColorIndex: serializer.fromJson<int>(json['bgColorIndex']),
      eventDate: serializer.fromJson<DateTime?>(json['eventDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'title': serializer.toJson<String>(title),
      'isMarkdown': serializer.toJson<bool>(isMarkdown),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'manualSortOrder': serializer.toJson<int>(manualSortOrder),
      'viewCount': serializer.toJson<int>(viewCount),
      'lastViewedAt': serializer.toJson<DateTime?>(lastViewedAt),
      'isLocked': serializer.toJson<bool>(isLocked),
      'bgColorIndex': serializer.toJson<int>(bgColorIndex),
      'eventDate': serializer.toJson<DateTime?>(eventDate),
    };
  }

  Memo copyWith({
    String? id,
    String? content,
    String? title,
    bool? isMarkdown,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    int? manualSortOrder,
    int? viewCount,
    Value<DateTime?> lastViewedAt = const Value.absent(),
    bool? isLocked,
    int? bgColorIndex,
    Value<DateTime?> eventDate = const Value.absent(),
  }) => Memo(
    id: id ?? this.id,
    content: content ?? this.content,
    title: title ?? this.title,
    isMarkdown: isMarkdown ?? this.isMarkdown,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPinned: isPinned ?? this.isPinned,
    manualSortOrder: manualSortOrder ?? this.manualSortOrder,
    viewCount: viewCount ?? this.viewCount,
    lastViewedAt: lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
    isLocked: isLocked ?? this.isLocked,
    bgColorIndex: bgColorIndex ?? this.bgColorIndex,
    eventDate: eventDate.present ? eventDate.value : this.eventDate,
  );
  Memo copyWithCompanion(MemosCompanion data) {
    return Memo(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      title: data.title.present ? data.title.value : this.title,
      isMarkdown: data.isMarkdown.present
          ? data.isMarkdown.value
          : this.isMarkdown,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      manualSortOrder: data.manualSortOrder.present
          ? data.manualSortOrder.value
          : this.manualSortOrder,
      viewCount: data.viewCount.present ? data.viewCount.value : this.viewCount,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      bgColorIndex: data.bgColorIndex.present
          ? data.bgColorIndex.value
          : this.bgColorIndex,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Memo(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('title: $title, ')
          ..write('isMarkdown: $isMarkdown, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('manualSortOrder: $manualSortOrder, ')
          ..write('viewCount: $viewCount, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('isLocked: $isLocked, ')
          ..write('bgColorIndex: $bgColorIndex, ')
          ..write('eventDate: $eventDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    title,
    isMarkdown,
    createdAt,
    updatedAt,
    isPinned,
    manualSortOrder,
    viewCount,
    lastViewedAt,
    isLocked,
    bgColorIndex,
    eventDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Memo &&
          other.id == this.id &&
          other.content == this.content &&
          other.title == this.title &&
          other.isMarkdown == this.isMarkdown &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isPinned == this.isPinned &&
          other.manualSortOrder == this.manualSortOrder &&
          other.viewCount == this.viewCount &&
          other.lastViewedAt == this.lastViewedAt &&
          other.isLocked == this.isLocked &&
          other.bgColorIndex == this.bgColorIndex &&
          other.eventDate == this.eventDate);
}

class MemosCompanion extends UpdateCompanion<Memo> {
  final Value<String> id;
  final Value<String> content;
  final Value<String> title;
  final Value<bool> isMarkdown;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isPinned;
  final Value<int> manualSortOrder;
  final Value<int> viewCount;
  final Value<DateTime?> lastViewedAt;
  final Value<bool> isLocked;
  final Value<int> bgColorIndex;
  final Value<DateTime?> eventDate;
  final Value<int> rowid;
  const MemosCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.title = const Value.absent(),
    this.isMarkdown = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.manualSortOrder = const Value.absent(),
    this.viewCount = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.bgColorIndex = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemosCompanion.insert({
    required String id,
    this.content = const Value.absent(),
    this.title = const Value.absent(),
    this.isMarkdown = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.manualSortOrder = const Value.absent(),
    this.viewCount = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.bgColorIndex = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Memo> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<String>? title,
    Expression<bool>? isMarkdown,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isPinned,
    Expression<int>? manualSortOrder,
    Expression<int>? viewCount,
    Expression<DateTime>? lastViewedAt,
    Expression<bool>? isLocked,
    Expression<int>? bgColorIndex,
    Expression<DateTime>? eventDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (title != null) 'title': title,
      if (isMarkdown != null) 'is_markdown': isMarkdown,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (manualSortOrder != null) 'manual_sort_order': manualSortOrder,
      if (viewCount != null) 'view_count': viewCount,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
      if (isLocked != null) 'is_locked': isLocked,
      if (bgColorIndex != null) 'bg_color_index': bgColorIndex,
      if (eventDate != null) 'event_date': eventDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemosCompanion copyWith({
    Value<String>? id,
    Value<String>? content,
    Value<String>? title,
    Value<bool>? isMarkdown,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isPinned,
    Value<int>? manualSortOrder,
    Value<int>? viewCount,
    Value<DateTime?>? lastViewedAt,
    Value<bool>? isLocked,
    Value<int>? bgColorIndex,
    Value<DateTime?>? eventDate,
    Value<int>? rowid,
  }) {
    return MemosCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      title: title ?? this.title,
      isMarkdown: isMarkdown ?? this.isMarkdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      manualSortOrder: manualSortOrder ?? this.manualSortOrder,
      viewCount: viewCount ?? this.viewCount,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      isLocked: isLocked ?? this.isLocked,
      bgColorIndex: bgColorIndex ?? this.bgColorIndex,
      eventDate: eventDate ?? this.eventDate,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isMarkdown.present) {
      map['is_markdown'] = Variable<bool>(isMarkdown.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (manualSortOrder.present) {
      map['manual_sort_order'] = Variable<int>(manualSortOrder.value);
    }
    if (viewCount.present) {
      map['view_count'] = Variable<int>(viewCount.value);
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (bgColorIndex.present) {
      map['bg_color_index'] = Variable<int>(bgColorIndex.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemosCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('title: $title, ')
          ..write('isMarkdown: $isMarkdown, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('manualSortOrder: $manualSortOrder, ')
          ..write('viewCount: $viewCount, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('isLocked: $isLocked, ')
          ..write('bgColorIndex: $bgColorIndex, ')
          ..write('eventDate: $eventDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _gridSizeMeta = const VerificationMeta(
    'gridSize',
  );
  @override
  late final GeneratedColumn<int> gridSize = GeneratedColumn<int>(
    'grid_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _parentTagIdMeta = const VerificationMeta(
    'parentTagId',
  );
  @override
  late final GeneratedColumn<String> parentTagId = GeneratedColumn<String>(
    'parent_tag_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorIndex,
    gridSize,
    parentTagId,
    sortOrder,
    isSystem,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('grid_size')) {
      context.handle(
        _gridSizeMeta,
        gridSize.isAcceptableOrUnknown(data['grid_size']!, _gridSizeMeta),
      );
    }
    if (data.containsKey('parent_tag_id')) {
      context.handle(
        _parentTagIdMeta,
        parentTagId.isAcceptableOrUnknown(
          data['parent_tag_id']!,
          _parentTagIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      gridSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grid_size'],
      )!,
      parentTagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_tag_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final int colorIndex;
  final int gridSize;
  final String? parentTagId;
  final int sortOrder;
  final bool isSystem;
  final DateTime updatedAt;
  const Tag({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.gridSize,
    this.parentTagId,
    required this.sortOrder,
    required this.isSystem,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    map['grid_size'] = Variable<int>(gridSize);
    if (!nullToAbsent || parentTagId != null) {
      map['parent_tag_id'] = Variable<String>(parentTagId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_system'] = Variable<bool>(isSystem);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorIndex: Value(colorIndex),
      gridSize: Value(gridSize),
      parentTagId: parentTagId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTagId),
      sortOrder: Value(sortOrder),
      isSystem: Value(isSystem),
      updatedAt: Value(updatedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      gridSize: serializer.fromJson<int>(json['gridSize']),
      parentTagId: serializer.fromJson<String?>(json['parentTagId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'gridSize': serializer.toJson<int>(gridSize),
      'parentTagId': serializer.toJson<String?>(parentTagId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isSystem': serializer.toJson<bool>(isSystem),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    int? colorIndex,
    int? gridSize,
    Value<String?> parentTagId = const Value.absent(),
    int? sortOrder,
    bool? isSystem,
    DateTime? updatedAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    gridSize: gridSize ?? this.gridSize,
    parentTagId: parentTagId.present ? parentTagId.value : this.parentTagId,
    sortOrder: sortOrder ?? this.sortOrder,
    isSystem: isSystem ?? this.isSystem,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      gridSize: data.gridSize.present ? data.gridSize.value : this.gridSize,
      parentTagId: data.parentTagId.present
          ? data.parentTagId.value
          : this.parentTagId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('gridSize: $gridSize, ')
          ..write('parentTagId: $parentTagId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSystem: $isSystem, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorIndex,
    gridSize,
    parentTagId,
    sortOrder,
    isSystem,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.gridSize == this.gridSize &&
          other.parentTagId == this.parentTagId &&
          other.sortOrder == this.sortOrder &&
          other.isSystem == this.isSystem &&
          other.updatedAt == this.updatedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<int> gridSize;
  final Value<String?> parentTagId;
  final Value<int> sortOrder;
  final Value<bool> isSystem;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.gridSize = const Value.absent(),
    this.parentTagId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.gridSize = const Value.absent(),
    this.parentTagId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<int>? gridSize,
    Expression<String>? parentTagId,
    Expression<int>? sortOrder,
    Expression<bool>? isSystem,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (gridSize != null) 'grid_size': gridSize,
      if (parentTagId != null) 'parent_tag_id': parentTagId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isSystem != null) 'is_system': isSystem,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<int>? gridSize,
    Value<String?>? parentTagId,
    Value<int>? sortOrder,
    Value<bool>? isSystem,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      gridSize: gridSize ?? this.gridSize,
      parentTagId: parentTagId ?? this.parentTagId,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (gridSize.present) {
      map['grid_size'] = Variable<int>(gridSize.value);
    }
    if (parentTagId.present) {
      map['parent_tag_id'] = Variable<String>(parentTagId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('gridSize: $gridSize, ')
          ..write('parentTagId: $parentTagId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSystem: $isSystem, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoItemsTable extends TodoItems
    with TableInfo<$TodoItemsTable, TodoItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    title,
    isDone,
    parentId,
    sortOrder,
    createdAt,
    updatedAt,
    eventDate,
    memo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
    );
  }

  @override
  $TodoItemsTable createAlias(String alias) {
    return $TodoItemsTable(attachedDatabase, alias);
  }
}

class TodoItem extends DataClass implements Insertable<TodoItem> {
  final String id;
  final String listId;
  final String title;
  final bool isDone;
  final String? parentId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? eventDate;
  final String? memo;
  const TodoItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.isDone,
    this.parentId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.eventDate,
    this.memo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['list_id'] = Variable<String>(listId);
    map['title'] = Variable<String>(title);
    map['is_done'] = Variable<bool>(isDone);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || eventDate != null) {
      map['event_date'] = Variable<DateTime>(eventDate);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    return map;
  }

  TodoItemsCompanion toCompanion(bool nullToAbsent) {
    return TodoItemsCompanion(
      id: Value(id),
      listId: Value(listId),
      title: Value(title),
      isDone: Value(isDone),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      eventDate: eventDate == null && nullToAbsent
          ? const Value.absent()
          : Value(eventDate),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
    );
  }

  factory TodoItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoItem(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      eventDate: serializer.fromJson<DateTime?>(json['eventDate']),
      memo: serializer.fromJson<String?>(json['memo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String>(listId),
      'title': serializer.toJson<String>(title),
      'isDone': serializer.toJson<bool>(isDone),
      'parentId': serializer.toJson<String?>(parentId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'eventDate': serializer.toJson<DateTime?>(eventDate),
      'memo': serializer.toJson<String?>(memo),
    };
  }

  TodoItem copyWith({
    String? id,
    String? listId,
    String? title,
    bool? isDone,
    Value<String?> parentId = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> eventDate = const Value.absent(),
    Value<String?> memo = const Value.absent(),
  }) => TodoItem(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    parentId: parentId.present ? parentId.value : this.parentId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    eventDate: eventDate.present ? eventDate.value : this.eventDate,
    memo: memo.present ? memo.value : this.memo,
  );
  TodoItem copyWithCompanion(TodoItemsCompanion data) {
    return TodoItem(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      memo: data.memo.present ? data.memo.value : this.memo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoItem(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('eventDate: $eventDate, ')
          ..write('memo: $memo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    title,
    isDone,
    parentId,
    sortOrder,
    createdAt,
    updatedAt,
    eventDate,
    memo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoItem &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.isDone == this.isDone &&
          other.parentId == this.parentId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.eventDate == this.eventDate &&
          other.memo == this.memo);
}

class TodoItemsCompanion extends UpdateCompanion<TodoItem> {
  final Value<String> id;
  final Value<String> listId;
  final Value<String> title;
  final Value<bool> isDone;
  final Value<String?> parentId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> eventDate;
  final Value<String?> memo;
  final Value<int> rowid;
  const TodoItemsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.memo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoItemsCompanion.insert({
    required String id,
    required String listId,
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.memo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       listId = Value(listId);
  static Insertable<TodoItem> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<bool>? isDone,
    Expression<String>? parentId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? eventDate,
    Expression<String>? memo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (isDone != null) 'is_done': isDone,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (eventDate != null) 'event_date': eventDate,
      if (memo != null) 'memo': memo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? listId,
    Value<String>? title,
    Value<bool>? isDone,
    Value<String?>? parentId,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? eventDate,
    Value<String?>? memo,
    Value<int>? rowid,
  }) {
    return TodoItemsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      eventDate: eventDate ?? this.eventDate,
      memo: memo ?? this.memo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoItemsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('eventDate: $eventDate, ')
          ..write('memo: $memo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoListsTable extends TodoLists
    with TableInfo<$TodoListsTable, TodoList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _manualSortOrderMeta = const VerificationMeta(
    'manualSortOrder',
  );
  @override
  late final GeneratedColumn<int> manualSortOrder = GeneratedColumn<int>(
    'manual_sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isMergedMeta = const VerificationMeta(
    'isMerged',
  );
  @override
  late final GeneratedColumn<bool> isMerged = GeneratedColumn<bool>(
    'is_merged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_merged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bgColorIndexMeta = const VerificationMeta(
    'bgColorIndex',
  );
  @override
  late final GeneratedColumn<int> bgColorIndex = GeneratedColumn<int>(
    'bg_color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    isPinned,
    isLocked,
    manualSortOrder,
    createdAt,
    updatedAt,
    isMerged,
    eventDate,
    bgColorIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    }
    if (data.containsKey('manual_sort_order')) {
      context.handle(
        _manualSortOrderMeta,
        manualSortOrder.isAcceptableOrUnknown(
          data['manual_sort_order']!,
          _manualSortOrderMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_merged')) {
      context.handle(
        _isMergedMeta,
        isMerged.isAcceptableOrUnknown(data['is_merged']!, _isMergedMeta),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    }
    if (data.containsKey('bg_color_index')) {
      context.handle(
        _bgColorIndexMeta,
        bgColorIndex.isAcceptableOrUnknown(
          data['bg_color_index']!,
          _bgColorIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      manualSortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isMerged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_merged'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      ),
      bgColorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bg_color_index'],
      )!,
    );
  }

  @override
  $TodoListsTable createAlias(String alias) {
    return $TodoListsTable(attachedDatabase, alias);
  }
}

class TodoList extends DataClass implements Insertable<TodoList> {
  final String id;
  final String title;
  final bool isPinned;
  final bool isLocked;
  final int manualSortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMerged;
  final DateTime? eventDate;
  final int bgColorIndex;
  const TodoList({
    required this.id,
    required this.title,
    required this.isPinned,
    required this.isLocked,
    required this.manualSortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.isMerged,
    this.eventDate,
    required this.bgColorIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_locked'] = Variable<bool>(isLocked);
    map['manual_sort_order'] = Variable<int>(manualSortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_merged'] = Variable<bool>(isMerged);
    if (!nullToAbsent || eventDate != null) {
      map['event_date'] = Variable<DateTime>(eventDate);
    }
    map['bg_color_index'] = Variable<int>(bgColorIndex);
    return map;
  }

  TodoListsCompanion toCompanion(bool nullToAbsent) {
    return TodoListsCompanion(
      id: Value(id),
      title: Value(title),
      isPinned: Value(isPinned),
      isLocked: Value(isLocked),
      manualSortOrder: Value(manualSortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isMerged: Value(isMerged),
      eventDate: eventDate == null && nullToAbsent
          ? const Value.absent()
          : Value(eventDate),
      bgColorIndex: Value(bgColorIndex),
    );
  }

  factory TodoList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoList(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      manualSortOrder: serializer.fromJson<int>(json['manualSortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isMerged: serializer.fromJson<bool>(json['isMerged']),
      eventDate: serializer.fromJson<DateTime?>(json['eventDate']),
      bgColorIndex: serializer.fromJson<int>(json['bgColorIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isLocked': serializer.toJson<bool>(isLocked),
      'manualSortOrder': serializer.toJson<int>(manualSortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isMerged': serializer.toJson<bool>(isMerged),
      'eventDate': serializer.toJson<DateTime?>(eventDate),
      'bgColorIndex': serializer.toJson<int>(bgColorIndex),
    };
  }

  TodoList copyWith({
    String? id,
    String? title,
    bool? isPinned,
    bool? isLocked,
    int? manualSortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMerged,
    Value<DateTime?> eventDate = const Value.absent(),
    int? bgColorIndex,
  }) => TodoList(
    id: id ?? this.id,
    title: title ?? this.title,
    isPinned: isPinned ?? this.isPinned,
    isLocked: isLocked ?? this.isLocked,
    manualSortOrder: manualSortOrder ?? this.manualSortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isMerged: isMerged ?? this.isMerged,
    eventDate: eventDate.present ? eventDate.value : this.eventDate,
    bgColorIndex: bgColorIndex ?? this.bgColorIndex,
  );
  TodoList copyWithCompanion(TodoListsCompanion data) {
    return TodoList(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      manualSortOrder: data.manualSortOrder.present
          ? data.manualSortOrder.value
          : this.manualSortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isMerged: data.isMerged.present ? data.isMerged.value : this.isMerged,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      bgColorIndex: data.bgColorIndex.present
          ? data.bgColorIndex.value
          : this.bgColorIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoList(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('isPinned: $isPinned, ')
          ..write('isLocked: $isLocked, ')
          ..write('manualSortOrder: $manualSortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isMerged: $isMerged, ')
          ..write('eventDate: $eventDate, ')
          ..write('bgColorIndex: $bgColorIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    isPinned,
    isLocked,
    manualSortOrder,
    createdAt,
    updatedAt,
    isMerged,
    eventDate,
    bgColorIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoList &&
          other.id == this.id &&
          other.title == this.title &&
          other.isPinned == this.isPinned &&
          other.isLocked == this.isLocked &&
          other.manualSortOrder == this.manualSortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isMerged == this.isMerged &&
          other.eventDate == this.eventDate &&
          other.bgColorIndex == this.bgColorIndex);
}

class TodoListsCompanion extends UpdateCompanion<TodoList> {
  final Value<String> id;
  final Value<String> title;
  final Value<bool> isPinned;
  final Value<bool> isLocked;
  final Value<int> manualSortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isMerged;
  final Value<DateTime?> eventDate;
  final Value<int> bgColorIndex;
  final Value<int> rowid;
  const TodoListsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.manualSortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isMerged = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.bgColorIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.manualSortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isMerged = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.bgColorIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<TodoList> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<bool>? isPinned,
    Expression<bool>? isLocked,
    Expression<int>? manualSortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isMerged,
    Expression<DateTime>? eventDate,
    Expression<int>? bgColorIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isLocked != null) 'is_locked': isLocked,
      if (manualSortOrder != null) 'manual_sort_order': manualSortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isMerged != null) 'is_merged': isMerged,
      if (eventDate != null) 'event_date': eventDate,
      if (bgColorIndex != null) 'bg_color_index': bgColorIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<bool>? isPinned,
    Value<bool>? isLocked,
    Value<int>? manualSortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isMerged,
    Value<DateTime?>? eventDate,
    Value<int>? bgColorIndex,
    Value<int>? rowid,
  }) {
    return TodoListsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      manualSortOrder: manualSortOrder ?? this.manualSortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMerged: isMerged ?? this.isMerged,
      eventDate: eventDate ?? this.eventDate,
      bgColorIndex: bgColorIndex ?? this.bgColorIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (manualSortOrder.present) {
      map['manual_sort_order'] = Variable<int>(manualSortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isMerged.present) {
      map['is_merged'] = Variable<bool>(isMerged.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (bgColorIndex.present) {
      map['bg_color_index'] = Variable<int>(bgColorIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('isPinned: $isPinned, ')
          ..write('isLocked: $isLocked, ')
          ..write('manualSortOrder: $manualSortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isMerged: $isMerged, ')
          ..write('eventDate: $eventDate, ')
          ..write('bgColorIndex: $bgColorIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagHistoriesTable extends TagHistories
    with TableInfo<$TagHistoriesTable, TagHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _parentTagIdMeta = const VerificationMeta(
    'parentTagId',
  );
  @override
  late final GeneratedColumn<String> parentTagId = GeneratedColumn<String>(
    'parent_tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childTagIdMeta = const VerificationMeta(
    'childTagId',
  );
  @override
  late final GeneratedColumn<String> childTagId = GeneratedColumn<String>(
    'child_tag_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usedAtMeta = const VerificationMeta('usedAt');
  @override
  late final GeneratedColumn<DateTime> usedAt = GeneratedColumn<DateTime>(
    'used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, parentTagId, childTagId, usedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('parent_tag_id')) {
      context.handle(
        _parentTagIdMeta,
        parentTagId.isAcceptableOrUnknown(
          data['parent_tag_id']!,
          _parentTagIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parentTagIdMeta);
    }
    if (data.containsKey('child_tag_id')) {
      context.handle(
        _childTagIdMeta,
        childTagId.isAcceptableOrUnknown(
          data['child_tag_id']!,
          _childTagIdMeta,
        ),
      );
    }
    if (data.containsKey('used_at')) {
      context.handle(
        _usedAtMeta,
        usedAt.isAcceptableOrUnknown(data['used_at']!, _usedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      parentTagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_tag_id'],
      )!,
      childTagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_tag_id'],
      ),
      usedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}used_at'],
      )!,
    );
  }

  @override
  $TagHistoriesTable createAlias(String alias) {
    return $TagHistoriesTable(attachedDatabase, alias);
  }
}

class TagHistory extends DataClass implements Insertable<TagHistory> {
  final int id;
  final String parentTagId;
  final String? childTagId;
  final DateTime usedAt;
  const TagHistory({
    required this.id,
    required this.parentTagId,
    this.childTagId,
    required this.usedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['parent_tag_id'] = Variable<String>(parentTagId);
    if (!nullToAbsent || childTagId != null) {
      map['child_tag_id'] = Variable<String>(childTagId);
    }
    map['used_at'] = Variable<DateTime>(usedAt);
    return map;
  }

  TagHistoriesCompanion toCompanion(bool nullToAbsent) {
    return TagHistoriesCompanion(
      id: Value(id),
      parentTagId: Value(parentTagId),
      childTagId: childTagId == null && nullToAbsent
          ? const Value.absent()
          : Value(childTagId),
      usedAt: Value(usedAt),
    );
  }

  factory TagHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagHistory(
      id: serializer.fromJson<int>(json['id']),
      parentTagId: serializer.fromJson<String>(json['parentTagId']),
      childTagId: serializer.fromJson<String?>(json['childTagId']),
      usedAt: serializer.fromJson<DateTime>(json['usedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'parentTagId': serializer.toJson<String>(parentTagId),
      'childTagId': serializer.toJson<String?>(childTagId),
      'usedAt': serializer.toJson<DateTime>(usedAt),
    };
  }

  TagHistory copyWith({
    int? id,
    String? parentTagId,
    Value<String?> childTagId = const Value.absent(),
    DateTime? usedAt,
  }) => TagHistory(
    id: id ?? this.id,
    parentTagId: parentTagId ?? this.parentTagId,
    childTagId: childTagId.present ? childTagId.value : this.childTagId,
    usedAt: usedAt ?? this.usedAt,
  );
  TagHistory copyWithCompanion(TagHistoriesCompanion data) {
    return TagHistory(
      id: data.id.present ? data.id.value : this.id,
      parentTagId: data.parentTagId.present
          ? data.parentTagId.value
          : this.parentTagId,
      childTagId: data.childTagId.present
          ? data.childTagId.value
          : this.childTagId,
      usedAt: data.usedAt.present ? data.usedAt.value : this.usedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagHistory(')
          ..write('id: $id, ')
          ..write('parentTagId: $parentTagId, ')
          ..write('childTagId: $childTagId, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentTagId, childTagId, usedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagHistory &&
          other.id == this.id &&
          other.parentTagId == this.parentTagId &&
          other.childTagId == this.childTagId &&
          other.usedAt == this.usedAt);
}

class TagHistoriesCompanion extends UpdateCompanion<TagHistory> {
  final Value<int> id;
  final Value<String> parentTagId;
  final Value<String?> childTagId;
  final Value<DateTime> usedAt;
  const TagHistoriesCompanion({
    this.id = const Value.absent(),
    this.parentTagId = const Value.absent(),
    this.childTagId = const Value.absent(),
    this.usedAt = const Value.absent(),
  });
  TagHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String parentTagId,
    this.childTagId = const Value.absent(),
    this.usedAt = const Value.absent(),
  }) : parentTagId = Value(parentTagId);
  static Insertable<TagHistory> custom({
    Expression<int>? id,
    Expression<String>? parentTagId,
    Expression<String>? childTagId,
    Expression<DateTime>? usedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentTagId != null) 'parent_tag_id': parentTagId,
      if (childTagId != null) 'child_tag_id': childTagId,
      if (usedAt != null) 'used_at': usedAt,
    });
  }

  TagHistoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? parentTagId,
    Value<String?>? childTagId,
    Value<DateTime>? usedAt,
  }) {
    return TagHistoriesCompanion(
      id: id ?? this.id,
      parentTagId: parentTagId ?? this.parentTagId,
      childTagId: childTagId ?? this.childTagId,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (parentTagId.present) {
      map['parent_tag_id'] = Variable<String>(parentTagId.value);
    }
    if (childTagId.present) {
      map['child_tag_id'] = Variable<String>(childTagId.value);
    }
    if (usedAt.present) {
      map['used_at'] = Variable<DateTime>(usedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('parentTagId: $parentTagId, ')
          ..write('childTagId: $childTagId, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }
}

class $MemoTagsTable extends MemoTags with TableInfo<$MemoTagsTable, MemoTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _memoIdMeta = const VerificationMeta('memoId');
  @override
  late final GeneratedColumn<String> memoId = GeneratedColumn<String>(
    'memo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memos (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [memoId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memo_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('memo_id')) {
      context.handle(
        _memoIdMeta,
        memoId.isAcceptableOrUnknown(data['memo_id']!, _memoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {memoId, tagId};
  @override
  MemoTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoTag(
      memoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $MemoTagsTable createAlias(String alias) {
    return $MemoTagsTable(attachedDatabase, alias);
  }
}

class MemoTag extends DataClass implements Insertable<MemoTag> {
  final String memoId;
  final String tagId;
  const MemoTag({required this.memoId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['memo_id'] = Variable<String>(memoId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  MemoTagsCompanion toCompanion(bool nullToAbsent) {
    return MemoTagsCompanion(memoId: Value(memoId), tagId: Value(tagId));
  }

  factory MemoTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoTag(
      memoId: serializer.fromJson<String>(json['memoId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'memoId': serializer.toJson<String>(memoId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  MemoTag copyWith({String? memoId, String? tagId}) =>
      MemoTag(memoId: memoId ?? this.memoId, tagId: tagId ?? this.tagId);
  MemoTag copyWithCompanion(MemoTagsCompanion data) {
    return MemoTag(
      memoId: data.memoId.present ? data.memoId.value : this.memoId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoTag(')
          ..write('memoId: $memoId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(memoId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoTag &&
          other.memoId == this.memoId &&
          other.tagId == this.tagId);
}

class MemoTagsCompanion extends UpdateCompanion<MemoTag> {
  final Value<String> memoId;
  final Value<String> tagId;
  final Value<int> rowid;
  const MemoTagsCompanion({
    this.memoId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoTagsCompanion.insert({
    required String memoId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : memoId = Value(memoId),
       tagId = Value(tagId);
  static Insertable<MemoTag> custom({
    Expression<String>? memoId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (memoId != null) 'memo_id': memoId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoTagsCompanion copyWith({
    Value<String>? memoId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return MemoTagsCompanion(
      memoId: memoId ?? this.memoId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (memoId.present) {
      map['memo_id'] = Variable<String>(memoId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoTagsCompanion(')
          ..write('memoId: $memoId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoItemTagsTable extends TodoItemTags
    with TableInfo<$TodoItemTagsTable, TodoItemTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoItemTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _todoItemIdMeta = const VerificationMeta(
    'todoItemId',
  );
  @override
  late final GeneratedColumn<String> todoItemId = GeneratedColumn<String>(
    'todo_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todo_items (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [todoItemId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_item_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoItemTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('todo_item_id')) {
      context.handle(
        _todoItemIdMeta,
        todoItemId.isAcceptableOrUnknown(
          data['todo_item_id']!,
          _todoItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_todoItemIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {todoItemId, tagId};
  @override
  TodoItemTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoItemTag(
      todoItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_item_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TodoItemTagsTable createAlias(String alias) {
    return $TodoItemTagsTable(attachedDatabase, alias);
  }
}

class TodoItemTag extends DataClass implements Insertable<TodoItemTag> {
  final String todoItemId;
  final String tagId;
  const TodoItemTag({required this.todoItemId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['todo_item_id'] = Variable<String>(todoItemId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TodoItemTagsCompanion toCompanion(bool nullToAbsent) {
    return TodoItemTagsCompanion(
      todoItemId: Value(todoItemId),
      tagId: Value(tagId),
    );
  }

  factory TodoItemTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoItemTag(
      todoItemId: serializer.fromJson<String>(json['todoItemId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'todoItemId': serializer.toJson<String>(todoItemId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TodoItemTag copyWith({String? todoItemId, String? tagId}) => TodoItemTag(
    todoItemId: todoItemId ?? this.todoItemId,
    tagId: tagId ?? this.tagId,
  );
  TodoItemTag copyWithCompanion(TodoItemTagsCompanion data) {
    return TodoItemTag(
      todoItemId: data.todoItemId.present
          ? data.todoItemId.value
          : this.todoItemId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoItemTag(')
          ..write('todoItemId: $todoItemId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(todoItemId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoItemTag &&
          other.todoItemId == this.todoItemId &&
          other.tagId == this.tagId);
}

class TodoItemTagsCompanion extends UpdateCompanion<TodoItemTag> {
  final Value<String> todoItemId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TodoItemTagsCompanion({
    this.todoItemId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoItemTagsCompanion.insert({
    required String todoItemId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : todoItemId = Value(todoItemId),
       tagId = Value(tagId);
  static Insertable<TodoItemTag> custom({
    Expression<String>? todoItemId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (todoItemId != null) 'todo_item_id': todoItemId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoItemTagsCompanion copyWith({
    Value<String>? todoItemId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TodoItemTagsCompanion(
      todoItemId: todoItemId ?? this.todoItemId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (todoItemId.present) {
      map['todo_item_id'] = Variable<String>(todoItemId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoItemTagsCompanion(')
          ..write('todoItemId: $todoItemId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoListTagsTable extends TodoListTags
    with TableInfo<$TodoListTagsTable, TodoListTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _todoListIdMeta = const VerificationMeta(
    'todoListId',
  );
  @override
  late final GeneratedColumn<String> todoListId = GeneratedColumn<String>(
    'todo_list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todo_lists (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [todoListId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_list_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoListTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('todo_list_id')) {
      context.handle(
        _todoListIdMeta,
        todoListId.isAcceptableOrUnknown(
          data['todo_list_id']!,
          _todoListIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_todoListIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {todoListId, tagId};
  @override
  TodoListTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoListTag(
      todoListId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_list_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TodoListTagsTable createAlias(String alias) {
    return $TodoListTagsTable(attachedDatabase, alias);
  }
}

class TodoListTag extends DataClass implements Insertable<TodoListTag> {
  final String todoListId;
  final String tagId;
  const TodoListTag({required this.todoListId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['todo_list_id'] = Variable<String>(todoListId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TodoListTagsCompanion toCompanion(bool nullToAbsent) {
    return TodoListTagsCompanion(
      todoListId: Value(todoListId),
      tagId: Value(tagId),
    );
  }

  factory TodoListTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoListTag(
      todoListId: serializer.fromJson<String>(json['todoListId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'todoListId': serializer.toJson<String>(todoListId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TodoListTag copyWith({String? todoListId, String? tagId}) => TodoListTag(
    todoListId: todoListId ?? this.todoListId,
    tagId: tagId ?? this.tagId,
  );
  TodoListTag copyWithCompanion(TodoListTagsCompanion data) {
    return TodoListTag(
      todoListId: data.todoListId.present
          ? data.todoListId.value
          : this.todoListId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoListTag(')
          ..write('todoListId: $todoListId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(todoListId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoListTag &&
          other.todoListId == this.todoListId &&
          other.tagId == this.tagId);
}

class TodoListTagsCompanion extends UpdateCompanion<TodoListTag> {
  final Value<String> todoListId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TodoListTagsCompanion({
    this.todoListId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListTagsCompanion.insert({
    required String todoListId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : todoListId = Value(todoListId),
       tagId = Value(tagId);
  static Insertable<TodoListTag> custom({
    Expression<String>? todoListId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (todoListId != null) 'todo_list_id': todoListId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListTagsCompanion copyWith({
    Value<String>? todoListId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TodoListTagsCompanion(
      todoListId: todoListId ?? this.todoListId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (todoListId.present) {
      map['todo_list_id'] = Variable<String>(todoListId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListTagsCompanion(')
          ..write('todoListId: $todoListId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoImagesTable extends MemoImages
    with TableInfo<$MemoImagesTable, MemoImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoIdMeta = const VerificationMeta('memoId');
  @override
  late final GeneratedColumn<String> memoId = GeneratedColumn<String>(
    'memo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memos (id)',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memoId,
    filePath,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memo_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('memo_id')) {
      context.handle(
        _memoIdMeta,
        memoId.isAcceptableOrUnknown(data['memo_id']!, _memoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoImagesTable createAlias(String alias) {
    return $MemoImagesTable(attachedDatabase, alias);
  }
}

class MemoImage extends DataClass implements Insertable<MemoImage> {
  final String id;
  final String memoId;
  final String filePath;
  final int sortOrder;
  final DateTime createdAt;
  const MemoImage({
    required this.id,
    required this.memoId,
    required this.filePath,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['memo_id'] = Variable<String>(memoId);
    map['file_path'] = Variable<String>(filePath);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MemoImagesCompanion toCompanion(bool nullToAbsent) {
    return MemoImagesCompanion(
      id: Value(id),
      memoId: Value(memoId),
      filePath: Value(filePath),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory MemoImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoImage(
      id: serializer.fromJson<String>(json['id']),
      memoId: serializer.fromJson<String>(json['memoId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memoId': serializer.toJson<String>(memoId),
      'filePath': serializer.toJson<String>(filePath),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MemoImage copyWith({
    String? id,
    String? memoId,
    String? filePath,
    int? sortOrder,
    DateTime? createdAt,
  }) => MemoImage(
    id: id ?? this.id,
    memoId: memoId ?? this.memoId,
    filePath: filePath ?? this.filePath,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoImage copyWithCompanion(MemoImagesCompanion data) {
    return MemoImage(
      id: data.id.present ? data.id.value : this.id,
      memoId: data.memoId.present ? data.memoId.value : this.memoId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoImage(')
          ..write('id: $id, ')
          ..write('memoId: $memoId, ')
          ..write('filePath: $filePath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, memoId, filePath, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoImage &&
          other.id == this.id &&
          other.memoId == this.memoId &&
          other.filePath == this.filePath &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class MemoImagesCompanion extends UpdateCompanion<MemoImage> {
  final Value<String> id;
  final Value<String> memoId;
  final Value<String> filePath;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MemoImagesCompanion({
    this.id = const Value.absent(),
    this.memoId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoImagesCompanion.insert({
    required String id,
    required String memoId,
    required String filePath,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       memoId = Value(memoId),
       filePath = Value(filePath);
  static Insertable<MemoImage> custom({
    Expression<String>? id,
    Expression<String>? memoId,
    Expression<String>? filePath,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memoId != null) 'memo_id': memoId,
      if (filePath != null) 'file_path': filePath,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? memoId,
    Value<String>? filePath,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoImagesCompanion(
      id: id ?? this.id,
      memoId: memoId ?? this.memoId,
      filePath: filePath ?? this.filePath,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (memoId.present) {
      map['memo_id'] = Variable<String>(memoId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoImagesCompanion(')
          ..write('id: $id, ')
          ..write('memoId: $memoId, ')
          ..write('filePath: $filePath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictHistoriesTable extends ConflictHistories
    with TableInfo<$ConflictHistoriesTable, ConflictHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _memoIdMeta = const VerificationMeta('memoId');
  @override
  late final GeneratedColumn<String> memoId = GeneratedColumn<String>(
    'memo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lostSideMeta = const VerificationMeta(
    'lostSide',
  );
  @override
  late final GeneratedColumn<String> lostSide = GeneratedColumn<String>(
    'lost_side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lostTitleMeta = const VerificationMeta(
    'lostTitle',
  );
  @override
  late final GeneratedColumn<String> lostTitle = GeneratedColumn<String>(
    'lost_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lostContentMeta = const VerificationMeta(
    'lostContent',
  );
  @override
  late final GeneratedColumn<String> lostContent = GeneratedColumn<String>(
    'lost_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lostUpdatedAtMeta = const VerificationMeta(
    'lostUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lostUpdatedAt =
      GeneratedColumn<DateTime>(
        'lost_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _winnerUpdatedAtMeta = const VerificationMeta(
    'winnerUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> winnerUpdatedAt =
      GeneratedColumn<DateTime>(
        'winner_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memoId,
    lostSide,
    lostTitle,
    lostContent,
    lostUpdatedAt,
    winnerUpdatedAt,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflict_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConflictHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('memo_id')) {
      context.handle(
        _memoIdMeta,
        memoId.isAcceptableOrUnknown(data['memo_id']!, _memoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoIdMeta);
    }
    if (data.containsKey('lost_side')) {
      context.handle(
        _lostSideMeta,
        lostSide.isAcceptableOrUnknown(data['lost_side']!, _lostSideMeta),
      );
    } else if (isInserting) {
      context.missing(_lostSideMeta);
    }
    if (data.containsKey('lost_title')) {
      context.handle(
        _lostTitleMeta,
        lostTitle.isAcceptableOrUnknown(data['lost_title']!, _lostTitleMeta),
      );
    }
    if (data.containsKey('lost_content')) {
      context.handle(
        _lostContentMeta,
        lostContent.isAcceptableOrUnknown(
          data['lost_content']!,
          _lostContentMeta,
        ),
      );
    }
    if (data.containsKey('lost_updated_at')) {
      context.handle(
        _lostUpdatedAtMeta,
        lostUpdatedAt.isAcceptableOrUnknown(
          data['lost_updated_at']!,
          _lostUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lostUpdatedAtMeta);
    }
    if (data.containsKey('winner_updated_at')) {
      context.handle(
        _winnerUpdatedAtMeta,
        winnerUpdatedAt.isAcceptableOrUnknown(
          data['winner_updated_at']!,
          _winnerUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_winnerUpdatedAtMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConflictHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConflictHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      memoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_id'],
      )!,
      lostSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lost_side'],
      )!,
      lostTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lost_title'],
      )!,
      lostContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lost_content'],
      )!,
      lostUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lost_updated_at'],
      )!,
      winnerUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}winner_updated_at'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $ConflictHistoriesTable createAlias(String alias) {
    return $ConflictHistoriesTable(attachedDatabase, alias);
  }
}

class ConflictHistory extends DataClass implements Insertable<ConflictHistory> {
  final int id;
  final String memoId;
  final String lostSide;
  final String lostTitle;
  final String lostContent;
  final DateTime lostUpdatedAt;
  final DateTime winnerUpdatedAt;
  final DateTime recordedAt;
  const ConflictHistory({
    required this.id,
    required this.memoId,
    required this.lostSide,
    required this.lostTitle,
    required this.lostContent,
    required this.lostUpdatedAt,
    required this.winnerUpdatedAt,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['memo_id'] = Variable<String>(memoId);
    map['lost_side'] = Variable<String>(lostSide);
    map['lost_title'] = Variable<String>(lostTitle);
    map['lost_content'] = Variable<String>(lostContent);
    map['lost_updated_at'] = Variable<DateTime>(lostUpdatedAt);
    map['winner_updated_at'] = Variable<DateTime>(winnerUpdatedAt);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  ConflictHistoriesCompanion toCompanion(bool nullToAbsent) {
    return ConflictHistoriesCompanion(
      id: Value(id),
      memoId: Value(memoId),
      lostSide: Value(lostSide),
      lostTitle: Value(lostTitle),
      lostContent: Value(lostContent),
      lostUpdatedAt: Value(lostUpdatedAt),
      winnerUpdatedAt: Value(winnerUpdatedAt),
      recordedAt: Value(recordedAt),
    );
  }

  factory ConflictHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConflictHistory(
      id: serializer.fromJson<int>(json['id']),
      memoId: serializer.fromJson<String>(json['memoId']),
      lostSide: serializer.fromJson<String>(json['lostSide']),
      lostTitle: serializer.fromJson<String>(json['lostTitle']),
      lostContent: serializer.fromJson<String>(json['lostContent']),
      lostUpdatedAt: serializer.fromJson<DateTime>(json['lostUpdatedAt']),
      winnerUpdatedAt: serializer.fromJson<DateTime>(json['winnerUpdatedAt']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'memoId': serializer.toJson<String>(memoId),
      'lostSide': serializer.toJson<String>(lostSide),
      'lostTitle': serializer.toJson<String>(lostTitle),
      'lostContent': serializer.toJson<String>(lostContent),
      'lostUpdatedAt': serializer.toJson<DateTime>(lostUpdatedAt),
      'winnerUpdatedAt': serializer.toJson<DateTime>(winnerUpdatedAt),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  ConflictHistory copyWith({
    int? id,
    String? memoId,
    String? lostSide,
    String? lostTitle,
    String? lostContent,
    DateTime? lostUpdatedAt,
    DateTime? winnerUpdatedAt,
    DateTime? recordedAt,
  }) => ConflictHistory(
    id: id ?? this.id,
    memoId: memoId ?? this.memoId,
    lostSide: lostSide ?? this.lostSide,
    lostTitle: lostTitle ?? this.lostTitle,
    lostContent: lostContent ?? this.lostContent,
    lostUpdatedAt: lostUpdatedAt ?? this.lostUpdatedAt,
    winnerUpdatedAt: winnerUpdatedAt ?? this.winnerUpdatedAt,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  ConflictHistory copyWithCompanion(ConflictHistoriesCompanion data) {
    return ConflictHistory(
      id: data.id.present ? data.id.value : this.id,
      memoId: data.memoId.present ? data.memoId.value : this.memoId,
      lostSide: data.lostSide.present ? data.lostSide.value : this.lostSide,
      lostTitle: data.lostTitle.present ? data.lostTitle.value : this.lostTitle,
      lostContent: data.lostContent.present
          ? data.lostContent.value
          : this.lostContent,
      lostUpdatedAt: data.lostUpdatedAt.present
          ? data.lostUpdatedAt.value
          : this.lostUpdatedAt,
      winnerUpdatedAt: data.winnerUpdatedAt.present
          ? data.winnerUpdatedAt.value
          : this.winnerUpdatedAt,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConflictHistory(')
          ..write('id: $id, ')
          ..write('memoId: $memoId, ')
          ..write('lostSide: $lostSide, ')
          ..write('lostTitle: $lostTitle, ')
          ..write('lostContent: $lostContent, ')
          ..write('lostUpdatedAt: $lostUpdatedAt, ')
          ..write('winnerUpdatedAt: $winnerUpdatedAt, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    memoId,
    lostSide,
    lostTitle,
    lostContent,
    lostUpdatedAt,
    winnerUpdatedAt,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictHistory &&
          other.id == this.id &&
          other.memoId == this.memoId &&
          other.lostSide == this.lostSide &&
          other.lostTitle == this.lostTitle &&
          other.lostContent == this.lostContent &&
          other.lostUpdatedAt == this.lostUpdatedAt &&
          other.winnerUpdatedAt == this.winnerUpdatedAt &&
          other.recordedAt == this.recordedAt);
}

class ConflictHistoriesCompanion extends UpdateCompanion<ConflictHistory> {
  final Value<int> id;
  final Value<String> memoId;
  final Value<String> lostSide;
  final Value<String> lostTitle;
  final Value<String> lostContent;
  final Value<DateTime> lostUpdatedAt;
  final Value<DateTime> winnerUpdatedAt;
  final Value<DateTime> recordedAt;
  const ConflictHistoriesCompanion({
    this.id = const Value.absent(),
    this.memoId = const Value.absent(),
    this.lostSide = const Value.absent(),
    this.lostTitle = const Value.absent(),
    this.lostContent = const Value.absent(),
    this.lostUpdatedAt = const Value.absent(),
    this.winnerUpdatedAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  ConflictHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String memoId,
    required String lostSide,
    this.lostTitle = const Value.absent(),
    this.lostContent = const Value.absent(),
    required DateTime lostUpdatedAt,
    required DateTime winnerUpdatedAt,
    this.recordedAt = const Value.absent(),
  }) : memoId = Value(memoId),
       lostSide = Value(lostSide),
       lostUpdatedAt = Value(lostUpdatedAt),
       winnerUpdatedAt = Value(winnerUpdatedAt);
  static Insertable<ConflictHistory> custom({
    Expression<int>? id,
    Expression<String>? memoId,
    Expression<String>? lostSide,
    Expression<String>? lostTitle,
    Expression<String>? lostContent,
    Expression<DateTime>? lostUpdatedAt,
    Expression<DateTime>? winnerUpdatedAt,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memoId != null) 'memo_id': memoId,
      if (lostSide != null) 'lost_side': lostSide,
      if (lostTitle != null) 'lost_title': lostTitle,
      if (lostContent != null) 'lost_content': lostContent,
      if (lostUpdatedAt != null) 'lost_updated_at': lostUpdatedAt,
      if (winnerUpdatedAt != null) 'winner_updated_at': winnerUpdatedAt,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  ConflictHistoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? memoId,
    Value<String>? lostSide,
    Value<String>? lostTitle,
    Value<String>? lostContent,
    Value<DateTime>? lostUpdatedAt,
    Value<DateTime>? winnerUpdatedAt,
    Value<DateTime>? recordedAt,
  }) {
    return ConflictHistoriesCompanion(
      id: id ?? this.id,
      memoId: memoId ?? this.memoId,
      lostSide: lostSide ?? this.lostSide,
      lostTitle: lostTitle ?? this.lostTitle,
      lostContent: lostContent ?? this.lostContent,
      lostUpdatedAt: lostUpdatedAt ?? this.lostUpdatedAt,
      winnerUpdatedAt: winnerUpdatedAt ?? this.winnerUpdatedAt,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (memoId.present) {
      map['memo_id'] = Variable<String>(memoId.value);
    }
    if (lostSide.present) {
      map['lost_side'] = Variable<String>(lostSide.value);
    }
    if (lostTitle.present) {
      map['lost_title'] = Variable<String>(lostTitle.value);
    }
    if (lostContent.present) {
      map['lost_content'] = Variable<String>(lostContent.value);
    }
    if (lostUpdatedAt.present) {
      map['lost_updated_at'] = Variable<DateTime>(lostUpdatedAt.value);
    }
    if (winnerUpdatedAt.present) {
      map['winner_updated_at'] = Variable<DateTime>(winnerUpdatedAt.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('memoId: $memoId, ')
          ..write('lostSide: $lostSide, ')
          ..write('lostTitle: $lostTitle, ')
          ..write('lostContent: $lostContent, ')
          ..write('lostUpdatedAt: $lostUpdatedAt, ')
          ..write('winnerUpdatedAt: $winnerUpdatedAt, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MemosTable memos = $MemosTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TodoItemsTable todoItems = $TodoItemsTable(this);
  late final $TodoListsTable todoLists = $TodoListsTable(this);
  late final $TagHistoriesTable tagHistories = $TagHistoriesTable(this);
  late final $MemoTagsTable memoTags = $MemoTagsTable(this);
  late final $TodoItemTagsTable todoItemTags = $TodoItemTagsTable(this);
  late final $TodoListTagsTable todoListTags = $TodoListTagsTable(this);
  late final $MemoImagesTable memoImages = $MemoImagesTable(this);
  late final $ConflictHistoriesTable conflictHistories =
      $ConflictHistoriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    memos,
    tags,
    todoItems,
    todoLists,
    tagHistories,
    memoTags,
    todoItemTags,
    todoListTags,
    memoImages,
    conflictHistories,
  ];
}

typedef $$MemosTableCreateCompanionBuilder =
    MemosCompanion Function({
      required String id,
      Value<String> content,
      Value<String> title,
      Value<bool> isMarkdown,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isPinned,
      Value<int> manualSortOrder,
      Value<int> viewCount,
      Value<DateTime?> lastViewedAt,
      Value<bool> isLocked,
      Value<int> bgColorIndex,
      Value<DateTime?> eventDate,
      Value<int> rowid,
    });
typedef $$MemosTableUpdateCompanionBuilder =
    MemosCompanion Function({
      Value<String> id,
      Value<String> content,
      Value<String> title,
      Value<bool> isMarkdown,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isPinned,
      Value<int> manualSortOrder,
      Value<int> viewCount,
      Value<DateTime?> lastViewedAt,
      Value<bool> isLocked,
      Value<int> bgColorIndex,
      Value<DateTime?> eventDate,
      Value<int> rowid,
    });

final class $$MemosTableReferences
    extends BaseReferences<_$AppDatabase, $MemosTable, Memo> {
  $$MemosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemoTagsTable, List<MemoTag>> _memoTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.memoTags,
    aliasName: $_aliasNameGenerator(db.memos.id, db.memoTags.memoId),
  );

  $$MemoTagsTableProcessedTableManager get memoTagsRefs {
    final manager = $$MemoTagsTableTableManager(
      $_db,
      $_db.memoTags,
    ).filter((f) => f.memoId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemoImagesTable, List<MemoImage>>
  _memoImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoImages,
    aliasName: $_aliasNameGenerator(db.memos.id, db.memoImages.memoId),
  );

  $$MemoImagesTableProcessedTableManager get memoImagesRefs {
    final manager = $$MemoImagesTableTableManager(
      $_db,
      $_db.memoImages,
    ).filter((f) => f.memoId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemosTableFilterComposer extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMarkdown => $composableBuilder(
    column: $table.isMarkdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualSortOrder => $composableBuilder(
    column: $table.manualSortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bgColorIndex => $composableBuilder(
    column: $table.bgColorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memoTagsRefs(
    Expression<bool> Function($$MemoTagsTableFilterComposer f) f,
  ) {
    final $$MemoTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoTags,
      getReferencedColumn: (t) => t.memoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoTagsTableFilterComposer(
            $db: $db,
            $table: $db.memoTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoImagesRefs(
    Expression<bool> Function($$MemoImagesTableFilterComposer f) f,
  ) {
    final $$MemoImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoImages,
      getReferencedColumn: (t) => t.memoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoImagesTableFilterComposer(
            $db: $db,
            $table: $db.memoImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemosTableOrderingComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMarkdown => $composableBuilder(
    column: $table.isMarkdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualSortOrder => $composableBuilder(
    column: $table.manualSortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bgColorIndex => $composableBuilder(
    column: $table.bgColorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemosTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableAnnotationComposer({
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

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isMarkdown => $composableBuilder(
    column: $table.isMarkdown,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get manualSortOrder => $composableBuilder(
    column: $table.manualSortOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get viewCount =>
      $composableBuilder(column: $table.viewCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<int> get bgColorIndex => $composableBuilder(
    column: $table.bgColorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  Expression<T> memoTagsRefs<T extends Object>(
    Expression<T> Function($$MemoTagsTableAnnotationComposer a) f,
  ) {
    final $$MemoTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoTags,
      getReferencedColumn: (t) => t.memoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoImagesRefs<T extends Object>(
    Expression<T> Function($$MemoImagesTableAnnotationComposer a) f,
  ) {
    final $$MemoImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoImages,
      getReferencedColumn: (t) => t.memoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.memoImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemosTable,
          Memo,
          $$MemosTableFilterComposer,
          $$MemosTableOrderingComposer,
          $$MemosTableAnnotationComposer,
          $$MemosTableCreateCompanionBuilder,
          $$MemosTableUpdateCompanionBuilder,
          (Memo, $$MemosTableReferences),
          Memo,
          PrefetchHooks Function({bool memoTagsRefs, bool memoImagesRefs})
        > {
  $$MemosTableTableManager(_$AppDatabase db, $MemosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isMarkdown = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> manualSortOrder = const Value.absent(),
                Value<int> viewCount = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int> bgColorIndex = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemosCompanion(
                id: id,
                content: content,
                title: title,
                isMarkdown: isMarkdown,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                manualSortOrder: manualSortOrder,
                viewCount: viewCount,
                lastViewedAt: lastViewedAt,
                isLocked: isLocked,
                bgColorIndex: bgColorIndex,
                eventDate: eventDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> content = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isMarkdown = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> manualSortOrder = const Value.absent(),
                Value<int> viewCount = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int> bgColorIndex = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemosCompanion.insert(
                id: id,
                content: content,
                title: title,
                isMarkdown: isMarkdown,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                manualSortOrder: manualSortOrder,
                viewCount: viewCount,
                lastViewedAt: lastViewedAt,
                isLocked: isLocked,
                bgColorIndex: bgColorIndex,
                eventDate: eventDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MemosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({memoTagsRefs = false, memoImagesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memoTagsRefs) db.memoTags,
                    if (memoImagesRefs) db.memoImages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memoTagsRefs)
                        await $_getPrefetchedData<Memo, $MemosTable, MemoTag>(
                          currentTable: table,
                          referencedTable: $$MemosTableReferences
                              ._memoTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemosTableReferences(
                                db,
                                table,
                                p0,
                              ).memoTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoImagesRefs)
                        await $_getPrefetchedData<Memo, $MemosTable, MemoImage>(
                          currentTable: table,
                          referencedTable: $$MemosTableReferences
                              ._memoImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemosTableReferences(
                                db,
                                table,
                                p0,
                              ).memoImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memoId == item.id,
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

typedef $$MemosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemosTable,
      Memo,
      $$MemosTableFilterComposer,
      $$MemosTableOrderingComposer,
      $$MemosTableAnnotationComposer,
      $$MemosTableCreateCompanionBuilder,
      $$MemosTableUpdateCompanionBuilder,
      (Memo, $$MemosTableReferences),
      Memo,
      PrefetchHooks Function({bool memoTagsRefs, bool memoImagesRefs})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      Value<String> name,
      Value<int> colorIndex,
      Value<int> gridSize,
      Value<String?> parentTagId,
      Value<int> sortOrder,
      Value<bool> isSystem,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorIndex,
      Value<int> gridSize,
      Value<String?> parentTagId,
      Value<int> sortOrder,
      Value<bool> isSystem,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemoTagsTable, List<MemoTag>> _memoTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.memoTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.memoTags.tagId),
  );

  $$MemoTagsTableProcessedTableManager get memoTagsRefs {
    final manager = $$MemoTagsTableTableManager(
      $_db,
      $_db.memoTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TodoItemTagsTable, List<TodoItemTag>>
  _todoItemTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoItemTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.todoItemTags.tagId),
  );

  $$TodoItemTagsTableProcessedTableManager get todoItemTagsRefs {
    final manager = $$TodoItemTagsTableTableManager(
      $_db,
      $_db.todoItemTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoItemTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TodoListTagsTable, List<TodoListTag>>
  _todoListTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoListTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.todoListTags.tagId),
  );

  $$TodoListTagsTableProcessedTableManager get todoListTagsRefs {
    final manager = $$TodoListTagsTableTableManager(
      $_db,
      $_db.todoListTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoListTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gridSize => $composableBuilder(
    column: $table.gridSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTagId => $composableBuilder(
    column: $table.parentTagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memoTagsRefs(
    Expression<bool> Function($$MemoTagsTableFilterComposer f) f,
  ) {
    final $$MemoTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoTagsTableFilterComposer(
            $db: $db,
            $table: $db.memoTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> todoItemTagsRefs(
    Expression<bool> Function($$TodoItemTagsTableFilterComposer f) f,
  ) {
    final $$TodoItemTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoItemTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemTagsTableFilterComposer(
            $db: $db,
            $table: $db.todoItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> todoListTagsRefs(
    Expression<bool> Function($$TodoListTagsTableFilterComposer f) f,
  ) {
    final $$TodoListTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoListTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListTagsTableFilterComposer(
            $db: $db,
            $table: $db.todoListTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gridSize => $composableBuilder(
    column: $table.gridSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTagId => $composableBuilder(
    column: $table.parentTagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gridSize =>
      $composableBuilder(column: $table.gridSize, builder: (column) => column);

  GeneratedColumn<String> get parentTagId => $composableBuilder(
    column: $table.parentTagId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> memoTagsRefs<T extends Object>(
    Expression<T> Function($$MemoTagsTableAnnotationComposer a) f,
  ) {
    final $$MemoTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> todoItemTagsRefs<T extends Object>(
    Expression<T> Function($$TodoItemTagsTableAnnotationComposer a) f,
  ) {
    final $$TodoItemTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoItemTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> todoListTagsRefs<T extends Object>(
    Expression<T> Function($$TodoListTagsTableAnnotationComposer a) f,
  ) {
    final $$TodoListTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoListTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoListTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({
            bool memoTagsRefs,
            bool todoItemTagsRefs,
            bool todoListTagsRefs,
          })
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> gridSize = const Value.absent(),
                Value<String?> parentTagId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                colorIndex: colorIndex,
                gridSize: gridSize,
                parentTagId: parentTagId,
                sortOrder: sortOrder,
                isSystem: isSystem,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> gridSize = const Value.absent(),
                Value<String?> parentTagId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                colorIndex: colorIndex,
                gridSize: gridSize,
                parentTagId: parentTagId,
                sortOrder: sortOrder,
                isSystem: isSystem,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                memoTagsRefs = false,
                todoItemTagsRefs = false,
                todoListTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memoTagsRefs) db.memoTags,
                    if (todoItemTagsRefs) db.todoItemTags,
                    if (todoListTagsRefs) db.todoListTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memoTagsRefs)
                        await $_getPrefetchedData<Tag, $TagsTable, MemoTag>(
                          currentTable: table,
                          referencedTable: $$TagsTableReferences
                              ._memoTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TagsTableReferences(db, table, p0).memoTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tagId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (todoItemTagsRefs)
                        await $_getPrefetchedData<Tag, $TagsTable, TodoItemTag>(
                          currentTable: table,
                          referencedTable: $$TagsTableReferences
                              ._todoItemTagsRefsTable(db),
                          managerFromTypedResult: (p0) => $$TagsTableReferences(
                            db,
                            table,
                            p0,
                          ).todoItemTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tagId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (todoListTagsRefs)
                        await $_getPrefetchedData<Tag, $TagsTable, TodoListTag>(
                          currentTable: table,
                          referencedTable: $$TagsTableReferences
                              ._todoListTagsRefsTable(db),
                          managerFromTypedResult: (p0) => $$TagsTableReferences(
                            db,
                            table,
                            p0,
                          ).todoListTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tagId == item.id,
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

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({
        bool memoTagsRefs,
        bool todoItemTagsRefs,
        bool todoListTagsRefs,
      })
    >;
typedef $$TodoItemsTableCreateCompanionBuilder =
    TodoItemsCompanion Function({
      required String id,
      required String listId,
      Value<String> title,
      Value<bool> isDone,
      Value<String?> parentId,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> eventDate,
      Value<String?> memo,
      Value<int> rowid,
    });
typedef $$TodoItemsTableUpdateCompanionBuilder =
    TodoItemsCompanion Function({
      Value<String> id,
      Value<String> listId,
      Value<String> title,
      Value<bool> isDone,
      Value<String?> parentId,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> eventDate,
      Value<String?> memo,
      Value<int> rowid,
    });

final class $$TodoItemsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoItemsTable, TodoItem> {
  $$TodoItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodoItemTagsTable, List<TodoItemTag>>
  _todoItemTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoItemTags,
    aliasName: $_aliasNameGenerator(
      db.todoItems.id,
      db.todoItemTags.todoItemId,
    ),
  );

  $$TodoItemTagsTableProcessedTableManager get todoItemTagsRefs {
    final manager = $$TodoItemTagsTableTableManager(
      $_db,
      $_db.todoItemTags,
    ).filter((f) => f.todoItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoItemTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodoItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoItemsTable> {
  $$TodoItemsTableFilterComposer({
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

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> todoItemTagsRefs(
    Expression<bool> Function($$TodoItemTagsTableFilterComposer f) f,
  ) {
    final $$TodoItemTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoItemTags,
      getReferencedColumn: (t) => t.todoItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemTagsTableFilterComposer(
            $db: $db,
            $table: $db.todoItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoItemsTable> {
  $$TodoItemsTableOrderingComposer({
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

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoItemsTable> {
  $$TodoItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  Expression<T> todoItemTagsRefs<T extends Object>(
    Expression<T> Function($$TodoItemTagsTableAnnotationComposer a) f,
  ) {
    final $$TodoItemTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoItemTags,
      getReferencedColumn: (t) => t.todoItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoItemsTable,
          TodoItem,
          $$TodoItemsTableFilterComposer,
          $$TodoItemsTableOrderingComposer,
          $$TodoItemsTableAnnotationComposer,
          $$TodoItemsTableCreateCompanionBuilder,
          $$TodoItemsTableUpdateCompanionBuilder,
          (TodoItem, $$TodoItemsTableReferences),
          TodoItem,
          PrefetchHooks Function({bool todoItemTagsRefs})
        > {
  $$TodoItemsTableTableManager(_$AppDatabase db, $TodoItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoItemsCompanion(
                id: id,
                listId: listId,
                title: title,
                isDone: isDone,
                parentId: parentId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                eventDate: eventDate,
                memo: memo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String listId,
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoItemsCompanion.insert(
                id: id,
                listId: listId,
                title: title,
                isDone: isDone,
                parentId: parentId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                eventDate: eventDate,
                memo: memo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todoItemTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todoItemTagsRefs) db.todoItemTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todoItemTagsRefs)
                    await $_getPrefetchedData<
                      TodoItem,
                      $TodoItemsTable,
                      TodoItemTag
                    >(
                      currentTable: table,
                      referencedTable: $$TodoItemsTableReferences
                          ._todoItemTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TodoItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).todoItemTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.todoItemId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TodoItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoItemsTable,
      TodoItem,
      $$TodoItemsTableFilterComposer,
      $$TodoItemsTableOrderingComposer,
      $$TodoItemsTableAnnotationComposer,
      $$TodoItemsTableCreateCompanionBuilder,
      $$TodoItemsTableUpdateCompanionBuilder,
      (TodoItem, $$TodoItemsTableReferences),
      TodoItem,
      PrefetchHooks Function({bool todoItemTagsRefs})
    >;
typedef $$TodoListsTableCreateCompanionBuilder =
    TodoListsCompanion Function({
      required String id,
      Value<String> title,
      Value<bool> isPinned,
      Value<bool> isLocked,
      Value<int> manualSortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isMerged,
      Value<DateTime?> eventDate,
      Value<int> bgColorIndex,
      Value<int> rowid,
    });
typedef $$TodoListsTableUpdateCompanionBuilder =
    TodoListsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<bool> isPinned,
      Value<bool> isLocked,
      Value<int> manualSortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isMerged,
      Value<DateTime?> eventDate,
      Value<int> bgColorIndex,
      Value<int> rowid,
    });

final class $$TodoListsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoListsTable, TodoList> {
  $$TodoListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TodoListTagsTable, List<TodoListTag>>
  _todoListTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todoListTags,
    aliasName: $_aliasNameGenerator(
      db.todoLists.id,
      db.todoListTags.todoListId,
    ),
  );

  $$TodoListTagsTableProcessedTableManager get todoListTagsRefs {
    final manager = $$TodoListTagsTableTableManager(
      $_db,
      $_db.todoListTags,
    ).filter((f) => f.todoListId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todoListTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodoListsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualSortOrder => $composableBuilder(
    column: $table.manualSortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMerged => $composableBuilder(
    column: $table.isMerged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bgColorIndex => $composableBuilder(
    column: $table.bgColorIndex,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> todoListTagsRefs(
    Expression<bool> Function($$TodoListTagsTableFilterComposer f) f,
  ) {
    final $$TodoListTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoListTags,
      getReferencedColumn: (t) => t.todoListId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListTagsTableFilterComposer(
            $db: $db,
            $table: $db.todoListTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualSortOrder => $composableBuilder(
    column: $table.manualSortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMerged => $composableBuilder(
    column: $table.isMerged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bgColorIndex => $composableBuilder(
    column: $table.bgColorIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<int> get manualSortOrder => $composableBuilder(
    column: $table.manualSortOrder,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isMerged =>
      $composableBuilder(column: $table.isMerged, builder: (column) => column);

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<int> get bgColorIndex => $composableBuilder(
    column: $table.bgColorIndex,
    builder: (column) => column,
  );

  Expression<T> todoListTagsRefs<T extends Object>(
    Expression<T> Function($$TodoListTagsTableAnnotationComposer a) f,
  ) {
    final $$TodoListTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todoListTags,
      getReferencedColumn: (t) => t.todoListId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoListTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodoListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListsTable,
          TodoList,
          $$TodoListsTableFilterComposer,
          $$TodoListsTableOrderingComposer,
          $$TodoListsTableAnnotationComposer,
          $$TodoListsTableCreateCompanionBuilder,
          $$TodoListsTableUpdateCompanionBuilder,
          (TodoList, $$TodoListsTableReferences),
          TodoList,
          PrefetchHooks Function({bool todoListTagsRefs})
        > {
  $$TodoListsTableTableManager(_$AppDatabase db, $TodoListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int> manualSortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isMerged = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<int> bgColorIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion(
                id: id,
                title: title,
                isPinned: isPinned,
                isLocked: isLocked,
                manualSortOrder: manualSortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isMerged: isMerged,
                eventDate: eventDate,
                bgColorIndex: bgColorIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int> manualSortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isMerged = const Value.absent(),
                Value<DateTime?> eventDate = const Value.absent(),
                Value<int> bgColorIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion.insert(
                id: id,
                title: title,
                isPinned: isPinned,
                isLocked: isLocked,
                manualSortOrder: manualSortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isMerged: isMerged,
                eventDate: eventDate,
                bgColorIndex: bgColorIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todoListTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (todoListTagsRefs) db.todoListTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (todoListTagsRefs)
                    await $_getPrefetchedData<
                      TodoList,
                      $TodoListsTable,
                      TodoListTag
                    >(
                      currentTable: table,
                      referencedTable: $$TodoListsTableReferences
                          ._todoListTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TodoListsTableReferences(
                            db,
                            table,
                            p0,
                          ).todoListTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.todoListId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TodoListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListsTable,
      TodoList,
      $$TodoListsTableFilterComposer,
      $$TodoListsTableOrderingComposer,
      $$TodoListsTableAnnotationComposer,
      $$TodoListsTableCreateCompanionBuilder,
      $$TodoListsTableUpdateCompanionBuilder,
      (TodoList, $$TodoListsTableReferences),
      TodoList,
      PrefetchHooks Function({bool todoListTagsRefs})
    >;
typedef $$TagHistoriesTableCreateCompanionBuilder =
    TagHistoriesCompanion Function({
      Value<int> id,
      required String parentTagId,
      Value<String?> childTagId,
      Value<DateTime> usedAt,
    });
typedef $$TagHistoriesTableUpdateCompanionBuilder =
    TagHistoriesCompanion Function({
      Value<int> id,
      Value<String> parentTagId,
      Value<String?> childTagId,
      Value<DateTime> usedAt,
    });

class $$TagHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $TagHistoriesTable> {
  $$TagHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTagId => $composableBuilder(
    column: $table.parentTagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get childTagId => $composableBuilder(
    column: $table.childTagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TagHistoriesTable> {
  $$TagHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTagId => $composableBuilder(
    column: $table.parentTagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get childTagId => $composableBuilder(
    column: $table.childTagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagHistoriesTable> {
  $$TagHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentTagId => $composableBuilder(
    column: $table.parentTagId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get childTagId => $composableBuilder(
    column: $table.childTagId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get usedAt =>
      $composableBuilder(column: $table.usedAt, builder: (column) => column);
}

class $$TagHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagHistoriesTable,
          TagHistory,
          $$TagHistoriesTableFilterComposer,
          $$TagHistoriesTableOrderingComposer,
          $$TagHistoriesTableAnnotationComposer,
          $$TagHistoriesTableCreateCompanionBuilder,
          $$TagHistoriesTableUpdateCompanionBuilder,
          (
            TagHistory,
            BaseReferences<_$AppDatabase, $TagHistoriesTable, TagHistory>,
          ),
          TagHistory,
          PrefetchHooks Function()
        > {
  $$TagHistoriesTableTableManager(_$AppDatabase db, $TagHistoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> parentTagId = const Value.absent(),
                Value<String?> childTagId = const Value.absent(),
                Value<DateTime> usedAt = const Value.absent(),
              }) => TagHistoriesCompanion(
                id: id,
                parentTagId: parentTagId,
                childTagId: childTagId,
                usedAt: usedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String parentTagId,
                Value<String?> childTagId = const Value.absent(),
                Value<DateTime> usedAt = const Value.absent(),
              }) => TagHistoriesCompanion.insert(
                id: id,
                parentTagId: parentTagId,
                childTagId: childTagId,
                usedAt: usedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagHistoriesTable,
      TagHistory,
      $$TagHistoriesTableFilterComposer,
      $$TagHistoriesTableOrderingComposer,
      $$TagHistoriesTableAnnotationComposer,
      $$TagHistoriesTableCreateCompanionBuilder,
      $$TagHistoriesTableUpdateCompanionBuilder,
      (
        TagHistory,
        BaseReferences<_$AppDatabase, $TagHistoriesTable, TagHistory>,
      ),
      TagHistory,
      PrefetchHooks Function()
    >;
typedef $$MemoTagsTableCreateCompanionBuilder =
    MemoTagsCompanion Function({
      required String memoId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$MemoTagsTableUpdateCompanionBuilder =
    MemoTagsCompanion Function({
      Value<String> memoId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$MemoTagsTableReferences
    extends BaseReferences<_$AppDatabase, $MemoTagsTable, MemoTag> {
  $$MemoTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemosTable _memoIdTable(_$AppDatabase db) => db.memos.createAlias(
    $_aliasNameGenerator(db.memoTags.memoId, db.memos.id),
  );

  $$MemosTableProcessedTableManager get memoId {
    final $_column = $_itemColumn<String>('memo_id')!;

    final manager = $$MemosTableTableManager(
      $_db,
      $_db.memos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias($_aliasNameGenerator(db.memoTags.tagId, db.tags.id));

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoTagsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoTagsTable> {
  $$MemoTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MemosTableFilterComposer get memoId {
    final $$MemosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoId,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableFilterComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoTagsTable> {
  $$MemoTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MemosTableOrderingComposer get memoId {
    final $$MemosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoId,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableOrderingComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoTagsTable> {
  $$MemoTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MemosTableAnnotationComposer get memoId {
    final $$MemosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoId,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableAnnotationComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoTagsTable,
          MemoTag,
          $$MemoTagsTableFilterComposer,
          $$MemoTagsTableOrderingComposer,
          $$MemoTagsTableAnnotationComposer,
          $$MemoTagsTableCreateCompanionBuilder,
          $$MemoTagsTableUpdateCompanionBuilder,
          (MemoTag, $$MemoTagsTableReferences),
          MemoTag,
          PrefetchHooks Function({bool memoId, bool tagId})
        > {
  $$MemoTagsTableTableManager(_$AppDatabase db, $MemoTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> memoId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  MemoTagsCompanion(memoId: memoId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String memoId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => MemoTagsCompanion.insert(
                memoId: memoId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memoId = false, tagId = false}) {
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
                    if (memoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memoId,
                                referencedTable: $$MemoTagsTableReferences
                                    ._memoIdTable(db),
                                referencedColumn: $$MemoTagsTableReferences
                                    ._memoIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$MemoTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$MemoTagsTableReferences
                                    ._tagIdTable(db)
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

typedef $$MemoTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoTagsTable,
      MemoTag,
      $$MemoTagsTableFilterComposer,
      $$MemoTagsTableOrderingComposer,
      $$MemoTagsTableAnnotationComposer,
      $$MemoTagsTableCreateCompanionBuilder,
      $$MemoTagsTableUpdateCompanionBuilder,
      (MemoTag, $$MemoTagsTableReferences),
      MemoTag,
      PrefetchHooks Function({bool memoId, bool tagId})
    >;
typedef $$TodoItemTagsTableCreateCompanionBuilder =
    TodoItemTagsCompanion Function({
      required String todoItemId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TodoItemTagsTableUpdateCompanionBuilder =
    TodoItemTagsCompanion Function({
      Value<String> todoItemId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$TodoItemTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoItemTagsTable, TodoItemTag> {
  $$TodoItemTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TodoItemsTable _todoItemIdTable(_$AppDatabase db) =>
      db.todoItems.createAlias(
        $_aliasNameGenerator(db.todoItemTags.todoItemId, db.todoItems.id),
      );

  $$TodoItemsTableProcessedTableManager get todoItemId {
    final $_column = $_itemColumn<String>('todo_item_id')!;

    final manager = $$TodoItemsTableTableManager(
      $_db,
      $_db.todoItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todoItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) => db.tags.createAlias(
    $_aliasNameGenerator(db.todoItemTags.tagId, db.tags.id),
  );

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TodoItemTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoItemTagsTable> {
  $$TodoItemTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TodoItemsTableFilterComposer get todoItemId {
    final $$TodoItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoItemId,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableFilterComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoItemTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoItemTagsTable> {
  $$TodoItemTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TodoItemsTableOrderingComposer get todoItemId {
    final $$TodoItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoItemId,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableOrderingComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoItemTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoItemTagsTable> {
  $$TodoItemTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TodoItemsTableAnnotationComposer get todoItemId {
    final $$TodoItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoItemId,
      referencedTable: $db.todoItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoItemTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoItemTagsTable,
          TodoItemTag,
          $$TodoItemTagsTableFilterComposer,
          $$TodoItemTagsTableOrderingComposer,
          $$TodoItemTagsTableAnnotationComposer,
          $$TodoItemTagsTableCreateCompanionBuilder,
          $$TodoItemTagsTableUpdateCompanionBuilder,
          (TodoItemTag, $$TodoItemTagsTableReferences),
          TodoItemTag,
          PrefetchHooks Function({bool todoItemId, bool tagId})
        > {
  $$TodoItemTagsTableTableManager(_$AppDatabase db, $TodoItemTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoItemTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoItemTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoItemTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> todoItemId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoItemTagsCompanion(
                todoItemId: todoItemId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String todoItemId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TodoItemTagsCompanion.insert(
                todoItemId: todoItemId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoItemTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todoItemId = false, tagId = false}) {
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
                    if (todoItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.todoItemId,
                                referencedTable: $$TodoItemTagsTableReferences
                                    ._todoItemIdTable(db),
                                referencedColumn: $$TodoItemTagsTableReferences
                                    ._todoItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$TodoItemTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$TodoItemTagsTableReferences
                                    ._tagIdTable(db)
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

typedef $$TodoItemTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoItemTagsTable,
      TodoItemTag,
      $$TodoItemTagsTableFilterComposer,
      $$TodoItemTagsTableOrderingComposer,
      $$TodoItemTagsTableAnnotationComposer,
      $$TodoItemTagsTableCreateCompanionBuilder,
      $$TodoItemTagsTableUpdateCompanionBuilder,
      (TodoItemTag, $$TodoItemTagsTableReferences),
      TodoItemTag,
      PrefetchHooks Function({bool todoItemId, bool tagId})
    >;
typedef $$TodoListTagsTableCreateCompanionBuilder =
    TodoListTagsCompanion Function({
      required String todoListId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TodoListTagsTableUpdateCompanionBuilder =
    TodoListTagsCompanion Function({
      Value<String> todoListId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$TodoListTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TodoListTagsTable, TodoListTag> {
  $$TodoListTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TodoListsTable _todoListIdTable(_$AppDatabase db) =>
      db.todoLists.createAlias(
        $_aliasNameGenerator(db.todoListTags.todoListId, db.todoLists.id),
      );

  $$TodoListsTableProcessedTableManager get todoListId {
    final $_column = $_itemColumn<String>('todo_list_id')!;

    final manager = $$TodoListsTableTableManager(
      $_db,
      $_db.todoLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todoListIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) => db.tags.createAlias(
    $_aliasNameGenerator(db.todoListTags.tagId, db.tags.id),
  );

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TodoListTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListTagsTable> {
  $$TodoListTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TodoListsTableFilterComposer get todoListId {
    final $$TodoListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoListId,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListsTableFilterComposer(
            $db: $db,
            $table: $db.todoLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoListTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListTagsTable> {
  $$TodoListTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TodoListsTableOrderingComposer get todoListId {
    final $$TodoListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoListId,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListsTableOrderingComposer(
            $db: $db,
            $table: $db.todoLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoListTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListTagsTable> {
  $$TodoListTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TodoListsTableAnnotationComposer get todoListId {
    final $$TodoListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoListId,
      referencedTable: $db.todoLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodoListsTableAnnotationComposer(
            $db: $db,
            $table: $db.todoLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodoListTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListTagsTable,
          TodoListTag,
          $$TodoListTagsTableFilterComposer,
          $$TodoListTagsTableOrderingComposer,
          $$TodoListTagsTableAnnotationComposer,
          $$TodoListTagsTableCreateCompanionBuilder,
          $$TodoListTagsTableUpdateCompanionBuilder,
          (TodoListTag, $$TodoListTagsTableReferences),
          TodoListTag,
          PrefetchHooks Function({bool todoListId, bool tagId})
        > {
  $$TodoListTagsTableTableManager(_$AppDatabase db, $TodoListTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> todoListId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListTagsCompanion(
                todoListId: todoListId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String todoListId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TodoListTagsCompanion.insert(
                todoListId: todoListId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodoListTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todoListId = false, tagId = false}) {
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
                    if (todoListId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.todoListId,
                                referencedTable: $$TodoListTagsTableReferences
                                    ._todoListIdTable(db),
                                referencedColumn: $$TodoListTagsTableReferences
                                    ._todoListIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$TodoListTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$TodoListTagsTableReferences
                                    ._tagIdTable(db)
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

typedef $$TodoListTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListTagsTable,
      TodoListTag,
      $$TodoListTagsTableFilterComposer,
      $$TodoListTagsTableOrderingComposer,
      $$TodoListTagsTableAnnotationComposer,
      $$TodoListTagsTableCreateCompanionBuilder,
      $$TodoListTagsTableUpdateCompanionBuilder,
      (TodoListTag, $$TodoListTagsTableReferences),
      TodoListTag,
      PrefetchHooks Function({bool todoListId, bool tagId})
    >;
typedef $$MemoImagesTableCreateCompanionBuilder =
    MemoImagesCompanion Function({
      required String id,
      required String memoId,
      required String filePath,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$MemoImagesTableUpdateCompanionBuilder =
    MemoImagesCompanion Function({
      Value<String> id,
      Value<String> memoId,
      Value<String> filePath,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$MemoImagesTableReferences
    extends BaseReferences<_$AppDatabase, $MemoImagesTable, MemoImage> {
  $$MemoImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemosTable _memoIdTable(_$AppDatabase db) => db.memos.createAlias(
    $_aliasNameGenerator(db.memoImages.memoId, db.memos.id),
  );

  $$MemosTableProcessedTableManager get memoId {
    final $_column = $_itemColumn<String>('memo_id')!;

    final manager = $$MemosTableTableManager(
      $_db,
      $_db.memos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoImagesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoImagesTable> {
  $$MemoImagesTableFilterComposer({
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

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemosTableFilterComposer get memoId {
    final $$MemosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoId,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableFilterComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoImagesTable> {
  $$MemoImagesTableOrderingComposer({
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

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemosTableOrderingComposer get memoId {
    final $$MemosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoId,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableOrderingComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoImagesTable> {
  $$MemoImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MemosTableAnnotationComposer get memoId {
    final $$MemosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memoId,
      referencedTable: $db.memos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemosTableAnnotationComposer(
            $db: $db,
            $table: $db.memos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoImagesTable,
          MemoImage,
          $$MemoImagesTableFilterComposer,
          $$MemoImagesTableOrderingComposer,
          $$MemoImagesTableAnnotationComposer,
          $$MemoImagesTableCreateCompanionBuilder,
          $$MemoImagesTableUpdateCompanionBuilder,
          (MemoImage, $$MemoImagesTableReferences),
          MemoImage,
          PrefetchHooks Function({bool memoId})
        > {
  $$MemoImagesTableTableManager(_$AppDatabase db, $MemoImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memoId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoImagesCompanion(
                id: id,
                memoId: memoId,
                filePath: filePath,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memoId,
                required String filePath,
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoImagesCompanion.insert(
                id: id,
                memoId: memoId,
                filePath: filePath,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memoId = false}) {
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
                    if (memoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memoId,
                                referencedTable: $$MemoImagesTableReferences
                                    ._memoIdTable(db),
                                referencedColumn: $$MemoImagesTableReferences
                                    ._memoIdTable(db)
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

typedef $$MemoImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoImagesTable,
      MemoImage,
      $$MemoImagesTableFilterComposer,
      $$MemoImagesTableOrderingComposer,
      $$MemoImagesTableAnnotationComposer,
      $$MemoImagesTableCreateCompanionBuilder,
      $$MemoImagesTableUpdateCompanionBuilder,
      (MemoImage, $$MemoImagesTableReferences),
      MemoImage,
      PrefetchHooks Function({bool memoId})
    >;
typedef $$ConflictHistoriesTableCreateCompanionBuilder =
    ConflictHistoriesCompanion Function({
      Value<int> id,
      required String memoId,
      required String lostSide,
      Value<String> lostTitle,
      Value<String> lostContent,
      required DateTime lostUpdatedAt,
      required DateTime winnerUpdatedAt,
      Value<DateTime> recordedAt,
    });
typedef $$ConflictHistoriesTableUpdateCompanionBuilder =
    ConflictHistoriesCompanion Function({
      Value<int> id,
      Value<String> memoId,
      Value<String> lostSide,
      Value<String> lostTitle,
      Value<String> lostContent,
      Value<DateTime> lostUpdatedAt,
      Value<DateTime> winnerUpdatedAt,
      Value<DateTime> recordedAt,
    });

class $$ConflictHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ConflictHistoriesTable> {
  $$ConflictHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoId => $composableBuilder(
    column: $table.memoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lostSide => $composableBuilder(
    column: $table.lostSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lostTitle => $composableBuilder(
    column: $table.lostTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lostContent => $composableBuilder(
    column: $table.lostContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lostUpdatedAt => $composableBuilder(
    column: $table.lostUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get winnerUpdatedAt => $composableBuilder(
    column: $table.winnerUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConflictHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConflictHistoriesTable> {
  $$ConflictHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoId => $composableBuilder(
    column: $table.memoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lostSide => $composableBuilder(
    column: $table.lostSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lostTitle => $composableBuilder(
    column: $table.lostTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lostContent => $composableBuilder(
    column: $table.lostContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lostUpdatedAt => $composableBuilder(
    column: $table.lostUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get winnerUpdatedAt => $composableBuilder(
    column: $table.winnerUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConflictHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConflictHistoriesTable> {
  $$ConflictHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get memoId =>
      $composableBuilder(column: $table.memoId, builder: (column) => column);

  GeneratedColumn<String> get lostSide =>
      $composableBuilder(column: $table.lostSide, builder: (column) => column);

  GeneratedColumn<String> get lostTitle =>
      $composableBuilder(column: $table.lostTitle, builder: (column) => column);

  GeneratedColumn<String> get lostContent => $composableBuilder(
    column: $table.lostContent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lostUpdatedAt => $composableBuilder(
    column: $table.lostUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get winnerUpdatedAt => $composableBuilder(
    column: $table.winnerUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$ConflictHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConflictHistoriesTable,
          ConflictHistory,
          $$ConflictHistoriesTableFilterComposer,
          $$ConflictHistoriesTableOrderingComposer,
          $$ConflictHistoriesTableAnnotationComposer,
          $$ConflictHistoriesTableCreateCompanionBuilder,
          $$ConflictHistoriesTableUpdateCompanionBuilder,
          (
            ConflictHistory,
            BaseReferences<
              _$AppDatabase,
              $ConflictHistoriesTable,
              ConflictHistory
            >,
          ),
          ConflictHistory,
          PrefetchHooks Function()
        > {
  $$ConflictHistoriesTableTableManager(
    _$AppDatabase db,
    $ConflictHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictHistoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> memoId = const Value.absent(),
                Value<String> lostSide = const Value.absent(),
                Value<String> lostTitle = const Value.absent(),
                Value<String> lostContent = const Value.absent(),
                Value<DateTime> lostUpdatedAt = const Value.absent(),
                Value<DateTime> winnerUpdatedAt = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
              }) => ConflictHistoriesCompanion(
                id: id,
                memoId: memoId,
                lostSide: lostSide,
                lostTitle: lostTitle,
                lostContent: lostContent,
                lostUpdatedAt: lostUpdatedAt,
                winnerUpdatedAt: winnerUpdatedAt,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String memoId,
                required String lostSide,
                Value<String> lostTitle = const Value.absent(),
                Value<String> lostContent = const Value.absent(),
                required DateTime lostUpdatedAt,
                required DateTime winnerUpdatedAt,
                Value<DateTime> recordedAt = const Value.absent(),
              }) => ConflictHistoriesCompanion.insert(
                id: id,
                memoId: memoId,
                lostSide: lostSide,
                lostTitle: lostTitle,
                lostContent: lostContent,
                lostUpdatedAt: lostUpdatedAt,
                winnerUpdatedAt: winnerUpdatedAt,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConflictHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConflictHistoriesTable,
      ConflictHistory,
      $$ConflictHistoriesTableFilterComposer,
      $$ConflictHistoriesTableOrderingComposer,
      $$ConflictHistoriesTableAnnotationComposer,
      $$ConflictHistoriesTableCreateCompanionBuilder,
      $$ConflictHistoriesTableUpdateCompanionBuilder,
      (
        ConflictHistory,
        BaseReferences<_$AppDatabase, $ConflictHistoriesTable, ConflictHistory>,
      ),
      ConflictHistory,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db, _db.memos);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TodoItemsTableTableManager get todoItems =>
      $$TodoItemsTableTableManager(_db, _db.todoItems);
  $$TodoListsTableTableManager get todoLists =>
      $$TodoListsTableTableManager(_db, _db.todoLists);
  $$TagHistoriesTableTableManager get tagHistories =>
      $$TagHistoriesTableTableManager(_db, _db.tagHistories);
  $$MemoTagsTableTableManager get memoTags =>
      $$MemoTagsTableTableManager(_db, _db.memoTags);
  $$TodoItemTagsTableTableManager get todoItemTags =>
      $$TodoItemTagsTableTableManager(_db, _db.todoItemTags);
  $$TodoListTagsTableTableManager get todoListTags =>
      $$TodoListTagsTableTableManager(_db, _db.todoListTags);
  $$MemoImagesTableTableManager get memoImages =>
      $$MemoImagesTableTableManager(_db, _db.memoImages);
  $$ConflictHistoriesTableTableManager get conflictHistories =>
      $$ConflictHistoriesTableTableManager(_db, _db.conflictHistories);
}
