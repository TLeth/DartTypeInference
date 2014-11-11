library test.generic_factory;

class A<T> {
  A._internal();

  factory A.make() => new A._internal();
}

A<int> a = new A<int>.make();
