library tests.function_function_arg;

String apply(String f(String a), String arg) => f(arg);
String id(String a) => a;


void main() {
  apply(id, 'hej');
}
