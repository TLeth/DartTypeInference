library tests.constructor_fieldinit;

class A {
  var a;
  var b;
  A()
      : a = 3,
        this.b = 4;
}
