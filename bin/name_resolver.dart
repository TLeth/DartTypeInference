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

//TODO (jln): factories should be handled here. in ConstructorName there should be resolved what is a prefix of another library, and what is a factory call.

class IdentifierResolver extends Our.RecursiveElementVisitor {

  Map<AstNode, Our.NamedElement> declaredElements = {};
  Our.LibraryElement currentLibrary;
  Engine engine;

  IdentifierResolver(this.engine, Our.ElementAnalysis elem) {
    visitElementAnalysis(elem);
  }

  void visitElementAnalysis(Our.ElementAnalysis element) {
    element.sources.forEach((source, sourceElement) =>
        sourceElement.accept(this));
  }
  
  void visitSourceElement(Our.SourceElement element) {

    // if (element.source != this.engine.entrySource) return;
    
    declaredElements.clear();
    currentLibrary = element.library;
    
    //Pile together all declared elements
    visitBlock(element);
    
    ScopeVisitor visitor = new ScopeVisitor(this.engine, this.declaredElements, element.resolvedIdentifiers, this.currentLibrary);
    element.ast.accept(visitor);
  }
  
  void visitBlock(Our.Block block) {
    block.nestedBlocks.forEach(visitBlock);
    block.declaredElements.values.forEach((Our.Element elem) {
      this.declaredElements[elem.ast] = elem;
    });
  }
}


class ScopeVisitor extends GeneralizingAstVisitor {

  Our.LibraryElement library;

  Map<AstNode, Our.NamedElement> declaredElements;
  Map<Expression, Our.NamedElement> references = {};
  Map<String, Our.NamedElement> scope;
  
  Engine engine;
  Our.ClassElement _currentClass = null;

  ScopeVisitor(this.engine, this.declaredElements, this.references, this.library) {
    this.scope = {};
  }

  visitBlock(Block node) {
    _openNewScope(scope, (_) =>
        super.visitBlock(node));
  }

  visitFormalParameter(FormalParameter node) {
    this.scope[node.identifier.toString()] = this.declaredElements[node];
    super.visitFormalParameter(node);
  }
  
  visitClassDeclaration(ClassDeclaration node){
    _openNewScope(scope, (_) {
      this.scope["this"] = this.declaredElements[node];
      super.visitClassDeclaration(node);
    });
  }

  visitVariableDeclaration(VariableDeclaration node) {
    node.safelyVisitChild(node.initializer, this);
    this.scope[node.name.toString()] = this.declaredElements[node];
    node.safelyVisitChild(node.name, this);
  }
  
  visitFunctionDeclaration(FunctionDeclaration node) {

    if (node.name != null) {
      this.scope[node.name.toString()] = this.declaredElements[node];
    } else { print('ooooookaaaay'); }

    if (this.declaredElements[node] == null) {
      print('failed for  -- ${node} -- (${node.hashCode})');
      this.declaredElements.keys.forEach((key){
        print('${key} (${key.hashCode})');
      });
    }
    
    _openNewScope(scope, (_) {
      super.visitFunctionDeclaration(node);      
    });

  }
  
  visitSimpleIdentifier(SimpleIdentifier node) {

    Our.Name n = new Our.Name(node.name.toString());
    var local_element = scope[node.name.toString()];
    var lib_element = library.lookup(n, false);

    if (local_element != null) {
      references[node] = local_element;
    } else if (lib_element != null) {
      references[node] = lib_element;
    } else {
      this.engine.errors.addError(new EngineError('Couldnt resolve ${node.name}'));
    }
  }
  
  visitConstructorName(ConstructorName node){
    if (node.name == null){
      //Only prefixed identifiers needs resolving
      if (node.type.name is PrefixedIdentifier){
        PrefixedIdentifier ident = node.type.name;
        Our.NamedElement element = this.declaredElements[new Our.Name.FromIdentifier(ident.prefix)];
        if (element is Our.ClassElement){
          node.name = ident.identifier;
          node.type.name = ident.prefix;
          return;
        }
      }
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

  //Dont visit identifiers in these AST nodes.
  visitLibraryDirective(LibraryDirective node) {}
  visitImportDirective(ImportDirective node) {}
  visitExportDirective(ExportDirective node) {}
  visitPartDirective(PartDirective node) {}
  visitPartOfDirective(PartOfDirective node) {}
}