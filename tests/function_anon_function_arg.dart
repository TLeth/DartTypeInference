library tests.funciton_anon_function_arg;

String apply(String f(String), String arg) => f(arg);

void main() {
  apply((String x) => x, 'hej');
}
