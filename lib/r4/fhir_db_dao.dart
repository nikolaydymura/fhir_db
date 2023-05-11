// Dart imports:
import 'dart:async';

import 'package:fhir/r4.dart';

import 'fhir_db.dart';

class FhirDbDao {
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

  /// Singleton factory
  factory FhirDbDao() => _fhirFhirDbDao;

  /// Initalizes the database, configure its path, and return it
  Future<FhirDb> init(String path) async {
    await _fhirDb.initDb(path);
    return _fhirDb;
  }

  /// Saves a [Resource] to the local Db, [password] is optional (but after set,
  /// it must always be used everytime), will update the FhirFhirFhirMeta fields
  /// of the [Resource] and adds an id if none is already given.
  Future<Resource> save(String? password, Resource? resource) async {
    if (resource != null) {
      if (resource.resourceType != null) {
        return resource.id == null
            ? await _insert(password, resource)
            : await fhirDb.exists(resource.resourceType!, resource.id!)
                ? await _update(password, resource)
                : await _insert(password, resource);
      } else {
        throw const FormatException('ResourceType cannot be null');
      }
    } else {
      throw const FormatException('Resource to save cannot be null');
    }
  }

  /// This version of save is only designed to be used to bulk upload an amount
  /// of data/resources that haven't been uploaded yet. Unlike normal saving,
  /// this method does not check if the resource is already in the database,
  /// and will therefore overwrite it if it is
  Future<bool> bulkSave(String? password, List<Resource> resources) async {
    final resourceMap =
        <R4ResourceType, Set<Map<String, Map<String, dynamic>>>>{};

    resources.forEach((resource) {
      if (resource.resourceType != null) {
        if (!resourceMap.keys.contains(resource.resourceType)) {
          resourceMap[resource.resourceType!] = {};
        }
        if (resource.id == null) {
          final newResource = resource.newId();
          resourceMap[resource.resourceType!]!
              .add(<String, Map<String, dynamic>>{
            newResource.id!: newResource.toJson()
          });
        } else {
          resourceMap[resource.resourceType!]!.add(
              <String, Map<String, dynamic>>{resource.id!: resource.toJson()});
        }
      }
    });
    return _fhirDb.bulkSave(resourceMap);
  }

  /// function used to save a new resource in the db
  Future<Resource> _insert(String? password, Resource resource) async {
    final newResource = resource.updateVersion().newIdIfNoId();
    await _fhirDb.save(newResource);
    return newResource;
  }

  /// functions used to update a resource which has already been saved into the
  /// db, will also save the old version
  Future<Resource> _update(String? password, Resource resource) async {
    if (resource.resourceTypeString != null) {
      if (resource.id != null) {
        final dbResource =
            await _fhirDb.get(resource.resourceType!, resource.id!);
        if (dbResource != null) {
          final oldResource = dbResource;
          await _fhirDb.saveHistory(oldResource);
          final oldMeta = oldResource['meta'] == null
              ? null
              : FhirMeta.fromJson(oldResource['meta']);
          final newResource = resource.updateVersion(oldMeta: oldMeta);
          await _fhirDb.save(newResource);
          return newResource;
        } else {
          return _insert(password, resource);
        }
      } else {
        return _insert(password, resource);
      }
    } else {
      throw const FormatException('Resource passed must have a resourceType');
    }
  }

  /// function used to save a new resource in the db
  Future<Resource?> get(
      String? password, R4ResourceType resourceType, String id) async {
    final resourceMap = await _fhirDb.get(resourceType, id);
    return resourceMap == null ? null : Resource.fromJson(resourceMap);
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
  ///
  Future<List<Resource>> find(
    String? password, {
    Resource? resource,
    R4ResourceType? resourceType,
    String? id,
    List? field,
    String? value,
  }) async {
    /// if we're just trying to match a resource
    if (resource != null &&
        resource.resourceType != null &&
        (resource.id != null || id != null)) {
      final newResource =
          await fhirDb.get(resource.resourceType!, resource.id!);
      return newResource == null ? [] : [Resource.fromJson(newResource)];
    } else if (resourceType != null && id != null) {
      final newResource = await fhirDb.get(resourceType, id);
      return newResource == null ? [] : [Resource.fromJson(newResource)];
    } else if (resourceType != null && field != null && value != null) {
      bool Function(Map<String, dynamic>) finder =
          (Map<String, dynamic> finderResource) {
        dynamic result = finderResource;
        for (final key in field) {
          result = result[key];
        }
        return result.toString() == value;
      };
      return _search(resourceType, finder);
    } else {
      throw const FormatException('Must have either: '
          '\n1) a resource with a resourceType'
          '\n2) a resourceType and an Id'
          '\n3) a resourceType, a specific field, and the value of interest');
    }
  }

  /// returns all resources of a specific type
  Future<List<Resource>> getActiveResourcesOfType(
    String? password, {
    List<R4ResourceType>? resourceTypes,
    List<String>? resourceTypeStrings,
    Resource? resource,
  }) async {
    final typeList = <R4ResourceType>{};
    if (resource?.resourceType != null) {
      typeList.add(resource!.resourceType!);
    }
    if (resourceTypes != null && resourceTypes.isNotEmpty) {
      typeList.addAll(resourceTypes);
    }
    if (resourceTypeStrings != null) {
      for (final type in resourceTypeStrings) {
        final resourceType = resourceTypeFromStringMap[type];
        if (resourceType != null) {
          typeList.add(resourceType);
        }
      }
    }

    final List<Resource> resourceList = [];
    for (final type in typeList) {
      final newResources = await _fhirDb.getActiveResourcesOfType(type);
      resourceList.addAll(newResources.map((e) => Resource.fromJson(e)));
    }
    return resourceList;
  }

  /// returns all resources in the [db], including historical versions
  Future<List<Resource>> getAllActiveResources(String? password) async =>
      (await _fhirDb.getAllActiveResources())
          .map((e) => Resource.fromJson(e))
          .toList();

  /// Delete specific resource
  Future<bool> delete(
    String? password,
    Resource? resource,
    R4ResourceType? resourceType,
    String? id,
    bool Function(Map<String, dynamic>)? finder,
  ) async {
    if (resource != null &&
        resource.resourceType != null &&
        resource.id != null) {
      return await _fhirDb.deleteById(resource.resourceType!, resource.id!);
    } else if (resourceType != null && id != null) {
      return await _fhirDb.deleteById(resourceType, id);
    } else if (resourceType != null && finder != null) {
      return _fhirDb.delete(resourceType, finder);
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
  Future<bool> deleteSingleType(
    String? password, {
    R4ResourceType? resourceType,
    Resource? resource,
  }) async {
    if (resourceType != null || resource?.resourceType != null) {
      resourceType ??= resource?.resourceType;
      return _fhirDb.deleteSingleType(resourceType!);
    }
    return false;
  }

  Future<bool> clear(String? password) async => deleteAllResources(password);

  /// Deletes all resources, including historical versions
  Future<bool> deleteAllResources(String? password) async =>
      _fhirDb.deleteAllData(password);

  /// remove the resourceType from the list of types stored in the db
  Future<bool> _removeResourceType(
    String? password,
    List<R4ResourceType> types,
  ) async {
    for (final type in types) {
      final deleted = await deleteSingleType(password, resourceType: type);
      if (!deleted) {
        return false;
      }
    }
    return true;
  }

  /// ultimate search function, must pass in finder
  Future<List<Resource>> _search(
    R4ResourceType resourceType,
    bool Function(Map<String, dynamic>) finder,
  ) async =>
      (await _fhirDb.search(resourceType, finder))
          .map((e) => Resource.fromJson(e))
          .toList();

  /// ************************************************************************
  /// All of the above has been for FHIR resources and data, below is if you
  /// need to store whatever else as well
  /// ************************************************************************
  Future<int> saveGeneral(
    String? password,
    Object object,
    int? key,
  ) async =>
      _fhirDb.saveGeneral(password, object, key);

  Future<Object?> readGeneral({String? password, required int key}) async =>
      _fhirDb.readGeneral(key);

  Future<Iterable<Object>> getAllGeneral({String? password}) async =>
      _fhirDb.getAllGeneral();

  /// Delete specific entry
  Future deleteFromGeneral(String password, int key) async =>
      _fhirDb.deletefromGeneral(password, key);

  /// Deletes everything stored in the general store
  Future deleteAllGeneral(String? password) async =>
      _fhirDb.clearGeneral(password);

  /// Find specific entry
  // Future findGeneral(String? password, String key) async =>
  //     await _fhirDb.record(key).get(await _db(password));
}
