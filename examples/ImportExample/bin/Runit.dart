import 'Corporation.dart';
import 'Manager.dart';
import 'Person.dart';
import 'dart:io';
import 'package:analyzer/analyzer.dart';

void main() {
  var corp = new Corporation();
  var theBoss = new Manager("Anders", corp);
  
  ['Jytte Hansen','Frede Abe','Chris Abekat'].forEach((name) => corp.hire(new Person(name, 10000))); 
  print(corp.employees);
}