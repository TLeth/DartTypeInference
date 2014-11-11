library test.generic_field2;

class A<T> {
  T a;
  A(T this.a);
}

A<int> b = new A<int>(3);
int c = b.a;
