library tests.named_constructor;

class A {
  A.Test(c);
}

main() {
  var a = new A.Test("test");
}
