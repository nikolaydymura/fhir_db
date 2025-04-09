import 'dart:async';

abstract class HistoryRecorder {
  FutureOr<bool> saveRecord({
    required Map<String, dynamic> resource,
    String? pw,
  });
}

class NoHistoryRecorder extends HistoryRecorder {
  factory NoHistoryRecorder() => _instance;

  NoHistoryRecorder._();

  static final NoHistoryRecorder _instance = NoHistoryRecorder._();

  @override
  FutureOr<bool> saveRecord({
    required Map<String, dynamic> resource,
    String? pw,
  }) =>
      false;
}
