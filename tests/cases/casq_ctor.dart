library tests.casq_ctor;

class Foo {
  void change() => print('Foo');
}

void main() {
  Foo f = new Foo()..change();
}
