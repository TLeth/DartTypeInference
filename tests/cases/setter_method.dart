library test.setter_method;

class A {
  void set x(int _x) {}  
}

void main() {
  A a = new A();
  a.x = 3;
}
