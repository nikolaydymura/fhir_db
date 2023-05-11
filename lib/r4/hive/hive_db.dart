import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:fhir/r4/resource/resource.dart';
import 'package:hive/hive.dart';

class HiveDb {
  bool initialized = false;
  Set<R4ResourceType> _types = {};

  /// To initialize the database as a whole. Configure the path, set initialized
  /// to true, register all of the ResourceTypeAdapters, and then assign the
  /// set of all of the types to the variable types
  Future<void> initDb(String? path) async {
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

  // TODO(Dokotela): saveAll - list of Resources

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

  Future<bool> deleteById(R4ResourceType resourceType, String id) async {
    try {
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
      final Box<Map<String, dynamic>> box = await _getBox(resourceType);
      await box.clear();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAllData(String? password) async {
    try {
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
}
