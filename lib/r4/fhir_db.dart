// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:fhir/r4/resource/resource.dart';
import 'package:hive/hive.dart';

import '../cipher_from_key.dart';

class FhirDb {
  bool initialized = false;
  Set<R4ResourceType> _types = <R4ResourceType>{};

  Future<void> updateCipher(
      HiveCipher? oldCipher, HiveCipher? newCipher) async {
    /// only both to change things if the new password doesn't equal the old password
    if (oldCipher != newCipher) {
      await _ensureInit(cipher: oldCipher);

      /// The types box contains only a single entry, which is a list of all of the
      /// resource types that have been saved to the database
      final Box<List<String>> typesBox = await Hive.openBox<List<String>>(
          'types',
          encryptionCipher: oldCipher);

      /// get that list of types
      final List<String> types = typesBox.get('types') ?? <String>[];

      /// Create a new temporary box to store resources while we are updating the boxes
      /// with a new password
      final Box<Map<dynamic, dynamic>> tempBox =
          await Hive.openBox<Map<dynamic, dynamic>>('temp',
              encryptionCipher: newCipher);

      /// for each type in the list
      for (final String type in types) {
        /// Retrieve all resources currently in the box
        final Box<Map<dynamic, dynamic>> oldBox =
            await Hive.openBox<Map<dynamic, dynamic>>(type,
                encryptionCipher: oldCipher);

        /// for each map in the box
        for (final Map<dynamic, dynamic> value in oldBox.values) {
          /// Cast map to correct type
          final Map<String, dynamic> newValue =
              jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

          /// convert it to a resource
          final Resource resource = Resource.fromJson(newValue);

          /// Save it in the temporary box as we're changing over to the new password, so
          /// in case something goes wrong, we don't lose the data
          await tempBox.put(resource.fhirId, newValue);
        }

        /// after we have saved all of the resources in the temporary box, we can
        /// delete the old box
        await oldBox.deleteFromDisk();

        /// Create the new box with the new password
        final Box<Map<dynamic, dynamic>> newBox =
            await Hive.openBox<Map<dynamic, dynamic>>(type,
                encryptionCipher: newCipher);

        /// for each map in the temp box
        for (final Map<dynamic, dynamic> value in tempBox.values) {
          /// Cast map to correct type
          final Map<String, dynamic> newValue =
              Map<String, dynamic>.from(value);

          /// convert it to a resource
          final Resource resource = Resource.fromJson(newValue);

          /// Save it to the new box with the new password
          await newBox.put(resource.fhirId, newValue);
        }

        /// clear everything from the tempBox so we can use it again
        await tempBox.clear();
      }

      /// After we've been through all of the types, delete the tempBox.
      await tempBox.deleteFromDisk();

      /// Delete the typesBox because we need to replace it too using the new password
      await typesBox.deleteFromDisk();

      /// Recreate the types box
      final Box<List<String>> newTypesBox = await Hive.openBox<List<String>>(
          'types',
          encryptionCipher: newCipher);
      await newTypesBox.put('types', types);
      await Hive.close();
    }
  }

  Future<void> updatePw(String? oldPw, String? newPw) async {
    if (oldPw != newPw) {
      final HiveCipher? oldCipher = cipherFromKey(key: oldPw);
      final HiveCipher? newCipher = cipherFromKey(key: newPw);
      await updateCipher(oldCipher, newCipher);
    }
  }

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
  Future<Box<Map<dynamic, dynamic>>> _getBox(
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
      final Box<Map<dynamic, dynamic>> box =
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
      Box<Map<dynamic, dynamic>> box;
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
      final Box<Map<dynamic, dynamic>> box =
          await _getBox(resourceType: resourceType, cipher: cipher);
      return box.containsKey(id);
    }
  }

  Future<Map<String, dynamic>> get({
    required R4ResourceType resourceType,
    required String id,
    HiveCipher? cipher,
  }) async {
    await _ensureInit(cipher: cipher);
    final Box<Map<dynamic, dynamic>> box =
        await _getBox(resourceType: resourceType, cipher: cipher);
    try {
      final Map<dynamic, dynamic>? resourceMap = box.get(id);
      final Map<String, dynamic> newResourceMap = resourceMap == null
          ? <String, dynamic>{}
          : jsonDecode(jsonEncode(resourceMap)) as Map<String, dynamic>;
      return newResourceMap;
    } catch (e, s) {
      print(e);
      print(s);
      return <String, dynamic>{};
    }
  }

  Future<Iterable<Map<String, dynamic>>> getActiveResourcesOfType(
      {required R4ResourceType resourceType, HiveCipher? cipher}) async {
    await _ensureInit(cipher: cipher);
    final Box<Map<dynamic, dynamic>> box =
        await _getBox(resourceType: resourceType, cipher: cipher);
    return box.values
        .map((Map<dynamic, dynamic> e) =>
            jsonDecode(jsonEncode(e)) as Map<String, dynamic>)
        .toList();
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
      final Box<Map<dynamic, dynamic>> box = await _getBox(
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
      final Box<Map<dynamic, dynamic>> box =
          await _getBox(resourceType: resourceType, cipher: cipher);
      final String? resourceId = box.values
          .firstWhereOrNull((Map<dynamic, dynamic> element) =>
              finder(Map<String, dynamic>.from(element)))?['id']
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
      final Box<Map<dynamic, dynamic>> box = await _getBox(
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
        final Box<Map<dynamic, dynamic>> box =
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
    await _ensureInit(cipher: cipher);
    final Box<Map<dynamic, dynamic>> box =
        await _getBox(resourceType: resourceType, cipher: cipher);
    final Map<dynamic, Map<dynamic, dynamic>> boxData = box.toMap();
    boxData.removeWhere((dynamic key, Map<dynamic, dynamic> value) =>
        !finder(Map<String, dynamic>.from(value)));
    return boxData.values
        .map((Map<dynamic, dynamic> e) =>
            jsonDecode(jsonEncode(e)) as Map<String, dynamic>)
        .toList();
  }

  /// ************************************************************************
  /// All of the above has been for FHIR resources and data, below is if you
  /// need to store whatever else as well
  /// ************************************************************************

  Future<int> saveGeneral(
      {required Object object, int? key, HiveCipher? cipher}) async {
    await _ensureInit(cipher: cipher);
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
    await _ensureInit(cipher: cipher);
    final Box<Object> box;
    if (!Hive.isBoxOpen('general')) {
      box = await Hive.openBox('general', encryptionCipher: cipher);
    } else {
      box = Hive.box('general');
    }
    return box.get(key);
  }

  Future<Iterable<Object>> getAllGeneral([HiveCipher? cipher]) async {
    await _ensureInit(cipher: cipher);
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
    await _ensureInit(cipher: cipher);
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
    await _ensureInit(cipher: cipher);
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
    await _ensureInit(cipher: cipher);
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

  /// ************************************************************************
  /// These methods are for closing boxes, usually not needed and mostly for
  /// debugging purposes
  /// ************************************************************************
  Future<void> closeAllBoxes() async => Hive.close();

  /// Specify a list of which boxes you want to close
  Future<void> closeResourceBoxes(
    List<R4ResourceType> types, [
    HiveCipher? cipher,
  ]) async {
    await _ensureInit(cipher: cipher);
    for (final R4ResourceType resourceType in types) {
      final String resourceTypeString =
          Resource.resourceTypeToString(resourceType);
      if (!Hive.isBoxOpen(resourceTypeString)) {
        await Hive.box(resourceTypeString).close();
      }
    }
  }

  /// Close the history box
  Future<void> closeHistoryBox([HiveCipher? cipher]) async {
    await _ensureInit(cipher: cipher);
    if (Hive.isBoxOpen('history')) {
      await Hive.box('history').close();
    }
  }

  /// Close the general box
  Future<void> closeGeneralBox([HiveCipher? cipher]) async {
    await _ensureInit(cipher: cipher);
    if (Hive.isBoxOpen('general')) {
      await Hive.box('general').close();
    }
  }

  /// Close the types box
  Future<void> closeTypesBox([HiveCipher? cipher]) async {
    await _ensureInit(cipher: cipher);
    if (Hive.isBoxOpen('types')) {
      await Hive.box('types').close();
    }
  }
}
