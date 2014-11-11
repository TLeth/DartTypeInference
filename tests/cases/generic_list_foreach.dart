library test.generic_list_foeach;

void main() {

  List<bool> a = new List<bool>(256);
  Function c = a.forEach;
  a.forEach((bool b) => print('hej'));
}
