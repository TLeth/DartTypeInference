library tests.function_arg_type_dynamic;

dynamic b(dynamic c) => c;

void main() {
  b('hej');
  b(3);
}
