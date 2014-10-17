library test.setter_staticmethod;

class A {
  static set x(_x) {}
}

main() {
  A.x = 3;
}
