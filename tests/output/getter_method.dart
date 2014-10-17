library test.getter_method;

class A {
  int get x => 2;
}

void main() {
  A a = new A();
  int y = a.x;
}
