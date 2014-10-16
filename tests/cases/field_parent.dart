library test.field_parent;
class A {
  String a;
  dynamic b;
}

class B extends A {}
void main() {
  B a = new B();
  a.a = "test";
  a.b = "test";
  a.b = 3;
  String b = a.a;
  dynamic c = a.b;
}
