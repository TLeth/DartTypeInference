library tests.constructor_field;

class A {
  String c;
  A(String this.c);
}

void main() {
  A a = new A("test");
}
