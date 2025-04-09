import 'dart:async';

import 'package:fhir/r4/resource/resource.dart';
import 'package:hive/hive.dart';

abstract class BoxLoader {
  FutureOr<BoxBase<E>> loadBox<E>({
    required R4ResourceType resourceType,
    String? pw,
  });

  FutureOr<Iterable<E>> loadAll<E>({
    required R4ResourceType resourceType,
    String? pw,
  });
}
