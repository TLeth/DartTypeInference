library test.field_parent;
class A {
  var a;
  var b;
}

class B extends A {}
main() {
  var a = new B();
  a.a = "test";
  a.b = "test";
  a.b = 3;
  var b = a.a;
  var c = a.b;
}
