library tests.function_function_arg;

String apply(String f(String), String arg) => f(arg);
String id(String a) => a;


void main() {
  apply(a, 'hej');
}
