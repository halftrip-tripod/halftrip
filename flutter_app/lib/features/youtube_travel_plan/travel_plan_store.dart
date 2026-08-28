import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_models.dart';
import 'travel_plan_models.dart';

class TravelPlanConflict {
  const TravelPlanConflict({
    required this.firstItemId,
    required this.secondItemId,
    required this.message,
  });

  final String firstItemId;
  final String secondItemId;
  final String message;
}

class TravelPlanStore extends ChangeNotifier {
  TravelPlanStore._({
    required SharedPreferences preferences,
    required TravelPlanDocument document,
    Future<void> Function(TravelPlanDocument document)? onSaved,
  }) : _preferences = preferences,
       _document = document,
       _onSaved = onSaved;

  static const _storagePrefix = 'youtube-travel-plan-v1:';
  static const _saveDelay = Duration(milliseconds: 450);

  final SharedPreferences _preferences;
  final Future<void> Function(TravelPlanDocument document)? _onSaved;
  TravelPlanDocument _document;
  Timer? _saveTimer;
  TravelPlanSaveStatus _saveStatus = TravelPlanSaveStatus.idle;
  TravelPlanFilter _filter = TravelPlanFilter.all;
  TravelPlanSort _sort = TravelPlanSort.custom;
  String? _selectedItemId;
  final List<TravelPlanDocument> _undoStack = [];
  final List<TravelPlanDocument> _redoStack = [];

  TravelPlanDocument get document => _document;
  TravelPlanSaveStatus get saveStatus => _saveStatus;
  TravelPlanFilter get filter => _filter;
  TravelPlanSort get sort => _sort;
  String? get selectedItemId => _selectedItemId;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  List<TravelPlanItem> get visibleItems {
    final filtered = _document.items.where(_matchesFilter).toList();
    switch (_sort) {
      case TravelPlanSort.custom:
        filtered.sort((a, b) => a.order.compareTo(b.order));
      case TravelPlanSort.dateTime:
        filtered.sort((a, b) {
          final aKey = '${a.date ?? '9999-99-99'} ${a.startTime ?? '99:99'}';
          final bKey = '${b.date ?? '9999-99-99'} ${b.startTime ?? '99:99'}';
          return aKey.compareTo(bKey);
        });
      case TravelPlanSort.placeName:
        filtered.sort((a, b) => a.placeName.compareTo(b.placeName));
      case TravelPlanSort.category:
        filtered.sort((a, b) => a.category.name.compareTo(b.category.name));
      case TravelPlanSort.restaurantPriceLevel:
        filtered.sort(
          (a, b) => (a.restaurantPriceLevel ?? 'ZZZ').compareTo(
            b.restaurantPriceLevel ?? 'ZZZ',
          ),
        );
    }
    return filtered;
  }

  List<TravelPlanConflict> get conflicts {
    final byDate = <String, List<TravelPlanItem>>{};
    for (final item in _document.items) {
      if (item.verificationStatus == TravelPlanVerificationStatus.excluded ||
          item.date == null ||
          item.startTime == null ||
          item.endTime == null) {
        continue;
      }
      byDate.putIfAbsent(item.date!, () => []).add(item);
    }

    final result = <TravelPlanConflict>[];
    for (final entry in byDate.entries) {
      final items = [...entry.value]
        ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
      for (var index = 0; index < items.length - 1; index++) {
        final current = items[index];
        final next = items[index + 1];
        if (current.endTime!.compareTo(next.startTime!) > 0) {
          result.add(
            TravelPlanConflict(
              firstItemId: current.id,
              secondItemId: next.id,
              message:
                  '${entry.key} ${current.placeName} 일정과 ${next.placeName} 일정이 겹칩니다.',
            ),
          );
        }
      }
    }
    return result;
  }

  /// 코스함 코스에서 계획표 열기 — 유튜브 job 없이 SavedCourse 기반.
  /// 문서 키는 'course-{id}'로 job과 같은 저장 공간을 쓰되 충돌하지 않는다.
  static Future<TravelPlanStore> loadForCourse(
    SavedCourse course, {
    Future<void> Function(TravelPlanDocument document)? onSaved,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final docKey = 'course-${course.id}';
    final raw = preferences.getString('$_storagePrefix$docKey');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return TravelPlanStore._(
            preferences: preferences,
            document: TravelPlanDocument.fromJson(decoded),
            onSaved: onSaved,
          );
        }
      } catch (_) {
        // 로컬 초안이 깨졌어도 코스로부터 새로 만들면 된다.
      }
    }

    // DAY·방문 순서대로 계획표 행 생성.
    final sorted = [...course.stops]..sort((a, b) =>
        a.day != b.day ? a.day.compareTo(b.day) : 0);
    final items = <TravelPlanItem>[
      for (var i = 0; i < sorted.length; i++)
        TravelPlanItem.fromCourseStop(sorted[i], docKey: docKey, order: i + 1),
    ];
    final document = TravelPlanDocument(
      jobId: docKey,
      tripId: null,
      title: course.title,
      city: course.regionName,
      startDate: null,
      endDate: null,
      participantCount: null,
      youtubeUrl: '',
      videoTitle: '',
      items: items,
      updatedAt: DateTime.now(),
      lastExportedAt: null,
      spreadsheetId: null,
      spreadsheetUrl: null,
    );
    final store = TravelPlanStore._(
      preferences: preferences,
      document: document,
      onSaved: onSaved,
    );
    await store.saveNow();
    return store;
  }

  static Future<TravelPlanStore> load({
    required YoutubeCourseJobItem job,
    TripDetail? tripDetail,
    Future<void> Function(TravelPlanDocument document)? onSaved,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_storagePrefix${job.jobId}');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return TravelPlanStore._(
            preferences: preferences,
            document: TravelPlanDocument.fromJson(decoded),
            onSaved: onSaved,
          );
        }
      } catch (_) {
        // A damaged local draft should not block opening the generated course.
      }
    }

    final result = job.result;
    final trip = tripDetail?.trip;
    final items =
        result?.stops
            .map(
              (stop) => TravelPlanItem.fromYoutubeStop(stop, jobId: job.jobId),
            )
            .toList() ??
        <TravelPlanItem>[];
    final now = DateTime.now();
    final document = TravelPlanDocument(
      jobId: job.jobId,
      tripId: job.tripId,
      title:
          result?.title.trim().isNotEmpty == true
              ? result!.title.trim()
              : '${job.regionName} 영상 여행 계획',
      city: trip?.regionName ?? job.regionName,
      startDate: trip == null ? null : _dateText(trip.startDate),
      endDate: trip == null ? null : _dateText(trip.endDate),
      participantCount: trip?.travelerCount,
      youtubeUrl: job.youtubeUrl,
      videoTitle: result?.title ?? '',
      items: items,
      updatedAt: now,
      lastExportedAt: null,
      spreadsheetId: null,
      spreadsheetUrl: null,
    );
    final store = TravelPlanStore._(
      preferences: preferences,
      document: document,
      onSaved: onSaved,
    );
    await store.saveNow();
    return store;
  }

  void setFilter(TravelPlanFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void setSort(TravelPlanSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  void selectItem(String? itemId) {
    if (_selectedItemId == itemId) return;
    _selectedItemId = itemId;
    notifyListeners();
  }

  void updateHeader({
    String? title,
    String? city,
    Object? startDate = _storeUnset,
    Object? endDate = _storeUnset,
    Object? participantCount = _storeUnset,
  }) {
    _recordUndo();
    _document = TravelPlanDocument(
      jobId: _document.jobId,
      tripId: _document.tripId,
      title: title ?? _document.title,
      city: city ?? _document.city,
      startDate:
          startDate == _storeUnset ? _document.startDate : startDate as String?,
      endDate: endDate == _storeUnset ? _document.endDate : endDate as String?,
      participantCount:
          participantCount == _storeUnset
              ? _document.participantCount
              : participantCount as int?,
      youtubeUrl: _document.youtubeUrl,
      videoTitle: _document.videoTitle,
      items: _document.items,
      updatedAt: DateTime.now(),
      lastExportedAt: _document.lastExportedAt,
      spreadsheetId: _document.spreadsheetId,
      spreadsheetUrl: _document.spreadsheetUrl,
    );
    _changed();
  }

  void updateItem(TravelPlanItem updated) {
    final index = _document.items.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;
    _recordUndo();
    final items = [..._document.items];
    items[index] = updated;
    _replaceItems(items);
  }

  void addItem() {
    _recordUndo();
    final nextOrder = _document.items.length + 1;
    final item = TravelPlanItem(
      id: '${_document.jobId}-user-${DateTime.now().microsecondsSinceEpoch}',
      order: nextOrder,
      date: null,
      startTime: null,
      endTime: null,
      placeId: null,
      placeName: '새 일정',
      address: null,
      latitude: null,
      longitude: null,
      category: TravelCategory.etc,
      activity: '',
      participantCount: _document.participantCount,
      transportType: null,
      transportMinutes: null,
      reservationStatus: ReservationStatus.unknown,
      memo: '',
      videoTimestampSeconds: null,
      videoEndTimestampSeconds: null,
      videoEvidenceText: null,
      foodName: null,
      foodDescription: null,
      foodVerificationStatus: FoodVerificationStatus.notApplicable,
      menuPriceAmount: null,
      menuPriceCurrency: null,
      menuPriceSource: 'NONE',
      restaurantPriceLevel: null,
      restaurantPriceMin: null,
      restaurantPriceMax: null,
      restaurantPriceCurrency: null,
      restaurantPriceSource: RestaurantPriceSource.none,
      sourceType: TravelPlanSourceType.user,
      verificationStatus: TravelPlanVerificationStatus.unconfirmed,
      completed: false,
    );
    _selectedItemId = item.id;
    _replaceItems([..._document.items, item]);
  }

  void duplicateItem(String itemId) {
    final source =
        _document.items.where((item) => item.id == itemId).firstOrNull;
    if (source == null) return;
    _recordUndo();
    final sourceIndex = _document.items.indexOf(source);
    final duplicate = source.copyWith(
      id: '${_document.jobId}-copy-${DateTime.now().microsecondsSinceEpoch}',
      sourceType: TravelPlanSourceType.user,
      completed: false,
    );
    final items = [..._document.items]..insert(sourceIndex + 1, duplicate);
    _selectedItemId = duplicate.id;
    _replaceItems(_normalizeOrders(items));
  }

  void deleteItem(String itemId) {
    if (!_document.items.any((item) => item.id == itemId)) return;
    _recordUndo();
    final items = _document.items.where((item) => item.id != itemId).toList();
    if (_selectedItemId == itemId) _selectedItemId = null;
    _replaceItems(_normalizeOrders(items));
  }

  void moveItem(String itemId, int delta) {
    final items = [..._document.items];
    final index = items.indexWhere((item) => item.id == itemId);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= items.length) return;
    _recordUndo();
    final item = items.removeAt(index);
    items.insert(target, item);
    _replaceItems(_normalizeOrders(items));
  }

  void reorder(int oldIndex, int newIndex) {
    final ordered = [..._document.items]
      ..sort((a, b) => a.order.compareTo(b.order));
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= ordered.length) return;
    _recordUndo();
    final item = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, item);
    _replaceItems(_normalizeOrders(ordered));
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_document);
    _document = _undoStack.removeLast();
    _changed();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_document);
    _document = _redoStack.removeLast();
    _changed();
  }

  Future<void> markExported({
    required String spreadsheetId,
    required String spreadsheetUrl,
  }) async {
    _document = _document.copyWith(
      lastExportedAt: DateTime.now(),
      spreadsheetId: spreadsheetId,
      spreadsheetUrl: spreadsheetUrl,
      updatedAt: DateTime.now(),
    );
    await saveNow();
    notifyListeners();
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    _saveStatus = TravelPlanSaveStatus.saving;
    notifyListeners();
    try {
      await _preferences.setString(
        '$_storagePrefix${_document.jobId}',
        jsonEncode(_document.toJson()),
      );
      await _onSaved?.call(_document);
      _saveStatus = TravelPlanSaveStatus.saved;
    } catch (_) {
      _saveStatus = TravelPlanSaveStatus.failed;
    }
    notifyListeners();
  }

  bool _matchesFilter(TravelPlanItem item) {
    return switch (_filter) {
      TravelPlanFilter.all => true,
      TravelPlanFilter.dated => item.date != null,
      TravelPlanFilter.foodAndCafe => item.isFoodPlace,
      TravelPlanFilter.foodConfirmed =>
        item.foodVerificationStatus == FoodVerificationStatus.confirmed,
      TravelPlanFilter.foodNeedsReview =>
        item.isFoodPlace &&
            (item.foodVerificationStatus == FoodVerificationStatus.estimated ||
                item.foodVerificationStatus == FoodVerificationStatus.unknown),
      TravelPlanFilter.reservationRequired =>
        item.reservationStatus == ReservationStatus.required,
      TravelPlanFilter.completed => item.completed,
      TravelPlanFilter.excluded =>
        item.verificationStatus == TravelPlanVerificationStatus.excluded,
    };
  }

  void _recordUndo() {
    _undoStack.add(_document);
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _replaceItems(List<TravelPlanItem> items) {
    _document = _document.copyWith(items: items, updatedAt: DateTime.now());
    _changed();
  }

  void _changed() {
    _saveStatus = TravelPlanSaveStatus.saving;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => unawaited(saveNow()));
    notifyListeners();
  }

  static List<TravelPlanItem> _normalizeOrders(List<TravelPlanItem> items) {
    return [
      for (var index = 0; index < items.length; index++)
        items[index].copyWith(order: index + 1),
    ];
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_saveStatus == TravelPlanSaveStatus.saving) {
      unawaited(
        _preferences.setString(
          '$_storagePrefix${_document.jobId}',
          jsonEncode(_document.toJson()),
        ),
      );
    }
    super.dispose();
  }
}

String _dateText(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

const Object _storeUnset = Object();

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
