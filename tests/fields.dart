library tests.fields;

class A {
  String a;
  static String b;
  dynamic c;
  static dynamic d;
}
void main() {
  A a = new A();
  a.a = "test";
  A.b = "test";
  a.c = "test";
  a.c = 3;
  A.d = "test";
  A.d = 3;
}

