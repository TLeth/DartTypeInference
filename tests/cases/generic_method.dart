library test.generic_method;

class A<T> {
  T b() => null;
}

A<int> b = new A<int>();
int c = b.b();
