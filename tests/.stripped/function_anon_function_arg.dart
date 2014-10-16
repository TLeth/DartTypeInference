library tests.funciton_anon_function_arg;

apply(fff(a), arg) => fff(arg);

main() {
  apply((x) => x, 'hej');
}
