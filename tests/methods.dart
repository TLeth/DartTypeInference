library tests.methods;

class A {
  static String a(String b) => b;
  dynamic b(String c) {
    if (1 > 2) return b; else return 2;
  }
}
class B extends A {
  static dynamic c(String d) {
    if (1 > 2) return "test"; else return 3;
  }
  dynamic d(dynamic g) => g;
  String e(num g) => "String";
}
void main(){
  B b = new B();
  B.c("test");
  b.d(2);
  b.d("test");
  b.e(3.0);
  b.e(2);
  
  A.a("test");
  b.b("test");
}