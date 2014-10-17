library test.setter_method;

class A {
  set x(_x) {}
}

main() {
  var a = new A();
  a.x = 3;
}
