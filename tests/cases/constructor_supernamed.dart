library tests.constructor_supernamed;

class A {
  A.Test(String c) {}
}

class B extends A {
  B(String c) : super.Test(c);
}

void main() {
  B a = new B("test");
}
