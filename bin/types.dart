library typeanalysis.types;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'engine.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'element.dart';
import 'constraint.dart';
import 'util.dart';

abstract class AbstractType {
  
  /**
   * Return the least upper bound of this type and the given type, or `null` if there is no
   * least upper bound.
   *
   */
   AbstractType getLeastUpperBound(AbstractType type);
  
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
  
  
  factory FunctionType.FromCallableElement(CallableElement element, LibraryElement library, ElementTyper typer){
    TypeIdentifier returnIdentifier = typer.typeReturn(element, library, element.sourceElement);

    if (element.parameters == null)
      return new FunctionType(<TypeIdentifier>[], returnIdentifier);
    
    ParameterTypes params = typer.typeParameters(element, library, element.sourceElement);
    return new FunctionType(params.normalParameterTypes, returnIdentifier, params.optionalParameterTypes, params.namedParameterTypes); 
  }

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
  
  AbstractType getLeastUpperBound(AbstractType t) {
    if (t is DynamicType || t is VoidType)
          return t;
    
    //TODO (jln): Implement this, a simple implementation could be if t is a FunctionType then return the nominalType Function.
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
  
  NominalType(ClassElement this.element);
 
  String toString() => element.name.toString();
  
  bool operator ==(Object other) => other is NominalType && other.element == this.element;
  
  bool isSubtypeOf(AbstractType type) {
    if (type is NominalType)
      return element.isSubtypeOf(type.element);
    else if (type is DynamicType)
      return true;
    else
      return false;
  }
  
  AbstractType getLeastUpperBound(AbstractType t){
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

    //TODO (jln): If t is FunctionType the only possible case would be if this nominalType is FunctionType.
    return new DynamicType();
  }
  
  int get hashCode => element.hashCode;
}

class DynamicType extends AbstractType {
  static DynamicType _instance = null;
  factory DynamicType() => (_instance == null ? _instance = new DynamicType._internal() : _instance);
  
  DynamicType._internal();
  
  bool isSubtypeOf(DynamicType t) => true;
  
  AbstractType getLeastUpperBound(AbstractType t) => this;
  
  String toString() => "dynamic";
  bool operator ==(Object other) => other is VoidType;
  
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
  
  AbstractType getLeastUpperBound(AbstractType t) => (t is DynamicType ? t : this);
  
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

class ParameterTypes { 
  List<TypeIdentifier> normalParameterTypes = <TypeIdentifier>[];
  List<TypeIdentifier> optionalParameterTypes = <TypeIdentifier>[];
  Map<Name, TypeIdentifier> namedParameterTypes = <Name, TypeIdentifier>{};
}

class ElementTyper {
  Map<AstNode, TypeIdentifier> types = <AstNode, TypeIdentifier>{};
  Map<CallableElement, ReturnTypeIdentifier> returns = <CallableElement, ReturnTypeIdentifier>{};
  
  
  ConstraintAnalysis constraintAnalysis;
  Engine get engine => constraintAnalysis.engine;
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  TypeMap get typeMap => constraintAnalysis.typeMap; 
  
  ElementTyper(ConstraintAnalysis this.constraintAnalysis);
  
  TypeIdentifier typeNamedElement(NamedElement element, LibraryElement library){
    if (element is ClassElement)
      return typeClassElement(element);
    else if (element is MethodElement)
      return typeMethodElement(element, library);
    if (element is AnnotatedElement)
      return typeAnnotatedElement(element, library);
    if (element is ConstructorElement)
      return typeConstructorElement(element, library);
    if (element is NamedFunctionElement)
      return typeNamedFunctionElement(element, library);
    engine.errors.addError(new EngineError("The typeNamedElement method was called with a illigal classMember.", element.sourceElement.source), true);
    return null;
  }
  
  TypeIdentifier typeClassMember(ClassMember element, LibraryElement library){
    if (element is MethodElement)
      return typeMethodElement(element, library);
    if (element is FieldElement)
      return typeAnnotatedElement(element, library);
    if (element is ConstructorElement)
      return typeConstructorElement(element, library);
    engine.errors.addError(new EngineError("The typeClassMember method was called with a illigal classMember.", element.sourceElement.source), true);
    return null;
  }
  
  TypeIdentifier typeMethodElement(MethodElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(element.identifier);
    AbstractType elementType = new FunctionType.FromCallableElement(element, library, this);
    if (!typeMap.containsKey(elementTypeIdent))
      typeMap.replace(elementTypeIdent, new TypeVariable());
    
    typeMap.put(elementTypeIdent,elementType);
    
    return types[element.ast] = elementTypeIdent;
  }
  
  TypeIdentifier typeNamedFunctionElement(NamedFunctionElement element, LibraryElement library) {
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(element.identifier);
    AbstractType elementType = new FunctionType.FromCallableElement(element, library, this);
    if (!typeMap.containsKey(elementTypeIdent))
      typeMap.replace(elementTypeIdent, new TypeVariable());
    
    typeMap.put(elementTypeIdent,elementType);
    
    return types[element.ast] = elementTypeIdent;
  }
  
  TypeIdentifier typeAnnotatedElement(AnnotatedElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(element.identifier);
    AbstractType elementType = resolveType(element.annotatedType, library, element.sourceElement);
    if (!typeMap.containsKey(elementTypeIdent))
      typeMap.replace(elementTypeIdent, new TypeVariable());
    
    if (elementType != null)
      typeMap.put(elementTypeIdent, elementType);
    
    return types[element.ast] = elementTypeIdent;
  }
  
  TypeIdentifier typeConstructorElement(ConstructorElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(element.identifier);
    AbstractType elementType = new FunctionType.FromCallableElement(element, library, this);
    if (!typeMap.containsKey(elementTypeIdent))
      typeMap.replace(elementTypeIdent, new TypeVariable());
    
    typeMap.put(elementTypeIdent, elementType);
      
    return types[element.ast] = elementTypeIdent;
    
  }
  
  TypeIdentifier typeClassElement(ClassElement element){
    if (types.containsKey(element.ast))
      return types[element.ast];

    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(element.identifier);
    AbstractType elementType = new NominalType(element);
    if (!typeMap.containsKey(elementTypeIdent))
      typeMap.replace(elementTypeIdent, new TypeVariable());
    
    typeMap.put(elementTypeIdent, elementType);
    
    return types[element.ast] = elementTypeIdent;
  }
  
  TypeIdentifier typeReturn(CallableElement element, LibraryElement library, SourceElement source){
    if (returns.containsKey(element))
          return returns[element];
    
    TypeIdentifier ident = new ReturnTypeIdentifier(element);
    AbstractType type;
    if (!typeMap.containsKey(ident))
        typeMap.replace(ident, new TypeVariable());
    
    type = resolveType(element.returnType, library, source);
    if (type != null)
      typeMap.put(ident, type);
    
    return returns[element] = ident;
  }
  
  ParameterTypes typeParameters(CallableElement element, LibraryElement library, SourceElement source){
    FormalParameterList paramList = element.parameters;
    ParameterTypes types = new ParameterTypes();
    
    if (paramList.parameters == null || paramList.length == 0) 
      return types;
    
    NodeList<FormalParameter> params = paramList.parameters;
    
    for(FormalParameter param in params){
      var normalParam; 
      if (param is NormalFormalParameter) normalParam = param;
      else if (param is DefaultFormalParameter) normalParam = param.parameter;
      
      TypeIdentifier paramTypeIdent;
      if (this.types.containsKey(normalParam))
        paramTypeIdent = this.types[normalParam];  
      else {
        paramTypeIdent = new ExpressionTypeIdentifier(param.identifier);
        
        
        AbstractType type; 
        if (normalParam is SimpleFormalParameter || normalParam is FieldFormalParameter) {
          if (normalParam.type != null)
            type = this.resolveType(normalParam.type, library, source);
            
        } else if (normalParam is FunctionTypedFormalParameter){
          if (elementAnalysis.containsElement(normalParam) && elementAnalysis.elements[normalParam] is CallableElement){
            CallableElement callElement = elementAnalysis.elements[normalParam];
            type = new FunctionType.FromCallableElement(callElement, library, this);
          } else {
            //The element should be in the elementAnalysis.
            engine.errors.addError(new EngineError("A FunctionTypedFormaParameter was found in the typing step, but didn't have a associated elemenet.", source.source, normalParam.offset, normalParam.length ), true);
            type = null;
          }
        }
        
        if (!typeMap.containsKey(paramTypeIdent))
          typeMap.replace(paramTypeIdent, new TypeVariable());
        
        if (type != null)
          typeMap.put(paramTypeIdent, type);
        
        this.types[normalParam] = paramTypeIdent; 
      }
      
      if (normalParam.kind == ParameterKind.REQUIRED)
        types.normalParameterTypes.add(paramTypeIdent);
      else if (normalParam.kind == ParameterKind.POSITIONAL)
        types.optionalParameterTypes.add(paramTypeIdent);
      else if (normalParam.kind == ParameterKind.REQUIRED)
        types.namedParameterTypes[new Name.FromIdentifier(normalParam.identifier)] = paramTypeIdent;
    }
    
    return types;
  }
  
  AbstractType resolveType(TypeName type, LibraryElement library, SourceElement source){
    if (type == null)
      return null;
    else {
      ClassElement classElement = elementAnalysis.resolveClassElement(new Name.FromIdentifier(type.name), library, source);
      if (classElement != null)
        return new NominalType(elementAnalysis.resolveClassElement(new Name.FromIdentifier(type.name), library, source));
      else 
        return null;
    }
  }
}