library tests.functions;

String a(String b) => b;
dynamic b(String c) {
  if (1 > 2) return b; else return 2;
}
dynamic c(String d) {
  if (1 > 2) return "test"; else return 3;
}
dynamic d(dynamic g) => g;
String e(num g) => "String";
void main(){
  a("test");
  b("test");
  c("test");
  e(2);
  e(3.0);
  
  d(2);
  d("test");
}