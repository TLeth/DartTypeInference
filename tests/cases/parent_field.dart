library tests.parent_field;

class A {
  int f = 3;
}

class B extends A {
  int g;

  B() {
    g = f;
  }
}
