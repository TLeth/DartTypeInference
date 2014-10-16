library tests.operator_arrayassign;

class A {
  void operator []=(int index, String str) {
    str;
  }
}
void main() {
  A h = new A();
  String b = h[3] = "test";
}
