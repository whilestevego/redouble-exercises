import 'dart:convert';
import 'dart:io';

typedef Json = Map<String, dynamic>;

Object? readJson(String path) => jsonDecode(File(path).readAsStringSync());

/// Two-space indent and a final newline, so a change shows as a small diff.
String encodeJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void writeJson(String path, Object? value) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(encodeJson(value));
}
