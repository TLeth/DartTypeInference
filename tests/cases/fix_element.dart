library tests.fix_element;

import 'dart:html';

void foo() {
  dynamic a = querySelector("...");
  String b = a.src;
}
