// ignore_for_file: avoid_print

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fhir/r4.dart';
import 'package:fhir_bulk/r4.dart';
import 'package:fhir_db/r4/fhir_db_dao.dart';
import 'package:hive/hive.dart';

import 'test_resources.dart';

Future<void> main() async {
  final String file = await File('key.txt').readAsString();
  final List<int> key =
      file.split(',').map((e) => int.parse(e.trim())).toList();
  final HiveAesCipher cipher = HiveAesCipher(key);

  /// Initialize Hive & Clear Current Hive DB
  final FhirDbDao hiveDao = FhirDbDao();
  await hiveDao.init(path: 'db');
  await hiveDao.clear();
  String output = '';
  final Directory dir = Directory('assets');
  final List<String> fileList =
      await dir.list().map((FileSystemEntity event) => event.path).toList();
  int total = 0;
  const int numberOfTimes = 1;
  for (int i = 0; i < numberOfTimes; i++) {
    final DateTime startTime = DateTime.now();
    for (final String file in fileList) {
      print(file);
      int i = 0;
      final List<Resource> resources = await FhirBulk.fromFile(file);
      for (final Resource? resource in resources) {
        if (resource != null) {
          i++;
          await hiveDao.save(resource: resource, cipher: cipher);
        }
      }
      total += i;
    }
    final DateTime endTime = DateTime.now();
    final Duration duration = endTime.difference(startTime);
    output += 'Total Resources: $total\n';
    output += 'Total time: ${duration.inSeconds} seconds\n';
  }

  print(output);
  final DateTime testStartTime = DateTime.now();
  print(await compareTwoResources(patient1, hiveDao, cipher));
  print(await compareTwoResources(patient2, hiveDao, cipher));
  print(await compareTwoResources(observation1, hiveDao, cipher));
  print(await compareTwoResources(observation2, hiveDao, cipher));
  print(await compareTwoResources(observation3, hiveDao, cipher));
  print(await compareTwoResources(observation4, hiveDao, cipher));
  print(await compareTwoResources(observation5, hiveDao, cipher));
  print(await compareTwoResources(observation6, hiveDao, cipher));
  print(await compareTwoResources(conceptMap1, hiveDao, cipher));
  print(await compareTwoResources(condition1, hiveDao, cipher));
  final DateTime testEndTime = DateTime.now();
  print(
      'Found 10 resources in total of ${testEndTime.difference(testStartTime).inMilliseconds} ms');
  await Hive.close();
}

Future<bool> compareTwoResources(
    Resource originalResource, FhirDbDao hiveDao, HiveCipher cipher) async {
  final Resource? dbResource = await hiveDao.get(
      resourceType: originalResource.resourceType!,
      id: originalResource.fhirId!,
      cipher: cipher);
  final Map<String, dynamic> resource1Json = originalResource.toJson();
  final Map<String, dynamic>? resource2json = dbResource?.toJson();
  if (!(const DeepCollectionEquality()).equals(resource1Json, resource2json)) {
    return false;
  }
  if (!(const DeepCollectionEquality()).equals(resource2json, resource1Json)) {
    return false;
  }
  return true;
}
