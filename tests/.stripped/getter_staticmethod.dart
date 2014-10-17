library test.getter_staticmethod;

class A {
  static get x => 2;
}

main() {
  var y = A.x;
}
