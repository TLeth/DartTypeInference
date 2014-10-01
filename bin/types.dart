library typeanalysis.types;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'engine.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'element.dart';
import 'constraint.dart';
import 'util.dart';

abstract class AbstractType {}

class FreeType extends AbstractType {
  static int _countID = 0;
  
  int _typeID;
  
  FreeType(): _typeID = _countID++;
  
  String toString() => "\u{03b1}${_typeID}";
  
  //TODO (jln): a free type is equal to any free type right?
  //bool operator ==(Object other) => other is FreeType;
}

class FunctionType extends AbstractType {
  List<TypeIdentifier> normalParameterTypes;
  List<TypeIdentifier> optionalParameterTypes;
  Map<Name, TypeIdentifier> namedParameterTypes;
  TypeIdentifier returnType;
  
  FunctionType(List<TypeIdentifier> this.normalParameterTypes, TypeIdentifier this.returnType, 
              [List<TypeIdentifier> optionalParameterTypes = null, Map<Name, TypeIdentifier> namedParameterTypes = null ] ) :
                this.optionalParameterTypes = (optionalParameterTypes == null ? <TypeIdentifier>[] : optionalParameterTypes),
                this.namedParameterTypes = (namedParameterTypes == null ? <Name, TypeIdentifier>{} : namedParameterTypes);
  
  
  factory FunctionType.FromElements(Identifier functionIdentifier, TypeName returnType, FormalParameterList paramList, LibraryElement library, SourceElement sourceElement, ElementTyper typer){
    TypeIdentifier returnIdentifier = typer.typeReturn(functionIdentifier, returnType, library, sourceElement);
    if (paramList == null)
      return new FunctionType(<TypeIdentifier>[], returnIdentifier);
    
    ParameterTypes params = typer.typeParameters(paramList, library, sourceElement);
    return new FunctionType(params.normalParameterTypes, returnIdentifier, params.optionalParameterTypes, params.namedParameterTypes); 
  }

  factory FunctionType.FromFunctionTypedFormalParameter(FunctionTypedFormalParameter element, LibraryElement library, ElementTyper typer, SourceElement sourceElement){
    return new FunctionType.FromElements(element.identifier, element.returnType, element.parameters, library, sourceElement, typer);
  }
  
  factory FunctionType.FromMethodElement(MethodElement element, LibraryElement library, ElementTyper typer){
    return new FunctionType.FromElements(element.identifier, element.returnType, element.ast.parameters, library, element.sourceElement, typer);
  }
  
  factory FunctionType.FromConstructorElement(ConstructorElement element, LibraryElement library, ElementTyper typer){
    FunctionType functionType = new FunctionType.FromElements(element.identifier, element.returnType, element.ast.parameters, library, element.sourceElement, typer);
    //typer.typeMap.replace(functionType.returnType, typer.typeMap[typer.typeClassElement(element.classDecl)]);
    return functionType;
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
  
  int get hashCode => element.hashCode;
}

class UnionType extends AbstractType {
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
}

class VoidType extends AbstractType {

  static VoidType _instance = null;
  factory VoidType() => (_instance == null ? _instance = new VoidType._internal() : _instance);
  
  VoidType._internal();
  
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
  Identifier _functionIdentifier;
  
  ReturnTypeIdentifier(Identifier this._functionIdentifier);
  
  int get hashCode => _functionIdentifier.hashCode * 31;
  
  bool operator ==(Object other) => other is ReturnTypeIdentifier && other._functionIdentifier == _functionIdentifier;
  
  String toString() => "#ret.${_functionIdentifier}";
}

class ParameterTypes { 
  List<TypeIdentifier> normalParameterTypes = <TypeIdentifier>[];
  List<TypeIdentifier> optionalParameterTypes = <TypeIdentifier>[];
  Map<Name, TypeIdentifier> namedParameterTypes = <Name, TypeIdentifier>{};
}

class ElementTyper {
  Map<AstNode, TypeIdentifier> types = <AstNode, TypeIdentifier>{};
  Map<AstNode, ReturnTypeIdentifier> returns = <AstNode, ReturnTypeIdentifier>{};
  
  
  ConstraintAnalysis constraintAnalysis;
  Engine get engine => constraintAnalysis.engine;
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  TypeMap get typeMap => constraintAnalysis.typeMap; 
  
  ElementTyper(ConstraintAnalysis this.constraintAnalysis);
  
  TypeIdentifier typeClassMember(ClassMember element, LibraryElement library){
    if (element is MethodElement)
      return typeMethodElement(element, library);
    if (element is FieldElement)
      return typeFieldElement(element, library);
    if (element is ConstructorElement)
      return typeConstructorElement(element, library);

    return null;
  }
  
  TypeIdentifier typeMethodElement(MethodElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(element.identifier);
    AbstractType elementType = new FunctionType.FromMethodElement(element, library, this);
    if (!typeMap.containsKey(elementTypeIdent))
      typeMap.replace(elementTypeIdent, new TypeVariable());
    
    typeMap.put(elementTypeIdent,elementType);
    
    
    return types[element.ast] = elementTypeIdent;
  }
  
  TypeIdentifier typeFieldElement(FieldElement element,LibraryElement library){
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
    AbstractType elementType = new FunctionType.FromConstructorElement(element, library, this);
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
  
  TypeIdentifier typeReturn(Identifier functionIdentifier, TypeName returnType, LibraryElement library, SourceElement source){
    if (returns.containsKey(functionIdentifier))
          return returns[functionIdentifier];
    
    TypeIdentifier ident = new ReturnTypeIdentifier(functionIdentifier);
    AbstractType type;
    if (!typeMap.containsKey(ident))
        typeMap.replace(ident, new TypeVariable());
    
    type = resolveType(returnType, library, source);
    if (type != null)
      typeMap.put(ident, type);
    
    return returns[functionIdentifier] = ident;
  }
  
  ParameterTypes typeParameters(FormalParameterList paramList, LibraryElement library, SourceElement source){
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
          type = new FunctionType.FromFunctionTypedFormalParameter(normalParam, library, this, source);
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