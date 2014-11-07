library test.generic_constructor;

class A<T> {
  T a;
  A(T this.a);
}

A<int> b = new A<int>(3);
