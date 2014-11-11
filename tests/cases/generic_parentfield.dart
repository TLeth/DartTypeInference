library test.generic_parentfield;

class A<T> {
  T b;
}

class B<R> extends A<R> {}

B<double> b = new B<double>();
double c = b.b;
