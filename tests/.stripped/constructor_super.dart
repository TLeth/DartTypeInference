library tests.constructor_super;

class A {
  A(c) {}
}

class B extends A {
  B(c) : super(c);
}

main() {
  var a = new B("test");
}
