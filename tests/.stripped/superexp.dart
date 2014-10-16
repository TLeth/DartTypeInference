library test.superexp;

class A {
  var b;
  A() : b = 3;
}
class B extends A {
  var a;
  test() {
    a = super.b;
  }
}
