library tests.classes;

class A {
  dynamic c;

  String a = "test";

  A(dynamic this.c);
}

class B extends A {
  String d;
  String b = "test";

  B(int c, String d) : super(c);
}

void main() {
  A a = new A("test");
  String b = a.a;
  B c = new B(3, "test");
  String d = c.b;
  a = c;
}


