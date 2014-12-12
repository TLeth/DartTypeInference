library typeanalysis.types;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'element.dart';
import 'util.dart';
import 'engine.dart';
import 'generics.dart';
import 'dart:collection';

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
  
  static AbstractType LeastUpperBound(Set<AbstractType> types, Engine engine, {AbstractType defaultValue: null}){
    if (defaultValue == null) defaultValue = new DynamicType();
    if (types.length == 0) return defaultValue;
    Queue<AbstractType> queue = new Queue<AbstractType>.from(types);
    AbstractType res = queue.removeFirst();
    res = queue.fold(res, (AbstractType res, AbstractType t) => res.getLeastUpperBound(t, engine));
    if (res == null)
      return defaultValue;
    else 
      return res;
  }
}

/*class FreeType extends AbstractType {
  static int _countID = 0;
  
  int _typeID;
  
  FreeType(): _typeID = _countID++;
  
  String toString() => "\u{03b1}${_typeID}";
  
  bool isSubtypeOf(AbstractType type) => type is FreeType;
  
  //bool operator ==(Object other) => other is FreeType;
}*/

class FunctionType extends AbstractType {
  List<TypeIdentifier> normalParameterTypes;
  List<TypeIdentifier> optionalParameterTypes;
  Map<Name, TypeIdentifier> namedParameterTypes;
  TypeIdentifier returnType;
  
  FunctionType(List<TypeIdentifier> this.normalParameterTypes, TypeIdentifier this.returnType, 
              [List<TypeIdentifier> optionalParameterTypes = null, Map<Name, TypeIdentifier> namedParameterTypes = null]) :
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
    
    return false;
  }
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) {
    if (t is DynamicType || t is VoidType || t is ParameterType)
          return t.getLeastUpperBound(this, engine);
    
    ClassElement funcElement = engine.elementAnalysis.functionElement;
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
  GenericMap _genericMap;
  GenericMapGenerator get _generator => element.sourceElement.engine.genericMapGenerator;
  GenericMap get genericMap => _genericMap;
  
  NominalType(ClassElement this.element) {
    _genericMap = _generator.create(element, null, element.sourceElement);
  }
  
  NominalType.makeInstance(ClassElement this.element, GenericMap this._genericMap);
  
  Map<ParameterType, AbstractType> getGenericTypeMap(GenericMapGenerator generator) {
    if (_genericMap == null)
      _genericMap = generator.create(element, null, element.sourceElement);
    return _genericMap.get();
  }
  
  String toString([int level = RECURSIVE_LEVEL]) {
    if (_genericMap != null) 
      return "${element.name.toString()}${_genericMap.toString(level)}";
    else 
      return element.name.toString();
  }
  
  bool operator ==(Object other) => other is NominalType && other.element == this.element && other._genericMap == _genericMap;
  
  bool isSubtypeOf(AbstractType type) {
    if (type is NominalType)
      return element.isSubtypeOf(type.element);
    else if (type is DynamicType)
      return true;
    else
      return false;
  }
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine, [int level = RECURSIVE_LEVEL]){
    
    if (t is DynamicType || t is VoidType || t is ParameterType)
      return t.getLeastUpperBound(this, engine);
    
    if (t is NominalType) {
      ClassElement leastUpperBound = element.getLeastUpperBound(t.element);
      if (leastUpperBound == null)
        //In some cases the element cannot find the least upper bound, then return a object type (all is a child of object).
        return new NominalType(engine.elementAnalysis.objectElement);
      else {
        
        GenericMap genericMap = _genericMap.getLeastUpperBound(leastUpperBound, t, engine, level);
        
        return new NominalType.makeInstance(leastUpperBound, genericMap);
      }   
    }
   
    //If this type is Function and t is FunctionType, return Function.
    ClassElement funcElement = engine.elementAnalysis.functionElement;
    if (funcElement == null)
      engine.errors.addError(new EngineError("Function could not be found in dart core library. Called from functionType getLeastUpperBound."), true);
    if (t is FunctionType && element.getLeastUpperBound(funcElement) == funcElement){
      return new NominalType(funcElement);
    }
    return new DynamicType();
  }
  
  int get hashCode => genericMap.hashCode;
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
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) {
    if (t is ParameterType)
      return t.getLeastUpperBound(this, engine);
    else
      return this;
  }
  
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
  
  AbstractType getLeastUpperBound(AbstractType t, Engine engine) => (t is DynamicType || t is ParameterType ? t.getLeastUpperBound(this, engine) : this);
  
  String toString() => "void";
  bool operator ==(Object other) => other is VoidType;
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
  
  FunctionParameterElement functionParameterElement = null;
  bool get isPropertyLookup => false;
  Name get propertyIdentifierName => null;
  AbstractType get propertyIdentifierType => null;
}


class ExpressionTypeIdentifier extends TypeIdentifier {
  AstNode exp;
  
  ExpressionTypeIdentifier(AstNode this.exp);
  
  int get hashCode => exp.hashCode;
  
  bool operator ==(Object other) => other is ExpressionTypeIdentifier && other.exp == exp;
  
  String toString() => "#{${exp}}";
}

class SyntheticTypeIdentifier extends TypeIdentifier {
  TypeIdentifier _relation;
  
  SyntheticTypeIdentifier(TypeIdentifier this._relation);
  
  int get hashCode => _relation.hashCode * 31;
  
  String toString() => "SYN:${_relation}";
  
  bool operator ==(Object other) => other is SyntheticTypeIdentifier && other._relation == _relation;
}

/**
 * Properties hashCode and equals methods should not take generics into account.
 */
class PropertyTypeIdentifier extends TypeIdentifier {
  AbstractType _type;
  Name _name;
  
  PropertyTypeIdentifier(AbstractType this._type, Name this._name);
  
  int get hashCode {
    if (_type is NominalType){
      NominalType type = _type;
      return type.element.hashCode + 31 * _name.hashCode;
    } else {
      return _type.hashCode + 31 * _name.hashCode;
    }
  }
  
  bool operator ==(Object other) {
    if (other is! PropertyTypeIdentifier)
      return false;
    
    PropertyTypeIdentifier otr = other as PropertyTypeIdentifier; 
    
    if (_type is NominalType && otr._type is NominalType){
      return (_type as NominalType).element == (otr._type as NominalType).element && otr._name == _name; 
    } else {
      return otr._type == _type && otr._name == _name;
    }
  }
  
  bool get isPropertyLookup => true;
  Name get propertyIdentifierName => _name;
  AbstractType get propertyIdentifierType => _type;
  
  String toString() => (_type is NominalType ? "#${(_type as NominalType).element}.${_name}" : "#${_type}.${_name}");
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
  
  factory ParameterTypeIdentifiers.FromCallableElement(CallableElement element, LibraryElement library, SourceElement source, ElementAnalysis analysis){
    
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
      if (param is FunctionTypedFormalParameter)        
        paramTypeIdent.functionParameterElement = analysis.elements[param];
      
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