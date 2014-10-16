library tests.operator_arrayindex;

class A {
  operator [](index) {
    return "Str";
  }
}
main() {
  var h = new A();
  var a = h[3];
}
