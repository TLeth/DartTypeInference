import 'dart:html';
import 'src/Example.dart';


void main() {
  var corp = new Corporation();
  var theBoss = new Manager("Anders", corp);
  
  ['Jytte Hansen','Frede Abe','Chris Abekat'].forEach((name) => corp.hire(new Person(name, 10000))); 
  
  
  updateVisuals(corp, theBoss);
}

void updateVisuals(corp, manager){
  querySelector("#employees").innerHtml = "";
  corp.employees.forEach((p) => querySelector("#employees").appendHtml("<li data-name=\""+p.getName()+"\">" + p.lastName + ", "+p.firstName + " - " + p.getSalery().toString() + "</li>"));
  querySelector("#manager").innerHtml = manager.getName() + " - " + manager.getSalery().toString();
  
  querySelector("#employees li").onClick.listen((e) {
    manager.fire(corp.find(e.target.attributes["data-name"]));
    updateVisuals(corp, manager);
  });
}