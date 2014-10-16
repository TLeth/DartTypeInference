library tests.methods;

class A {
  static a(b) => b;
  b(c) {
    if (1 > 2) return c; else return 2;
  }
}
class B extends A {
  static c(d) {
    if (1 > 2) return "test"; else return 3;
  }
  d(g) => g;
  e(g) => "String";
}
main() {
  var b = new B();
  var c = B.c("test");
  var d = b.d(2);
  var e = b.d("test");
  var f = b.e(3.0);
  var g = b.e(2);

  var h = A.a("test");
  var i = b.b("test");
}
