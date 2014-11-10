library typeanalysis.generics;


import 'element.dart';
import 'types.dart';
import 'engine.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'util.dart';

class GenericMap {
  SourceElement source;
  ClassElement classElement;
  TypeArgumentList typeArguments;
  Map<ParameterType, AbstractType> _map = null;
  GenericMapGenerator generator;
  Map<ParameterType, AbstractType> get() {
    if (_map == null)
      _map = _generateMap();
    return _map;
  }
  
  GenericMap._create(ClassElement this.classElement, TypeArgumentList this.typeArguments, SourceElement this.source, GenericMapGenerator this.generator);
  
  Map<ParameterType, AbstractType> _generateMap() {
    Engine engine = generator.engine;
    
    if (typeArguments == null)
      return generator.getUnfilledParamterMap(classElement);
      
    Map<ParameterType, AbstractType> res = <ParameterType, AbstractType>{};
    
    if (typeArguments.arguments.length != classElement.typeParameters.length)
      engine.errors.addError(new EngineError("The typeArguments ${typeArguments} did not match the length og the parameters for the class ${classElement}", source.source, typeArguments.offset, typeArguments.length), true);
    
    for(var i = 0; i < typeArguments.arguments.length; i++){
      TypeName type = typeArguments.arguments[i];
      AbstractType richType = null;
      if (type.name.toString() == 'void')
        richType = new VoidType();
      if (type.name.toString() == 'dynamic')
        richType = new DynamicType();
      
      NamedElement e = source.resolvedIdentifiers[type.name];
      if (e is ClassElement)
        richType = new NominalType.makeInstance(e, generator.create(e, type.typeArguments, source));
      if (e is TypeParameterElement)
        richType = new ParameterType(e);
      
      if (richType == null){
        engine.errors.addError(new EngineError("The typeArgument: ${type} could not be resolved", source.source, type.offset, type.length));
        richType = new DynamicType();
      }
      
      res[new ParameterType(classElement.typeParameters[i])] = richType;
    }
    
    if (classElement.extendsElement != null){
      TypeArgumentList typeArguments = null;
      if (classElement.superclass != null)
        typeArguments = classElement.superclass.typeArguments;
      GenericMap genericMap = generator.create(classElement.extendsElement, typeArguments, classElement.sourceElement);
      NominalType parentType = new NominalType.makeInstance(classElement.extendsElement, genericMap);
      res = MapUtil.union(parentType.getGenericTypeMap(generator), res);
    }
  
    return res;  
  }
  
  GenericMap copyWithBoundParameters(Map<ParameterType, AbstractType> map){
    GenericMap res = new GenericMap._create(classElement, typeArguments, source, generator);
    res.get();
    
    for(ParameterType k in res._map.keys){
      if (res._map[k] is ParameterType && map.containsKey(res._map[k]))
        res._map[k] = map[res._map[k]];
    }
    
    return res;
  }
  
  String toString([int level = 2]){
    if (level <= 0)
      return "<...>";
    
    Map<ParameterType, AbstractType> map = get();
    if (map.isEmpty)
      return "";
    
    String res = "<";
    int i = 0;
    for(ParameterType param in map.keys){
      AbstractType type = map[param];
      if (i > 0)
        res += ", ";
      if (type is NominalType){
        res += "${param.parameter}: ${type.toString(level - 1)}";
      } else {
        res += "${param.parameter}: ${type}";
      }
      i++;
    }
    return res + ">";
  }
}


class GenericMapGenerator {
  
  Engine engine;
  
  GenericMapGenerator(Engine this.engine);
  

  NominalType createInstanceWithBinds(NominalType oldType, Map<ParameterType, AbstractType> map){
    ClassElement element = oldType.element;
    GenericMap genericMap;
    if (oldType.genericMap == null)
      genericMap = create(element, null, element.sourceElement);
    else
      genericMap = oldType.genericMap;
    
    genericMap = genericMap.copyWithBoundParameters(map);
    return new NominalType.makeInstance(element, genericMap);
  }
  
  Map<ParameterType, AbstractType> getDynamicParamterMap(ClassElement classElement){
    Map<ParameterType, AbstractType> res = <ParameterType, AbstractType>{};
    
    for(TypeParameterElement t in classElement.typeParameters)
      res[new ParameterType(t)] = new DynamicType();
    
    if (classElement.extendsElement != null){
      TypeArgumentList typeArguments = null;
      if (classElement.superclass != null)
        typeArguments = classElement.superclass.typeArguments;
      GenericMap genericMap = create(classElement.extendsElement, typeArguments, classElement.sourceElement);
      NominalType parentType = new NominalType.makeInstance(classElement.extendsElement, genericMap);
      res = MapUtil.union(parentType.getGenericTypeMap(this), res);
    }
    return res;
  }

  
  Map<ParameterType, AbstractType> getUnfilledParamterMap(ClassElement classElement){
    Map<ParameterType, AbstractType> res = <ParameterType, AbstractType>{};
    
    for(TypeParameterElement t in classElement.typeParameters)
      res[new ParameterType(t)] = new ParameterType(t);
    
    if (classElement.extendsElement != null){
      TypeArgumentList typeArguments = null;
      if (classElement.superclass != null)
        typeArguments = classElement.superclass.typeArguments;
      GenericMap genericMap = create(classElement.extendsElement, typeArguments, classElement.sourceElement);
      NominalType parentType = new NominalType.makeInstance(classElement.extendsElement, genericMap);
      res = MapUtil.union(parentType.getGenericTypeMap(this), res);
    }
    return res;
  }
  
  GenericMap create(ClassElement classElement, TypeArgumentList typeArguments, SourceElement source) =>
    new GenericMap._create(classElement, typeArguments, source, this);
  
}