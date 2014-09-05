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
}


class Element {}
class Block {
  Map<SimpleIdentifier, Element> scope = <SimpleIdentifier, Element>{};
  
  /*
  VariableElement lookupVariableElement(SimpleIdentifier ident) => 
      variables.firstWhere((VariableElement v) => v.doesReference(ident));
 */
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
  List<VariableElement> top_variables = <VariableElement>[];
  
  SourceElement(Source this.source, CompilationUnit this.ast);
  
  void addImport(Source source) => imports.add(source);
  
  void addExport(Source source) => exports.add(source);
  
  void addPart(Source source) => parts.add(source);
  
  void addPartOf(Source source) => partOf.add(source);
  
  void addClass(ClassElement classDecl) => classes.add(classDecl);
  
  void addFunction(FunctionElement func) => functions.add(func);
}

class ClassElement implements Element{
  List<FieldElement> fields = <FieldElement>[];
  List<MethodElement> methods = <MethodElement>[];
  
  SourceElement source;
  ClassDeclaration ast;
  
  SimpleIdentifier get ident => ast.name;
  bool get isAbstract => ast.isAbstract;
  
  ClassElement(ClassDeclaration this.ast, SourceElement this.source);
  
  void addField(FieldElement field) => fields.add(field);
  void addMethod(MethodElement method) => methods.add(method);
}

class VariableElement implements Element {
  List<SimpleIdentifier> references = <SimpleIdentifier>[];
  Block parent_block;
  
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
    
  MethodElement(MethodDeclaration this.ast, ClassElement classDecl): super(classDecl);
}


class FunctionElement extends Block implements Element {
  SourceElement source;
  FunctionDeclaration ast;
  
  FunctionElement(FunctionDeclaration this.ast, SourceElement this.source);
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
      //print("Analyzing: " + this.source.toString());
      if (source.toString() == '/Applications/dart/dart-sdk/lib/internal/lists.dart') {
        PrintVisitor printer = new PrintVisitor();
        printer.visitCompilationUnit(unit);
      }
      this.visitCompilationUnit(unit);
      //print("Finish analyzing: " + this.source.toString());
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

