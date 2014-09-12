
import 'dart:io';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/constant.dart';

class Test{
  Test(){
    var n;
  }
  
}

void main() {
  int a = 3;
  int b = 4;
  var c = 4.0;
  var d = 3.5;
  
  var e = a + b;
  
  var f = c + d;
  var g = c + a;
  

 
  
  /*
  print(g is num);  //true
  print(g is double); //true
  print(g is int);  //false
  print(e is double); //false
  print(e is num);  //true
  
  */
  
  /*var corp = new Corporation();
  var theBoss = new Manager("Anders", corp);
  
  ['Jytte Hansen','Frede Abe','Chris Abekat'].forEach((name) => corp.hire(new Person(name, 10000))); 
  print(corp.employees);*/
}