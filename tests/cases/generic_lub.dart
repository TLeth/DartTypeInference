library test.generic_lub;
class A<R, T> {}

class B<R, T> extends A<R, int> {}

void main() {
  List<num> a = new List<int>();
  a = new List<double>();
  List b = new List<int>();
  b = new List<String>();

  A<dynamic, num> c = new A<int, num>();
  c = new B<String, num>();
}
