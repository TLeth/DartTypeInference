class Person {
  var name;
  var salery;
  
  Person(name, salery) {
    this.name = name;
    this.salery = salery / 1000;
  }
  
  get firstName => name.split(' ')[0];
  get lastName => name.split(' ')[1];
  
  getName() => name;
  
  setSalery(p) => salery = p / 1000;
  getSalery() => salery * 1000;
}

class Corporation {
  List persons;
  
  Corporation() {
    persons = new List();
  }
  
  get employees => persons;
  
  hire(p) => persons.add(p);
  
  fire(p) => persons.remove(p);
  
  find(name) => persons.firstWhere((p) => p.name == name); 
}

class Manager extends Person {
  var org;
  
  Manager(name, org):super(name, 100000) {
    this.org = org;
  }
  
  fire(p) {
    org.fire(p);
    this.setSalery(p.getSalery());  
  }
  
}