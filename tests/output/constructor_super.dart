library tests.constructor_super;

class A {
  A(String c) {}
}

class B extends A {
  B(String c) : super(c);
}

void main() {
  B a = new B("test");
}
