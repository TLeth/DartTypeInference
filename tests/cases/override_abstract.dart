library tests.override_abstract;

abstract class A {
  int a;
  int foo();
}

class B extends A {
  int a = 3;
  int foo() => 3;
}

void main() {
}
