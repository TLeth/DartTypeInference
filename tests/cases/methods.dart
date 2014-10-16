library tests.methods;

class A {
  static String a(String b) => b;
  dynamic b(String c) {
    if (1 > 2) return c; else return 2;
  }
}
class B extends A {
  static dynamic c(String d) {
    if (1 > 2) return "test"; else return 3;
  }
  dynamic d(dynamic g) => g;
  String e(num g) => "String";
}
void main() {
  B b = new B();
  dynamic c = B.c("test");
  dynamic d = b.d(2);
  dynamic e = b.d("test");
  String f = b.e(3.0);
  String g = b.e(2);

  String h = A.a("test");
  dynamic i = b.b("test");
}
