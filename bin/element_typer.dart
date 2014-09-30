library typeanalysis.element_typer;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'engine.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'element.dart';
import 'constraint.dart';

class ParameterTypes { 
  List<TypeIdentifier> normalParameterTypes = <TypeIdentifier>[];
  List<TypeIdentifier> optionalParameterTypes = <TypeIdentifier>[];
  Map<Name, TypeIdentifier> namedParameterTypes = <Name, TypeIdentifier>{};
}

class ElementTyper {
  Map<AstNode, TypeIdentifier> types = <AstNode, TypeIdentifier>{};
  Map<Identifier, ReturnTypeIdentifier> returns = <Identifier, ReturnTypeIdentifier>{};
  
  
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
      ClassElement classElement = elementAnalysis.resolveClassElement(type.name.toString(), library, source);
      if (classElement != null)
        return new NominalType(elementAnalysis.resolveClassElement(type.name.toString(), library, source));
      else 
        return null;
    }
  }
}