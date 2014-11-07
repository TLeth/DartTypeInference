library test.generic_notype;

class A<T> {}
class B<T> {
  T d;
  B();
  B.Foo();
}

A a = new A();
B b = new B();
B c = new B.Foo();
