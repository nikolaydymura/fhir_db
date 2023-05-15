import 'dart:convert';

import 'package:hive/hive.dart';

/// Generates a new secure key from a string (password) you pass in, otherwise,
/// generates a completely new one that you will need to store
List<int> generateSecureKey({String? key}) =>
    key != null ? base64Url.decode(key) : Hive.generateSecureKey();

/// Generates the cipher directly from a key (password)
HiveAesCipher cipherFromKey(String key) =>
    cipherFromSecureKey(base64Url.decode(key));

/// Accepts a List<int> as input and provides the HiveAesCipher (256 bit)
HiveAesCipher cipherFromSecureKey(List<int> key) => HiveAesCipher(key);
