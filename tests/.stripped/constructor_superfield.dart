library tests.constructor_superfield;

class A {
  var c;

  A(this.c);
}

class B extends A {
  B(c) : super(c);
}

main() {
  var a = new B("test");
}
