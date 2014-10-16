library tests.constructor_redirect;

class A {
  A(int b);

  A.Test() : this(3);
}
