library typeanalysis.element;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'engine.dart';


import 'printer.dart';

/**
 * Instances of the class `ElementAnalysis` is the collection of all the `SourceElement`s 
 * used in the entry file.
 **/
class ElementAnalysis {
  // Mapping from a source to the SourceElement.
  Map<Source, SourceElement> sources = <Source, SourceElement>{};
  
  // Mapping from a library identifier to the main `SourceElement`. If the library uses part/part of. 
  // the part header source is the SourceElement.  
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
/** 
 * Instances of the class `Block` represents a static scope of the program. it could be a Library, a Class, a Method etc.
 * **/ 
class Block {

  Map<SimpleIdentifier, Element> references = <SimpleIdentifier, Element>{};
  Map<SimpleIdentifier, VariableElement> declaredVariables = <SimpleIdentifier, VariableElement>{};

  Block parent_block = null;

  Map<FunctionDeclaration, FunctionElement> functions = <FunctionDeclaration, FunctionElement>{};

  VariableElement addVariable(SimpleIdentifier ident, VariableElement variable) => declaredVariables[ident] = variable; 
  VariableElement lookupVariableElement(SimpleIdentifier ident) => declaredVariables[ident];

  FunctionElement addFunction(FunctionDeclaration funcDecl, FunctionElement func) => functions[funcDecl] = func; 
  FunctionElement lookupFunctionElement(FunctionDeclaration funcDecl) => functions[funcDecl];
}


/**
 * Instances of the class `SourceElement` represents a source file and contains all the the information reguarding its content
 **/
class SourceElement extends Block {
  Source source;
  CompilationUnit ast;
  //If library is `null` it means that the library is implicit named. This means the library name is: ''.
  LibraryIdentifier library = null;
  SourceElement partOf = null;
  List<Source> imports = <Source>[];
  Map<Source, SourceElement> parts = <Source, SourceElement>{};
  List<Source> exports = <Source>[];
  List<ClassElement> classes = <ClassElement>[];

  Map<SimpleIdentifier, VariableElement> get top_variables => declaredVariables;
  
  SourceElement(Source this.source, CompilationUnit this.ast);
  
  void addImport(Source source) => imports.add(source);
  void addExport(Source source) => exports.add(source);
  void addPart(Source source, SourceElement element){ parts[source] = element; }
  void addClass(ClassElement classDecl) => classes.add(classDecl);
  dynamic accept(ElementVisitor visitor) => visitor.visitSourceElement(this);
  
  String toString() {
    if (partOf != null) return "Part of '${partOf}'";
    else if (library == null) return "Library ''";
    else return "Library '${library}'";
  }
}

/** 
 * Instance of a `ClassElement` is our abstract representation of the class.
 **/
class ClassElement implements Element {
  List<FieldElement> fields = <FieldElement>[];
  List<MethodElement> methods = <MethodElement>[];
  
  SourceElement source;
  ClassDeclaration ast;
  
  SimpleIdentifier get ident => ast.name;
  bool get isAbstract => ast.isAbstract;
  bool get isSynthetic => ast.isSynthetic;
  
  ClassElement(ClassDeclaration this.ast, SourceElement this.source);
  
  dynamic accept(ElementVisitor visitor) => visitor.visitClassElement(this);

  void addField(FieldElement field) => fields.add(field);
  void addMethod(MethodElement method) => methods.add(method);

  String toString() {
    return "Class [${isAbstract ? ' abstract ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ident}";
  }
}


/** 
 * Instance of a `VariableElement` is our abstract representation of a variable.
 **/
class VariableElement implements Element {
  List<SimpleIdentifier> references = <SimpleIdentifier>[];
  
  Block parent_block;
  VariableDeclaration ast;
  
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => ast.isConst;
  bool get isFinal => ast.isFinal;
  
  SimpleIdentifier get ident => ast.name;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitVariableElement(this);

  VariableElement(VariableDeclaration this.ast, Block this.parent_block);
  
  bool doesReference(SimpleIdentifier ident) => references.contains(ident);
  
  String toString() {
    return "Var [${isConst ? ' const ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}, ${ast.metadata}] ${ident}";
  }
}

/**
 * Instances of a class `ClassMember` is a our abstract representation of class members
 **/
class ClassMember {
  ClassElement classDecl;
  ClassMember (ClassElement this.classDecl);
}


/**
 * Instances of a class`FieldElement` is a our abstract representation of fields
 **/
class FieldElement extends ClassMember {
  
  List<Identifier> references = <Identifier>[];
  bool doesReference(Identifier ident) => references.contains(ident);
  
  FieldDeclaration ast;
  VariableDeclaration varDecl;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => varDecl.isConst;
  bool get isFinal => varDecl.isFinal;

  
  SimpleIdentifier get ident => varDecl.name;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitFieldElement(this);

  FieldElement(FieldDeclaration this.ast,VariableDeclaration this.varDecl, ClassElement classDecl): super(classDecl);
  
  String toString() {
    return "Field [${isConst ? ' const ' : ''}"+
            "${isStatic ? ' static ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}, ${ast.metadata}] ${ident}";
  }
}

/**
 * Instances of a class`MethodElement` is a our abstract representation of methods
 **/
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
  
  String toString() {
    return "Method [${isAbstract ? ' abstract ' : ''}"+
            "${isGetter ? ' getter ' : ''}"+
            "${isSetter ? ' setter ' : ''}"+
            "${isOperator ? ' oper ' : ''}"+
            "${isStatic ? ' static ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}, ${ast.metadata}] ${ast.returnType} ${ast.name}(${ast.parameters})";
  }
}


/**
 * Instances of a class`FunctionElement` is a our abstract representation of functions
 **/
class FunctionElement extends Block implements Element {
  SourceElement source;
  FunctionDeclaration ast;
  
  bool get isGetter => ast.isGetter;
  bool get isSetter => ast.isSetter;
  bool get isSynthetic => ast.isSynthetic;

  dynamic accept(ElementVisitor visitor) => visitor.visitFunctionElement(this);
  
  FunctionElement(FunctionDeclaration this.ast, SourceElement this.source);
  
  String toString(){
    return "Func [${isGetter ? ' getter ' : ''}"+
            "${isSetter ? ' setter ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}, ${ast.metadata}] ${ast.returnType} ${ast.name}(${ast.functionExpression.parameters})";
  }
}

abstract class ElementVisitor<R> {
  R visitElementAnalysis(ElementAnalysis node);
  
  R visitSourceElement(SourceElement node);
  
  R visitBlock(Block node);
  R visitClassElement(ClassElement node);
  R visitFunctionElement(FunctionElement node);
  R visitVariableElement(VariableElement node);
  
  R visitClassMember(ClassMember node);
  R visitFieldElement(FieldElement node);
  R visitMethodElement(MethodElement node);
}

class RecursiveElementVisitor<A> implements ElementVisitor<A> {
  A visitElementAnalysis(ElementAnalysis node) {
    A res = null;
    node.libraries.values.forEach((SourceElement source) => res = this.visitSourceElement(source));
    return res;
  }
  
  A visitSourceElement(SourceElement node) {
    visitBlock(node);
    node.classes.forEach(this.visitClassElement);
    return null;
  }
  
  A visitClassElement(ClassElement node) {
    node.fields.forEach(this.visitFieldElement);
    node.methods.forEach(this.visitMethodElement);
    return null;
  }
  
  A visitFunctionElement(FunctionElement node) {
    visitBlock(node);
    return null;
  }
  
  A visitVariableElement(VariableElement node) {    
    return null;
  }
  
  A visitClassMember(ClassMember node) {
    return null;
  }
  
  A visitBlock(Block node){
    node.declaredVariables.values.forEach(this.visitVariableElement);
    node.functions.values.forEach(this.visitFunctionElement);
    return null;
  }
  
  A visitMethodElement(MethodElement node) {
    visitBlock(node);
    visitClassMember(node);
    return null;
  }
  
  A visitFieldElement(FieldElement node) {
    visitClassMember(node);
    return null;
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
      
      //PrintAstVisitor printer = new PrintAstVisitor();
      //printer.visitCompilationUnit(unit);
      
      Block oldBlock = _currentBlock; 
      _currentBlock = element;
      _currentBlock.parent_block = oldBlock;
      
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
    generator.element.partOf = element;
    element.addPart(part_source, generator.element);
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
    _currentBlock.parent_block = oldBlock;
    
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
    element.addFunction(node, _currentFunctionElement);
    
    Block oldBlock = _currentBlock;
    _currentBlock = _currentFunctionElement;
    _currentBlock.parent_block = oldBlock;
    
    super.visitFunctionDeclaration(node);
    
    _currentBlock = oldBlock;
    _currentFunctionElement = null;
  }
}

