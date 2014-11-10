library test.generic_field;

class A<T> {
  T a;
  A(T a) {
    this.a = a;
  }
}

A<int> b = new A<int>(3);
int c = b.a;
