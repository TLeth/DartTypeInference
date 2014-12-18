library typeanalysis.restrict;

import 'engine.dart';
import 'element.dart';
import 'types.dart';
import 'use_analysis.dart';
import 'package:analyzer/src/generated/source.dart';

class Restriction {
  
  Engine engine;
  UseAnalysis get useAnalysis => engine.useAnalysis;
  
  
  Restriction(Engine this.engine);
  
  Set<AbstractType> restrict(AbstractType abstractType, Name property, Source source){
    Set<AbstractType> res = new Set<AbstractType>();
    
    if (abstractType is! NominalType){
      res.add(abstractType);
      return res;
    }
    
    NominalType type = abstractType as NominalType;
    if (type.element.properties().contains(property)){
      res.add(type);
      return res;
    }
    
    res.addAll(restrictNominalType(type, <Name>[property], source));
    return res;
  }
  
  Set<NominalType> restrictNominalType(NominalType nominalType, Iterable<Name> properties, Source source){
    ClassElement element = nominalType.element; 
    if (source == engine.entrySource && engine.options.printRestrictNodes)
      print("Type: ${element} - looking for properties: ${properties}");
    
    Set<NominalType> res = new Set<NominalType>();
    if (element.properties().containsAll(properties)){
      if (source == engine.entrySource && engine.options.printRestrictNodes)
        print("Found on the exact element");
      res.add(nominalType);
      return res;
    }
    
    Set<ClassElement> next_queue = new Set<ClassElement>();
    next_queue.addAll(element.extendsSubClasses);
    
    while(!next_queue.isEmpty){
      Set<ClassElement> queue = next_queue;
      next_queue = new Set<ClassElement>();
      for(ClassElement classElement in queue){
        if (classElement.properties().containsAll(properties))
          res.add(new NominalType(classElement));
        else {
          next_queue.addAll(classElement.extendsSubClasses); 
        }
      }
      
      if (!res.isEmpty)
        break;
    }
    
    if (source == engine.entrySource && engine.options.printRestrictNodes)
      print("Found on: ${res}");
    return res;
  }
  
  Set<AbstractType> focus(AbstractType abstractType, Set<Name> properties, Source source) {
    Set<AbstractType> res = new Set<AbstractType>();
    
    if (abstractType is! NominalType){
      if (abstractType is VoidType && !properties.isEmpty)
        res.add(new DynamicType());
      else
        res.add(abstractType);
      return res;
    }
    
    NominalType type = abstractType as NominalType;
    
    res.addAll(restrictNominalType(type, properties, source));
    if (res.isEmpty)
      res.add(abstractType);
    return res;
  }
  
}