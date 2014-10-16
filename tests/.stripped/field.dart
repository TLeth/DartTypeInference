library test.field;

class A {
  var a;
  var b;
}
main() {
  var a = new A();
  a.a = "test";
  a.b = "test";
  a.b = 3;
  var b = a.a;
  var c = a.b;
}
