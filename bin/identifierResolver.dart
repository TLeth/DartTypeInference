library typeanalysis.Local;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';

import 'element.dart' as Our;
import 'engine.dart';

import 'dart:collection';

_openNewScope(scope, k) {
  Map curr = {};
  curr.addAll(scope);
  var ret = k(scope);
  scope.clear();
  scope.addAll(curr);
  return ret;
}

class IdentifierResolver extends Our.RecursiveElementVisitor {

  Map<SimpleIdentifier, Our.VariableElement> declaredVariables = {};

  var engine;


  IdentifierResolver(this.engine, Our.ElementAnalysis elem) {
    visitElementAnalysis(elem);
  }

  void visitElementAnalysis(Our.ElementAnalysis element) {
    element.sources.forEach((source, sourceElement) =>
        sourceElement.accept(this));
  }
  
  void visitSourceElement(Our.SourceElement element) {
    if (element.source != this.engine.entrySource) return;
    
    declaredVariables.clear();

    declaredVariables.addAll(element.declaredVariables);
    element.functions.values.forEach((f) { f.accept(this); });
    //    element.classes.forEach((c) { c.accept(this); });
        
    Map<String, Our.Element> scope = {};
    ScopeVisitor visitor = new ScopeVisitor(this.engine, 
                                            scope, 
                                            this.declaredVariables,
                                            element.references);

    _openNewScope(scope, (scope) => 
        element.ast.accept(visitor));
  }
  
  void visitFunctionElement(Our.FunctionElement element) {
    declaredVariables.addAll(element.declaredVariables);
  }
  
  void visitClassElement(Our.ClassElement element) {
    //declaredVariables.addAll(element.declaredVariables);
    element.methods.forEach((m) => m.accept(this));
  }
      
  void visitMethodElement(Our.MethodElement element) {
    declaredVariables.addAll(element.declaredVariables);
  }
}


class ScopeVisitor extends GeneralizingAstVisitor {

  Map<Identifier, Our.Element> references = {};
  Map<Identifier, Our.VariableElement> declaredVariables;
  Map<Identifier, Our.VariableElement> declaredFunctions = {};
  Map<String, Our.Element> scope;
  
  var engine;
  
  ScopeVisitor(this.engine, 
               this.scope, 
               this.declaredVariables, 
               this.references); 

  visitBlock(Block node) {
    _openNewScope(scope, (_) => super.visitBlock(node));
  }

//  visitFormalParameter(FormalParameter node) {
//
//  }


  visitVariableDeclaration(VariableDeclaration node) {
    print(node.name);
    print(this.declaredVariables);
    
    this.scope[node.name.toString()] = this.declaredVariables[node.name];
    super.visitVariableDeclaration(node);
  }

  visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name != null) {
      this.scope[node.name.toString()] = this.declaredFunctions[node];
    }
    super.visitFunctionDeclaration(node);
  }
  
  
  visitSimpleIdentifier(SimpleIdentifier node) {
    
    var element = scope[node.name.toString()];
    if (element != null) {
      references[node] = element;
    } else {
      this.engine.errors.addError(new EngineError('Couldnt resolve ${node.name}'));
    }
  }


  //Only resolve the prefix.
  //TODO handle library 'as ...' imports.
  visitPrefixedIdentifier(PrefixedIdentifier node) {
    node.safelyVisitChild(node.prefix, this);
  }

  //Only try to resolve the target.
  visitPropertyAcces(PropertyAccess node) {
    node.safelyVisitChild(node.target, this);
  }

}