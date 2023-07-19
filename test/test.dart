// ignore_for_file: avoid_print

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fhir/r4.dart';
import 'package:fhir_bulk/r4.dart';
import 'package:fhir_db/r4/fhir_db_dao.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

import 'test_resources.dart';

Future<void> main() async {
  const String directory = 'db';
  await Directory(directory).delete(recursive: true);

  /// Initialize Hive & Clear Current Hive DB
  final FhirDbDao fhirDbDao = FhirDbDao();
  const String password1 = 'password1';
  const String password2 = 'password2';
  await fhirDbDao.init(null, directory);
  final Patient patient1 = Patient(fhirId: '1');
  final Resource saved1 = await fhirDbDao.save(password1, patient1);
  final List<Resource> search1 =
      await fhirDbDao.find(null, resourceType: R4ResourceType.Patient, id: '1');
  test('Saved A Patient, Found A Patient', () async {
    expect(saved1, search1[0]);
  });

  final List<Resource> search2 = await fhirDbDao.find(password1,
      resourceType: R4ResourceType.Patient, id: '1');
  test('Found Patient With New Password Because Box Was Already Opened',
      () async {
    expect(saved1, search2[0]);
  });
  await fhirDbDao.updatePw(null, password1);
  final List<Resource> search3 =
      await fhirDbDao.find(null, resourceType: R4ResourceType.Patient, id: '1');
  test('Changed', () async {
    expect(saved1, search1[0]);
  });

  // print(search1[0].toJson());
  // await fhirDbDao.clear(password1);
  // String output = '';
  // final Directory dir = Directory('assets');
  // final List<String> fileList =
  //     await dir.list().map((FileSystemEntity event) => event.path).toList();
  // int total = 0;
  // const int numberOfTimes = 1;
  // for (int i = 0; i < numberOfTimes; i++) {
  //   final DateTime startTime = DateTime.now();
  //   for (final String file in fileList) {
  //     print(file);
  //     int i = 0;
  //     final List<Resource> resources = await FhirBulk.fromFile(file);
  //     for (final Resource? resource in resources) {
  //       if (resource != null) {
  //         i++;
  //         await fhirDbDao.save(password1, resource);
  //       }
  //     }
  //     total += i;
  //   }
  //   final DateTime endTime = DateTime.now();
  //   final Duration duration = endTime.difference(startTime);
  //   output += 'Total Resources: $total\n';
  //   output += 'Total time: ${duration.inSeconds} seconds\n';
  // }
  // group('Playing with passwords', () {
  //   test('Playing with Passwords', () async {

  //     // print(saved.toJson());

  //     // await fhirDbDao.updatePw(null, password1);
  //     final List<Resource> search1 = await fhirDbDao.find(password1,
  //         resourceType: R4ResourceType.Patient, id: '1');

  //     print(search1[0].toJson());

  //     // await fhirDbDao.updatePw(password1, password2);
  //     // final List<Resource> search2 = await fhirDbDao.find(password2,
  //     //     resourceType: R4ResourceType.Patient, id: '1');
  //     // expect(saved, search2[0]);

  //     // await fhirDbDao.updatePw(password2, null);
  //     // final List<Resource> search3 = await fhirDbDao.find(null,
  //     //     resourceType: R4ResourceType.Patient, id: '1');
  //     // expect(saved, search3[0]);

  //     // await fhirDbDao.deleteAllResources(null);
  //   });
  // });
  // await fhirDbDao.save(password2, patient1);
  // await fhirDbDao.save(password2, patient2);
  // await fhirDbDao.save(password2, observation1);
  // await fhirDbDao.save(password2, observation2);
  // await fhirDbDao.save(password2, observation3);
  // await fhirDbDao.save(password2, observation4);
  // await fhirDbDao.save(password2, observation5);
  // await fhirDbDao.save(password2, observation6);
  // await fhirDbDao.save(password2, conceptMap1);
  // await fhirDbDao.save(password2, condition1);

  // print(output);
  // final DateTime testStartTime = DateTime.now();
  // print(await compareTwoResources(patient1, fhirDbDao, password2));
  // print(await compareTwoResources(patient2, fhirDbDao, password2));
  // print(await compareTwoResources(observation1, fhirDbDao, password2));
  // print(await compareTwoResources(observation2, fhirDbDao, password2));
  // print(await compareTwoResources(observation3, fhirDbDao, password2));
  // print(await compareTwoResources(observation4, fhirDbDao, password2));
  // print(await compareTwoResources(observation5, fhirDbDao, password2));
  // print(await compareTwoResources(observation6, fhirDbDao, password2));
  // print(await compareTwoResources(conceptMap1, fhirDbDao, password2));
  // print(await compareTwoResources(condition1, fhirDbDao, password2));
  // final DateTime testEndTime = DateTime.now();
  // print(
  //     'Found 10 resources in total of ${testEndTime.difference(testStartTime).inMilliseconds} ms');
  await Hive.close();
}

Future<bool> compareTwoResources(
    Resource originalResource, FhirDbDao fhirDbDao, String? pw) async {
  final Resource? dbResource = await fhirDbDao.get(
      pw, originalResource.resourceType!, originalResource.fhirId!);
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
