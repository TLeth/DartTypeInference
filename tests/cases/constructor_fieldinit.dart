library tests.constructor_fieldinit;

class A {
  int a;
  int b;
  A()
      : a = 3,
        this.b = 4;
}
