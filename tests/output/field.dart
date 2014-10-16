library test.field;

class A {
  String a;
  dynamic b;
}
void main() {
  A a = new A();
  a.a = "test";
  a.b = "test";
  a.b = 3;
  String b = a.a;
  dynamic c = a.b;
}
