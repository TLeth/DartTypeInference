library Person;

class Person {
  String name;
  num salery;
  
  Person(String name, num salery) {
    this.name = name;
    this.salery = salery / 1000;
  }
  
  String get firstName => name.split(' ')[0];
  String get lastName => name.split(' ').length > 1 ? name.split(' ')[1] : '';
  
  String getName() => name;
  
  num setSalery(p) => salery = p / 1000;
  num getSalery() => salery * 1000;
}