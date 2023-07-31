// ignore_for_file: avoid_dynamic_calls

// Dart imports:
import 'dart:async';

import 'package:fhir/stu3.dart';

import '../cipher_from_key.dart';
import 'fhir_db.dart';

class FhirDbDao {
  /// Singleton factory
  factory FhirDbDao() => _fhirFhirDbDao;

  /// Private Constructor
  FhirDbDao._() {
    _fhirDb = FhirDb();
  }

  /// Singleton Accessor
  FhirDb get fhirDb => _fhirDb;

  /// The actual database
  late FhirDb _fhirDb;

  /// Singleton Instance
  static final FhirDbDao _fhirFhirDbDao = FhirDbDao._();

  /// Initalizes the database, configure its path, and return it
  Future<FhirDb> init(String? path, {HiveCipher? cipher, String? pw}) async {
    await _fhirDb.initDb(path: path, cipher: cipher ?? cipherFromKey(key: pw));
    return _fhirDb;
  }

  Future<void> updateCipher(
          HiveCipher? oldCipher, HiveCipher? newCipher) async =>
      _fhirDb.updateCipher(oldCipher, newCipher);

  Future<void> updatePw(String? oldPw, String? newPw) async =>
      _fhirDb.updatePw(oldPw, newPw);

  /// Saves a [Resource] to the local Db, [cipher] is optional (but after set,
  /// it must always be used everytime), will update the FhirFhirFhirMeta fields
  /// of the [Resource] and adds an id if none is already given.
  Future<Resource> save(
    Resource? resource, {
    HiveCipher? cipher,
    String? pw,
  }) async {
    cipher ??= cipherFromKey(key: pw);
    if (resource != null) {
      if (resource.resourceType != null) {
        return resource.fhirId == null
            ? await _insert(resource, cipher)
            : await fhirDb.exists(
                resourceType: resource.resourceType!,
                id: resource.fhirId!.toString(),
                cipher: cipher,
              )
                ? await _update(resource, cipher)
                : await _insert(resource, cipher);
      } else {
        throw const FormatException('ResourceType cannot be null');
      }
    } else {
      throw const FormatException('Resource cannot be null');
    }
  }

  /// The built-in bulkSave (called addAll) for Hive only allows automatically
  /// generated, incremented (int) IDs, so this function really just calls the
  /// save function over and over
  Future<bool> saveAll(List<Resource> resources,
      {HiveCipher? cipher, String? pw}) async {
    cipher ??= cipherFromKey(key: pw);
    for (final Resource resource in resources) {
      try {
        await save(resource, cipher: cipher);
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  Future<bool> addAll(List<Resource> resources,
          {HiveCipher? cipher, String? pw}) async =>
      saveAll(resources, cipher: cipher ?? cipherFromKey(key: pw));

  /// function used to save a new resource in the db
  Future<Resource> _insert(
    Resource resource,
    HiveCipher? cipher,
  ) async {
    final Resource newResource =
        resource.newIdIfNoId().updateVersion(oldMeta: resource.meta);
    await _fhirDb.save(
      resourceType: newResource.resourceType!,
      resource: newResource.toJson(),
      cipher: cipher,
    );
    return newResource;
  }

  /// functions used to update a resource which has already been saved into the
  /// db, will also save the old version
  Future<Resource> _update(
    Resource resource,
    HiveCipher? cipher,
  ) async {
    if (resource.resourceTypeString != null) {
      if (resource.fhirId != null) {
        final Map<String, dynamic> dbResource = await _fhirDb.get(
          resourceType: resource.resourceType!,
          id: resource.fhirId!.toString(),
          cipher: cipher,
        );
        if (dbResource.isNotEmpty) {
          final Map<String, dynamic> oldResource =
              Map<String, dynamic>.from(dbResource);
          await _fhirDb.saveHistory(
            resource: oldResource,
            cipher: cipher,
          );
          final FhirMeta? oldMeta = oldResource['meta'] == null
              ? null
              : FhirMeta.fromJson(oldResource['meta'] as Map<String, dynamic>);
          final Resource newResource = resource.updateVersion(oldMeta: oldMeta);
          await _fhirDb.save(
            resourceType: newResource.resourceType!,
            resource: newResource.toJson(),
            cipher: cipher,
          );
          return newResource;
        } else {
          return _insert(resource, cipher);
        }
      } else {
        return _insert(resource, cipher);
      }
    } else {
      throw const FormatException('Resource passed must have a resourceType');
    }
  }

  /// function used to save a new resource in the db
  Future<Resource?> get({
    required Stu3ResourceType resourceType,
    required String id,
    HiveCipher? cipher,
    String? pw,
  }) async {
    cipher ??= cipherFromKey(key: pw);

    final Map<String, dynamic> resourceMap = await _fhirDb.get(
      resourceType: resourceType,
      id: id,
      cipher: cipher,
    );
    return resourceMap.isEmpty
        ? null
        : Resource.fromJson(Map<String, dynamic>.from(resourceMap));
  }

  /// searches for a specific [Resource]. That resource can be defined by
  /// passing a full [Resource] object, you may pass a [resourceType] and [id]
  /// or you can pass a search [field] - since we are dealing with maps, this
  /// should be a list of strings or integers, and this function will walk
  /// through them:
  ///
  /// field = ['name', 'given', 2]
  /// newValue = resource['name'];
  /// newValue = newValue['given'];
  /// newValue = newValue[2];
  Future<List<Resource>> find({
    Resource? resource,
    Stu3ResourceType? resourceType,
    String? id,
    List<Object>? field,
    String? value,
    HiveCipher? cipher,
    String? pw,
  }) async {
    cipher ??= cipherFromKey(key: pw);

    /// if we're just trying to match a resource
    if (resource != null &&
        resource.resourceType != null &&
        (resource.fhirId != null || id != null)) {
      final Map<String, dynamic> newResource = await fhirDb.get(
        resourceType: resource.resourceType!,
        id: resource.fhirId!.toString(),
        cipher: cipher,
      );
      return newResource.isEmpty
          ? <Resource>[]
          : <Resource>[
              Resource.fromJson(Map<String, dynamic>.from(newResource))
            ];
    } else if (resourceType != null && id != null) {
      final Map<String, dynamic> newResource = await fhirDb.get(
        resourceType: resourceType,
        id: id,
        cipher: cipher,
      );
      return newResource.isEmpty
          ? <Resource>[]
          : <Resource>[
              Resource.fromJson(Map<String, dynamic>.from(newResource))
            ];
    } else if (resourceType != null && field != null && value != null) {
      bool finder(Map<String, dynamic> finderResource) {
        dynamic result = finderResource;
        for (final Object key in field) {
          result = result[key];
        }
        return result.toString() == value;
      }

      return _search(
          resourceType: resourceType, finder: finder, cipher: cipher);
    } else {
      throw const FormatException('Must have either: '
          '\n1) a resource with a resourceType'
          '\n2) a resourceType and an Id'
          '\n3) a resourceType, a specific field, and the value of interest');
    }
  }

  /// returns all resources of a specific type
  Future<List<Resource>> getActiveResourcesOfType({
    List<Stu3ResourceType>? resourceTypes,
    List<String>? resourceTypeStrings,
    Resource? resource,
    HiveCipher? cipher,
    String? pw,
  }) async {
    cipher ??= cipherFromKey(key: pw);
    final Set<Stu3ResourceType> typeList = <Stu3ResourceType>{};
    if (resource?.resourceType != null) {
      typeList.add(resource!.resourceType!);
    }
    if (resourceTypes != null && resourceTypes.isNotEmpty) {
      typeList.addAll(resourceTypes);
    }
    if (resourceTypeStrings != null) {
      for (final String type in resourceTypeStrings) {
        final Stu3ResourceType? resourceType = resourceTypeFromStringMap[type];
        if (resourceType != null) {
          typeList.add(resourceType);
        }
      }
    }

    final List<Resource> resourceList = <Resource>[];
    for (final Stu3ResourceType type in typeList) {
      final Iterable<Map<String, dynamic>> newResources =
          await _fhirDb.getActiveResourcesOfType(
        resourceType: type,
        cipher: cipher,
      );
      resourceList.addAll(
          newResources.map((Map<String, dynamic> e) => Resource.fromJson(e)));
    }
    return resourceList;
  }

  /// returns all resources in the [db], including historical versions
  Future<List<Resource>> getAllActiveResources(String? pw,
          [HiveCipher? cipher]) async =>
      (await _fhirDb.getAllActiveResources(cipher ?? cipherFromKey(key: pw)))
          .map((Map<String, dynamic> e) => Resource.fromJson(e))
          .toList();

  /// Delete specific resource
  Future<bool> delete({
    Resource? resource,
    Stu3ResourceType? resourceType,
    String? id,
    bool Function(Map<String, dynamic>)? finder,
    HiveCipher? cipher,
    String? pw,
  }) async {
    cipher ??= cipherFromKey(key: pw);
    if (resource != null &&
        resource.resourceType != null &&
        resource.fhirId != null) {
      return _fhirDb.deleteById(
        resourceType: resource.resourceType!,
        id: resource.fhirId!.toString(),
        cipher: cipher,
      );
    } else if (resourceType != null && id != null) {
      return _fhirDb.deleteById(
        resourceType: resourceType,
        id: id,
        cipher: cipher,
      );
    } else if (resourceType != null && finder != null) {
      return _fhirDb.delete(
        resourceType: resourceType,
        finder: finder,
        cipher: cipher,
      );
    } else {
      throw const FormatException('Must have either: '
          '\n1) a resource with a resourceType'
          '\n2) a resourceType and an Id'
          '\n3) a resourceType, a specific field, and the value of interest');
    }
  }

  /// pass in a resourceType or a resource, and db will delete all resources of
  /// that type - Note: will NOT delete any _historical stores (must pass in
  /// _history as the type for this to happen)
  Future<bool> deleteSingleType({
    Stu3ResourceType? resourceType,
    Resource? resource,
    HiveCipher? cipher,
    String? pw,
  }) async {
    cipher ??= cipherFromKey(key: pw);
    if (resourceType != null || resource?.resourceType != null) {
      resourceType ??= resource?.resourceType;
      return _fhirDb.deleteSingleType(
        resourceType: resourceType!,
        cipher: cipher,
      );
    }
    return false;
  }

  Future<bool> clear({HiveCipher? cipher, String? pw}) async =>
      deleteAllResources(cipher: cipher ?? cipherFromKey(key: pw));

  /// Deletes all resources, including historical versions
  Future<bool> deleteAllResources({HiveCipher? cipher, String? pw}) async =>
      _fhirDb.deleteAllData(cipher ?? cipherFromKey(key: pw));

  /// ultimate search function, must pass in finder
  Future<List<Resource>> _search({
    required Stu3ResourceType resourceType,
    required bool Function(Map<String, dynamic>) finder,
    HiveCipher? cipher,
  }) async =>
      (await _fhirDb.search(
        resourceType: resourceType,
        finder: finder,
        cipher: cipher,
      ))
          .map((Map<String, dynamic> e) => Resource.fromJson(e))
          .toList();

  /// ************************************************************************
  /// All of the above has been for FHIR resources and data, below is if you
  /// need to store whatever else as well
  /// ************************************************************************
  Future<int> saveGeneral({
    required Object object,
    int? key,
    HiveCipher? cipher,
    String? pw,
  }) async =>
      _fhirDb.saveGeneral(
        object: object,
        key: key,
        cipher: cipher ?? cipherFromKey(key: pw),
      );

  Future<Object?> readGeneral({
    required int key,
    HiveCipher? cipher,
    String? pw,
  }) async =>
      _fhirDb.readGeneral(
        key: key,
        cipher: cipher ?? cipherFromKey(key: pw),
      );

  Future<Iterable<Object>> getAllGeneral({HiveCipher? cipher, String? pw}) async =>
      _fhirDb.getAllGeneral();

  Future<Iterable<Object>> searchGeneral({
    required bool Function(Object) finder,
    HiveCipher? cipher,
    String? pw,
  }) async =>
      _fhirDb.searchGeneral(
        finder: finder,
        cipher: cipher ?? cipherFromKey(key: pw),
      );

  /// Delete specific entry
  Future<bool> deleteFromGeneral({
    required int key,
    HiveCipher? cipher,
    String? pw,
  }) async =>
      _fhirDb.deletefromGeneral(
        key: key,
        cipher: cipher ?? cipherFromKey(key: pw),
      );

  Future<bool> clearGeneral({HiveCipher? cipher, String? pw}) =>
      _fhirDb.clearGeneral(cipher ?? cipherFromKey(key: pw));

  /// Deletes everything stored in the general store
  Future<bool> deleteAllGeneral({HiveCipher? cipher, String? pw}) async =>
      _fhirDb.clearGeneral(cipher ?? cipherFromKey(key: pw));

  /// ************************************************************************
  /// These methods are for closing boxes, usually not needed and mostly for
  /// debugging purposes
  /// ************************************************************************
  Future<void> closeAllBoxes() async => _fhirDb.closeAllBoxes();

  /// Specify a list of which boxes you want to close
  Future<void> closeResourceBoxes(List<Stu3ResourceType> types,
          {HiveCipher? cipher, String? pw}) async =>
      _fhirDb.closeResourceBoxes(types, cipher ?? cipherFromKey(key: pw));

  /// Close the general box
  Future<void> closeHistoryBox({HiveCipher? cipher, String? pw}) async =>
      _fhirDb.closeHistoryBox(cipher ?? cipherFromKey(key: pw));

  /// Close the general box
  Future<void> closeGeneralBox({HiveCipher? cipher, String? pw}) async =>
      _fhirDb.closeGeneralBox(cipher ?? cipherFromKey(key: pw));

  /// Close the types box
  Future<void> closeTypesBox({HiveCipher? cipher, String? pw}) async =>
  _fhirDb.closeTypesBox(cipher ?? cipherFromKey(key: pw));
}
