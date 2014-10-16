library tests.function_arg_type;

b(c) {
  if (1 > 2) return b; else return 2;
}


main() {
  b('hej');
}
