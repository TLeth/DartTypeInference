library test.generic_multi;

class A<T, R> {}
class B<T, R> {
  T d;
  B();
  B.Foo();
}

A<int, double> a = new A<int, double>();
B<int, double> b = new B<int, double>();
B<int, double> c = new B<int, double>.Foo();
