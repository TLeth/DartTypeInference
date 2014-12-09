library tests.mixin_method;

class Mixin {
  int foo() => 3;
}

class A extends Object with Mixin {}

void bar() {
  A a = new A();
  int b = a.foo();
}
