library test.setter_staticmethod;

class A {
  static void set x(dynamic _x) {}
}

void main() {
  A.x = 3;
}
