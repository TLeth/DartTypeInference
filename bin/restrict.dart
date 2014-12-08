library typeanalysis.restrict;

import 'engine.dart';
import 'element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'util.dart';
import '/Users/jstroem/Projects/DartTypeInference/inferred/StageXL/lib/src/geom/matrix_3d.dart';

class UseAnalysis {

  Engine engine;
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  Map<Source, ElementRestrictionMap> restrictions = <Source, ElementRestrictionMap>{};
  
  UseAnalysis(Engine this.engine) {
    elementAnalysis.sources.forEach(_generateUseMap);
  }
  
  void _generateUseMap(Source source, SourceElement sourceElement){
    RestrictMapGenerator generator = new RestrictMapGenerator(engine, sourceElement);
    sourceElement.ast.accept(generator);
    restrictions[source] = generator.map;
  }
}

class ElementRestrictionMap {
  Map<NamedElement, RestrictMap> map = <NamedElement, RestrictMap>{};
  
  RestrictMap operator [](NamedElement n) => map[n];
  operator []=(NamedElement n, RestrictMap m) => map[n] = m;
  
  String toString() {
    if (map.isEmpty) 
      return "{}";
    String res = "{\n";
    res += MapUtil.join(map, "\n");
    res += "\n}";
    return res;
  }
}

class FieldElement extends RestrictElement {
  FieldElement(String name) : super(name);
  FieldElement.FromIdentifier(SimpleIdentifier ident) : super(ident.name);
  String toString() => name;
  
  bool operator ==(Object other) => other is FieldElement && name == other.name;
  int get hashCode => name.hashCode;
}

class MethodElement extends RestrictElement {
  MethodElement(String name) : super(name);
  MethodElement.FromIdentifier(SimpleIdentifier ident) : super(ident.name);
  String toString() => name + "()";
  
  bool operator ==(Object other) => other is MethodElement && name == other.name;
  int get hashCode => name.hashCode * 31; 
}

class RestrictElement {
  String name;
  
  RestrictElement(String this.name);
}

class RestrictMap {
  static int _printIdent = 0;
  String toString() => "?";
}

class ActualRestrictMap extends RestrictMap {
  Map<RestrictElement, RestrictMap> map = <RestrictElement, RestrictMap>{};
  
  RestrictMap operator [](RestrictElement n) => map[n];
  operator []=(RestrictElement n, RestrictMap m) => map[n] = m;
  
  String toString() {
    if (map.isEmpty) 
      return "{}";
    String res = "{\n";
    RestrictMap._printIdent++;
    res += (" " * RestrictMap._printIdent);
    res += MapUtil.join(map, "\n" + (" " * RestrictMap._printIdent));
    RestrictMap._printIdent--;
    res += "\n" +(" " * RestrictMap._printIdent) + "}";
    return res;
  }
}

class RestrictMapGenerator extends GeneralizingAstVisitor {
  
  ElementRestrictionMap map = new ElementRestrictionMap();
  ActualRestrictMap currentPropertyMap = null;
  Engine engine;
  SourceElement currentSourceElement;
  Map<Identifier, NamedElement> get resolvedIdentifiers => currentSourceElement.resolvedIdentifiers;
  
  RestrictMapGenerator(Engine this.engine, SourceElement this.currentSourceElement);
  
  visitPrefixedIdentifier(PrefixedIdentifier node){
    //If the identifier is written within a comment dont look into it.
    if (node.parent != null && node.parent.runtimeType.toString() == 'CommentReference')
      return;
    
    if (resolvedIdentifiers[node] != null) {
      map[resolvedIdentifiers[node]] = currentPropertyMap;
    } else {
      ActualRestrictMap lastPropertyMap = currentPropertyMap;
      RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
      currentPropertyMap = new ActualRestrictMap();
      currentPropertyMap[new FieldElement.FromIdentifier(node.identifier)] = property;
      
      node.prefix.accept(this);
      
      currentPropertyMap = lastPropertyMap;
    }
  }
  
  visitSimpleIdentifier(SimpleIdentifier node){
    if (currentPropertyMap == null)
      return;
    
    //If the identifier is written within a label, dont look into it.
    if (node.parent != null && node.parent.runtimeType.toString() == 'Label')
      return;
    
    if (resolvedIdentifiers[node] == null){
      engine.errors.addError(new EngineError("The identifier: ${node} could not be resolved in the restrict pre-fase.", currentSourceElement.source, node.offset, node.length));
    }
    
    map[resolvedIdentifiers[node]] = currentPropertyMap;
    
    super.visitSimpleIdentifier(node);
  }
  
  visitMethodInvocation(MethodInvocation node){
    
    if (node.realTarget == null){
      if (currentPropertyMap == null)
        return;
      
      if (resolvedIdentifiers[node.methodName] == null)
        engine.errors.addError(new EngineError("The identifier: ${node.methodName} could not be resolved in the restrict pre-fase.", currentSourceElement.source, node.methodName.offset, node.methodName.length));
      
      map[resolvedIdentifiers[node.methodName]] = currentPropertyMap;
    } else {
      if (resolvedIdentifiers[node.methodName] != null){
        map[resolvedIdentifiers[node.methodName]] = currentPropertyMap;
      } else {
        ActualRestrictMap lastPropertyMap = currentPropertyMap;
        RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
        currentPropertyMap = new ActualRestrictMap();
        currentPropertyMap[new MethodElement.FromIdentifier(node.methodName)] = property;
        node.realTarget.accept(this);
        currentPropertyMap = lastPropertyMap;
      }
    }
  }
  
  visitPropertyAccess(PropertyAccess node) {
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
    
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    currentPropertyMap[new FieldElement.FromIdentifier(node.propertyName)] = property;
    node.realTarget.accept(this);
    currentPropertyMap = lastPropertyMap;
  }
  
  visitIndexExpression(IndexExpression node){
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    currentPropertyMap[new MethodElement("[]")] = property;
    node.realTarget.accept(this);
    currentPropertyMap = lastPropertyMap; 
  }
}