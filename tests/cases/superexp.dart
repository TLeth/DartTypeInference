library test.superexp;

class A {
  int b;
  A() : b = 3;
}
class B extends A {
  int a;
  void test() {
    a = super.b;
  }
}
