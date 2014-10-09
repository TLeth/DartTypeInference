class A {
  String operator [](int index) {
    return "Str";
  }
}

void main() {
  A h = new A();
  String a = h[3];
}
