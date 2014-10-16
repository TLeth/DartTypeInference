library tests.constructor_superfield;

class A {
  String c;
  
  A(String this.c);
}

class B extends A {
  B(String c) : super(c);
}

void main() {
  B a = new B("test");
}