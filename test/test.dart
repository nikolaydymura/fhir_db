import 'dart:io';

import 'package:fhir_bulk/r4.dart';
import 'package:fhir_db/r4/fhir_db_dao.dart';

Future<void> main() async {
  /// Initialize Hive & Clear Current Hive DB
  final hiveDao = FhirDbDao();
  await hiveDao.init('.');
  await hiveDao.clear(null);
  var output = '';
  var dir = Directory('assets');
  final fileList = await dir.list().map((event) => event.path).toList();
  final startTime = DateTime.now();
  int total = 0;

  for (final file in fileList) {
    int i = 0;
    final resources = await FhirBulk.fromFile(file);
    for (final resource in resources) {
      if (resource != null) {
        i++;
        await hiveDao.save(null, resource);
      }
    }
    output += '$i ${resources.first?.resourceTypeString}s\n';
    total += i;
  }
  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);
  output += 'Total Resources: $total\n';
  output += 'Total time: ${duration.inSeconds} seconds\n';
  print(output);
}
