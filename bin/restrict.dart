library typeanalysis.restrict;

import 'engine.dart';
import 'element.dart';
import 'types.dart';

class Restriction {
  
  Engine engine;
  
  
  Restriction(Engine this.engine);
  
  Set<AbstractType> restrict(AbstractType abstractType, Name property, SourceElement source){
    Set<AbstractType> res = new Set<AbstractType>();
    
    if (abstractType is! NominalType){
      res.add(abstractType);
      return res;
    }
    
    NominalType type = abstractType as NominalType;
    
    if (source.source == engine.entrySource && engine.options.printRestrictNodes)
      print("Type: ${abstractType} - looking for property ${property}");
    
    if (type.element.properties().contains(property)) {
      if (source.source == engine.entrySource && engine.options.printRestrictNodes)
        print("Found on the exact element");
      res.add(type);
      return res;
    }
    
    Set<ClassElement> next_queue = new Set<ClassElement>();
    next_queue.addAll(type.element.extendsSubClasses);
    
    Set<ClassElement> resClasses = new Set<ClassElement>();
    
    while(!next_queue.isEmpty){
      Set<ClassElement> queue = next_queue;
      next_queue = new Set<ClassElement>();
      for(ClassElement classElement in queue){
        if (classElement.properties().contains(property))
          resClasses.add(classElement);
        else {
          next_queue.addAll(classElement.extendsSubClasses); 
        }
      }
      
      if (!resClasses.isEmpty)
        break;
    }
    
    if (source.source == engine.entrySource && engine.options.printRestrictNodes)
      print("Found on: ${resClasses}");
    res.addAll(resClasses.map((ClassElement classElement) => new NominalType(classElement)));
    return res;
  }
  
}