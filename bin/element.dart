library typeanalysis.element;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'engine.dart';

import 'printer.dart';

class ElementAnalysis {
  Map<Source, SourceElement> sources = <Source, SourceElement>{};
  Map<LibraryIdentifier, SourceElement> libraries = <LibraryIdentifier, SourceElement>{};
  
  bool containsSource(Source source) => sources.containsKey(source);
  SourceElement addSource(Source source, SourceElement element) => sources[source] = element;
  SourceElement getSource(Source source) => sources[source];
  
  bool containsLibrary(LibraryIdentifier lib) => libraries.containsKey(lib);
  SourceElement addLibrary(LibraryIdentifier lib, SourceElement element) => libraries[lib] = element;
  SourceElement getLibrary(LibraryIdentifier lib) => libraries[lib];

  dynamic accept(ElementVisitor visitor) => visitor.visitElementAnalysis(this);
}


class Element {}
class Block {

  Map<SimpleIdentifier, Element> references = <SimpleIdentifier, Element>{};
  Map<SimpleIdentifier, VariableElement> declaredVariables = <SimpleIdentifier, VariableElement>{};

  VariableElement addVariable(SimpleIdentifier ident, VariableElement variable) => declaredVariables[ident] = variable; 
  VariableElement lookupVariableElement(SimpleIdentifier ident) => declaredVariables[ident];
}


class SourceElement extends Block {
  Source source;
  CompilationUnit ast;
  LibraryIdentifier library = null;
  List<Source> partOf = <Source>[];
  List<Source> imports = <Source>[];
  List<Source> parts = <Source>[];
  List<Source> exports = <Source>[];
  List<ClassElement> classes = <ClassElement>[];
  List<FunctionElement> functions = <FunctionElement>[];

  Map<SimpleIdentifier, VariableElement> get top_variables => declaredVariables;
  
  SourceElement(Source this.source, CompilationUnit this.ast);
  
  void addImport(Source source) => imports.add(source);
  void addExport(Source source) => exports.add(source);
  void addPart(Source source) => parts.add(source);
  void addPartOf(Source source) => partOf.add(source);
  void addClass(ClassElement classDecl) => classes.add(classDecl);
  void addFunction(FunctionElement func) => functions.add(func);
  dynamic accept(ElementVisitor visitor) => visitor.visitSourceElement(this);
}

class ClassElement implements Element {
  List<FieldElement> fields = <FieldElement>[];
  List<MethodElement> methods = <MethodElement>[];
  
  SourceElement source;
  ClassDeclaration ast;
  
  SimpleIdentifier get ident => ast.name;
  bool get isAbstract => ast.isAbstract;
  
  ClassElement(ClassDeclaration this.ast, SourceElement this.source);
  
  dynamic accept(ElementVisitor visitor) => visitor.visitClassElement(this);

  void addField(FieldElement field) => fields.add(field);
  void addMethod(MethodElement method) => methods.add(method);
}

class VariableElement implements Element {
  List<SimpleIdentifier> references = <SimpleIdentifier>[];
  
  Block parent_block;
  VariableDeclaration ast;
  
  SimpleIdentifier get ident => ast.name;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitVariableElement(this);

  VariableElement(VariableDeclaration this.ast, Block this.parent_block);
  
  bool doesReference(SimpleIdentifier ident) => references.contains(ident);
}


class ClassMember {
  ClassElement classDecl;
  ClassMember (ClassElement this.classDecl);
}

class FieldElement extends ClassMember {
  
  List<Identifier> references = <Identifier>[];
  bool doesReference(Identifier ident) => references.contains(ident);
  
  FieldDeclaration ast;
  VariableDeclaration varDecl;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => varDecl.isConst;
  bool get isFinal => varDecl.isFinal;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitFieldElement(this);

  FieldElement(FieldDeclaration this.ast,VariableDeclaration this.varDecl, ClassElement classDecl): super(classDecl); 
}


class MethodElement extends ClassMember with Block implements Element {
  MethodDeclaration ast;
  
  SimpleIdentifier get ident => ast.name;
  bool get isAbstract => ast.isAbstract;
  bool get isGetter => ast.isGetter;
  bool get isOperator => ast.isOperator;
  bool get isSetter => ast.isSetter;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
    
  dynamic accept(ElementVisitor visitor) => visitor.visitMethodElement(this);

  MethodElement(MethodDeclaration this.ast, ClassElement classDecl): super(classDecl);
}


class FunctionElement extends Block implements Element {
  SourceElement source;
  FunctionDeclaration ast;

  dynamic accept(ElementVisitor visitor) => visitor.visitFunctionElement(this);
  
  FunctionElement(FunctionDeclaration this.ast, SourceElement this.source);
}

abstract class ElementVisitior<R> {
  R visitElementAnalysis(ElementAnalysis node);
  
  R visitSourceElement(SourceElement node);
  
  R visitClassElement(ClassElement node);
  R visitFunctionElement(FunctionElement node);
  R visitVariableElement(VariableElement node);
  
  R visitFieldElement(FieldElement node);
  R visitMethodElement(MethodElement node);
}

abstract class RecursiveElementVisitor<A> implements ElementVisitior<A> {
  A visitElementAnalysis(ElementAnalysis node) {
    A res = null;
    node.libraries.values.forEach((SourceElement source) => res = this.visitSourceElement(source));
    return res;
  }
  
  A visitSourceElement(SourceElement node) {
    A res = null;
    node.variables.values.forEach((VariableElement varDecl) => res = this.visitVariableElement(varDecl));
    node.functions.forEach((FunctionElement func) => res = this.visitFunctionElement(func));
    node.classes.forEach((ClassElement classDecl) => res = this.visitClassElement(classDecl));
    return res;
  }
  
  A visitClassElement(ClassElement node) {
    A res = null;
    node.fields.forEach((FieldElement field) => res = this.visitFieldElement(field));
    node.methods.forEach((MethodElement method) => res = this.visitMethodElement(method));
    return res;
  }
  
  A visitFunctionElement(FunctionElement node) {
    A res = null;
    node.variables.values.forEach((VariableElement varDecl) => res = this.visitVariableElement(varDecl));
    return res;
  }
  
  A visitMethodElement(MethodElement node) {
    A res = null;
    node.variables.values.forEach((VariableElement varDecl) => res = this.visitVariableElement(varDecl));
    return res;
  }
}

class ElementGenerator extends GeneralizingAstVisitor {
  
  SourceElement element;
  Source source;
  ElementAnalysis analysis;
  Engine engine;
  
  ClassElement _currentClassElement = null;
  MethodElement _currentMethodElement = null;
  FunctionElement _currentFunctionElement = null;
  FieldDeclaration _currentFieldDeclaration = null;
  Block _currentBlock = null;
  
  ElementGenerator(Engine this.engine, Source this.source, ElementAnalysis this.analysis) {
    if (!analysis.containsSource(source)) {
      CompilationUnit unit = engine.getCompilationUnit(source); 
      element = new SourceElement(source, unit);
      analysis.addSource(source, element);
      
      //PrintVisitor printer = new PrintVisitor();
      //printer.visitCompilationUnit(unit);
      
      Block oldBlock = _currentBlock; 
      _currentBlock = element;
      
      this.visitCompilationUnit(unit);
      
      _currentBlock = oldBlock;
      
    } else {
      element = analysis.getSource(source);
    }
  }
  
  visitImportDirective(ImportDirective node) {
    //TODO (jln) dart:core is always imported, either explicit or implicit, this should be made.
    Source import_source = engine.resolveDirective(source, node);
    ElementGenerator generator = new ElementGenerator(engine, import_source, analysis);
    element.addImport(import_source);
    super.visitImportDirective(node);
  }
  
  visitPartDirective(PartDirective node){
    Source part_source = engine.resolveDirective(source, node);
    ElementGenerator generator = new ElementGenerator(engine, part_source, analysis);
    generator.element.addPartOf(source);
    element.addPart(part_source);
    super.visitPartDirective(node);
  }
  
  visitExportDirective(ExportDirective node){
    Source export_source = engine.resolveDirective(source, node);
    ElementGenerator generator = new ElementGenerator(engine, export_source, analysis);
    element.addExport(export_source);
    super.visitExportDirective(node);
  }
  
  visitPartOfDirective(PartOfDirective node){
    //print(node.libraryName);
    element.library = node.libraryName;
    super.visitPartOfDirective(node);
  }
  
  visitLibraryDirective(LibraryDirective node) {
    analysis.addLibrary(node.name, element);
    //print(node.name);
    element.library = node.name;
    super.visitLibraryDirective(node);
  }
  
  visitClassDeclaration(ClassDeclaration node){
    _currentClassElement = new ClassElement(node, element);
    element.addClass(_currentClassElement);
    super.visitClassDeclaration(node);
    _currentClassElement = null;
  }
  
  visitMethodDeclaration(MethodDeclaration node) {
    if (_currentClassElement == null)
      engine.errors.addError(new EngineError("Visited method declaration, but currentClass was null.", source, node.offset, node.length), true);
    
    if (_currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited method declaration, inside another method declaration.", source, node.offset, node.length), true);
    
    _currentMethodElement = new MethodElement(node, _currentClassElement);
    _currentClassElement.addMethod(_currentMethodElement);

    Block oldBlock = _currentBlock;
    _currentBlock = _currentMethodElement;
    
    super.visitMethodDeclaration(node);
    
    _currentBlock = oldBlock;
    _currentMethodElement = null;
    
  }
  
  visitFieldDeclaration(FieldDeclaration node) {
    if (_currentClassElement == null)
      engine.errors.addError(new EngineError("Visited field declaration, but currentClass was null.", source, node.offset, node.length), true);
    _currentFieldDeclaration = node;
    super.visitFieldDeclaration(node);
    _currentFieldDeclaration = null;
  }
  
  visitVariableDeclaration(VariableDeclaration node){
    if (_currentFieldDeclaration != null) {
      if (_currentClassElement == null)
         engine.errors.addError(new EngineError("Visited variable decl inside a field declaration, but currentClass was null.", source, node.offset, node.length), true);
      
      FieldElement field = new FieldElement(_currentFieldDeclaration, node, _currentClassElement);
      _currentClassElement.addField(field);
      super.visitVariableDeclaration(node);
      return;
    }
    
    if (_currentBlock != null) {
      VariableElement variable = new VariableElement(node, _currentBlock);
      _currentBlock.addVariable(variable.ident, variable);
      return;
    }
  }
  
  visitFunctionDeclaration(FunctionDeclaration node) {
    FunctionElement oldFunctionElement = _currentFunctionElement;
    _currentFunctionElement = new FunctionElement(node, element);
    element.addFunction(_currentFunctionElement);
    
    Block oldBlock = _currentBlock;
    _currentBlock = _currentFunctionElement;
    
    super.visitFunctionDeclaration(node);
    
    _currentBlock = oldBlock;
    _currentFunctionElement = null;
  }
}

