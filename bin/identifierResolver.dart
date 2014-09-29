library typeanalysis.Local;

import 'package:analyzer/src/generated/ast.dart';

import 'element.dart' as Our;
import 'engine.dart';

_openNewScope(scope, k) {
  Map curr = {};
  curr.addAll(scope);
  var ret = k(scope);
  scope.clear();
  scope.addAll(curr);
  return ret;
}

_addToScope(scope, bindings, k) {
  return _openNewScope(scope, (scope) {
    scope.addAll(bindings);
    k(scope);
  });
}

class IdentifierResolver extends Our.RecursiveElementVisitor {

  Map<Our.Name, Our.NamedElement> declaredElements = {};
  Our.LibraryElement currentLibrary;
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
    
    declaredElements.clear();
    currentLibrary = element.library;
    
    visitBlock(element);
    
    Map<String, Our.NamedElement> scope = {};
    ScopeVisitor visitor = new ScopeVisitor(this.engine, 
                                            scope, 
                                            this.declaredElements,
                                            element.resolvedIdentifiers);

    _openNewScope(scope, (scope) => element.ast.accept(visitor));
  }
  
  void visitBlockList(List<Our.Block> blocks) {
    blocks.forEach((block) {
        visitBlock(block);
    });      
  }
  
  void visitBlock(Our.Block block) {
    this.declaredElements.addAll(block.declaredElements);
    
    visitBlockList(block.nestedBlocks);      
  }
}


class ScopeVisitor extends GeneralizingAstVisitor {

  Map<Expression, Our.NamedElement> references = {};
  Map<Our.Name, Our.NamedElement> declaredElements;
  Map<String, Our.NamedElement> scope;
  
  var engine;
  Our.ClassElement _currentClass = null;
  
  ScopeVisitor(this.engine, 
               this.scope, 
               this.declaredElements, 
               this.references); 

  visitBlock(Block node) {
    _openNewScope(scope, (_) => super.visitBlock(node));
  }

  visitFormalParameter(FormalParameter node) {
    this.scope[node.identifier.toString()] = this.declaredElements[new Our.Name.FromIdentifier(node.identifier)];
  }
  
  visitClassDeclaration(ClassDeclaration node){
    _currentClass = this.declaredElements[new Our.Name.FromIdentifier(node.name)];
    super.visitClassDeclaration(node);
    _currentClass = null;
  }

  visitVariableDeclaration(VariableDeclaration node) {
    this.scope[node.name.toString()] = this.declaredElements[new Our.Name.FromIdentifier(node.name)];
    super.visitVariableDeclaration(node);
  }

  visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name != null) {
      this.scope[node.name.toString()] = this.declaredElements[new Our.Name.FromIdentifier(node.name)];
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
    super.visitSimpleIdentifier(node);
  }
  
  visitThisExpression(ThisExpression node){
    if (_currentClass == null)
      this.engine.errors.addError(new EngineError('Referenced this without any current class set'), true);
    else
      references[node] = _currentClass;
    super.visitThisExpression(node);
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