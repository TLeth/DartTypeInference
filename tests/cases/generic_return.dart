library tests.generic_return;

class A<T> {}
class B<E> {
  A<E> c = new A<E>();
}

A<int> f() {
  B<int> aa = new B<int>();
  A<int> bb = aa.c;
  return bb;
}

void main() {
  A<int> gg = f();
}
