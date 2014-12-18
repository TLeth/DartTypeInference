library tests.restrict_getters;

class A {
  int RESTRICTGETTER = 4;
}

abstract class C {
  A get a;

  void b() {
    a.RESTRICTGETTER;
  }
}
