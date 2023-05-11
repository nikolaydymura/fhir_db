// Package imports:
import 'package:fhir/r4.dart';
import 'package:sembast/sembast.dart';

// Project imports:
import 'sembast_db.dart';

class SembastDao {
  /// Private Constructor
  SembastDao._() {
    _fhirDb = SembastDb();
  }

  /// Singleton Accessor
  SembastDb get fhirDb => _fhirDb;

  /// The actual database
  late SembastDb _fhirDb;

  /// Singleton Instance
  static final SembastDao _provider = SembastDao._();

  /// Singleton Factory
  factory SembastDao() => _provider;

  /// Initalizes the database, configure its path, and return it
  Future<SembastDb> init(String? password, String path) async {
    await _fhirDb.initDb(password, path);
    return _fhirDb;
  }

  /// update database password
  Future updatePw(String? oldPassword, String? newPassword) async =>
      await fhirDb.updatePassword(oldPassword, newPassword);

  /// Saves a [Resource] to the local Db, [password] is optional (but after set,
  /// it must always be used everytime), will update the meta fields of the
  /// [Resource] and adds an id if none is already given.
  Future<Resource> save(String? password, Resource? resource) async {
    if (resource != null) {
      if (resource.resourceType != null) {
        return resource.id == null
            ? await _insert(password, resource)
            : await fhirDb.exists(null, resource.resourceType!, resource.id!)
                ? await _insert(password, resource)
                : await _update(password, resource);
      } else {
        throw const FormatException('ResourceType cannot be null');
      }
    } else {
      throw const FormatException('Resource to save cannot be null');
    }
  }

  /// function used to save a new resource in the db
  Future<Resource> _insert(String? password, Resource resource) async {
    final newResource = resource.updateVersion().newIdIfNoId();
    await fhirDb.save(password, resource);
    return newResource;
  }

  /// functions used to update a resource which has already been saved into the
  /// db, will also save the old version
  Future<Resource> _update(String? password, Resource resource) async {
    if (resource.resourceTypeString != null) {
      if (resource.id != null) {
        final dbResource =
            await fhirDb.get(password, resource.resourceType!, resource.id!);
        if (dbResource != null) {
          final oldResource = dbResource;
          await fhirDb.saveHistory(password, oldResource);
          final oldMeta = oldResource['meta'] == null
              ? null
              : FhirMeta.fromJson(oldResource['meta']);
          final newResource = resource.updateVersion(oldMeta: oldMeta);
          await fhirDb.save(password, newResource);
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

  /// searches for a specific [Resource]. That resource can be defined by
  /// passing a full [Resource] object, you may pass a [resourceType] and [id]
  /// or you can pass a search [field] - which can be nested, and the [value]
  /// you're looking for in that field
  /// From the sembast documentation:
  /// [https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/queries.md]
  /// Assuming you have the following record:
  /// {
  ///   "resourceType": "Immunization",
  ///   "patient": {
  ///     "reference": "Patient/12345"
  ///   }
  /// }
  /// You can search for the nested value using a [Finder]
  /// Finder(filter: Filter.equals('patient.reference', 'Patient/12345'));
  Future<List<Resource>> find(
    String? password, {
    Resource? resource,
    R4ResourceType? resourceType,
    String? id,
    String? field,
    String? value,
  }) async {
    if ((resource != null && resource.resourceType != null) ||
        (resourceType != null && id != null) ||
        (resourceType != null && field != null && value != null)) {
      Finder finder;
      if (resource != null) {
        finder = Finder(filter: Filter.equals('id', '${resource.id}'));
      } else if (resourceType != null && id != null) {
        finder = Finder(filter: Filter.equals('id', id));
      } else {
        finder = Finder(filter: Filter.equals(field!, value));
      }

      final type = resource?.resourceType ?? resourceType!;

      return await _search(password, type, finder);
    } else {
      throw const FormatException('Must have either: '
          '\n1) a resource with a resourceType'
          '\n2) a resourceType and an Id'
          '\n3) a resourceType, a specific field, and the value of interest');
    }
  }

  /// returns all resources of a specific type
  Future<List<Resource>> getAllResourcesByType(
    String? password, {
    List<R4ResourceType>? resourceTypes,
    List<String>? resourceTypeStrings,
    Resource? resource,
  }) async {
    final typeList = <R4ResourceType>{};
    if (resource?.resourceType != null) {
      typeList.add(resource!.resourceType!);
    }
    if (resourceTypes != null) {
      if (resourceTypes.isNotEmpty) {
        typeList.addAll(resourceTypes);
      }
    }
    if (resourceTypeStrings != null) {
      for (final type in resourceTypeStrings) {
        if (Resource.resourceTypeFromString(type) != null) {
          typeList.add(Resource.resourceTypeFromString(type)!);
        }
      }
    }

    final List<Resource> resourceList = [];
    for (final type in typeList) {
      final newResources =
          await _fhirDb.getActiveResourcesOfType(password, type);
      resourceList.addAll(newResources.map((e) => Resource.fromJson(e)));
    }
    return resourceList;
  }

  /// returns all resources in the [db], including historical versions
  Future<List<Resource>> getAllActiveResources(String? password) async =>
      (await _fhirDb.getAllActiveResources(password))
          .map((e) => Resource.fromJson(e))
          .toList();

  /// Delete specific resource
  Future<bool> delete(
    String? password,
    Resource? resource,
    R4ResourceType? resourceType,
    String? id,
    String? field,
    String? value,
    Finder? finder,
  ) async {
    if (resource != null &&
        resource.resourceType != null &&
        resource.id != null) {
      return await _fhirDb.deleteById(
          password, resource.resourceType!, resource.id!);
    } else if (resourceType != null && id != null) {
      return await _fhirDb.deleteById(password, resourceType, id);
    } else if (resourceType != null && finder != null) {
      finder = Finder(filter: Filter.equals(field!, value));
      return await _fhirDb.delete(password, resourceType, finder);
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
      return _fhirDb.deleteSingleType(password, resourceType!);
    }
    return false;
  }

  /// Deletes all resources, including historical versions
  Future<bool> deleteAllResources(String? password) async =>
      _fhirDb.deleteAllData(password);

  /// remove the resourceType from the list of types stored in the db
  Future<bool> removeResourceTypes(
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
    String? password,
    R4ResourceType resourceType,
    Finder finder,
  ) async =>
      (await _fhirDb.search(password, resourceType, finder))
          .map((e) => Resource.fromJson(e))
          .toList();
}
