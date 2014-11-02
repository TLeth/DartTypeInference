library tests.functype_merg;

String foo(num a(num b)) => "Test";

void main() {
  Function a = (int a) => a;
  a(3);
  Function b = (double b) => b;
  b(3.0);
  foo(a);
  foo(b);
}
