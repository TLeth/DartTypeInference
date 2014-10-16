library tests.constructor_redirect;

class A {
  A(b);

  A.Test() : this(3);
}
