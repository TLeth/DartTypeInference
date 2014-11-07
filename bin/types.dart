library typeanalysis.types;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'element.dart';
import 'util.dart';
import 'engine.dart';
import 'resolver.dart';

abstract class AbstractType {
  /**
   * Return the least upper bound of this type and the given type, or `null` if there is no
   * least upper bound.
   *
   */
   AbstractType getLeastUpperBound(AbstractType type, Engine engine);
  
  /**
   * Return `true` if this type is assignable to the given type. A type <i>T</i> may be
   * assigned to a type <i>S</i>, written <i>T</i> &hArr; <i>S</i>, iff either <i>T</i> <: <i>S</i>
   * or <i>S</i> <: <i>T</i>.
   *
   */
  bool isAssignableTo(AbstractType type) => type.isSupertypeOf(this) || isSupertypeOf(type);
  
  /**
   * Return `true` if this type is a subtype of the given type.
   *
   */
  bool isSubtypeOf(AbstractType type);

  /**
   * Return `true` if this type is a supertype of the given type. A type <i>S</i> is a
   * supertype of <i>T</i>, written <i>S</i> :> <i>T</i>, iff <i>T</i> is a subtype of <i>S</i>.
   *
   */
  bool isSupertypeOf(AbstractType type) => type.isSubtypeOf(this);
}

/*class FreeType extends AbstractType {
  static int _countID = 0;
  
  int _typeID;
  
  FreeType(): _typeID = _countID++;
  
  String toString() => "\u{03b1}${_typeID}";
  
  bool isSubtypeOf(AbstractType type) => type is FreeType;
  
  //TODO (jln): a free type is equal to any free type right?
  //bool operator ==(Object other) => other is FreeType;
}*/

class FunctionType extends AbstractType {
  List<TypeIdentifier> normalParameterTypes;
  List<TypeIdentifier> optionalParameterTypes;
  Map<Name, TypeIdentifier> namedParameterTypes;
  TypeIdentifier returnType;
  
  FunctionType(List<TypeIdentifier> this.normalParameterTypes, TypeIdentifier this.returnType, 
              [List<TypeIdentifier> optionalParameterTypes = null, Map<Name, TypeIdentifier> namedParameterTypes = null ] ) :
                this.optionalParameterTypes = (optionalParameterTypes == null ? <TypeIdentifier>[] : optionalParameterTypes),
                this.namedParameterTypes = (namedParameterTypes == null ? <Name, TypeIdentifier>{} : namedParameterTypes);
  
  factory FunctionType.FromIdentifiers(TypeIdentifier returnIdent, ParameterTypeIdentifiers paramIdents) =>
    new FunctionType(paramIdents.normalParameterTypes, returnIdent, paramIdents.optionalParameterTypes, paramIdents.namedParameterTypes);
  
  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write("(${ListUtil.join(normalParameterTypes, " -> ")}");

    if (optionalParameterTypes.length > 0)
      sb.write("[${ListUtil.join(optionalParameterTypes, " -> ")}]");

    if (namedParameterTypes.length > 0){
      sb.write("{${MapUtil.join(namedParameterTypes, " -> ")}}");
    }
    sb.write(" -> ${returnType})");
    return sb.toString();
  }
  
  int get hashCode {
    int h = returnType.hashCode;
    for(Name name in namedParameterTypes.keys)
      h = h + name.hashCode + namedParameterTypes[name].hashCode;
    for(TypeIdentifier t in normalParameterTypes)
      h = 31*h + t.hashCode;
    for(TypeIdentifier t in optionalParameterTypes)
      h = 31*h + t.hashCode;
    return h;
  }
  
  bool isSubtypeOf(AbstractType t){
    //TODO (jln): If t is a NominalType with classELement function it should be OK.
    //TODO (jln): Implement this.
    
    return false;
  }
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) {
    if (t is DynamicType || t is VoidType)
          return t;
    
    ClassElement funcElement = engine.elementAnalysis.resolveClassElement(new Name('Function'), engine.elementAnalysis.dartCore, engine.elementAnalysis.dartCore.source);
    if (funcElement == null)
      engine.errors.addError(new EngineError("Function could not be found in dart core library. Called from functionType getLeastUpperBound."), true);
    
    if (t is FunctionType){
      if (t.normalParameterTypes.length == optionalParameterTypes.length && 
          t.optionalParameterTypes.length == optionalParameterTypes.length &&
          t.namedParameterTypes.length == namedParameterTypes.length && 
          ListUtil.union(namedParameterTypes.keys, t.namedParameterTypes.keys).length == namedParameterTypes.length) {
        
        
        //TODO (jln): Since elements in the function is typeIdentifiers we need to have a link to the types.
        //            This is only if typedefs are used, in functionTypedParameters, this is handled by constraints.
        return new NominalType(funcElement);
        
      } else
        return new NominalType(funcElement);
    }
    
    if (t is NominalType && t.element == funcElement)
      return t;
    else
      return new DynamicType();
  }
  
  bool operator ==(Object other) => 
      other is FunctionType &&
      ListUtil.equal(other.normalParameterTypes, this.normalParameterTypes) &&
      ListUtil.equal(other.optionalParameterTypes, this.optionalParameterTypes) &&
      this.returnType == other.returnType &&
      MapUtil.equal(other.namedParameterTypes, this.namedParameterTypes);  
}

class NominalType extends AbstractType {
  
  ClassElement element;
  Map<ParameterType, AbstractType> parameterTypeMap = <ParameterType, AbstractType>{};
  
  NominalType(ClassElement this.element) {
    if (element == null)
      throw new Exception("Nominal type was created with a null classElement.");
    
    for(TypeParameterElement key in element.typeParameterMap.keys){
      parameterTypeMap[new ParameterType(key)] = new ParameterType(key);
    }
  }
  
  factory NominalType.MakeInstance(ClassElement element, Map<TypeParameterElement, NamedElement> binds, [Map<ClassElement, AbstractType> cache = null]){
    if (cache == null)
      cache = <ClassElement, AbstractType>{};
      
    if (cache.containsKey(element))
      return cache[element];
    
    Iterable<TypeParameterElement> keys = element.typeParameterMap.keys;
    NominalType type = cache[element] = new NominalType(element);
    if (element.identifier.toString() =='C'){
      print("TEST");
    }
    for(TypeParameterElement key in keys){
      if (binds[key] is ClassElement){
        if (cache.containsKey(binds[key]))
          type.parameterTypeMap[new ParameterType(key)] = cache[binds[key]];
        else
          type.parameterTypeMap[new ParameterType(key)] = new NominalType.MakeInstance(binds[key], binds, cache);
      } else
        type.parameterTypeMap[new ParameterType(key)] = new DynamicType();
    }
    return type;
  }
  
  factory NominalType.MakeInstanceWithTypeArguments(ClassElement element, TypeArgumentList typeArguments, TypeParameterMapUtil parameterMapUtil, SourceElement source){
    Map<TypeParameterElement, NamedElement> binds = parameterMapUtil.getTypeParameterBinds(element.typeParameters, typeArguments, source);
    Map<TypeParameterElement, NamedElement> map = parameterMapUtil.bindTypeParameterElements(element.typeParameterMap, binds);
    
    
    return new NominalType.MakeInstance(element, map);
  }
  
  String _printParameterTypeMap(Map<ParameterType, AbstractType> map, [List<AbstractType> seenTypes = null]){
    if (seenTypes == null)
      seenTypes = [];
    
    List<ParameterType> keys = new List.from(map.keys);
    String res = "";
    for(var i = 0; i < keys.length; i++){
      if (i > 0)
        res += ", ";
      if (map[keys[i]] is NominalType){
        NominalType t = map[keys[i]];
        if (seenTypes.contains(t))
          res += "${keys[i]}: ${t.toString(false)}";
        else {
          seenTypes.add(t);
          res += "${keys[i]}: ${t.toString(true, seenTypes)}";          
        }
      } else 
        res += "${keys[i]}: ${map[keys[i]]}";
    }
    return res;
  }
 
  String toString([bool withTypeMap = true, List<AbstractType> seenTypes = null]) => (parameterTypeMap.isEmpty || !withTypeMap ? element.name.toString() : "${element.name}<${_printParameterTypeMap(parameterTypeMap, seenTypes)}>");
  
  bool operator ==(Object other) => other is NominalType && other.element == this.element;
  
  bool isSubtypeOf(AbstractType type) {
    if (type is NominalType)
      return element.isSubtypeOf(type.element);
    else if (type is DynamicType)
      return true;
    else
      return false;
  }
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine){
    if (t is NominalType) {
      ClassElement leastUpperBound = element.getLeastUpperBound(t.element);
      if (leastUpperBound == null)
        //In some cases the element cannot find the least upper bound, then return a dynamic type.
        return new DynamicType();
      else
        return new NominalType(leastUpperBound);
    }
    
    if (t is DynamicType || t is VoidType)
      return t;
   
    //If this type is Function and t is FunctionType, return Function.
    ClassElement funcElement = engine.elementAnalysis.resolveClassElement(new Name('Function'), engine.elementAnalysis.dartCore, engine.elementAnalysis.dartCore.source);
    if (funcElement == null)
      engine.errors.addError(new EngineError("Function could not be found in dart core library. Called from functionType getLeastUpperBound."), true);
    if (t is FunctionType && this.element == funcElement)
      return this;
    
    return new DynamicType();
  }
  
  int get hashCode => element.hashCode;
}

class ParameterType extends AbstractType {
  TypeParameterElement parameter;
  
  ParameterType(TypeParameterElement this.parameter);
  
  bool isSubtypeOf(DynamicType t) => false;
  
  /* 
   * This is called when trying to annotate variables, and by returning this, it ensures that the 
   * type annotated always is the type parameter used.
   * It should not b introduced into other structures.
   */
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) => this;
  
  String toString() => "<${parameter.name}>";
  bool operator ==(Object other) => other is ParameterType && other.parameter == parameter;
  
  int get hashCode => parameter.hashCode;
}

class DynamicType extends AbstractType {
  static DynamicType _instance = null;
  factory DynamicType() => (_instance == null ? _instance = new DynamicType._internal() : _instance);
  
  DynamicType._internal();
  
  bool isSubtypeOf(DynamicType t) => true;
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) => this;
  
  String toString() => "dynamic";
  bool operator ==(Object other) => other is DynamicType;
  
}

/*class UnionType extends AbstractType {
  Set<AbstractType> types = new Set<AbstractType>();
  
  UnionType(Iterable<AbstractType> types) {
    for(AbstractType type in types){
      if (type is UnionType)
        this.types.addAll(type.types);
    }
    this.types.addAll(types);
  }
  
  String toString() => "{${ListUtil.join(types, " + ")}}";
  
  bool operator ==(Object other) => other is UnionType && other.types == this.types;
}*/

class VoidType extends AbstractType {

  static VoidType _instance = null;
  factory VoidType() => (_instance == null ? _instance = new VoidType._internal() : _instance);
  
  VoidType._internal();
  
  bool isSubtypeOf(AbstractType t) => t is VoidType;
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) => (t is DynamicType ? t : this);
  
  String toString() => "void";
  bool operator ==(Object other) => other is VoidType;
}



class TypeParameterMapUtil {
  
  Engine engine;
  
  TypeParameterMapUtil(Engine this.engine);
  
  // Generates a new map with the TypeParameterElements bound.
  Map<TypeParameterElement, NamedElement> bindTypeParameterElements(Map<TypeParameterElement, NamedElement> map, Map<TypeParameterElement, NamedElement> binds){
    Map<TypeParameterElement, NamedElement> res = <TypeParameterElement, NamedElement>{};
    
    for(TypeParameterElement key in map.keys){
      res[key] = map[key];
      if (binds.containsKey(map[key]))
        res[key] = binds[map[key]];
    }
    
    for(TypeParameterElement key in binds.keys)
      res[key] = binds[key];
    
    return res;
  }

  
  Map<TypeParameterElement, NamedElement> getTypeParameterBinds(List<TypeParameterElement> typeParameters, TypeArgumentList typeArguments, SourceElement source){
    Map<TypeParameterElement, NamedElement> res = <TypeParameterElement, NamedElement>{};
    
    if (typeArguments == null){
      for(var i = 0; i < typeParameters.length; i++)
        res[typeParameters[i]] = typeParameters[i];
      return res;
    }
    
    if (typeParameters.length != typeArguments.arguments.length)
      engine.errors.addError(new EngineError("Paramter types was mapped to the parent class, but the type parameters and type arguments did not have same length.", source.source, typeArguments.offset, typeArguments.length), true);
    
    for(var i = 0; i < typeParameters.length; i++) {
      NamedElement namedElement = source.resolvedIdentifiers[typeArguments.arguments[i].name];
      if (namedElement is ClassElement){
        ClassHierarchyResolver.createTypeParameterMap(namedElement, this);
        Map<TypeParameterElement, NamedElement> typeParameterMap = namedElement.typeParameterMap;
        Map<TypeParameterElement, NamedElement> typeBinds = getTypeParameterBinds(namedElement.typeParameters, typeArguments.arguments[i].typeArguments, source);
        res = MapUtil.union(res, bindTypeParameterElements(typeParameterMap, typeBinds));
      }
      res[typeParameters[i]] = namedElement;
    }
          
    return res;
  }
  
  static AbstractType bindParamterTypes(AbstractType type, Map<ParameterType, AbstractType> map, [Map<AbstractType, AbstractType> cache = null]){
    if (type is ParameterType){
      if (map.containsKey(type))
        return map[type];
      else 
        return new DynamicType();
    }

    if (cache == null)
      cache = <AbstractType, AbstractType>{};
    
    if (type is NominalType){
      if (cache.containsKey(type))
        return cache[type];
      
      NominalType boundType = new NominalType(type.element);
      cache[type] = boundType;
      for(ParameterType key in type.parameterTypeMap.keys)
        boundType.parameterTypeMap[key] = bindParamterTypes(type.parameterTypeMap[key], map, cache);
      return boundType;
    }
    
    return type;
  }
}

/************ TypeIdentifiers *********************/
abstract class TypeIdentifier {  
  static TypeIdentifier ConvertToTypeIdentifier(dynamic ident) {
    if (ident is TypeIdentifier)
      return ident;
    else if (ident is Expression)
      return new ExpressionTypeIdentifier(ident);
    return null;
  }
  
  bool get isPropertyLookup => false;
  Name get propertyIdentifierName => null;
  AbstractType get propertyIdentifierType => null;
}


class ExpressionTypeIdentifier extends TypeIdentifier {
  Expression exp;
  
  ExpressionTypeIdentifier(Expression this.exp);
  
  int get hashCode => exp.hashCode;
  
  bool operator ==(Object other) => other is ExpressionTypeIdentifier && other.exp == exp;
  
  String toString() => "#{${exp}}";
}

class SyntheticTypeIdentifier extends TypeIdentifier {
  TypeIdentifier _relation;
  
  SyntheticTypeIdentifier(TypeIdentifier this._relation);
  
  int get hashCode => _relation.hashCode * 31;
  
  bool operator ==(Object other) => other is SyntheticTypeIdentifier && other._relation == _relation;
}


class PropertyTypeIdentifier extends TypeIdentifier {
  AbstractType _type;
  Name _name;
  
  PropertyTypeIdentifier(AbstractType this._type, Name this._name);
  
  int get hashCode => _type.hashCode + 31 * _name.hashCode;
  
  bool operator ==(Object other) => other is PropertyTypeIdentifier && other._type == _type && other._name == _name;
  bool get isPropertyLookup => true;
  Name get propertyIdentifierName => _name;
  AbstractType get propertyIdentifierType => _type;
  
  String toString() => "#${_type}.${_name}";
}

class ReturnTypeIdentifier extends TypeIdentifier {
  CallableElement _element;
  
  ReturnTypeIdentifier(CallableElement this._element);
  
  int get hashCode => _element.hashCode * 31;
  
  bool operator ==(Object other) => other is ReturnTypeIdentifier && other._element == _element;
  
  String toString() => "#ret.[${_element}]";
}

class ParameterTypeIdentifiers { 
  List<TypeIdentifier> normalParameterTypes = <TypeIdentifier>[];
  List<TypeIdentifier> optionalParameterTypes = <TypeIdentifier>[];
  Map<Name, TypeIdentifier> namedParameterTypes = <Name, TypeIdentifier>{};
  
  ParameterTypeIdentifiers();
  
  factory ParameterTypeIdentifiers.FromCallableElement(CallableElement element, LibraryElement library, SourceElement source){
    
    FormalParameterList paramList = element.parameters;
    ParameterTypeIdentifiers types = new ParameterTypeIdentifiers();
    
    if (paramList == null || paramList.parameters == null || paramList.length == 0) 
      return types;
    
    NodeList<FormalParameter> params = paramList.parameters;
    
    for(FormalParameter param in params){
      var normalParam; 
      if (param is NormalFormalParameter) normalParam = param;
      else if (param is DefaultFormalParameter) normalParam = param.parameter;
      
      TypeIdentifier paramTypeIdent = new ExpressionTypeIdentifier(param.identifier);
      
      if (normalParam.kind == ParameterKind.REQUIRED)
        types.normalParameterTypes.add(paramTypeIdent);
      else if (normalParam.kind == ParameterKind.POSITIONAL)
        types.optionalParameterTypes.add(paramTypeIdent);
      else if (normalParam.kind == ParameterKind.REQUIRED)
        types.namedParameterTypes[new Name.FromIdentifier(normalParam.identifier)] = paramTypeIdent;
    }
    
    return types;
  }
}