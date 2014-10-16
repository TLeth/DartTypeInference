library tests.factory;

class A {
  A();
  factory A.Test(String c) => new A();
}

void main() {
  A a = new A.Test("test");
}
