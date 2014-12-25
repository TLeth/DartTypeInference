library test.settervoid;

int _foo;
void set foo(int x) => (_foo = x as dynamic);
int get foo => _foo;

void bar() {
  foo = 3;
}
