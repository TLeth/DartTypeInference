library test.getter_method;

class A {
  get x => 2;
}

main() {
  var a = new A();
  var y = a.x;
}
