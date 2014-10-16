library tests.operator_arrayassign;

class A {
  operator []=(index, str) {
    str;
  }
}
main() {
  var h = new A();
  var b = h[3] = "test";
}
