library tests.constructor_supernamed;

class A {
  A.Test(c) {}
}

class B extends A {
  B(c) : super.Test(c);
}

main() {
  var a = new B("test");
}
