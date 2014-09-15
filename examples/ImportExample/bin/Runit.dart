/*
import 'dart:io';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/constant.dart';
*/




void main() {
  var c = 2;
  var d = foo(c);
  
  var e = (var f){
    return f+c;
  };
  
  var g = new Foo();
  var h = foo(g);
}

foo(var a){
  return a;
}

class Foo {
  foo_b(var foo_c){
    
    return foo_a + foo_c;
  }
  var foo_a;
  
}