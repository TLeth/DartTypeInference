library test.generic_parentmethod;

class A<T> {
  T b() => null;
}

class B<R> extends A<int> {}

B<double> b = new B<double>();
int c = b.b();
