// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:fhir/r4/resource/resource.dart';
import 'package:hive/hive.dart';

class FhirDb {
  bool initialized = false;
  Set<R4ResourceType> _types = <R4ResourceType>{};

  /// To initialize the database as a whole. Configure the path, set initialized
  /// to true, register all of the ResourceTypeAdapters, and then assign the
  /// set of all of the types to the variable types
  Future<void> initDb({String? path, HiveCipher? cipher}) async {
    if (!initialized) {
      Hive.init(path ?? '.');
      initialized = true;
      final Box<List<String>> typesBox =
          await Hive.openBox<List<String>>('types', encryptionCipher: cipher);
      _types = typesBox
              .get('types')
              ?.map((String e) => Resource.resourceTypeFromString(e)!)
              .toSet() ??
          <R4ResourceType>{};
    }
  }

  /// Convenience getter to ensure initialized
  Future<void> _ensureInit({String? path, HiveCipher? cipher}) async {
    if (!initialized) {
      await initDb(path: path, cipher: cipher);
    }
  }

  /// This is to get a specific Box
  Future<Box<Map<String, dynamic>>> _getBox(
      {required R4ResourceType resourceType, HiveCipher? cipher}) async {
    await _ensureInit(cipher: cipher);
    final String resourceTypeString =
        Resource.resourceTypeToString(resourceType);
    if (!Hive.isBoxOpen(resourceTypeString)) {
      return Hive.openBox(resourceTypeString, encryptionCipher: cipher);
    } else {
      return Hive.box(resourceTypeString);
    }
  }

  /// In this case we're adding a type. If it's already included, we just
  /// return true and don't re-add it. Otherwise we enseure db is initialized,
  /// and after we can assume the 'types' box is open, get the Set, update
  /// it, write it back, and return true.
  Future<bool> _addType({
    required R4ResourceType resourceType,
    HiveCipher? cipher,
  }) async {
    try {
      if (_types.contains(resourceType)) {
        return true;
      } else {
        _types.add(resourceType);
        await _ensureInit(cipher: cipher);
        final Box<List<String>> box = Hive.box<List<String>>('types');
        await box.put(
            'types',
            _types
                .map((R4ResourceType e) => Resource.resourceTypeToString(e))
                .toList());
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> save({
    required R4ResourceType resourceType,
    required Map<String, dynamic> resource,
    HiveCipher? cipher,
  }) async {
    try {
      await _ensureInit(cipher: cipher);
      final Box<Map<String, dynamic>> box =
          await _getBox(resourceType: resourceType, cipher: cipher);
      await box.put(resource['id'], resource);
      return await _addType(resourceType: resourceType, cipher: cipher);
    } catch (e, s) {
      log('Error: $e, Stack at time of Error: $s');
      return false;
    }
  }

  Future<bool> saveHistory(
      {required Map<String, dynamic> resource, HiveCipher? cipher}) async {
    try {
      await _ensureInit(cipher: cipher);
      Box<Map<String, dynamic>> box;
      if (!Hive.isBoxOpen('history')) {
        box = await Hive.openBox('history', encryptionCipher: cipher);
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

  Future<bool> exists({
    required R4ResourceType resourceType,
    required String id,
    HiveCipher? cipher,
  }) async {
    if (!_types.contains(resourceType)) {
      return false;
    } else {
      await _ensureInit(cipher: cipher);
      final Box<Map<String, dynamic>> box =
          await _getBox(resourceType: resourceType, cipher: cipher);
      return box.containsKey(id);
    }
  }

  Future<Map<String, dynamic>?> get({
    required R4ResourceType resourceType,
    required String id,
    HiveCipher? cipher,
  }) async {
    await _ensureInit(cipher: cipher);
    final Box<Map<String, dynamic>> box = await _getBox(
      resourceType: resourceType,
      cipher: cipher,
    );
    final Map<String, dynamic>? resourceMap = box.get(id);
    return resourceMap;
  }

  Future<Iterable<Map<String, dynamic>>> getActiveResourcesOfType(
      {required R4ResourceType resourceType, HiveCipher? cipher}) async {
    await _ensureInit(cipher: cipher);
    final Box<Map<String, dynamic>> box =
        await _getBox(resourceType: resourceType, cipher: cipher);
    return box.values;
  }

  Future<List<Map<String, dynamic>>> getAllActiveResources(
      [HiveCipher? cipher]) async {
    final List<Map<String, dynamic>> allResources = <Map<String, dynamic>>[];
    for (final R4ResourceType type in _types) {
      allResources.addAll(
          await getActiveResourcesOfType(resourceType: type, cipher: cipher));
    }
    return allResources;
  }

  Future<bool> deleteById({
    required R4ResourceType resourceType,
    required String id,
    HiveCipher? cipher,
  }) async {
    try {
      await _ensureInit(cipher: cipher);
      final Box<Map<String, dynamic>> box = await _getBox(
        resourceType: resourceType,
        cipher: cipher,
      );
      await box.delete(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete({
    required R4ResourceType resourceType,
    required bool Function(Map<String, dynamic>) finder,
    HiveCipher? cipher,
  }) async {
    try {
      await _ensureInit(cipher: cipher);
      final Box<Map<String, dynamic>> box =
          await _getBox(resourceType: resourceType, cipher: cipher);
      final String? resourceId = box.values
          .firstWhereOrNull(
              (Map<String, dynamic> element) => finder(element))?['id']
          ?.toString();
      if (resourceId != null) {
        await box.delete(resourceId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSingleType(
      {required R4ResourceType resourceType, HiveCipher? cipher}) async {
    try {
      await _ensureInit(cipher: cipher);
      final Box<Map<String, dynamic>> box = await _getBox(
        resourceType: resourceType,
        cipher: cipher,
      );
      await box.clear();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAllData([HiveCipher? cipher]) async {
    try {
      await _ensureInit(cipher: cipher);
      for (final R4ResourceType type in _types) {
        final Box<Map<String, dynamic>> box =
            await _getBox(resourceType: type, cipher: cipher);
        await box.deleteFromDisk();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteDatabase([HiveCipher? cipher]) async {
    await _ensureInit(cipher: cipher);
    await Hive.deleteFromDisk();
  }

  Future<Iterable<Map<String, dynamic>>> search({
    required R4ResourceType resourceType,
    required bool Function(Map<String, dynamic>) finder,
    HiveCipher? cipher,
  }) async {
    if (!initialized) {
      await initDb(cipher: cipher);
    }
    final Box<Map<String, dynamic>> box =
        await _getBox(resourceType: resourceType, cipher: cipher);
    final Map<dynamic, Map<String, dynamic>> boxData = box.toMap();
    boxData.removeWhere(
        (dynamic key, Map<String, dynamic> value) => !finder(value));
    return boxData.values;
  }

  /// ************************************************************************
  /// All of the above has been for FHIR resources and data, below is if you
  /// need to store whatever else as well
  /// ************************************************************************

  Future<int> saveGeneral(
      {required Object object, int? key, HiveCipher? cipher}) async {
    try {
      final Box<Object> box;
      if (!Hive.isBoxOpen('general')) {
        box = await Hive.openBox('general', encryptionCipher: cipher);
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

  Future<Object?> readGeneral({required int key, HiveCipher? cipher}) async {
    if (!initialized) {
      await initDb(cipher: cipher);
    }
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general', encryptionCipher: cipher);
    } else {
      box = Hive.box('general');
    }
    return box.get(key);
  }

  Future<Iterable<Object>> getAllGeneral([HiveCipher? cipher]) async {
    if (!initialized) {
      await initDb(cipher: cipher);
    }
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general', encryptionCipher: cipher);
    } else {
      box = Hive.box('general');
    }
    final Map<dynamic, Object> boxData = box.toMap();
    return boxData.values;
  }

  Future<Iterable<Object>> searchGeneral({
    required bool Function(Object) finder,
    HiveCipher? cipher,
  }) async {
    if (!initialized) {
      await initDb(cipher: cipher);
    }
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general', encryptionCipher: cipher);
    } else {
      box = Hive.box('general');
    }
    final Map<dynamic, Object> boxData = box.toMap();
    boxData.removeWhere((dynamic key, Object value) => !finder(value));
    return boxData.values;
  }

  Future<bool> deletefromGeneral({required int key, HiveCipher? cipher}) async {
    try {
      final Box<Object> box;
      if (!Hive.isBoxOpen('general')) {
        box = await Hive.openBox('general', encryptionCipher: cipher);
      } else {
        box = Hive.box('general');
      }
      await box.delete(key);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearGeneral([HiveCipher? cipher]) async {
    try {
      final Box<Object> box;
      if (!Hive.isBoxOpen('general')) {
        box = await Hive.openBox('general', encryptionCipher: cipher);
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
