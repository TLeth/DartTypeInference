library test.static_field;

class A {
  static String a;
  static dynamic b;
}
void main() {
  A.a = "test";
  A.b = "test";
  A.b = 3;
  String b = A.a;
  dynamic c = A.b;
}
