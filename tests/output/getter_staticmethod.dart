library test.getter_staticmethod;

class A {
  static int get x => 2;
}

void main() {
  int y = A.x;
}
