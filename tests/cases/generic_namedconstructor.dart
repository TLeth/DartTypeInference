library test.generic_namedconstructor;

class A<T> {
  T a;
  A.Foo(T this.a);
}

A<int> b = new A<int>.Foo(3);
