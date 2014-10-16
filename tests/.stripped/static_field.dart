library test.static_field;

class A {
  static var a;
  static var b;
}
main() {
  A.a = "test";
  A.b = "test";
  A.b = 3;
  var b = A.a;
  var c = A.b;
}
