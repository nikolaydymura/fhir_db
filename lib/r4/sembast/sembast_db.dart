// Dart imports:
import 'dart:async';
import 'dart:developer';
import 'dart:io';

// Package imports:
import 'package:fhir/r4.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/utils/sembast_import_export.dart';

// Project imports:
// import '../../encrypt/aes.dart';
import '../../encrypt/salsa.dart';

class SembastDb {
  bool _initialized = false;
  Set<R4ResourceType> _types = {};
  final _typesStore = StoreRef<String, List>.main();
  late StoreRef<String, Map<String, dynamic>> _resourceStore;
  late Database _db;
  late String _path;

  /// Database Factory
  DatabaseFactory _dbFactory = databaseFactoryIo;
  // getDatabaseFactorySqflite(sqflite.databaseFactory);

  /// To initialize the database as a whole. Configure the path, set initialized
  /// to true, create the typeStore and load the types if needed
  Future<void> initDb(String? password, path) async {
    /// Get the actual db
    _path = join(path, 'fhir.db');
    ;
    _db = await _getDb(password);
    _initialized = true;
    final oldTypes = await _typesStore.record('resourceTypes').get(_db);
    if (oldTypes == null) {
      await _typesStore.record('resourceTypes').add(_db, []);
    } else {
      final resourceTypes =
          oldTypes.map((e) => Resource.resourceTypeFromString(e));
      resourceTypes.forEach((element) {
        if (element != null) {
          _types.add(element);
        }
      });
    }
  }

  /// Convenience getter to ensure initialized
  Future<void> _ensureInit(String? password, String? path) async {
    if (!_initialized) {
      await initDb(password, path ?? '.');
    }
  }

  /// This is to get a specific Store
  Future<StoreRef<String, Map<String, dynamic>>> _getStore(
    String? password,
    R4ResourceType resourceType,
  ) async {
    await _ensureInit(password, null);
    final resourceTypeString = Resource.resourceTypeToString(resourceType);
    return stringMapStoreFactory.store(resourceTypeString);
  }

  /// This is to get a specific Store
  Future<StoreRef<String, Map<String, dynamic>>> _getHistoryStore(
    String? password,
    String resourceType,
  ) async {
    await _ensureInit(password, null);
    return stringMapStoreFactory.store('${resourceType}History');
  }

  /// In this case we're adding a type. If it's already included, we just
  /// return true and don't re-add it. Otherwise we enseure db is initialized,
  /// and after we can assume the 'types' box is open, get the Set, update
  /// it, write it back, and return true.
  Future<bool> _addType(String? password, R4ResourceType resourceType) async {
    try {
      if (_types.contains(resourceType)) {
        return true;
      } else {
        await _ensureInit(password, null);
        _types.add(resourceType);
        await _typesStore.record('resourceTypes').put(
            _db, _types.map((e) => Resource.resourceTypeToString(e)).toList());
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> save(String? password, Resource resource) async {
    try {
      await _ensureInit(password, null);
      final store = await _getStore(password, resource.resourceType!);
      store.record(resource.id!).put(_db, resource.toJson());
      return await _addType(password, resource.resourceType!);
    } catch (e, s) {
      log('Error: $e, Stack at time of Error: $s');
      return false;
    }
  }

  // TODO(Dokotela): saveAll - list of Resources

  Future<bool> exists(
      String? password, R4ResourceType resourceType, String id) async {
    if (!_types.contains(resourceType)) {
      return false;
    } else {
      await _ensureInit(password, null);
      final store = await _getStore(password, resourceType);
      return store.record(id).exists(_db);
    }
  }

  Future<Map<String, dynamic>?> get(
      String? password, R4ResourceType resourceType, String id) async {
    await _ensureInit(password, null);
    final store = await _getStore(password, resourceType);
    final resourceMap = (await store.record(id).get(_db));
    return resourceMap;
  }

  Future<Iterable<Map<String, dynamic>>> getActiveResourcesOfType(
    String? password,
    R4ResourceType resourceType,
  ) async {
    await _ensureInit;
    final finder = Finder(sortOrders: [SortOrder('id')]);
    return await search(password, resourceType, finder);
  }

  Future<Iterable<Map<String, dynamic>>> getAllActiveResources(
    String? password,
  ) async {
    final allResources = <Map<String, dynamic>>[];
    for (final type in _types) {
      allResources.addAll(await getActiveResourcesOfType(password, type));
    }
    return allResources;
  }

  Future<bool> saveHistory(
      String? password, Map<String, dynamic> resource) async {
    try {
      await _ensureInit;
      final store = await _getHistoryStore(password, resource['resourceType']);
      await store
          .record(
              '${resource["resourceType"]}/${resource["id"]}/${resource["meta"]?["versionId"]}')
          .put(_db, resource);
      return true;
    } catch (e, s) {
      log('Error: $e, Stack at time of Error: $s');
      return false;
    }
  }

  Future<bool> deleteById(
      String? password, R4ResourceType resourceType, String id) async {
    try {
      final store = await _getStore(password, resourceType);
      return (await store.record(id).delete(_db)) == null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(
    String? password,
    R4ResourceType resourceType,
    Finder finder,
  ) async {
    try {
      final store = await _getStore(password, resourceType);
      await store.delete(_db, finder: finder);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSingleType(
      String? password, R4ResourceType resourceType) async {
    try {
      final store = await _getStore(password, resourceType);
      await store.drop(_db);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// This will leave the datbase intact, but delete all of the data
  Future<bool> deleteAllData(String? password) async {
    try {
      for (final type in _types) {
        final store = await _getStore(password, type);
        await store.delete(_db);
        final historyStore = await _getHistoryStore(
            password, Resource.resourceTypeToString(type));
        await historyStore.delete(_db);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteDatabase(String password) async {
    await _db.close();
    await File(_path).delete();
  }

  /// ultimate search function, must pass in finder
  Future<Iterable<Map<String, dynamic>>> search(
    String? password,
    R4ResourceType resourceType,
    Finder finder,
  ) async {
    final recordSnapshots = await _resourceStore.find(_db, finder: finder);
    return recordSnapshots.map((snapshot) => snapshot.value);
  }

  Future<Database> _getDb(String? password) async {
    /// check if there is a codec and password
    final codec = password == null ? null : _codec(password);

    /// if there is, use it to open the Db
    return codec == null
        ? await _dbFactory.openDatabase(_path)
        : await _dbFactory.openDatabase(_path, codec: codec);
  }

  /// This is just for getting the codec, I've decided to default to Salsa20
  /// for no good reason, but just change it back if you prefer AES
  SembastCodec? _codec(String? password) => password == null || password == ''
      ? null
      : getEncryptSembastCodecSalsa20(password: password);
  // getEncryptSembastCodecAES(password: password);

  Future updatePassword(String? oldpassword, String? newpassword) async {
    /// Create the map of the old Db
    final exportMap = await exportDatabase(_db);

    /// Close old Db
    await _db.close();

    /// Create a copy of the old db - in case something messes up while we're
    /// changing to the new password
    final tempPath = _path.replaceAll('fhir.db', 'old_fhir.db');
    await File(_path).copy(tempPath);

    /// Create the new Db with the new password and codec
    _db = await importDatabase(
      exportMap,
      _dbFactory,
      _path,
      codec: _codec(newpassword),
    );

    /// Delete the old Db after the Db has successfully updated
    await File(tempPath).delete();
  }
}
