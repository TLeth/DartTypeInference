import 'Corporation.dart';
import 'Manager.dart';
import 'Person.dart';
import 'dart:io';

class Test{
  Test(){
    var n;
  }
  
  Test operator -() => this;
  Test operator -(Test t) => this;
}

void main() {
  
  int a = 3;
  int b = 4;
  var c = 4.0;
  var d = 3.5;
  
  var e = a + b;
  
  var f = c + d;
  var g = c + a;
  
  var h = new Test();
 
  
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