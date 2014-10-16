library tests.named_constructor;

class A {
  A.Test(String c);
}

void main() {
  A a = new A.Test("test");
}
