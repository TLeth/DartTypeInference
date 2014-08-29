library Manager;

import 'Person.dart';
import 'Corporation.dart';

class Manager extends Person {
  Corporation org;
  
  Manager(String name, Corporation org):super(name, 1234) {
    this.org = org;
  }
  
  fire(Person p) {
    org.fire(p);
    this.setSalery(p.getSalery() + this.getSalery());  
  }
  
}