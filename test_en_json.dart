import 'dart:convert';
import 'dart:io';

void main() {
  final raw = File('assets/translations/en.json').readAsStringSync();
  final m = jsonDecode(raw);
  for (var entry in m.entries) {
    if (entry.value is! String) {
      print('Key ${entry.key} is not a string: ${entry.value.runtimeType}');
    }
  }
  print('Done checking en.json');
}
