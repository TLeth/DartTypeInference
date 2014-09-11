library typeanalysis.element;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'engine.dart';
import 'resolver.dart';

export 'resolver.dart' show LibraryElement;



//TODO (jln): We need to take type alias definitions into account here, since they change the resolution step 
/**
 * Instances of the class `ElementAnalysis` is the collection of all the `SourceElement`s 
 * used in the entry file.
 **/
class ElementAnalysis {
  // Mapping from a source to the SourceElement.
  Map<Source, SourceElement> sources = <Source, SourceElement>{};
  
  // Mapping from a library identifier to the main `SourceElement`. If the library uses part/part of. 
  // the part header source is the SourceElement.  
  Map<String, SourceElement> librarySources = <String, SourceElement>{};
  
  bool containsSource(Source source) => sources.containsKey(source);
  SourceElement addSource(Source source, SourceElement element) => sources[source] = element;
  SourceElement getSource(Source source) => sources[source];
  
  bool containsLibrarySource(String lib) => librarySources.containsKey(lib);
  SourceElement addLibrarySource(String lib, SourceElement element) => librarySources[lib] = element;
  SourceElement getLibrarySource(String lib) => librarySources[lib];

  dynamic accept(ElementVisitor visitor) => visitor.visitElementAnalysis(this);
}


abstract class Element {
  Source get library_source;
  
  bool get fromSystemLibrary => library_source.isInSystemLibrary;
}
/** 
 * Instances of the class `Block` represents a static scope of the program. it could be a Library, a Class, a Method etc.
 * **/ 
abstract class Block {

  Map<SimpleIdentifier, Element> references = <SimpleIdentifier, Element>{};
  Map<SimpleIdentifier, VariableElement> declaredVariables = <SimpleIdentifier, VariableElement>{};

  Block parent_block = null;
  Source get library_source;
  bool get fromSystemLibrary => library_source.isInSystemLibrary;

  Map<FunctionDeclaration, FunctionElement> functions = <FunctionDeclaration, FunctionElement>{};

  VariableElement addVariable(SimpleIdentifier ident, VariableElement variable) => declaredVariables[ident] = variable; 
  VariableElement lookupVariableElement(SimpleIdentifier ident) => declaredVariables[ident];

  FunctionElement addFunction(FunctionDeclaration funcDecl, FunctionElement func) => functions[funcDecl] = func; 
  FunctionElement lookupFunctionElement(FunctionDeclaration funcDecl) => functions[funcDecl];
}


/**
 * Instances of the class `SourceElement` represents a source file and contains all the the information reguarding its content
 **/
class SourceElement extends Block implements Element {
  CompilationUnit ast;
  //If library is `null` it means that the library is implicit named. This means the library name is: ''.
  String libraryName = null;
  SourceElement partOf = null;
  Source source;
  Source get library_source => (partOf == null ? source : partOf.source);
  
  Map<Source, SourceElement> parts = <Source, SourceElement>{};
  
  Map<Source, ImportDirective> imports = <Source, ImportDirective>{};
  Map<Source, ExportDirective> exports = <Source, ExportDirective>{};
  List<ClassElement> classes = <ClassElement>[];
  
  bool implicitImportedDartCore = false;
  
  LibraryElement library = null;

  Map<SimpleIdentifier, VariableElement> get top_variables => declaredVariables;
  
  SourceElement(Source this.source, CompilationUnit this.ast);
  
  ImportDirective addImport(Source source, ImportDirective directive) => imports[source] = directive;
  ExportDirective addExport(Source source, ExportDirective directive) => exports[source] = directive;
  void addPart(Source source, SourceElement element){ parts[source] = element; }
  void addClass(ClassElement classDecl) => classes.add(classDecl);
  dynamic accept(ElementVisitor visitor) => visitor.visitSourceElement(this);
  
  String toString() {
    if (partOf != null) return "Part of '${partOf}'";
    else if (libraryName == null) return "Library ''";
    else return "Library '${libraryName}'";
  }
}

/** 
 * Instance of a `ClassElement` is our abstract representation of the class.
 **/
class ClassElement extends Element {
  List<FieldElement> fields = <FieldElement>[];
  List<MethodElement> methods = <MethodElement>[];
  List<ConstructorElement> constructors = <ConstructorElement>[];
  ClassDeclaration ast;
  
  SourceElement sourceElement;
  Source get library_source => sourceElement.library_source;
  
  String get ident => ast.name.toString();
  bool get isAbstract => ast.isAbstract;
  bool get isSynthetic => ast.isSynthetic;
  
  ClassElement(ClassDeclaration this.ast, SourceElement this.sourceElement);
  
  dynamic accept(ElementVisitor visitor) => visitor.visitClassElement(this);

  void addField(FieldElement field) => fields.add(field);
  void addMethod(MethodElement method) => methods.add(method);
  void addConstructor(ConstructorElement constructor) => constructors.add(constructor);

  String toString() {
    return "Class [${isAbstract ? ' abstract ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ident}";
  }
}


/** 
 * Instance of a `VariableElement` is our abstract representation of a variable.
 **/
class VariableElement extends Element {
  List<SimpleIdentifier> references = <SimpleIdentifier>[];
  
  Block parent_block;
  VariableDeclaration ast;
  
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => ast.isConst;
  bool get isFinal => ast.isFinal;
  
  String get ident => ast.name.toString();
  
  Source get library_source => parent_block.library_source;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitVariableElement(this);

  VariableElement(VariableDeclaration this.ast, Block this.parent_block);
  
  bool doesReference(SimpleIdentifier ident) => references.contains(ident);
  
  String toString() {
    return "Var [${isConst ? ' const ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ident}";
  }
}

/**
 * Instances of a class `ClassMember` is a our abstract representation of class members
 **/
class ClassMember {
  ClassElement classDecl;
  ClassMember (ClassElement this.classDecl);
  
  Source get library_source => classDecl.library_source;
}


/**
 * Instances of a class`FieldElement` is a our abstract representation of fields
 **/
class FieldElement extends ClassMember with Element {
  
  List<Identifier> references = <Identifier>[];
  bool doesReference(Identifier ident) => references.contains(ident);
  
  FieldDeclaration ast;
  VariableDeclaration varDecl;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => varDecl.isConst;
  bool get isFinal => varDecl.isFinal;
  
  String get ident => varDecl.name.toString();
  
  dynamic accept(ElementVisitor visitor) => visitor.visitFieldElement(this);

  FieldElement(FieldDeclaration this.ast,VariableDeclaration this.varDecl, ClassElement classDecl): super(classDecl);
  
  String toString() {
    return "Field [${isConst ? ' const ' : ''}"+
            "${isStatic ? ' static ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ident}";
  }
}

/**
 * Instances of a class`MethodElement` is a our abstract representation of methods
 **/
class MethodElement extends ClassMember with Block {
  MethodDeclaration ast;
  
  String get ident => ast.name.toString();
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
            "${isSynthetic ? ' synthetic ' : ''}] ${ast.returnType} ${ast.name}(${ast.parameters})";
  }
}

/**
 * Instances of a class `ConstructorElement` is a our abstract representation of constructors
 **/
class ConstructorElement extends ClassMember with Block implements Element {
  ConstructorDeclaration ast;
  
  String get ident => ast.name.toString();
  bool get isSynthetic => ast.isSynthetic;
  bool get isFactory => ast.factoryKeyword != null;
  bool get isExternal => ast.externalKeyword != null;
    
  dynamic accept(ElementVisitor visitor) => visitor.visitConstructorElement(this);

  ConstructorElement(ConstructorDeclaration this.ast, ClassElement classDecl): super(classDecl);
  
  String toString() {
    return "Constructor [${isFactory ? ' factory ' : ''}"+
            "${isExternal ? ' external ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ast.returnType} ${ast.name}(${ast.parameters})";
  }
}


/**
 * Instances of a class`FunctionElement` is a our abstract representation of functions
 **/
class FunctionElement extends Block implements Element {
  SourceElement sourceElement;
  FunctionDeclaration ast;
  
  Source get library_source => sourceElement.library_source;
  
  bool get isGetter => ast.isGetter;
  bool get isSetter => ast.isSetter;
  bool get isSynthetic => ast.isSynthetic;
  
  String get ident => ast.name.toString();

  dynamic accept(ElementVisitor visitor) => visitor.visitFunctionElement(this);
  
  FunctionElement(FunctionDeclaration this.ast, SourceElement this.sourceElement);
  
  
  
  String toString(){
    return "Func [${isGetter ? ' getter ' : ''}"+
            "${isSetter ? ' setter ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ast.returnType} ${ast.name}(${ast.functionExpression.parameters})";
  }
}

abstract class ElementVisitor<R> {
  R visitElementAnalysis(ElementAnalysis node);
  
  R visitSourceElement(SourceElement node);
  R visitLibraryElement(LibraryElement node);
  
  R visitBlock(Block node);
  R visitClassElement(ClassElement node);
  R visitFunctionElement(FunctionElement node);
  R visitVariableElement(VariableElement node);
  
  R visitClassMember(ClassMember node);
  R visitFieldElement(FieldElement node);
  R visitMethodElement(MethodElement node);
  R visitConstructorElement(ConstructorElement node);
}

class RecursiveElementVisitor<A> implements ElementVisitor<A> {
  A visitElementAnalysis(ElementAnalysis node) {
    node.librarySources.values.forEach(this.visitSourceElement);
    return null;
  }
  
  A visitSourceElement(SourceElement node) {
    visitBlock(node);
    if (node.library != null) this.visitLibraryElement(node.library);
    node.classes.forEach(this.visitClassElement);
    return null;
  }
  
  A visitLibraryElement(LibraryElement node) {
    
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
  
  A visitConstructorElement(ConstructorElement node) {
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
  ConstructorElement _currentConstructorElement = null;
  FieldDeclaration _currentFieldDeclaration = null;
  Block _currentBlock = null;
  
  ElementGenerator(Engine this.engine, Source this.source, ElementAnalysis this.analysis) {
    //print("Generating elements for: ${source} (${source.hashCode}) which is ${analysis.containsSource(source) ? "in already" : "not in already"}");
    if (!analysis.containsSource(source)) {
      CompilationUnit unit = engine.getCompilationUnit(source); 
      element = new SourceElement(source, unit);
      analysis.addSource(source, element);
      
      Block oldBlock = _currentBlock;
      _currentBlock = element;
      
      element.implicitImportedDartCore = _checkForImplicitDartCoreImport(unit);
      if (element.implicitImportedDartCore){
        Source dart_core = engine.resolveUri(source, DartSdk.DART_CORE);
        new ElementGenerator(engine, dart_core, analysis);
        element.addImport(dart_core, null);
      }
      
      this.visitCompilationUnit(unit);
      
      _currentBlock = oldBlock;
      
    } else {
      element = analysis.getSource(source);
    }
  }
  
  bool _checkForImplicitDartCoreImport(CompilationUnit unit){
    //Determine if the 'dart:core' library needs to be implicitly imported.
    bool isPartOf = false;
    bool importsCore = false;
    
    Source coreSource = engine.getCore(source);
    bool isCore = engine.isCore(source);
    
    if (!isCore){
      unit.directives.forEach((d) {
        if (d is ImportDirective) {
          Source importSource = engine.resolveDirective(source, d);
          if (importSource == coreSource) importsCore = true;
        }
        if (d is PartOfDirective) isPartOf = true;
      });
    }
    
    return !isCore && !isPartOf && !importsCore;
  }
  
  visitImportDirective(ImportDirective node) {
    Source import_source = engine.resolveDirective(source, node);
    ElementGenerator generator = new ElementGenerator(engine, import_source, analysis);
    element.addImport(import_source, node);
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
    element.addExport(export_source, node);
    super.visitExportDirective(node);
  }
  
  visitPartOfDirective(PartOfDirective node){
    element.libraryName = node.libraryName.toString();
    super.visitPartOfDirective(node);
  }
  
  visitLibraryDirective(LibraryDirective node) {
    analysis.addLibrarySource(node.name.toString(), element);
    element.libraryName = node.name.toString();
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
    
    if (_currentConstructorElement != null || _currentFieldDeclaration != null || _currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited method declaration, inside another method declaration.", source, node.offset, node.length), true);
    
    _currentMethodElement = new MethodElement(node, _currentClassElement);
    _currentClassElement.addMethod(_currentMethodElement);

    _currentMethodElement.parent_block = _currentBlock;
    _currentBlock = _currentMethodElement;
    
    super.visitMethodDeclaration(node);
    
    _currentBlock = _currentMethodElement.parent_block;
    _currentMethodElement = null;
  }
  
  visitConstructorDeclaration(ConstructorDeclaration node){
    if (_currentClassElement == null)
          engine.errors.addError(new EngineError("Visited constructor declaration, but currentClass was null.", source, node.offset, node.length), true);
        
    if (_currentConstructorElement != null || _currentFieldDeclaration != null || _currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited constructor declaration, inside another class member.", source, node.offset, node.length), true);
    
    _currentConstructorElement = new ConstructorElement(node, _currentClassElement);
    _currentClassElement.addConstructor(_currentConstructorElement);

    _currentConstructorElement.parent_block = _currentBlock;
    _currentBlock = _currentConstructorElement;
    
    super.visitConstructorDeclaration(node);
    
    _currentBlock = _currentConstructorElement.parent_block;
    _currentConstructorElement = null;
  }
  
  visitFieldDeclaration(FieldDeclaration node) {
    if (_currentClassElement == null)
      engine.errors.addError(new EngineError("Visited field declaration, but currentClass was null.", source, node.offset, node.length), true);
    if (_currentConstructorElement != null || _currentFieldDeclaration != null || _currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited field declaration, inside another class member.", source, node.offset, node.length), true);
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
      _currentBlock.addVariable(variable.ast.name, variable);
      return;
    } else {
      engine.errors.addError(new EngineError("The current block is not set, so the variable cannot be associated with any.", source, node.offset, node.length), true);
    }
  }
  
  visitFunctionDeclaration(FunctionDeclaration node) {
    FunctionElement functionElement = new FunctionElement(node, element);
    if (_currentBlock == null){
      engine.errors.addError(new EngineError("The current block is not set, so the function cannot be associated with any.", source, node.offset, node.length), true);
    }
    _currentBlock.addFunction(node, functionElement);
    
    functionElement.parent_block = _currentBlock;
    _currentBlock = functionElement;
    
    super.visitFunctionDeclaration(node);
    
    _currentBlock = functionElement.parent_block;
  }
}

