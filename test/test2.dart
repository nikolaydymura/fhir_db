import 'package:fhir_db/r4/utils.dart';
import 'package:hive/hive.dart';

Future<void> main() async {
  const String pw = 'password';
  final HiveAesCipher? cipher = cipherFromKey(key: pw);
  Hive.init('db');
  // final Box<String> box1 =
  //     await Hive.openBox<String>('box', encryptionCipher: cipher);
  // await box1.put('a', '1');
  // await box1.close();
  final Box<String> box2 =
      await Hive.openBox<String>('box', encryptionCipher: cipher);
  final String? response = box2.get('a');
  print(response);
}
