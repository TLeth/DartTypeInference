library tests.constructor_redirectnamed;

class A {
  A() : this.Test(3);

  A.Test(int b);
}
