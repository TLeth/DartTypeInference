library typeanalysis.annotation;

import 'engine.dart';
import 'constraint.dart';
import 'element.dart';
import 'dart:io';
import 'package:analyzer/src/services/formatter_impl.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'types.dart';

class TypeAnnotator {
  
  TypeMap typemap;
  ElementAnalysis analysis;
  
  TypeAnnotator(TypeMap this.typemap, ElementAnalysis this.analysis);
  
  TypeName annotateIdentifier(Identifier identifier, [int offset = 0]){
    TypeIdentifier typeIdent = new ExpressionTypeIdentifier(identifier);
    return annotateTypeIdentifier(typeIdent, offset);
  }
  
  TypeName annotateTypeIdentifier(TypeIdentifier typeIdent, [int offset = 0]){
    TypeVariable typeVariable = typemap[typeIdent];
    if (typeVariable == null)
      return new TypeName(new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset)), null);
    else 
      return AbstractTypeToTypeName(typeVariable.getLeastUpperBound(), offset);
  }
  
  TypeName AbstractTypeToTypeName(AbstractType t, [int offset = 0]){
    SimpleIdentifier identifier = null;
    if (t is DynamicType)
      identifier = new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset));
    else if (t is VoidType)
      identifier = new SimpleIdentifier(new KeywordToken(Keyword.VOID, offset));
    else if (t is FunctionType)
      //This sould be more specific.
      identifier = new SimpleIdentifier(new StringToken(TokenType.IDENTIFIER, 'Function', offset));
    else if (t is NominalType){
      ClassElement objectClassElement = analysis.resolveClassElement(new Name("Object"), analysis.dartCore, analysis.dartCore.source);
      if (t.element == objectClassElement)
        identifier = new SimpleIdentifier(new KeywordToken(Keyword.DYNAMIC, offset));
      else
        identifier = new SimpleIdentifier(new StringToken(TokenType.IDENTIFIER, t.toString(), offset));
    }
    
    return new TypeName(identifier, null);
  }
}

class Annotator {
  Engine engine;
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  ConstraintAnalysis get constraintAnalysis => engine.constraintAnalysis;
  TypeAnnotator typeAnnotator;
  
  Annotator(Engine this.engine){    
    typeAnnotator = new TypeAnnotator(engine.constraintAnalysis.typeMap, elementAnalysis);
    
    elementAnalysis.sources.values.forEach(annotateSource); 
  }
  
  annotateSource(SourceElement sourceElement){
    if (sourceElement.source.uriKind == UriKind.FILE_URI) {
      var selection = null;
      
      

      var annotateVisitor = new AnnotateSourceVisitor(this, sourceElement, new FormatterOptions(), sourceElement.ast.lineInfo, sourceElement.sourceContent, selection);
      sourceElement.ast.accept(annotateVisitor);
      String annotatedSource = annotateVisitor.writer.toString();
      
      FormattedSource formattedSource = new FormattedSource(annotatedSource, selection);
      
      CodeFormatter finisher = new CodeFormatter();
      formattedSource = finisher.format(CodeKind.COMPILATION_UNIT, formattedSource.source);
      
      new File.fromUri(sourceElement.source.uri).writeAsStringSync(formattedSource.source);
    }
  }
}

//This should be a visitor making all the visits the strip visitor does.
class AnnotateSourceVisitor extends SourceVisitor {
  Annotator annotator;
  ElementAnalysis get elementAnalysis => annotator.elementAnalysis;
  ConstraintAnalysis get constraintAnalysis => annotator.constraintAnalysis;
  TypeAnnotator get typeAnnotator => annotator.typeAnnotator;
  Engine get engine => annotator.engine;
  SourceElement sourceElement;
  
  AnnotateSourceVisitor(this.annotator, this.sourceElement, options, lineInfo, source, preSelection): super(options, lineInfo, source, preSelection);
  
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
     visitNode(typeAnnotator.annotateIdentifier(parameterElement.identifier), followedBy: nonBreakingSpace);
   } else {
     engine.errors.addError(new EngineError("A SimpleFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
   }
    
   visit(node.identifier);
 }
  
  visitFieldFormalParameter(FieldFormalParameter node) {
     token(node.keyword, followedBy: space);
     
      Element parameterElement = elementAnalysis.elements[node];
      if (parameterElement is ParameterElement) {
        visitNode(typeAnnotator.annotateIdentifier(parameterElement.identifier), followedBy: space);
      } else {
        engine.errors.addError(new EngineError("A FieldFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
      }
  
     token(node.thisToken);
     token(node.period);
     visit(node.identifier);
     visit(node.parameters);
   }

  visitFunctionDeclaration(FunctionDeclaration node) {

    preserveLeadingNewlines();
    visitMemberMetadata(node.metadata);
    modifier(node.externalKeyword);
    Element functionElement = elementAnalysis.elements[node];
    if (functionElement is FunctionElement) {
      ReturnTypeIdentifier typeIdent = new ReturnTypeIdentifier(functionElement);
      visitNode(typeAnnotator.annotateTypeIdentifier(typeIdent), followedBy: space);
    } else {
      engine.errors.addError(new EngineError("A FunctionDeclaration was not mapped to a FunctionElement", sourceElement.source, node.offset, node.length), false);     
    }
  
  
    modifier(node.propertyKeyword);
    visit(node.name);
    visit(node.functionExpression);
  }

  
  //TODO (jln): variable declarations from the benchmarks can for now only contain one variable but should be able to contain more.
  visitVariableDeclarationList(VariableDeclarationList node) {
    
    visitMemberMetadata(node.metadata);
    
    
    if (node.keyword is KeywordToken) {
      KeywordToken keyword = node.keyword;
      if (keyword.keyword != Keyword.VAR)
        modifier(node.keyword);
    } else
      modifier(node.keyword);
    
    if (node.variables.length > 0) {
      Element variableElement = elementAnalysis.elements[node.variables[0]];
      if (variableElement is NamedElement) {
        visitNode(typeAnnotator.annotateIdentifier(variableElement.identifier), followedBy: space);
      } else {
        engine.errors.addError(new EngineError("A VariableDeclaration was not mapped to a NamedElement", sourceElement.source, node.variables[0].offset, node.variables[0].length), false);
      }
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
        ReturnTypeIdentifier typeIdent = new ReturnTypeIdentifier(methodElement);
        visitNode(typeAnnotator.annotateTypeIdentifier(typeIdent), followedBy: space);
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
  
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    Element functionParameterElement = elementAnalysis.elements[node];
    if (functionParameterElement is CallableElement) {
      ReturnTypeIdentifier typeIdent = new ReturnTypeIdentifier(functionParameterElement);
      visitNode(typeAnnotator.annotateTypeIdentifier(typeIdent), followedBy: space);
    } else {
      engine.errors.addError(new EngineError("A SimpleFormalParameter was not mapped to a ParameterElement", sourceElement.source, node.offset, node.length), false);
    }
    
    visit(node.identifier);
    visit(node.parameters);
  }  

}