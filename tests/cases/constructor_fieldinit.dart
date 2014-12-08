library tests.constructor_fieldinit;

class A {
  int a;
  int b;
  int c;
  A(int c)
      : a = 3,
        this.b = 4,
        this.c = c;
}

void main() {
  A aa = new A(3);
}
