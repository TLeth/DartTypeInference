library tests.function_function_arg;

apply(f(a), arg) => f(arg);
id(a) => a;


main() {
  apply(id, 'hej');
}
