library test.gettersetter;

int _x;
int get x => _x;
void set x(int _y) {
  _x = _y;
}

void main() {
  x = 3;
  int y = x;
}
