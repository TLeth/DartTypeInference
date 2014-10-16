library tests.funciton_anon_function_arg;

String apply(String fff(String a), String arg) => fff(arg);

void main() {
  apply((String x) => x, 'hej');
}
