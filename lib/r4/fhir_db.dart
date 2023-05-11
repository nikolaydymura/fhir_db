import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:fhir/r4/resource/resource.dart';
import 'package:hive/hive.dart';

class FhirDb {
  bool initialized = false;
  Set<R4ResourceType> _types = {};

  /// To initialize the database as a whole. Configure the path, set initialized
  /// to true, register all of the ResourceTypeAdapters, and then assign the
  /// set of all of the types to the variable types
  Future<void> initDb(String? path) async {
    if (!initialized) {
      Hive.init(path ?? '.');
      initialized = true;
      final Box<List<String>> typesBox =
          await Hive.openBox<List<String>>('types');
      _types = typesBox
              .get('types')
              ?.map((e) => Resource.resourceTypeFromString(e)!)
              .toSet() ??
          <R4ResourceType>{};
    }
  }

  /// Convenience getter to ensure initialized
  Future<void> _ensureInit(String? path) async {
    if (!initialized) {
      await initDb(path);
    }
  }

  /// This is to get a specific Box
  Future<Box<Map<String, dynamic>>> _getBox(R4ResourceType resourceType) async {
    await _ensureInit;
    final resourceTypeString = Resource.resourceTypeToString(resourceType);
    if (!Hive.isBoxOpen(resourceTypeString)) {
      return Hive.openBox(resourceTypeString);
    } else {
      return Hive.box(resourceTypeString);
    }
  }

  /// In this case we're adding a type. If it's already included, we just
  /// return true and don't re-add it. Otherwise we enseure db is initialized,
  /// and after we can assume the 'types' box is open, get the Set, update
  /// it, write it back, and return true.
  Future<bool> _addType(R4ResourceType resourceType) async {
    try {
      if (_types.contains(resourceType)) {
        return true;
      } else {
        _types.add(resourceType);
        await _ensureInit;
        final Box<List<String>> box = Hive.box<List<String>>('types');
        await box.put('types',
            _types.map((e) => Resource.resourceTypeToString(e)).toList());
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> save(Resource resource) async {
    try {
      await _ensureInit;
      final Box<Map<String, dynamic>> box =
          await _getBox(resource.resourceType!);
      await box.put(resource.id, resource.toJson());
      return await _addType(resource.resourceType!);
    } catch (e, s) {
      log('Error: $e, Stack at time of Error: $s');
      return false;
    }
  }

  Future<bool> saveHistory(Map<String, dynamic> resource) async {
    try {
      await _ensureInit;
      Box<Map<String, dynamic>> box;
      if (!Hive.isBoxOpen('history')) {
        box = await Hive.openBox('history');
      } else {
        box = Hive.box('history');
      }
      await box.put(
          '${resource["resourceType"]}/${resource["id"]}/${resource["meta"]?["versionId"]}',
          resource);
      return true;
    } catch (e, s) {
      log('Error: $e, Stack at time of Error: $s');
      return false;
    }
  }

  Future<bool> bulkSave(
      Map<R4ResourceType, Iterable<Map<String, Map<String, dynamic>>>>
          resourceMap) async {
    try {
      await _ensureInit;
      for (final type in resourceMap.keys) {
        final Box<Map<String, dynamic>> box = await _getBox(type);
        await box.addAll(resourceMap[type]!);
      }
      return true;
    } catch (e, s) {
      log('Error: $e, Stack at time of Error: $s');
      return false;
    }
  }

  Future<bool> exists(R4ResourceType resourceType, String id) async {
    if (!_types.contains(resourceType)) {
      return false;
    } else {
      await _ensureInit;
      final Box<Map<String, dynamic>> box = await _getBox(resourceType);
      return box.containsKey(id);
    }
  }

  Future<Map<String, dynamic>?> get(
      R4ResourceType resourceType, String id) async {
    await _ensureInit;
    final Box<Map<String, dynamic>> box = await _getBox(resourceType);
    final resourceMap = box.get(id);
    return resourceMap;
  }

  Future<Iterable<Map<String, dynamic>>> getActiveResourcesOfType(
      R4ResourceType resourceType) async {
    await _ensureInit;
    final Box<Map<String, dynamic>> box = await _getBox(resourceType);
    return box.values;
  }

  Future<List<Map<String, dynamic>>> getAllActiveResources() async {
    final allResources = <Map<String, dynamic>>[];
    for (final type in _types) {
      allResources.addAll(await getActiveResourcesOfType(type));
    }
    return allResources;
  }

  Future<bool> deleteById(R4ResourceType resourceType, String id) async {
    try {
      await _ensureInit;
      final Box<Map<String, dynamic>> box = await _getBox(resourceType);
      await box.delete(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(
    R4ResourceType resourceType,
    bool Function(Map<String, dynamic>) finder,
  ) async {
    try {
      await _ensureInit;
      final Box<Map<String, dynamic>> box = await _getBox(resourceType);
      final resourceId =
          box.values.firstWhereOrNull((element) => finder(element))?['id'];
      if (resourceId != null) {
        await box.delete(resourceId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSingleType(R4ResourceType resourceType) async {
    try {
      await _ensureInit;
      final Box<Map<String, dynamic>> box = await _getBox(resourceType);
      await box.clear();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAllData(String? password) async {
    try {
      await _ensureInit;
      for (final type in _types) {
        final Box<Map<String, dynamic>> box = await _getBox(type);
        await box.deleteFromDisk();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteDatabase(String? password) async {
    await _ensureInit;
    await Hive.deleteFromDisk();
  }

  Future<Iterable<Map<String, dynamic>>> search(
    R4ResourceType resourceType,
    bool Function(Map<String, dynamic>) finder,
  ) async {
    if (!initialized) {
      await initDb(null);
    }
    final Box<Map<String, dynamic>> box = await _getBox(resourceType);
    final boxData = box.toMap();
    boxData.removeWhere((key, value) => !finder(value));
    return boxData.values;
  }

  /// ************************************************************************
  /// All of the above has been for FHIR resources and data, below is if you
  /// need to store whatever else as well
  /// ************************************************************************

  Future<int> saveGeneral(String? password, Object object, int? key) async {
    try {
      final Box<Object> box;
      if (!Hive.isBoxOpen('general')) {
        box = await Hive.openBox('general');
      } else {
        box = Hive.box('general');
      }
      if (key == null) {
        return box.add(object);
      } else {
        await box.put(key, object);
        return key;
      }
    } catch (e) {
      return -1;
    }
  }

  Future<Object?> readGeneral(int key) async {
    if (!initialized) {
      await initDb(null);
    }
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general');
    } else {
      box = Hive.box('general');
    }
    return await box.get(key);
  }

  Future<Iterable<Object>> getAllGeneral() async {
    if (!initialized) {
      await initDb(null);
    }
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general');
    } else {
      box = Hive.box('general');
    }
    final boxData = box.toMap();
    return boxData.values;
  }

  Future<Iterable<Object>> searchGeneral(
    bool Function(Object) finder,
  ) async {
    if (!initialized) {
      await initDb(null);
    }
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general');
    } else {
      box = Hive.box('general');
    }
    final boxData = box.toMap();
    boxData.removeWhere((key, value) => !finder(value));
    return boxData.values;
  }

  Future<bool> deletefromGeneral(String? password, int key) async {
    try {
      final Box<Object> box;
      if (!Hive.isBoxOpen('general')) {
        box = await Hive.openBox('general');
      } else {
        box = Hive.box('general');
      }
      await box.delete(key);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearGeneral(String? password) async {
    try {
      final Box<Object> box;
      if (!Hive.isBoxOpen('general')) {
        box = await Hive.openBox('general');
      } else {
        box = Hive.box('general');
      }
      await box.clear();
      return true;
    } catch (e) {
      return false;
    }
  }
}
