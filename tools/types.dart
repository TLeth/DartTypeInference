#!/usr/bin/env dart

import 'package:analyzer/src/generated/java_io.dart';
import 'dart:io';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/error.dart';


class Result {
  int type_mismatch = 0;
  int generic_misses = 0;
  int generic_mismatch = 0;
  Result(int this.type_mismatch);
  factory Result.Empty() => new Result(0);

  void add(Result other){
    this.type_mismatch += other.type_mismatch;
    this.generic_misses += other.generic_misses;
    this.generic_mismatch += other.generic_mismatch;
  }

  String toString() => "${type_mismatch} ${generic_misses} ${generic_mismatch}";
}

//expected always non-null
//actual may be null
Result classify(TypeName expected, TypeName actual) {
  Result res = new Result(0);
  if (actual == null || 
      actual.name.toString() != expected.name.toString()) res.type_mismatch++;
  
  if (actual != null && (expected.typeArguments != null && actual.typeArguments == null || expected.typeArguments == null && actual.typeArguments != null))
    res.generic_misses++;
  
  if (actual != null && (expected.typeArguments != null && actual.typeArguments != null)) {
    NodeList<TypeName> a = actual.typeArguments.arguments, b = expected.typeArguments.arguments;
    if (a.length < b.length){
      a = b;
      b = actual.typeArguments.arguments;
    }
    
    //generic mismatches can only be counted as one.
    for(var i = 0; i < a.length; i++){
      if (b.length <= i) {
        res.generic_mismatch++;
      } else {
        Result r = classify(a[i], b[i]);
        if (r.type_mismatch > 0) res.generic_mismatch++;
      }
    }
      
  }
   
  
  return res;
}

main(List<String> args) {

    JavaFile a = new JavaFile(args[0]);  
    CompilationUnit expected, actual;
    
    expected = getCompilationUnit(new FileBasedSource.con1(new JavaFile(args[0])));
    actual = getCompilationUnit(new FileBasedSource.con1(new JavaFile(args[1])));
    
    print(expected.accept(new TwinVisitor())(actual));
  
}

CompilationUnit getCompilationUnit(Source source) {
  RecordingErrorListener errorListener = new RecordingErrorListener();
  
  String content = source.contents.data;
  AnalysisOptions options = new AnalysisOptionsImpl();
  Scanner scanner = new Scanner(source, new CharSequenceReader(content), errorListener);
  scanner.preserveComments = options.preserveComments;
  Token tokenStream= scanner.tokenize();
  LineInfo lineInfo = new LineInfo(scanner.lineStarts);
  List<AnalysisError> errors = errorListener.getErrorsForSource(source);
  
  if (errors.length > 0) {
    print(errors);
    exit(0);
  }
  
  Parser parser = new Parser(source, errorListener);
  parser.parseFunctionBodies = options.analyzeFunctionBodies;
  parser.parseAsync = options.enableAsync;
  parser.parseDeferredLibraries = options.enableDeferredLoading;
  parser.parseEnum = options.enableEnum;
  CompilationUnit unit = parser.parseCompilationUnit(tokenStream);
  unit.lineInfo = lineInfo;
  
  errors = errorListener.getErrorsForSource(source);
  if (errors.length > 0) {
    print(errors);
    exit(0);
  }
  return unit;
}

class TwinVisitor extends GeneralizingAstVisitor {

  visitTypeName(TypeName expectedNode){
    return (TypeName actualNode){
      return classify(expectedNode, actualNode);
      /*

      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.typeArguments != null) {
          res.add(expectedNode.typeArguments.accept(this)(actualNode.typeArguments));
        }
      }
      return res;
      */
    };
  }
  
  visitAdjacentStrings(AdjacentStrings expectedNode){
    return (AdjacentStrings actualNode){
      var res = new Result.Empty();
      //visitStringLiteral(node);
      {
        int i = 0;
        expectedNode.strings.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.strings[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitAnnotatedNode(AnnotatedNode expectedNode){
    return (AnnotatedNode actualNode){
      var res = new Result.Empty();
      //COMMENTS ANNOTATIONS
      return res;
    };
  }
  


  visitAnnotation(Annotation expectedNode){
    return (Annotation actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.constructorName != null) {
          res.add(expectedNode.constructorName.accept(this)(actualNode.constructorName));
        }
        if (expectedNode.arguments != null) {
          res.add(expectedNode.arguments.accept(this)(actualNode.arguments));
        }
      }
      return res;
    };
  }

  
  visitArgumentList(ArgumentList expectedNode){
    return (ArgumentList actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.arguments.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.arguments[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitAsExpression(AsExpression expectedNode){
    return (AsExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
      }
      return res;
    };
  }

  
  visitAssertStatement(AssertStatement expectedNode){
    return (AssertStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.condition != null) {
          res.add(expectedNode.condition.accept(this)(actualNode.condition));
        }
      }
      return res;
    };
  }

  
  visitAssignmentExpression(AssignmentExpression expectedNode){
    return (AssignmentExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.leftHandSide != null) {
          res.add(expectedNode.leftHandSide.accept(this)(actualNode.leftHandSide));
        }
        if (expectedNode.rightHandSide != null) {
          res.add(expectedNode.rightHandSide.accept(this)(actualNode.rightHandSide));
        }
      }
      return res;
    };
  }

  
  visitAwaitExpression(AwaitExpression expectedNode){
    return (AwaitExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitBinaryExpression(BinaryExpression expectedNode){
    return (BinaryExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.leftOperand != null) {
          res.add(expectedNode.leftOperand.accept(this)(actualNode.leftOperand));
        }
        if (expectedNode.rightOperand != null) {
          res.add(expectedNode.rightOperand.accept(this)(actualNode.rightOperand));
        }
      }
      return res;
    };
  }

  
  visitBlock(Block expectedNode){
    return (Block actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        int i = 0;
        expectedNode.statements.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.statements[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitBlockFunctionBody(BlockFunctionBody expectedNode){
    return (BlockFunctionBody actualNode){
      var res = new Result.Empty();
      //visitFunctionBody(node);
      {
        if (expectedNode.block != null) {
          res.add(expectedNode.block.accept(this)(actualNode.block));
        }
      }
      return res;
    };
  }

  
  visitBooleanLiteral(BooleanLiteral expectedNode){
    return (BooleanLiteral actualNode){
      var res = new Result.Empty();
      //visitLiteral(node);
      {
      }
      return res;
    };
  }

  
  visitBreakStatement(BreakStatement expectedNode){
    return (BreakStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.label != null) {
          res.add(expectedNode.label.accept(this)(actualNode.label));
        }
      }
      return res;
    };
  }

  
  visitCascadeExpression(CascadeExpression expectedNode){
    return (CascadeExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.target != null) {
          res.add(expectedNode.target.accept(this)(actualNode.target));
        }
        int i = 0;
        expectedNode.cascadeSections.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.cascadeSections[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitCatchClause(CatchClause expectedNode){
    return (CatchClause actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.exceptionType != null) {
          res.add(expectedNode.exceptionType.accept(this)(actualNode.exceptionType));
        }
        if (expectedNode.exceptionParameter != null) {
          res.add(expectedNode.exceptionParameter.accept(this)(actualNode.exceptionParameter));
        }
        if (expectedNode.stackTraceParameter != null) {
          res.add(expectedNode.stackTraceParameter.accept(this)(actualNode.stackTraceParameter));
        }
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  
  visitClassDeclaration(ClassDeclaration expectedNode){
    return (ClassDeclaration actualNode){
      var res = new Result.Empty();
      //visitCompilationUnitMember(node);
      {
        //super.visitChildren(visitor); //class ClassDeclaration extends CompilationUnitMember {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.typeParameters != null) {
          res.add(expectedNode.typeParameters.accept(this)(actualNode.typeParameters));
        }
        if (expectedNode.extendsClause != null) {
          res.add(expectedNode.extendsClause.accept(this)(actualNode.extendsClause));
        }
        if (expectedNode.withClause != null) {
          res.add(expectedNode.withClause.accept(this)(actualNode.withClause));
        }
        if (expectedNode.implementsClause != null) {
          res.add(expectedNode.implementsClause.accept(this)(actualNode.implementsClause));
        }
        if (expectedNode.nativeClause != null) {
          res.add(expectedNode.nativeClause.accept(this)(actualNode.nativeClause));
        }
        int i = 0;
        expectedNode.members.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.members[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitClassMember(ClassMember expectedNode){
    return (ClassMember actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitClassTypeAlias(ClassTypeAlias expectedNode){
    return (ClassTypeAlias actualNode){
      var res = new Result.Empty();
      //visitTypeAlias(node);
      {
        //super.visitChildren(visitor); //class ClassTypeAlias extends TypeAlias {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.typeParameters != null) {
          res.add(expectedNode.typeParameters.accept(this)(actualNode.typeParameters));
        }
        if (expectedNode.superclass != null) {
          res.add(expectedNode.superclass.accept(this)(actualNode.superclass));
        }
        if (expectedNode.withClause != null) {
          res.add(expectedNode.withClause.accept(this)(actualNode.withClause));
        }
        if (expectedNode.implementsClause != null) {
          res.add(expectedNode.implementsClause.accept(this)(actualNode.implementsClause));
        }
      }
      return res;
    };
  }

  visitCombinator(Combinator expectedNode){
    return (Combinator actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitComment(Comment expectedNode){
    return (Comment actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.references.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.references[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitCommentReference(CommentReference expectedNode){
    return (CommentReference actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
      }
      return res;
    };
  }

  
  visitCompilationUnit(CompilationUnit expectedNode){
    return (CompilationUnit actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.scriptTag != null) {
          res.add(expectedNode.scriptTag.accept(this)(actualNode.scriptTag));
        }          
          int i = 0;
          expectedNode.directives.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.directives[i]));
            i++;
            return res;
          });
          
          i = 0;
          expectedNode.declarations.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.declarations[i]));
            i++;
            return res;
          });
          

      }
      return res;
    };
  }

  visitCompilationUnitMember(CompilationUnitMember expectedNode){
    return (CompilationUnitMember actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitConditionalExpression(ConditionalExpression expectedNode){
    return (ConditionalExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.condition != null) {
          res.add(expectedNode.condition.accept(this)(actualNode.condition));
        }
        if (expectedNode.thenExpression != null) {
          res.add(expectedNode.thenExpression.accept(this)(actualNode.thenExpression));
        }
        if (expectedNode.elseExpression != null) {
          res.add(expectedNode.elseExpression.accept(this)(actualNode.elseExpression));
        }
      }
      return res;
    };
  }

  
  visitConstructorDeclaration(ConstructorDeclaration expectedNode){
    return (ConstructorDeclaration actualNode){
      var res = new Result.Empty();
      //visitClassMember(node);
      {
        //super.visitChildren(visitor); //class ConstructorDeclaration extends ClassMember {
        if (expectedNode.returnType != null) {
          res.add(expectedNode.returnType.accept(this)(actualNode.returnType));
        }
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.parameters != null) {
          res.add(expectedNode.parameters.accept(this)(actualNode.parameters));
        }
        int i = 0;
        expectedNode.initializers.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.initializers[i]));
          i++;
          return res;
        });
        if (expectedNode.redirectedConstructor != null) {
          res.add(expectedNode.redirectedConstructor.accept(this)(actualNode.redirectedConstructor));
        }
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  
  visitConstructorFieldInitializer(ConstructorFieldInitializer expectedNode){
    return (ConstructorFieldInitializer actualNode){
      var res = new Result.Empty();
      //visitConstructorInitializer(node);
      {
        if (expectedNode.fieldName != null) {
          res.add(expectedNode.fieldName.accept(this)(actualNode.fieldName));
        }
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  visitConstructorInitializer(ConstructorInitializer expectedNode){
    return (ConstructorInitializer actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitConstructorName(ConstructorName expectedNode){
    return (ConstructorName actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
      }
      return res;
    };
  }

  
  visitContinueStatement(ContinueStatement expectedNode){
    return (ContinueStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.label != null) {
          res.add(expectedNode.label.accept(this)(actualNode.label));
        }
      }
      return res;
    };
  }

  visitDeclaration(Declaration expectedNode){
    return (Declaration actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitDeclaredIdentifier(DeclaredIdentifier expectedNode){
    return (DeclaredIdentifier actualNode){
      var res = new Result.Empty();
      //visitDeclaration(node);
      {
        //super.visitChildren(visitor); //class DeclaredIdentifier extends Declaration {
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
      }
      return res;
    };
  }

  
  visitDefaultFormalParameter(DefaultFormalParameter expectedNode){
    return (DefaultFormalParameter actualNode){
      var res = new Result.Empty();
      //visitFormalParameter(node);
      {
        if (expectedNode.parameter != null) {
          res.add(expectedNode.parameter.accept(this)(actualNode.parameter));
        }
        if (expectedNode.defaultValue != null) {
          res.add(expectedNode.defaultValue.accept(this)(actualNode.defaultValue));
        }
      }
      return res;
    };
  }

  visitDirective(Directive expectedNode){
    return (Directive actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitDoStatement(DoStatement expectedNode){
    return (DoStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
        if (expectedNode.condition != null) {
          res.add(expectedNode.condition.accept(this)(actualNode.condition));
        }
      }
      return res;
    };
  }

  
  visitDoubleLiteral(DoubleLiteral expectedNode){
    return (DoubleLiteral actualNode){
      var res = new Result.Empty();
      //visitLiteral(node);
      {
      }
      return res;
    };
  }

  
  visitEmptyFunctionBody(EmptyFunctionBody expectedNode){
    return (EmptyFunctionBody actualNode){
      var res = new Result.Empty();
      //visitFunctionBody(node);
      {
      }
      return res;
    };
  }

  
  visitEmptyStatement(EmptyStatement expectedNode){
    return (EmptyStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
      }
      return res;
    };
  }

  
  visitEnumConstantDeclaration(EnumConstantDeclaration expectedNode){
    return (EnumConstantDeclaration actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitEnumDeclaration(EnumDeclaration expectedNode){
    return (EnumDeclaration actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitExportDirective(ExportDirective expectedNode){
    return (ExportDirective actualNode){
      var res = new Result.Empty();
      //visitNamespaceDirective(node);
      {
        //super.visitChildren(visitor); //class ExportDirective extends NamespaceDirective {
        {
          int i = 0;
          expectedNode.combinators.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.combinators[i]));
            i++;
            return res;
          });
        }
      }
      return res;
    };
  }

  visitExpression(Expression expectedNode){
    return (Expression actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitExpressionFunctionBody(ExpressionFunctionBody expectedNode){
    return (ExpressionFunctionBody actualNode){
      var res = new Result.Empty();
      //visitFunctionBody(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitExpressionStatement(ExpressionStatement expectedNode){
    return (ExpressionStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitExtendsClause(ExtendsClause expectedNode){
    return (ExtendsClause actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.superclass != null) {
          res.add(expectedNode.superclass.accept(this)(actualNode.superclass));
        }
      }
      return res;
    };
  }

  
  visitFieldDeclaration(FieldDeclaration expectedNode){
    return (FieldDeclaration actualNode){
      var res = new Result.Empty();
      //visitClassMember(node);
      {
        //super.visitChildren(visitor); //class FieldDeclaration extends ClassMember {
        if (expectedNode.fields != null) {
          res.add(expectedNode.fields.accept(this)(actualNode.fields));
        }
      }
      return res;
    };
  }

  
  visitFieldFormalParameter(FieldFormalParameter expectedNode){
    return (FieldFormalParameter actualNode){
      var res = new Result.Empty();
      //visitNormalFormalParameter(node);
      {
        //super.visitChildren(visitor); //class FieldFormalParameter extends NormalFormalParameter {
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
        if (expectedNode.parameters != null) {
          res.add(expectedNode.parameters.accept(this)(actualNode.parameters));
        }
      }
      return res;
    };
  }

  
  visitForEachStatement(ForEachStatement expectedNode){
    return (ForEachStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.loopVariable != null) {
          res.add(expectedNode.loopVariable.accept(this)(actualNode.loopVariable));
        }
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
        if (expectedNode.iterator != null) {
          res.add(expectedNode.iterator.accept(this)(actualNode.iterator));
        }
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  visitFormalParameter(FormalParameter expectedNode){
    return (FormalParameter actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitFormalParameterList(FormalParameterList expectedNode){
    return (FormalParameterList actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.parameters.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.parameters[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitForStatement(ForStatement expectedNode){
    return (ForStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.variables != null) {
          res.add(expectedNode.variables.accept(this)(actualNode.variables));
        }
        if (expectedNode.initialization != null) {
          res.add(expectedNode.initialization.accept(this)(actualNode.initialization));
        }
        if (expectedNode.condition != null) {
          res.add(expectedNode.condition.accept(this)(actualNode.condition));
        }
        int i = 0;
        expectedNode.updaters.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.updaters[i]));
          i++;
          return res;
        });
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  visitFunctionBody(FunctionBody expectedNode){
    return (FunctionBody actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitFunctionDeclaration(FunctionDeclaration expectedNode){
    return (FunctionDeclaration actualNode){
      var res = new Result.Empty();
      //visitCompilationUnitMember(node);
      {
        //super.visitChildren(visitor); //class FunctionDeclaration extends CompilationUnitMember {
        if (expectedNode.returnType != null) {
          res.add(expectedNode.returnType.accept(this)(actualNode.returnType));
        }
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.functionExpression != null) {
          res.add(expectedNode.functionExpression.accept(this)(actualNode.functionExpression));
        }
      }
      return res;
    };
  }

  
  visitFunctionDeclarationStatement(FunctionDeclarationStatement expectedNode){
    return (FunctionDeclarationStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.functionDeclaration != null) {
          res.add(expectedNode.functionDeclaration.accept(this)(actualNode.functionDeclaration));
        }
      }
      return res;
    };
  }

  
  visitFunctionExpression(FunctionExpression expectedNode){
    return (FunctionExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.parameters != null) {
          res.add(expectedNode.parameters.accept(this)(actualNode.parameters));
        }
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  
  visitFunctionExpressionInvocation(FunctionExpressionInvocation expectedNode){
    return (FunctionExpressionInvocation actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.function != null) {
          res.add(expectedNode.function.accept(this)(actualNode.function));
        }
        if (expectedNode.argumentList != null) {
          res.add(expectedNode.argumentList.accept(this)(actualNode.argumentList));
        }
      }
      return res;
    };
  }

  
  visitFunctionTypeAlias(FunctionTypeAlias expectedNode){
    return (FunctionTypeAlias actualNode){
      var res = new Result.Empty();
      //visitTypeAlias(node);
      {
        //super.visitChildren(visitor); //class FunctionTypeAlias extends TypeAlias {
        if (expectedNode.returnType != null) {
          res.add(expectedNode.returnType.accept(this)(actualNode.returnType));
        }
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.typeParameters != null) {
          res.add(expectedNode.typeParameters.accept(this)(actualNode.typeParameters));
        }
        if (expectedNode.parameters != null) {
          res.add(expectedNode.parameters.accept(this)(actualNode.parameters));
        }
      }
      return res;
    };
  }

  
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter expectedNode){
    return (FunctionTypedFormalParameter actualNode){
      var res = new Result.Empty();
      //visitNormalFormalParameter(node);
      {
        //super.visitChildren(visitor); //class FunctionTypedFormalParameter extends NormalFormalParameter {
        if (expectedNode.returnType != null) {
          res.add(expectedNode.returnType.accept(this)(actualNode.returnType));
        }
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
        if (expectedNode.parameters != null) {
          res.add(expectedNode.parameters.accept(this)(actualNode.parameters));
        }
      }
      return res;
    };
  }

  
  visitHideCombinator(HideCombinator expectedNode){
    return (HideCombinator actualNode){
      var res = new Result.Empty();
      //visitCombinator(node);
      {
        int i = 0;
        expectedNode.hiddenNames.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.hiddenNames[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitIdentifier(Identifier expectedNode){
    return (Identifier actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitIfStatement(IfStatement expectedNode){
    return (IfStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.condition != null) {
          res.add(expectedNode.condition.accept(this)(actualNode.condition));
        }
        if (expectedNode.thenStatement != null) {
          res.add(expectedNode.thenStatement.accept(this)(actualNode.thenStatement));
        }
        if (expectedNode.elseStatement != null) {
          res.add(expectedNode.elseStatement.accept(this)(actualNode.elseStatement));
        }
      }
      return res;
    };
  }

  
  visitImplementsClause(ImplementsClause expectedNode){
    return (ImplementsClause actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.interfaces.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.interfaces[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitImportDirective(ImportDirective expectedNode){
    return (ImportDirective actualNode){
      var res = new Result.Empty();
      //visitNamespaceDirective(node);
      {
        //super.visitChildren(visitor); //class ImportDirective extends NamespaceDirective {
        if (expectedNode.prefix != null) {
          res.add(expectedNode.prefix.accept(this)(actualNode.prefix));
        }
        {
          int i = 0;
          expectedNode.combinators.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.combinators[i]));
            i++;
            return res;
          });
        }
      }
      return res;
    };
  }

  
  visitIndexExpression(IndexExpression expectedNode){
    return (IndexExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.target != null) {
          res.add(expectedNode.target.accept(this)(actualNode.target));
        }
        if (expectedNode.index != null) {
          res.add(expectedNode.index.accept(this)(actualNode.index));
        }
      }
      return res;
    };
  }

  
  visitInstanceCreationExpression(InstanceCreationExpression expectedNode){
    return (InstanceCreationExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.constructorName != null) {
          res.add(expectedNode.constructorName.accept(this)(actualNode.constructorName));
        }
        if (expectedNode.argumentList != null) {
          res.add(expectedNode.argumentList.accept(this)(actualNode.argumentList));
        }
      }
      return res;
    };
  }

  
  visitIntegerLiteral(IntegerLiteral expectedNode){
    return (IntegerLiteral actualNode){
      var res = new Result.Empty();
      //visitLiteral(node);
      {
      }
      return res;
    };
  }

  visitInterpolationElement(InterpolationElement expectedNode){
    return (InterpolationElement actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitInterpolationExpression(InterpolationExpression expectedNode){
    return (InterpolationExpression actualNode){
      var res = new Result.Empty();
      //visitInterpolationElement(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitInterpolationString(InterpolationString expectedNode){
    return (InterpolationString actualNode){
      var res = new Result.Empty();
      //visitInterpolationElement(node);
      {
      }
      return res;
    };
  }

  
  visitIsExpression(IsExpression expectedNode){
    return (IsExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
      }
      return res;
    };
  }

  
  visitLabel(Label expectedNode){
    return (Label actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.label != null) {
          res.add(expectedNode.label.accept(this)(actualNode.label));
        }
      }
      return res;
    };
  }

  
  visitLabeledStatement(LabeledStatement expectedNode){
    return (LabeledStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        int i = 0;
        expectedNode.labels.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.labels[i]));
          i++;
          return res;
        });
        if (expectedNode.statement != null) {
          res.add(expectedNode.statement.accept(this)(actualNode.statement));
        }
      }
      return res;
    };
  }

  
  visitLibraryDirective(LibraryDirective expectedNode){
    return (LibraryDirective actualNode){
      var res = new Result.Empty();
      //visitDirective(node);
      {
        //super.visitChildren(visitor); //class LibraryDirective extends Directive {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
      }
      return res;
    };
  }

  
  visitLibraryIdentifier(LibraryIdentifier expectedNode){
    return (LibraryIdentifier actualNode){
      var res = new Result.Empty();
      //visitIdentifier(node);
      {
        int i = 0;
        expectedNode.components.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.components[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitListLiteral(ListLiteral expectedNode){
    return (ListLiteral actualNode){
      var res = new Result.Empty();
      //visitTypedLiteral(node);
      {
        //super.visitChildren(visitor); //class ListLiteral extends TypedLiteral {
        int i = 0;
        expectedNode.elements.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.elements[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitLiteral(Literal expectedNode){
    return (Literal actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitMapLiteral(MapLiteral expectedNode){
    return (MapLiteral actualNode){
      var res = new Result.Empty();
      //visitTypedLiteral(node);
      {
        //super.visitChildren(visitor); //class MapLiteral extends TypedLiteral {
        int i = 0;
        expectedNode.entries.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.entries[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitMapLiteralEntry(MapLiteralEntry expectedNode){
    return (MapLiteralEntry actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.key != null) {
          res.add(expectedNode.key.accept(this)(actualNode.key));
        }
        if (expectedNode.value != null) {
          res.add(expectedNode.value.accept(this)(actualNode.value));
        }
      }
      return res;
    };
  }

  
  visitMethodDeclaration(MethodDeclaration expectedNode){
    return (MethodDeclaration actualNode){
      var res = new Result.Empty();
      //visitClassMember(node);
      {
        //super.visitChildren(visitor); //class MethodDeclaration extends ClassMember {
        if (expectedNode.returnType != null) {
          res.add(expectedNode.returnType.accept(this)(actualNode.returnType));
        }
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.parameters != null) {
          res.add(expectedNode.parameters.accept(this)(actualNode.parameters));
        }
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  
  visitMethodInvocation(MethodInvocation expectedNode){
    return (MethodInvocation actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.target != null) {
          res.add(expectedNode.target.accept(this)(actualNode.target));
        }
        if (expectedNode.methodName != null) {
          res.add(expectedNode.methodName.accept(this)(actualNode.methodName));
        }
        if (expectedNode.argumentList != null) {
          res.add(expectedNode.argumentList.accept(this)(actualNode.argumentList));
        }
      }
      return res;
    };
  }

  
  visitNamedExpression(NamedExpression expectedNode){
    return (NamedExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  visitNamespaceDirective(NamespaceDirective expectedNode){
    return (NamespaceDirective actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitNativeClause(NativeClause expectedNode){
    return (NativeClause actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
      }
      return res;
    };
  }

  
  visitNativeFunctionBody(NativeFunctionBody expectedNode){
    return (NativeFunctionBody actualNode){
      var res = new Result.Empty();
      //visitFunctionBody(node);
      {
        if (expectedNode.stringLiteral != null) {
          res.add(expectedNode.stringLiteral.accept(this)(actualNode.stringLiteral));
        }
      }
      return res;
    };
  }

  /*
  visitNode(AstNode expectedNode) {
    return (AstNode actualNode){
      var res = new Result.Empty();
      //node.visitChildren(this);
      return null;
      return res;
    };
  }
  */

  visitNormalFormalParameter(NormalFormalParameter expectedNode){
    return (NormalFormalParameter actualNode){
      var res = new Result.Empty();
      //COMMENT ANNOTATIONS
      return res;
    };
  }

  
  visitNullLiteral(NullLiteral expectedNode){
    return (NullLiteral actualNode){
      var res = new Result.Empty();
      //visitLiteral(node);
      {
      }
      return res;
    };
  }

  
  visitParenthesizedExpression(ParenthesizedExpression expectedNode){
    return (ParenthesizedExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitPartDirective(PartDirective expectedNode){
    return (PartDirective actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitPartOfDirective(PartOfDirective expectedNode){
    return (PartOfDirective actualNode){
      var res = new Result.Empty();
      //visitDirective(node);
      {
        //super.visitChildren(visitor); //class PartOfDirective extends Directive {
        if (expectedNode.libraryName != null) {
          res.add(expectedNode.libraryName.accept(this)(actualNode.libraryName));
        }
      }
      return res;
    };
  }

  
  visitPostfixExpression(PostfixExpression expectedNode){
    return (PostfixExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.operand != null) {
          res.add(expectedNode.operand.accept(this)(actualNode.operand));
        }
      }
      return res;
    };
  }

  
  visitPrefixedIdentifier(PrefixedIdentifier expectedNode){
    return (PrefixedIdentifier actualNode){
      var res = new Result.Empty();
      //visitIdentifier(node);
      {
        if (expectedNode.prefix != null) {
          res.add(expectedNode.prefix.accept(this)(actualNode.prefix));
        }
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
      }
      return res;
    };
  }

  
  visitPrefixExpression(PrefixExpression expectedNode){
    return (PrefixExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.operand != null) {
          res.add(expectedNode.operand.accept(this)(actualNode.operand));
        }
      }
      return res;
    };
  }

  
  visitPropertyAccess(PropertyAccess expectedNode){
    return (PropertyAccess actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.target != null) {
          res.add(expectedNode.target.accept(this)(actualNode.target));
        }
        if (expectedNode.propertyName != null) {
          res.add(expectedNode.propertyName.accept(this)(actualNode.propertyName));
        }
      }
      return res;
    };
  }

  
  visitRedirectingConstructorInvocation(RedirectingConstructorInvocation expectedNode){
    return (RedirectingConstructorInvocation actualNode){
      var res = new Result.Empty();
      //visitConstructorInitializer(node);
      {
        if (expectedNode.constructorName != null) {
          res.add(expectedNode.constructorName.accept(this)(actualNode.constructorName));
        }
        if (expectedNode.argumentList != null) {
          res.add(expectedNode.argumentList.accept(this)(actualNode.argumentList));
        }
      }
      return res;
    };
  }

  
  visitRethrowExpression(RethrowExpression expectedNode){
    return (RethrowExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
      }
      return res;
    };
  }

  
  visitReturnStatement(ReturnStatement expectedNode){
    return (ReturnStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitScriptTag(ScriptTag scriptTag){
    return (ScriptTag actualNode){
      var res = new Result.Empty();
      //visitNode(scriptTag);
      {
      }
      return res;
    };
  }

  
  visitShowCombinator(ShowCombinator expectedNode){
    return (ShowCombinator actualNode){
      var res = new Result.Empty();
      //visitCombinator(node);
      {
        int i = 0;
        expectedNode.shownNames.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.shownNames[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitSimpleFormalParameter(SimpleFormalParameter expectedNode){
    return (SimpleFormalParameter actualNode){
      var res = new Result.Empty();
      //visitNormalFormalParameter(node);
      {
        //super.visitChildren(visitor); //class SimpleFormalParameter extends NormalFormalParameter {
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
        if (expectedNode.identifier != null) {
          res.add(expectedNode.identifier.accept(this)(actualNode.identifier));
        }
      }
      return res;
    };
  }

  
  visitSimpleIdentifier(SimpleIdentifier expectedNode){
    return (SimpleIdentifier actualNode){
      var res = new Result.Empty();
      //visitIdentifier(node);
      {
      }
      return res;
    };
  }

  
  visitSimpleStringLiteral(SimpleStringLiteral expectedNode){
    return (SimpleStringLiteral actualNode){
      var res = new Result.Empty();
      //visitStringLiteral(node);
      {
      }
      return res;
    };
  }

  visitStatement(Statement expectedNode){
    return (Statement actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitStringInterpolation(StringInterpolation expectedNode){
    return (StringInterpolation actualNode){
      var res = new Result.Empty();
      //visitStringLiteral(node);
      {
        int i = 0;
        expectedNode.elements.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.elements[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitStringLiteral(StringLiteral expectedNode){
    return (StringLiteral actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitSuperConstructorInvocation(SuperConstructorInvocation expectedNode){
    return (SuperConstructorInvocation actualNode){
      var res = new Result.Empty();
      //visitConstructorInitializer(node);
      {
        if (expectedNode.constructorName != null) {
          res.add(expectedNode.constructorName.accept(this)(actualNode.constructorName));
        }
        if (expectedNode.argumentList != null) {
          res.add(expectedNode.argumentList.accept(this)(actualNode.argumentList));
        }
      }
      return res;
    };
  }

  
  visitSuperExpression(SuperExpression expectedNode){
    return (SuperExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
      }
      return res;
    };
  }

  
  visitSwitchCase(SwitchCase expectedNode){
    return (SwitchCase actualNode){
      var res = new Result.Empty();
      //visitSwitchMember(node);
      {
        {
          int i = 0;
          expectedNode.labels.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.labels[i]));
            i++;
            return res;
          });
        }
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
        {
          int i = 0;
          expectedNode.statements.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.statements[i]));
            i++;
            return res;
          });
        }
      }
      return res;
    };
  }

  
  visitSwitchDefault(SwitchDefault expectedNode){
    return (SwitchDefault actualNode){
      var res = new Result.Empty();
      //visitSwitchMember(node);
      {
        {
          int i = 0;
          expectedNode.labels.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.labels[i]));
            i++;
            return res;
          });
        }
        {
          int i = 0;
          expectedNode.statements.fold(res, (res, expectedChild) {
            res.add(expectedChild.accept(this)(actualNode.statements[i]));
            i++;
            return res;
          });
        }
      }
      return res;
    };
  }

  visitSwitchMember(SwitchMember expectedNode){
    return (SwitchMember actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitSwitchStatement(SwitchStatement expectedNode){
    return (SwitchStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
        int i = 0;
        expectedNode.members.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.members[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitSymbolLiteral(SymbolLiteral expectedNode){
    return (SymbolLiteral actualNode){
      var res = new Result.Empty();
      //visitLiteral(node);
      {
      }
      return res;
    };
  }

  
  visitThisExpression(ThisExpression expectedNode){
    return (ThisExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
      }
      return res;
    };
  }

  
  visitThrowExpression(ThrowExpression expectedNode){
    return (ThrowExpression actualNode){
      var res = new Result.Empty();
      //visitExpression(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }

  
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration expectedNode){
    return (TopLevelVariableDeclaration actualNode){
      var res = new Result.Empty();
      //visitCompilationUnitMember(node);
      {
        //super.visitChildren(visitor); //class TopLevelVariableDeclaration extends CompilationUnitMember {
        if (expectedNode.variables != null) {
          res.add(expectedNode.variables.accept(this)(actualNode.variables));
        }
      }
      return res;
    };
  }

  
  visitTryStatement(TryStatement expectedNode){
    return (TryStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
        int i = 0;
        expectedNode.catchClauses.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.catchClauses[i]));
          i++;
          return res;
        });
        if (expectedNode.finallyBlock != null) {
          res.add(expectedNode.finallyBlock.accept(this)(actualNode.finallyBlock));
        }
      }
      return res;
    };
  }

  visitTypeAlias(TypeAlias expectedNode){
    return (TypeAlias actualNode){
      var res = new Result.Empty();
      //NO VISITCHILD
      return res;
    };
  }

  
  visitTypeArgumentList(TypeArgumentList expectedNode){
    return (TypeArgumentList actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.arguments.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.arguments[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitTypedLiteral(TypedLiteral expectedNode){
    return (TypedLiteral actualNode){
      var res = new Result.Empty();
      //visitLiteral(node);
      {
        if (expectedNode.typeArguments != null) {
          res.add(expectedNode.typeArguments.accept(this)(actualNode.typeArguments));
        }
      }
      return res;
    };
  }
  
  visitTypeParameter(TypeParameter expectedNode){
    return (TypeParameter actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        //super.visitChildren(visitor); //class TypeParameter extends Declaration {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.bound != null) {
          res.add(expectedNode.bound.accept(this)(actualNode.bound));
        }
      }
      return res;
    };
  }

  
  visitTypeParameterList(TypeParameterList expectedNode){
    return (TypeParameterList actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.typeParameters.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.typeParameters[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  visitUriBasedDirective(UriBasedDirective expectedNode){
    return (UriBasedDirective actualNode){
      var res = new Result.Empty();
      //visitDirective(node);
      {
        //super.visitChildren(visitor); //abstract class UriBasedDirective extends Directive {
        if (expectedNode.uri != null) {
          res.add(expectedNode.uri.accept(this)(actualNode.uri));
        }
      }
      return res;
    };
  }

  
  visitVariableDeclaration(VariableDeclaration expectedNode){
    return (VariableDeclaration actualNode){
      var res = new Result.Empty();
      //visitDeclaration(node);
      {
        //super.visitChildren(visitor); //class VariableDeclaration extends Declaration {
        if (expectedNode.name != null) {
          res.add(expectedNode.name.accept(this)(actualNode.name));
        }
        if (expectedNode.initializer != null) {
          res.add(expectedNode.initializer.accept(this)(actualNode.initializer));
        }
      }
      return res;
    };
  }

  
  visitVariableDeclarationList(VariableDeclarationList expectedNode){
    return (VariableDeclarationList actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        //super.visitChildren(visitor); //class VariableDeclarationList extends AnnotatedNode {
        if (expectedNode.type != null) {
          res.add(expectedNode.type.accept(this)(actualNode.type));
        }
        int i = 0;
        expectedNode.variables.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.variables[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitVariableDeclarationStatement(VariableDeclarationStatement expectedNode){
    return (VariableDeclarationStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.variables != null) {
          res.add(expectedNode.variables.accept(this)(actualNode.variables));
        }
      }
      return res;
    };
  }

  
  visitWhileStatement(WhileStatement expectedNode){
    return (WhileStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.condition != null) {
          res.add(expectedNode.condition.accept(this)(actualNode.condition));
        }
        if (expectedNode.body != null) {
          res.add(expectedNode.body.accept(this)(actualNode.body));
        }
      }
      return res;
    };
  }

  
  visitWithClause(WithClause expectedNode){
    return (WithClause actualNode){
      var res = new Result.Empty();
      //visitNode(node);
      {
        int i = 0;
        expectedNode.mixinTypes.fold(res, (res, expectedChild) {
          res.add(expectedChild.accept(this)(actualNode.mixinTypes[i]));
          i++;
          return res;
        });
      }
      return res;
    };
  }

  
  visitYieldStatement(YieldStatement expectedNode){
    return (YieldStatement actualNode){
      var res = new Result.Empty();
      //visitStatement(node);
      {
        if (expectedNode.expression != null) {
          res.add(expectedNode.expression.accept(this)(actualNode.expression));
        }
      }
      return res;
    };
  }
}