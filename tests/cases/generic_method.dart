library test.generic_method;

class A<T> {
  T b(T a) => a;
}

A<int> b = new A<int>();
int c = b.b(3);
