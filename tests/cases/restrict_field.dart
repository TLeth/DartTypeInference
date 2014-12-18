library tests.restrict_field;

class A {
  int RESTRICTFIELD = 4;
}

abstract class C {
  A a;
  A c;

  void b() {
    a.RESTRICTFIELD;
    this.c.RESTRICTFIELD;
  }
}
