class A {
  void operator []=(int index, String res){
    
  }
  
  String operator [](int index){
    return "Str";
  }
}

void main(){
  bool a1 = 3 < 4;
  bool a2 = 4 > 3;
  bool a3 = 4 <= 3;
  bool a4 = 4 <= 3;
  bool a5 = 4 == 3;
  num b1 = 3;
  num b2 = b1 - 3;
  num b3 = b2 + 4;
  b3 += 3;
  b3 -= 4;
  b3 = -b3;
  double c1 = b1 / 3;
  int d1 = b2 ~/ 4;
  num b4 = b3 * 5;
  b4 *= 5;
  num b5 = b4 % 3;
  b5 %= 3;
  int d2 = d1 | d1;
  d2 |= 3;
  int d3 = d2 ^ d2;
  d3 ^= 4;
  int d4 = d3 & d3;
  d4 &= 5;
  int d5 = d4 << d4;
  d5 <<= 3;
  int d6 = d5 >> d5;
  d6 >>= 4;
  int d7 = ~d6;
  
  num e = (1>2 ? 3.0 : 3);
  dynamic f = (1>2 ? 4.0 : "String");
  String g = (1>2 ? "String" : "String2");
  
  A h = new A();
  String i = (h[3] = "test");
  String j = h[3];
}