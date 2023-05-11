import 'dart:io';

import 'package:fhir/r4.dart';
import 'package:fhir_bulk/r4.dart';
import 'package:fhir_db/r4/fhir_db_dao.dart';

Future<void> main() async {
  /// Initialize Hive & Clear Current Hive DB
  final FhirDbDao hiveDao = FhirDbDao();
  await hiveDao.init('.');
  await hiveDao.clear(null);
  String output = '';
  final Directory dir = Directory('assets');
  final List<String> fileList =
      await dir.list().map((FileSystemEntity event) => event.path).toList();
  final DateTime startTime = DateTime.now();
  int total = 0;

  for (final String file in fileList) {
    int i = 0;
    final List<Resource?> resources = await FhirBulk.fromFile(file);
    for (final Resource? resource in resources) {
      if (resource != null) {
        i++;
        await hiveDao.save(null, resource);
      }
    }
    output += '$i ${resources.first?.resourceTypeString}s\n';
    total += i;
  }
  final DateTime endTime = DateTime.now();
  final Duration duration = endTime.difference(startTime);
  output += 'Total Resources: $total\n';
  output += 'Total time: ${duration.inSeconds} seconds\n';
  print(output);
}
