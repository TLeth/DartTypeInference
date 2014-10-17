library test.setter_method;

class A {
  void set x(dynamic _x) {}
}

void main() {
  A a = new A();
  a.x = 3;
}
