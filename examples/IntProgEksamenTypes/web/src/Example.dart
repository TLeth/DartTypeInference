class Person {
  String name;
  num salery;
  
  Person(String name, int salery) {
    this.name = name;
    this.salery = salery / 1000;
  }
  
  String get firstName => name.split(' ')[0];
  String get lastName => name.split(' ')[1];
  
  String getName() => name;
  
  num setSalery(num p) => salery = p / 1000;
  num getSalery() => salery * 1000;
}

class Corporation {
  List<Person> persons;
  
  Corporation() {
    persons = new List<Person>();
  }
  
  List<Person> get employees => persons;
  
  void hire(Person p) => persons.add(p);
  
  bool fire(p) => persons.remove(p);
  
  Person find(String name) => persons.firstWhere((Person p) => p.name == name); 
}

class Manager extends Person {
  Corporation org;
  
  Manager(String name, Corporation org):super(name, 1234) {
    this.org = org;
  }
  
  void fire(p) {
    org.fire(p);
    this.setSalery(p.getSalery() + this.getSalery());  
  }
  
}