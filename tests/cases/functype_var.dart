library tests.functype_var;

void main() {
  Function a = (dynamic a) => a;
  a = (dynamic a, dynamic b) => b;
}
