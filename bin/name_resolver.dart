library typeanalysis.Local;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/source.dart';

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
    
    declaredElements.clear();
    currentLibrary = element.library;
    
    //Pile together all declared elements
    visitBlock(element);
    
    ScopeVisitor visitor = new ScopeVisitor(element.source, this.engine, this.declaredElements, element.resolvedIdentifiers, this.currentLibrary);
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
  
  Source source;
  
  Engine engine;
  Our.ClassElement _currentClass = null;

  ScopeVisitor(this.source, this.engine, this.declaredElements, this.references, this.library){
    this.scope = {};
  }

  @override
  visitBlock(Block node) {
    _openNewScope(scope, (_) =>
        super.visitBlock(node));
  }

  @override
  visitFormalParameter(FormalParameter node) {
    this.scope[node.identifier.toString()] = this.declaredElements[node];
    super.visitFormalParameter(node);
  }
  
  @override
  visitClassDeclaration(ClassDeclaration node){
    _openNewScope(scope, (_) {
      Our.ClassElement c = this.declaredElements[node];

      c.declaredElements.forEach((k, v) {
        this.scope[k.toString()] = v;
      });

      this.scope["this"] = c;
      this.scope[node.name.toString()] = c;
     
      super.visitClassDeclaration(node);
    });
    
  }
  
  visitClassTypeAlias(ClassTypeAlias node) {
    _openNewScope(scope, (_) {
      Our.ClassAliasElement c = this.declaredElements[node];
      c.declaredElements.forEach((k, v) {
        this.scope[k.toString()] = v;
      });
      this.scope[node.name.toString()] = c;
      super.visitClassTypeAlias(node);
    });
  }

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    node.safelyVisitChild(node.initializer, this);
    var namedElem = this.declaredElements[node];

    if (namedElem != null) {
      this.scope[node.name.toString()+'='] = namedElem;
      this.scope[node.name.toString()] = namedElem;
    }

    node.safelyVisitChild(node.name, this);
  }

  visitConstructorDeclaration(ConstructorDeclaration node) {

    Our.ClassElement classElement = scope[node.returnType.toString()];
    if (classElement != null)
      references[node.returnType] = classElement;
    else
      engine.errors.addError(new EngineError("ConstructorDeclaration was visited but the scope didn't contain the returnType", source, node.offset, node.length));

    if (node.name != null) {
      Our.ConstructorElement constructor = classElement.declaredConstructors[new Our.PrefixedName.FromIdentifier(node.returnType, new Our.Name.FromIdentifier(node.name))];
      if (constructor != null)
        references[node.name] = constructor;
      else
        engine.errors.addError(new EngineError("ConstructorDeclaration was visited but the scope the declared constructor couldn't be found.", source, node.offset, node.length));
    }
      
    
    node.safelyVisitChild(node.parameters, this);
    node.initializers.accept(this);
    node.safelyVisitChild(node.redirectedConstructor, this);
    node.safelyVisitChild(node.body, this);
  }
  
  @override
  visitFieldDeclaration(FieldDeclaration node) {
    node.visitChildren(this);
  }
  
  @override
  visitMethodDeclaration(MethodDeclaration node) {

    if (this.declaredElements[node] == null)
      engine.errors.addError(new EngineError("Failed to find MethodDeclaration ${node.name} in declaredElements", source, node.offset, node.length), true);
    
    if (node.name != null) {
      this.scope[node.name.toString()] = this.declaredElements[node];
    }
    
    _openNewScope(scope, (_) {
      super.visitMethodDeclaration(node);      
    });
  }

  @override
  visitFunctionDeclaration(FunctionDeclaration node) {

    if (this.declaredElements[node] == null)
      engine.errors.addError(new EngineError("Failed to find FunctionDeclaration ${node.name} in declaredElements", source, node.offset, node.length), true);
    
    if (node.name != null) {
      String name = node.name.toString() + (node.isSetter ? '=' : '');
      this.scope[name] = this.declaredElements[node];
    }
    
    _openNewScope(scope, (_) {
        super.visitFunctionDeclaration(node);      
    });

  }
  
  @override
  visitFunctionTypeAlias(FunctionTypeAlias node) {
    _openNewScope(scope, (_) {
      Our.FunctionAliasElement f = this.declaredElements[node];
      
      f.declaredTypeParameters.forEach((n, p) {
        this.scope[n.toString()] = p;
      });
      
      this.scope[node.name.toString()] = f;

      super.visitFunctionTypeAlias(node);
    });
  }

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {    

    String name = node.name.toString();

    Our.Name getter = new Our.Name(name);
    Our.Name setter = new Our.Name(name + '=');

    var local_getter_element = scope[name];
    var local_setter_element = scope[name + '='];
    var lib_getter_element = library.lookup(getter, false);
    var lib_setter_element = library.lookup(setter, false);

    if (local_getter_element != null) 
      {
        references[node] = local_getter_element;
      } 
    else if (lib_getter_element != null) 
      {
        references[node] = lib_getter_element;
      } 
    else if (local_setter_element != null) 
      {
        references[node] = local_setter_element;
      } 
    else if (lib_setter_element != null) 
      {
        references[node] = lib_setter_element;
      }
    else if (node.name.toString() == 'void') 
      {
        
      } 
    else 
      {
        this.engine.errors.addError(new EngineError('Couldnt resolve ${node.name}', source, node.offset, node.length));
      }
  }

  @override
  visitMethodInvocation(MethodInvocation node) {
    node.safelyVisitChild(node.target, this);

    if (node.target == null)
      node.safelyVisitChild(node.methodName, this);

    node.safelyVisitChild(node.argumentList, this);
  }


  //Only resolve the prefix.
  //TODO handle library 'as ...' imports.
  @override
  visitPrefixedIdentifier(PrefixedIdentifier node) {
    node.safelyVisitChild(node.prefix, this);
  }

  //Only try to resolve the target.
  @override
  visitPropertyAccess(PropertyAccess node) {
    node.safelyVisitChild(node.target, this);
  }

  @override
  visitNamedExpression(NamedExpression node) {
    node.safelyVisitChild(node.expression, this);
  }

  //Dont visit identifiers in these AST nodes.
  @override
  visitLibraryDirective(LibraryDirective node) {}

  @override
  visitImportDirective(ImportDirective node) {}

  @override
  visitExportDirective(ExportDirective node) {}

  @override
  visitPartDirective(PartDirective node) {}

  @override
  visitPartOfDirective(PartOfDirective node) {}
}