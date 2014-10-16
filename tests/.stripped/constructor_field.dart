library tests.constructor_field;

class A {
  var c;
  A(this.c);
}

main() {
  var a = new A("test");
}
