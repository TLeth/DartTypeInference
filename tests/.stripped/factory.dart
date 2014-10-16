library tests.factory;

class A {
  A();
  factory A.Test(c) => new A();
}

main() {
  var a = new A.Test("test");
}
