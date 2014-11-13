library typeanalysis.generics;


import 'element.dart';
import 'types.dart';
import 'engine.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'util.dart';

const int RECURSIVE_LEVEL = 3; 

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
  
  int get hashCode => _hashCode();
  
  int _hashCode([int level = RECURSIVE_LEVEL]){
    if (level <= 0)
      return classElement.hashCode;
    
    Map<ParameterType, AbstractType> map = get();
    if (map.isEmpty)
      return classElement.hashCode;
    
    int res = classElement.hashCode;
    for(ParameterType param in map.keys){
      AbstractType type = map[param];
      if (type is NominalType){
        res += param.hashCode * 13 * type.genericMap._hashCode(level - 1) * 31;
      } else
        res += param.hashCode * 13 * type.hashCode * 31;
    }
    return res;
  }
  
  operator ==(Object other) => other is GenericMap && other.hashCode == hashCode;
  
  GenericMap._create(ClassElement this.classElement, TypeArgumentList this.typeArguments, SourceElement this.source, GenericMapGenerator this.generator);
  
  Map<ParameterType, AbstractType> _generateMap() {
    Engine engine = generator.engine;
    
    if (typeArguments == null)
      return generator.getUnfilledParamterMap(classElement);
      
    Map<ParameterType, AbstractType> res = <ParameterType, AbstractType>{};
    
    if (typeArguments.arguments.length != classElement.typeParameters.length)
      engine.errors.addError(new EngineError("The typeArguments ${typeArguments} did not match the length of the parameters for the class ${classElement}", source.source, typeArguments.offset, typeArguments.length), true);
    
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
        engine.errors.addError(new EngineError("The typeArgument: ${type} could not be resolved", source.source, type.offset, type.length));
        richType = new DynamicType();
      }
      
      res[new ParameterType(classElement.typeParameters[i])] = richType;
    }
    
    if (classElement.extendsElement != null){
      TypeArgumentList typeArguments = null;
      if (classElement.superclass != null)
        typeArguments = classElement.superclass.typeArguments;
      GenericMap genericMap = generator.create(classElement.extendsElement, typeArguments, classElement.sourceElement);
      res = MapUtil.union(genericMap.copyWithBoundParameters(res).get(), res);
    }
    
    for(var i = 0; i < classElement.implementElements.length; i++){
      ClassElement implementsClass = classElement.implementElements[i];
      TypeArgumentList typeArguments = classElement.implements[i].typeArguments;
      GenericMap genericMap = generator.create(implementsClass, typeArguments, classElement.sourceElement);
      res = MapUtil.union(genericMap.copyWithBoundParameters(res).get(), res);      
    }
    
//    for(var i = 0; i < classElement.mixinElements.length; i++){
//      ClassElement mixinClass = classElement.mixinElements[i];
//      TypeArgumentList typeArguments = classElement.mixins[i].typeArguments;
//      GenericMap genericMap = generator.create(mixinClass, typeArguments, classElement.sourceElement);
//      res = MapUtil.union(genericMap.copyWithBoundParameters(res).get(), res);      
//    }

    return res;  
  }
  
  GenericMap getLeastUpperBound(ClassElement lub, AbstractType t, Engine engine, [level = RECURSIVE_LEVEL]){
    if (t is NominalType){
      
      if (t.genericMap == null)
        return generator.create(lub, null, lub.sourceElement);
      
      if (level <= 0)
        return generator.create(classElement, null, classElement.sourceElement);
      
      GenericMap map1 = createParentMap(lub);
      GenericMap map2 = t.genericMap.createParentMap(lub);
      return map1._leastUpperBound(map2, engine, level);
    }
    
    return generator.create(lub, null, lub.sourceElement);
  }
  
  GenericMap _leastUpperBound(GenericMap other, Engine engine, [level = RECURSIVE_LEVEL]){
    if (level <= 0)
      return generator.create(classElement, null, classElement.sourceElement);
    
    Map<ParameterType, AbstractType> otherMap = other.get();
    Map<ParameterType, AbstractType> map = get();
    Map<ParameterType, AbstractType> res = <ParameterType, AbstractType>{};
    
    List<ParameterType> keys = ListUtil.union(otherMap.keys, map.keys);
    //print("KEYS: ${keys}");
    for(ParameterType key in keys){
      if (!otherMap.containsKey(key) && !map.containsKey(key))
        res[key] = key;
      else if (!otherMap.containsKey(key))
        res[key] = map[key];
      else if (!map.containsKey(key))
        res[key] = otherMap[key];
      else {
        AbstractType t =  map[key];
        if (t is NominalType)
          res[key] = t.getLeastUpperBound(otherMap[key], engine, level-1);
        else
          res[key] = t.getLeastUpperBound(otherMap[key], engine);
      }
    }
    
    GenericMap newMap = generator.create(classElement, null, classElement.sourceElement);
    return newMap.copyWithBoundParameters(res);
  }
  
  GenericMap createParentMap(ClassElement parent){
    GenericMap t = this;
    Map<ParameterType, AbstractType> map = t.get();
    
    while(t.classElement != parent){
      
      if (t.classElement.extendsElement == null)
        return null; //Should never happen, the parent should be in the extendsElement chain.
      
      TypeArgumentList typeArguments = null;
      if (t.classElement.superclass != null)
        typeArguments = t.classElement.superclass.typeArguments;
      
      t = generator.create(t.classElement.extendsElement, 
                           typeArguments, 
                           t.classElement.sourceElement);
      t = t.copyWithBoundParameters(map);
      map = t.get();
    }
    return t;
  }
  
  
  GenericMap copyWithBoundParameters(Map<ParameterType, AbstractType> map){
    GenericMap copy = new GenericMap._create(classElement, typeArguments, source, generator);
    copy._map = copy.get();
    
    for(ParameterType k in copy._map.keys){
      if (copy._map[k] is ParameterType  && map.containsKey(copy._map[k]))
        copy._map[k] = map[copy._map[k]];
    }
    
    return copy;
  }
  
  String toString([int level = RECURSIVE_LEVEL]){
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
    GenericMap genericMap = oldType.genericMap;
    
    genericMap = genericMap.copyWithBoundParameters(map);
    return new NominalType.makeInstance(element, genericMap);
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