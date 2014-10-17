library test.method_gettersetter;

class A {
  int _x;
  void set x(int _x) {
    this._x = _x;
  }
  int get x => _x;
}

void main() {
  A a = new A();
  a.x = 3;
  int y = a.x;
}
