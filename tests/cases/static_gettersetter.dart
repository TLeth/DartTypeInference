library test.static_gettersetter;

class A {
  static int _x;
  static void set x(int _x) {
    A._x = _x;
  }
  static int get x => _x;
}

void main() {
  A.x = 3;
  int y = A.x;
}
