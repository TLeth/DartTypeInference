library tests.function_arg_type;

dynamic b(String c) {
  if (1 > 2) return b; else return 2;
}


void main() {
  b('hej');
}
