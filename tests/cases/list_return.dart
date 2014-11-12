library test.list_return;


List<bool> f() {
  List<bool> a = new List<bool>(256);
  return a;
}

void main() {
  List<bool> a = f();
}
