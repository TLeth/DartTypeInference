library Corporation;

import 'Person.dart';

class Corporation {
  List<Person> persons;
  
  Corporation() {
    persons = new List<Person>();
  }
  
  List<Person> get employees => persons;
  
  hire(Person p) => persons.add(p);
  
  fire(Person p) => persons.remove(p);
  
  find(String name) => persons.firstWhere((Person p) => p.name == name); 
}