library tests.future_then;

import 'dart:async';

Future<int> f() {
  Completer<int> c = new Completer<int>();
  Future<int> f = c.future;
  return f;
}

void main() {
  Future<int> a = f();
  a.then((int i) => print('hej'));
}
