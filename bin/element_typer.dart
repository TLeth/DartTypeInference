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
  Map<AstNode, TypeVariable> types = <AstNode, TypeVariable>{};
  
  
  ConstraintAnalysis constraintAnalysis;
  Engine get engine => constraintAnalysis.engine;
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  
  ElementTyper(ConstraintAnalysis this.constraintAnalysis);
  
  TypeVariable typeClassMember(ClassMember element, LibraryElement library){
    if (element is MethodElement)
      return typeMethodElement(element, library);
    if (element is FieldElement)
      return typeFieldElement(element, library);
    if (element is ConstructorElement)
      return typeConstructorElement(element, library);
    
    return null;
  }
  
  AbstractType typeMethodElement(MethodElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    return types[element.ast] = new FunctionType.FromMethodElement(element, library, this);
  }
  
  AbstractType typeFieldElement(FieldElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    AbstractType res = resolveType(element.annotatedType, library, element.sourceElement);
    if (res != null)
      return types[element.ast] = res;
    else
      return types[element.ast] = new FreeType();
  }
  
  AbstractType typeConstructorElement(ConstructorElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    return types[element.ast] = new FunctionType.FromConstructorElement(element, library, this);
  }
  
  AbstractType typeClassElement(ClassElement element){
    if (types.containsKey(element.ast))
      return types[element.ast];
    return types[element.ast] = new NominalType(element);
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
  
  ParameterTypes resolveParameters(FormalParameterList paramList, LibraryElement library, SourceElement source){
    ParameterTypes types = new ParameterTypes();
    
    if (paramList.parameters == null || paramList.length == 0) 
      return types;
    
    NodeList<FormalParameter> params = paramList.parameters;
    
    for(FormalParameter param in params){
      var normalParam; 
      if (param is NormalFormalParameter) normalParam = param;
      else if (param is DefaultFormalParameter) normalParam = param.parameter;
      
      AbstractType type; 
      if (normalParam is SimpleFormalParameter || normalParam is FieldFormalParameter) {
        if (normalParam.type != null)
          type = this.resolveType(normalParam.type, library, source);
        
        if (type == null)
          type = new FreeType();
          
      } else if (normalParam is FunctionTypedFormalParameter){
        type = new FunctionType.FromFunctionTypedFormalParameter(normalParam, library, this, source);
      }
      
      if (types == null)
        return types;
      
      if (normalParam.kind == ParameterKind.REQUIRED)
        types.normalParameterTypes.add(type);
      else if (normalParam.kind == ParameterKind.POSITIONAL)
        types.optionalParameterTypes.add(type);
      else if (normalParam.kind == ParameterKind.REQUIRED)
        types.namedParameterTypes[new Name.FromIdentifier(normalParam.identifier)] = type;
    }
    
    return types;
  }
}