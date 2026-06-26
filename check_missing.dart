import 'dart:io';
import 'dart:convert';

void main() {
  final en = jsonDecode(File('assets/translations/en.json').readAsStringSync());
  final other = jsonDecode(File('assets/translations/zh.json').readAsStringSync());
  final missing = en.keys.where((k) => !other.containsKey(k)).toList();
  for (var k in missing) {
    print(k + ': ' + en[k].toString());
  }
}
