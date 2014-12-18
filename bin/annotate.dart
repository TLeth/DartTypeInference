library typeanalysis.annotation;

import 'engine.dart';
import 'constraint.dart';
import 'element.dart';
import 'dart:io';
import 'package:analyzer/src/services/formatter_impl.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'package:analyzer/src/generated/scanner.dart';
import 'types.dart';
import 'result.dart';
import 'generics.dart';
import 'restrict.dart';
import 'use_analysis.dart' hide MethodElement, FieldElement;

class TypeAnnotator {
  
  TypeMap typemap;
  Engine engine;
  ElementAnalysis get analysis => engine.elementAnalysis; 
  Restriction get restrict => engine.restrict;
  UseAnalysis get useAnalysis => engine.useAnalysis;
  GenericMapGenerator get genericMapGenerator => engine.genericMapGenerator;
  ClassElement get objectElement => analysis.objectElement;
  ClassElement get functionElement => analysis.functionElement;
  
  TypeAnnotator(TypeMap this.typemap, Engine this.engine);
  
  TypeName checkAnnotatedElement(Element element){
    if (element is AnnotatedElement)
      return checkAnnotation(element.annotatedType);
    return null;
  }
  
  TypeName checkAnnotation(TypeName annotation){
    if (annotation == null)
      return null;
    if (annotation.name == null)
      return null;
    if (annotation.name.toString() == 'dynamic')
      return null;
    return annotation;
  }
  
  AbstractType fixRequirements(AbstractType abstractType, Set<Name> properties){
    if (abstractType is VoidType && !properties.isEmpty)
      return new DynamicType();
    if (abstractType is! NominalType)
      return abstractType;
    
    NominalType type = abstractType;
    if (type.element.properties().containsAll(properties))
      return type;
    else
      return new DynamicType();
  }
  
  TypeName annotateNamedElement(NamedElement variable, LibraryElement library, {bool canBeVoid: false, int offset: 0, List<TypeParameterElement> validTypeParameters: null}){
    if (checkAnnotatedElement(variable) != null)
      return checkAnnotatedElement(variable);
    
    TypeIdentifier typeIdent = new ExpressionTypeIdentifier(variable.identifier);
    TypeVariable typeVariable = typemap[typeIdent];
    RestrictMap map = useAnalysis.restrictions[variable.sourceElement.source][variable];
    if (map == null) map = new RestrictMap();
    
    return annotateWithRestrictions(typeVariable.types, map.properties, variable.sourceElement.source, library, canBeVoid: canBeVoid, offset: offset, validTypeParameters: validTypeParameters);
  }
  
  TypeName annotateVariableDeclarationList(VariableDeclarationList variables, SourceElement sourceElement, LibraryElement library, {bool canBeVoid: false, int offset: 0, List<TypeParameterElement> validTypeParameters: null}){
    if (checkAnnotation(variables.type) != null)
      return checkAnnotation(variables.type);
    TypeIdentifier typeIdent = new ExpressionTypeIdentifier(variables);
    TypeVariable typeVariable = typemap[typeIdent];
    
    Set<Name> properties = new Set<Name>();
    if (variables.variables != null){
      variables.variables.forEach((VariableDeclaration variable) {
        Element variableElement = analysis.elements[variable];
         if (variableElement is VariableElement || variableElement is FieldElement) {
           RestrictMap map = useAnalysis.restrictions[sourceElement.source][variableElement];
           if (map == null) map = new RestrictMap();
           properties.addAll(map.properties);
         } else {
           engine.errors.addError(new EngineError("A VariableDeclaration was not mapped to a VariableElement or a FieldElement", sourceElement.source, variable.offset, variable.length), false);
         }
      });
    }
     
    return annotateWithRestrictions(typeVariable.types, properties, sourceElement.source, library, canBeVoid: canBeVoid, offset: offset, validTypeParameters: validTypeParameters);
  }
  
  TypeName annotateWithRestrictions(Iterable<AbstractType> abstractTypes, Set<Name> properties, Source source, LibraryElement library, {bool canBeVoid: false, int offset: 0, List<TypeParameterElement> validTypeParameters: null}){
    if (abstractTypes == null) abstractTypes = [];
    
    Set<AbstractType> focusedTypes = new Set<AbstractType>();
    
    //TODO: (jln) This should be made in the fixpoint algorithm. 
    if (abstractTypes.length == 0)
      abstractTypes = [new NominalType(analysis.objectElement)];
    
    abstractTypes.forEach((AbstractType type) =>
        focusedTypes.addAll(restrict.focus(type, properties, source)));
    
    AbstractType type = AbstractType.LeastUpperBound(focusedTypes, engine, defaultValue: new NominalType(objectElement));
    
    type = fixRequirements(type, properties);
    
    if (type is VoidType && !canBeVoid)
      type = new DynamicType();
    
    return AbstractTypeToTypeName(type, library, offset: offset, validTypeParameters: validTypeParameters);
  }
  
  TypeName annotateCallableElement(CallableElement callableElement, LibraryElement library, {bool canBeVoid: false, int offset: 0, List<TypeParameterElement> validTypeParameters: null}){
    if (checkAnnotatedElement(callableElement) != null)
      return checkAnnotatedElement(callableElement);
    
    ReturnTypeIdentifier typeIdent = new ReturnTypeIdentifier(callableElement);
    TypeVariable typeVariable = typemap[typeIdent];
    if (typeVariable == null)
      return new TypeName(new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset)), null);
    
    AbstractType type = typeVariable.getLeastUpperBound(engine);
    if (type is VoidType && !canBeVoid)
      return new TypeName(new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset)), null);
    else
      return AbstractTypeToTypeName(type, library, offset: offset, validTypeParameters: validTypeParameters);    
  }
  
  TypeName AbstractTypeToTypeName(AbstractType t, LibraryElement library, {int offset: 0, List<TypeParameterElement> validTypeParameters: null}){
    Identifier identifier = null;
    TypeArgumentList typeArguments = null;
    if (t is DynamicType)
      identifier = new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset));
    else if (t is VoidType)
      identifier = new SimpleIdentifier(new KeywordToken(Keyword.VOID, offset));
    else if (t is ParameterType) {
      if (validTypeParameters != null && validTypeParameters.contains(t.parameter)) {
        identifier = Name.ConvertToIdentifier(new Name.FromIdentifier(t.parameter.ast.name), offset);
      } else {
        identifier = new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset));
      }
    } else if (t is FunctionType) {
      //TODO (jln): this could be more specific, maybe with use of typedef.
      identifier = convertClassName(functionElement, library, offset);
    } else if (t is NominalType){
      ClassElement objectClassElement = objectElement;
      if (t.element == objectClassElement)
        identifier = new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset));
      else {
        identifier = convertClassName(t.element, library, offset);
        typeArguments = generateTypeArguments(t, library, offset: offset, validTypeParameters: validTypeParameters);
      }
    }
    return new TypeName(identifier, typeArguments);
  }
  
  TypeArgumentList generateTypeArguments(NominalType type, LibraryElement library, {int offset: 0, List<TypeParameterElement> validTypeParameters: null}) {
    if (type.genericMap == null)
      return null;
     
    Map<ParameterType, AbstractType> map = type.genericMap.get();
    
    if (map.isEmpty)
      return null;
    
    ClassElement element = type.element;

    List<TypeName> typeArguments = <TypeName>[];
    int ost = offset + 1, i = 0;
    bool allDynamic = true;
    for(TypeParameterElement parameterElement in element.typeParameters) {
      TypeName typeName = AbstractTypeToTypeName(map[new ParameterType(parameterElement)], library, offset: ost, validTypeParameters: validTypeParameters);
      ost += typeName.length;
      allDynamic = allDynamic && isDynamicType(typeName);
      if (i > 0)
        _setPreviousToken(typeName, new Token(TokenType.COMMA, ost++));
      typeArguments.add(typeName);
      i++; 
    }
    if (allDynamic)
      return null;
    
    return new TypeArgumentList(new Token(TokenType.LT, offset), typeArguments, new Token(TokenType.GT, ost + 1));
  }
  
  void _setPreviousToken(AstNode node, Token token){
    if (node is TypeName)
      _setPreviousToken(node.name, token);
    else if (node is SimpleIdentifier)
      node.token.previous = token;
    else if (node is PrefixedIdentifier)
      _setPreviousToken(node.prefix, token);
  }
  
  bool isDynamicType(dynamic node){
    if (node is TypeName)
      return isDynamicType(node.name);
    if (node is SimpleIdentifier)
      return isDynamicType(node.token);
    if (node is KeywordToken)
      return node.keyword == Keyword.DYNAMIC;
    return false;
  }
  
  Identifier convertClassName(ClassElement classElement, LibraryElement library, [int offset = 0]){
    Name n = library.names[classElement];
    if (n == null)
      //The file ClassElement could not be mapped to a name within this library.
      return new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset));
    else
      return Name.ConvertToIdentifier(n, offset);
  }
}

class Annotator {
  Engine engine;
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  ConstraintAnalysis get constraintAnalysis => engine.constraintAnalysis;
  TypeAnnotator typeAnnotator;
  Result res;
  
  Annotator(Engine this.engine){    
    this.res = new Result.Empty();

    typeAnnotator = new TypeAnnotator(engine.constraintAnalysis.typeMap, engine);
    
    elementAnalysis.sources.values.forEach(findSourceAnnotations);
    elementAnalysis.sources.values.forEach(fixVoideOverride);
    elementAnalysis.sources.values.forEach(annotateSource);
    
    if (engine.options.compareTypes) {
      stdout.writeln(res);
      
      if (engine.options.emitJSON) {
        new File('./res.json').writeAsStringSync(res.toJson());         
      }
    }
  }
  
  findSourceAnnotations(SourceElement sourceElement){
    if (sourceElement.source.uriKind == UriKind.FILE_URI) {
      
      var selection = null;

      SourceVisitor visitor = new FindAnnotationsVisitor(this, sourceElement, new FormatterOptions(), sourceElement.ast.lineInfo, sourceElement.sourceContent, selection);
      sourceElement.ast.accept(visitor);
    }
  }
  
  fixVoideOverride(SourceElement sourceElement){
    if (sourceElement.source.uriKind == UriKind.FILE_URI) {
      var selection = null;
      
      SourceVisitor visitor = new FixVoidVisitor(engine, sourceElement, new FormatterOptions(), sourceElement.ast.lineInfo, sourceElement.sourceContent, selection);
      sourceElement.ast.accept(visitor);
    }
  }
  
  annotateSource(SourceElement sourceElement){
    if (sourceElement.source.uriKind == UriKind.FILE_URI) {
      
      var selection = null;

      SourceVisitor visitor = new AnnotateSourceVisitor(engine, sourceElement, new FormatterOptions(), sourceElement.ast.lineInfo, sourceElement.sourceContent, selection);
      sourceElement.ast.accept(visitor);
      String annotatedSource = visitor.writer.toString();
      
      FormattedSource formattedSource = new FormattedSource(annotatedSource, selection);
      FormattedSource finalSource;
      try {
        CodeFormatter finisher = new CodeFormatter();
        finalSource = finisher.format(CodeKind.COMPILATION_UNIT, formattedSource.source);
      }catch (exp){
        print("Exception while trying to format source code.");
        print(formattedSource.source);
        rethrow;
      }
      
      if (engine.options.overrideFiles)
        new File.fromUri(sourceElement.source.uri).writeAsStringSync(finalSource.source);        
      else
        print(finalSource.source);
        
      if (engine.options.compareTypes && engine.options.overrideFiles){
        String actualFilePath = sourceElement.source.fullName;
        
        String expectedFilePath = actualFilePath.replaceFirst(engine.options.actualRootPath, engine.options.expectedRootPath);
        
        this.res.add(compareTypes(expectedFilePath, actualFilePath, engine, sourceElement, false));
        this.res.add(compareTypes(actualFilePath, expectedFilePath, engine, sourceElement, true));
      }
    }
  }
}

class FindAnnotationsVisitor extends SourceVisitor {
  Annotator annotator;
  ElementAnalysis get elementAnalysis => annotator.elementAnalysis;
  ConstraintAnalysis get constraintAnalysis => annotator.constraintAnalysis;
  TypeAnnotator get typeAnnotator => annotator.typeAnnotator;
  Engine get engine => annotator.engine;
  SourceElement sourceElement;
  List<TypeParameterElement> typeableParameterElements;
  
  FindAnnotationsVisitor(this.annotator, this.sourceElement, options, lineInfo, source, preSelection): super(options, lineInfo, source, preSelection);
  
  static final bool ANNOTATE_GENERIC_TYPES = false;
  static final bool ANNOTATE_METHOD_TYPES = true;
  
  visitSimpleFormalParameter(SimpleFormalParameter node) {
    super.visitSimpleFormalParameter(node);
   Element parameterElement = elementAnalysis.elements[node];
   if (parameterElement is ParameterElement) {
     parameterElement.ourAnnotatedType = typeAnnotator.annotateNamedElement(parameterElement, sourceElement.library, offset: node.offset, validTypeParameters: typeableParameterElements);
   } else {
     engine.errors.addError(new EngineError("A SimpleFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
   }
 }
  
  visitClassDeclaration(ClassDeclaration node){
    ClassElement classElement = elementAnalysis.elements[node];
    typeableParameterElements = classElement.typeParameters;
    super.visitClassDeclaration(node);
    typeableParameterElements = null;
  }
  
  visitClassTypeAlias(ClassTypeAlias node){
    ClassAliasElement classAlias = elementAnalysis.elements[node];
    typeableParameterElements = classAlias.typeParameters;
    super.visitClassTypeAlias(node);
    typeableParameterElements = null;
  }
  
  visitFunctionTypeAlias(FunctionTypeAlias node){
    FunctionAliasElement funcAlias = elementAnalysis.elements[node];
    typeableParameterElements = funcAlias.typeParameters;
    super.visitFunctionTypeAlias(node);
    typeableParameterElements = null;
  }
  
  visitFieldFormalParameter(FieldFormalParameter node) {
    super.visitFieldFormalParameter(node);
    Element parameterElement = elementAnalysis.elements[node];
    if (parameterElement is ParameterElement) {
      parameterElement.ourAnnotatedType = typeAnnotator.annotateNamedElement(parameterElement, sourceElement.library, offset: node.offset, validTypeParameters: typeableParameterElements);
    } else {
      engine.errors.addError(new EngineError("A FieldFormalParameter was not mapped to a) ParameterElement", sourceElement.source, node.offset, node.length), false);
    }
   }
  
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    super.visitFunctionTypedFormalParameter(node);
    Element functionParameterElement = elementAnalysis.elements[node];
    if (functionParameterElement is CallableElement) {
      functionParameterElement.ourAnnotatedType = typeAnnotator.annotateCallableElement(functionParameterElement, sourceElement.library, canBeVoid: true, offset: node.offset, validTypeParameters: typeableParameterElements);
    } else {
      engine.errors.addError(new EngineError("A SimpleFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
    }
  }

  visitFunctionDeclaration(FunctionDeclaration node) {
    super.visitFunctionDeclaration(node);
    Element functionElement = elementAnalysis.elements[node];
    
    if (functionElement is FunctionElement) {
      functionElement.ourAnnotatedType = typeAnnotator.annotateCallableElement(functionElement, sourceElement.library, canBeVoid: true, offset: node.offset, validTypeParameters: typeableParameterElements);
    } else {
      engine.errors.addError(new EngineError("A FunctionDeclaration was not mapped to a FunctionElement", sourceElement.source, node.offset, node.length), false);     
    }
  }

  visitVariableDeclarationList(VariableDeclarationList node) {
    super.visitVariableDeclarationList(node);
    Element variableElementList = elementAnalysis.elements[node];
        
    if (variableElementList is VariableElementList) {
      variableElementList.ourAnnotatedType = typeAnnotator.annotateVariableDeclarationList(node, sourceElement, sourceElement.library, offset: node.offset, validTypeParameters: typeableParameterElements);
    } else {
      engine.errors.addError(new EngineError("A VariableDeclarationList was not mapped to a VariableElementList", sourceElement.source, node.offset, node.length), false);     
    }
  }
  
  visitMethodDeclaration(MethodDeclaration node) { 
    super.visitMethodDeclaration(node);
    Element methodElement = elementAnalysis.elements[node];
    if (methodElement is MethodElement) {
      methodElement.ourAnnotatedType = typeAnnotator.annotateCallableElement(methodElement, sourceElement.library, canBeVoid: true, offset: node.offset, validTypeParameters: typeableParameterElements);
    } else {
      engine.errors.addError(new EngineError("A MethodDeclaration was not mapped to a MethodElement", sourceElement.source, node.offset, node.length), false);
    }
  }
}

class FixVoidVisitor extends SourceVisitor {
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  Engine engine;
  SourceElement sourceElement;
  
  bool isVoid(TypeName t) => t == null || t.name == null || t.name.toString() == 'void';
  
  FixVoidVisitor(this.engine, this.sourceElement, options, lineInfo, source, preSelection): super(options, lineInfo, source, preSelection);
  visitMethodDeclaration(MethodDeclaration node) { 
    super.visitMethodDeclaration(node);
    Element methodElement = elementAnalysis.elements[node];
    if (methodElement is MethodElement) {
      if (methodElement.ourAnnotatedType != null){
        if (methodElement.ourAnnotatedType.name == null)
          print(methodElement.ourAnnotatedType);
        if (isVoid(methodElement.ourAnnotatedType)){
          bool canBeVoid = methodElement.overrides.fold(true, (bool canBeVoid, ClassMember member) => canBeVoid && member is MethodElement && isVoid(member.ourAnnotatedType));
          if (!canBeVoid)
            methodElement.ourAnnotatedType = null; //new TypeName(new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, methodElement.ourAnnotatedType.offset)), null);
        }
      }
    } else {
      engine.errors.addError(new EngineError("A MethodDeclaration was not mapped to a MethodElement", sourceElement.source, node.offset, node.length), false);
    }
  }
}

class AnnotateSourceVisitor extends SourceVisitor {
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  Engine engine;
  SourceElement sourceElement;
    
  AnnotateSourceVisitor(this.engine, this.sourceElement, options, lineInfo, source, preSelection): super(options, lineInfo, source, preSelection);
  
  static final bool ANNOTATE_GENERIC_TYPES = false;
  static final bool ANNOTATE_METHOD_TYPES = true;
  
  visitSimpleFormalParameter(SimpleFormalParameter node) {

    visitMemberMetadata(node.metadata);

    if (node.keyword is KeywordToken) {
      KeywordToken keyword = node.keyword;
      if (keyword.keyword != Keyword.VAR)
        modifier(node.keyword);
    } else
      modifier(node.keyword);
   
   Element parameterElement = elementAnalysis.elements[node];
   if (parameterElement is ParameterElement) {
     visitNode(parameterElement.ourAnnotatedType, followedBy: nonBreakingSpace);
   } else {
     engine.errors.addError(new EngineError("A SimpleFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
   }
    
   visit(node.identifier);
 }
  
  visitFieldFormalParameter(FieldFormalParameter node) {
     token(node.keyword, followedBy: space);
     
      Element parameterElement = elementAnalysis.elements[node];
      if (parameterElement is ParameterElement) {
        visitNode(parameterElement.ourAnnotatedType, followedBy: space);
      } else {
        engine.errors.addError(new EngineError("A FieldFormalParameter was not mapped to a) ParameterElement", sourceElement.source, node.offset, node.length), false);
      }
  
     token(node.thisToken);
     token(node.period);
     visit(node.identifier);
     visit(node.parameters);
   }
  
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    Element functionParameterElement = elementAnalysis.elements[node];
    if (functionParameterElement is CallableElement) {
      visitNode(functionParameterElement.ourAnnotatedType, followedBy: space);
    } else {
      engine.errors.addError(new EngineError("A SimpleFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
    }
    
    visit(node.identifier);
    visit(node.parameters);
  }

  visitFunctionDeclaration(FunctionDeclaration node) {
    preserveLeadingNewlines();
    visitMemberMetadata(node.metadata);
    modifier(node.externalKeyword);
    Element functionElement = elementAnalysis.elements[node];
    
    if (functionElement is FunctionElement) {
      visitNode(functionElement.ourAnnotatedType, followedBy: space);
    } else {
      engine.errors.addError(new EngineError("A FunctionDeclaration was not mapped to a FunctionElement", sourceElement.source, node.offset, node.length), false);     
    }
  
  
    modifier(node.propertyKeyword);
    visit(node.name);
    visit(node.functionExpression);
  }

  visitVariableDeclarationList(VariableDeclarationList node) {
    
    visitMemberMetadata(node.metadata);
    
    
    if (node.keyword is KeywordToken) {
      KeywordToken keyword = node.keyword;
      if (keyword.keyword != Keyword.VAR)
        modifier(node.keyword);
    } else
      modifier(node.keyword);

    Element variableElementList = elementAnalysis.elements[node];
    if (variableElementList is VariableElementList) {
      visitNode(variableElementList.ourAnnotatedType, followedBy: space);
    } else {
      engine.errors.addError(new EngineError("A MethodDeclaration was not mapped to a MethodElement", sourceElement.source, node.offset, node.length), false);
    }

    var variables = node.variables;
    // Decls with initializers get their own lines (dartbug.com/16849)
    if (variables.any((v) => (v.initializer != null))) {
      var size = variables.length;
      if (size > 0) {
        var variable;
        for (var i = 0; i < size; i++) {
          variable = variables[i];
          if (i > 0) {
            var comma = variable.beginToken.previous;
            token(comma);
            newlines();
          }
          if (i == 1) {
            indent(2);
          }
          variable.accept(this);
        }
        if (size > 1) {
          unindent(2);
        }
      }
    } else {
      visitCommaSeparatedNodes(node.variables);
    }
  }
  
  visitMethodDeclaration(MethodDeclaration node) {
      visitMemberMetadata(node.metadata);
      modifier(node.externalKeyword);
      modifier(node.modifierKeyword); 
      
      Element methodElement = elementAnalysis.elements[node];
      if (methodElement is MethodElement) {
        visitNode(methodElement.ourAnnotatedType, followedBy: space);
      } else {
        engine.errors.addError(new EngineError("A MethodDeclaration was not mapped to a MethodElement", sourceElement.source, node.offset, node.length), false);
      }
      
      modifier(node.propertyKeyword);
      modifier(node.operatorKeyword);
      visit(node.name);
      if (!node.isGetter) {
        visit(node.parameters);
      }
      visitPrefixedBody(nonBreakingSpace, node.body);
    }

}