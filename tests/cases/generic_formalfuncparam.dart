library tests.generic_formalfuncparam;

class A<T> {
  void foo(dynamic f(T a)) => print("test");
}

void main(){
  A<int> a = new A<int>();
  a.foo((int a) => print("test"));
}