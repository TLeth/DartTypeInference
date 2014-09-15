library typeanalysis.element;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'engine.dart';
import 'resolver.dart';
import 'util.dart';

export 'resolver.dart' show LibraryElement;


//TODO (jln): Variable scoping rules, check page 13 in the specification (tlj).
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
  Map<Name, SourceElement> librarySources = <Name, SourceElement>{};
  
  bool containsSource(Source source) => sources.containsKey(source);
  SourceElement addSource(Source source, SourceElement element) => sources[source] = element;
  SourceElement getSource(Source source) => sources[source];
  
  bool containsLibrarySource(Name lib) => librarySources.containsKey(lib);
  SourceElement addLibrarySource(Name lib, SourceElement element) => librarySources[lib] = element;
  SourceElement getLibrarySource(Name lib) => librarySources[lib];

  dynamic accept(ElementVisitor visitor) => visitor.visitElementAnalysis(this);
}

class Name {
  String _name;
  
  Name(String this._name);
  factory Name.FromIdentifier(Identifier name) => new Name(name.toString());
  
  bool get isPrivate => Identifier.isPrivateName(_name);
  String get name => _name;
  
  bool operator ==(Object other){
    return other is Name && this._name == other._name;
  }
  
  String toString() => name;
  
  static Name SetterName(Name name) => new Name(name.name + "=");
  static Name UnaryMinusName() => new Name('unary-');
  static bool IsSetterName(Name name) => name._name[name._name.length - 1] == "=";
  static Name GetterName(Name name) => IsSetterName(name) ? new Name(name._name.substring(0, name._name.length - 1) ) : name;
  bool get isSetterName => IsSetterName(this); 
  
  int get hashCode => _name.hashCode;
}

class PrefixedName implements Name {
  String _prefix;
  Name _postfixName;
  
  PrefixedName(String this._prefix, Name this._postfixName);
  factory PrefixedName.FromIdentifier(Identifier prefix, Name postfixName) => new PrefixedName(prefix.toString(), postfixName);
  
  bool get isPrivate => Identifier.isPrivateName(_postfixName.toString()) || Identifier.isPrivateName(_prefix);
  
  String get _name => _prefix + "." + _postfixName.name;
  void set _name(String name) { _postfixName._name = name; }
  String get name => _name;
  bool get isSetterName => Name.IsSetterName(this);
  
 // int get hashCode => _prefix.hashCode + _postfixName.hashCode;
      
  bool operator ==(Object other){
    return other is PrefixedName && this._prefix == other._prefix && _postfixName == other._postfixName; 
  }
}

/** 
 * Instances of the class `Block` represents a static scope of the program. 
 * it could be a Library, a Class, a Method etc.
 * **/ 
class Block {
  Block enclosingBlock = null;
  List<Block> nestedBlocks = <Block>[];  

  Map<Name, Element> get declaredElements => MapUtil.union(declaredVariables, declaredFunctions);
  Map<Name, VariableElement> declaredVariables = <Name, VariableElement>{};
  Map<Name, NamedFunctionElement> declaredFunctions = <Name, NamedFunctionElement>{};
  
  VariableElement addVariable(VariableElement variable) => declaredVariables[variable.name] = variable; 
  VariableElement lookupVariableElement(Name name) => declaredVariables[name];

  NamedFunctionElement addFunction(NamedFunctionElement func) => declaredFunctions[func.name] = func;
  NamedFunctionElement lookupFunctionElement(Name name) => declaredFunctions[name];
}

abstract class Element {
  Source get librarySource => sourceElement.librarySource;
  SourceElement get sourceElement;
  
  bool get fromSystemLibrary => librarySource.isInSystemLibrary;
}

abstract class NamedElement extends Element {
  Name get name;
  bool get isPrivate => name.isPrivate;
  
  Name get getterName => name;
  Name get setterName => Name.SetterName(name);
}

/**
 * Instances of the class `SourceElement` represents a source file and contains all the the information reguarding its content
 **/
class SourceElement extends Block with Element {
  
  CompilationUnit ast;
  //If library is `null` it means that the library is implicit named. This means the library name is: ''.
  String libraryName = null;
  SourceElement partOf = null;
  Source source;
  Source get librarySource => (partOf == null ? source : partOf.source);
  SourceElement get sourceElement => this;
  
  Map<Source, SourceElement> parts = <Source, SourceElement>{};
  
  Map<Source, ImportDirective> imports = <Source, ImportDirective>{};
  Map<Source, ExportDirective> exports = <Source, ExportDirective>{};
  Map<Name, ClassElement> declaredClasses = <Name, ClassElement>{};
  
  Map<Identifier, Element> resolvedIdentifiers = <Identifier, Element>{};
  
  bool implicitImportedDartCore = false;
  
  LibraryElement library = null;
   
  SourceElement(Source this.source, CompilationUnit this.ast);
  
  ImportDirective addImport(Source source, ImportDirective directive) => imports[source] = directive;
  ExportDirective addExport(Source source, ExportDirective directive) => exports[source] = directive;
  void addPart(Source source, SourceElement element){ parts[source] = element; }
  ClassElement addClass(ClassElement classDecl) => declaredClasses[classDecl.name] = classDecl;
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
class ClassElement extends NamedElement with Block {
  Map<Name, FieldElement> declaredFields = <Name, FieldElement>{};
  Map<Name, MethodElement> declaredMethods = <Name, MethodElement>{};
  Map<Name, ConstructorElement> declaredConstructors = <Name, ConstructorElement>{};

  Map<Name, Element> get declaredElements => [declaredFields, declaredMethods, declaredConstructors].reduce(MapUtil.union);
  
  ClassDeclaration ast;
  
  SourceElement sourceElement;
  
  Name name;
  bool get isAbstract => ast.isAbstract;
  bool get isSynthetic => ast.isSynthetic;
  
  ClassElement(ClassDeclaration this.ast, SourceElement this.sourceElement) {
    name = new Name.FromIdentifier(this.ast.name);
  }
  
  dynamic accept(ElementVisitor visitor) => visitor.visitClassElement(this);

  FieldElement addField(Name name, FieldElement field) => declaredFields[name] = field;
  MethodElement addMethod(Name name, MethodElement method) => declaredMethods[name] = method;
  ConstructorElement addConstructor(Name name, ConstructorElement constructor) => declaredConstructors[name] = constructor;

  String toString() {
    return "Class [${isAbstract ? ' abstract ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${name}";
  }
  
  ClassMember lookup(Name name) {
    List<ClassMember> res = <ClassMember>[];
    if (declaredFields.containsKey(name))
      res.add(declaredFields[name]);
    
    if (declaredMethods.containsKey(name))
      res.add(declaredMethods[name]);
    
    if (declaredConstructors.containsKey(name))
      res.add(declaredConstructors[name]);
    
    if (res.length == 1) 
      return res[0];
    else 
      return null;
  }
}


/** 
 * Instance of a `VariableElement` is our abstract representation of a variable.
 **/
class VariableElement extends NamedElement {
  Block enclosingBlock = null;
  VariableDeclaration variableAst;
  FormalParameter parameterAst;
  
  dynamic get ast => (variableAst == null) ? parameterAst : variableAst;
  bool get isSynthetic => this.ast.isSynthetic;
  bool get isConst => this.ast.isConst;
  bool get isFinal => this.ast.isFinal;
  Name name;
  
  SourceElement sourceElement;

  dynamic accept(ElementVisitor visitor) => visitor.visitVariableElement(this);

  VariableElement(VariableDeclaration this.variableAst, Block this.enclosingBlock, SourceElement this.sourceElement, [FormalParameter this.parameterAst = null]) {
    if (parameterAst != null)
      name = new Name.FromIdentifier(this.ast.identifier);
    else
      name = new Name.FromIdentifier(this.ast.name);
  }
  
  String toString() {
    return "Var [${isConst ? ' const ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${name}";
  }
}

/**
 * Instances of a class `ClassMember` is a our abstract representation of class members
 **/
abstract class ClassMember {
  ClassElement get classDecl;
  
  SourceElement get sourceElement => classDecl.sourceElement;
}


/**
 * Instances of a class`FieldElement` is a our abstract representation of fields
 **/
class FieldElement extends NamedElement with ClassMember {
  FieldDeclaration ast;
  VariableDeclaration varDecl;
  ClassElement classDecl;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => varDecl.isConst;
  bool get isFinal => varDecl.isFinal;
  
  Name name;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitFieldElement(this);

  FieldElement(FieldDeclaration this.ast,VariableDeclaration this.varDecl, ClassElement this.classDecl) {
    name = new Name.FromIdentifier(this.varDecl.name);
  }
  
  String toString() {
    return "Field [${isConst ? ' const ' : ''}"+
            "${isStatic ? ' static ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${name}";
  }
}

/**
 * Instances of a class`MethodElement` is a our abstract representation of methods
 **/
class MethodElement extends NamedElement with Block, ClassMember {
  MethodDeclaration ast;
  ClassElement classDecl;
  
  Name _name;
  Name get setterName => Name.SetterName(_name);
  Name get getterName => _name;
  Name get name => isSetter ? setterName : getterName;
  bool get isAbstract => ast.isAbstract;
  bool get isGetter => ast.isGetter;
  bool get isOperator => ast.isOperator;
  bool get isSetter => ast.isSetter;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
    
  dynamic accept(ElementVisitor visitor) => visitor.visitMethodElement(this);
  
  MethodElement(MethodDeclaration this.ast, ClassElement this.classDecl) {
    if (this.ast.name.toString() == '-' && this.ast.parameters.length == 0){
      _name = Name.UnaryMinusName();
    } else if (isSetter) {
      _name = Name.SetterName(new Name.FromIdentifier(this.ast.name));
    } else {
      _name = new Name.FromIdentifier(this.ast.name);
    }
  }
  
  String toString() {
    return "Method [${isAbstract ? ' abstract ' : ''}"+
            "${isGetter ? ' getter ' : ''}"+
            "${isSetter ? ' setter ' : ''}"+
            "${isOperator ? ' oper ' : ''}"+
            "${isStatic ? ' static ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ast.returnType} ${name}(${ast.parameters})";
  }
}

/**
 * Instances of a class `ConstructorElement` is a our abstract representation of constructors
 **/
class ConstructorElement extends NamedElement with Block, ClassMember {
  ConstructorDeclaration ast;
  ClassElement classDecl;
  
  Name name;
  bool get isSynthetic => ast.isSynthetic;
  bool get isFactory => ast.factoryKeyword != null;
  bool get isExternal => ast.externalKeyword != null;
    
  dynamic accept(ElementVisitor visitor) => visitor.visitConstructorElement(this);

  ConstructorElement(ConstructorDeclaration this.ast, ClassElement this.classDecl) {
    name = new Name.FromIdentifier(this.ast.name);
  }
  
  String toString() {
    return "Constructor [${isFactory ? ' factory ' : ''}"+
            "${isExternal ? ' external ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${ast.returnType} ${name}(${ast.parameters})";
  }
}


/**
 * Instances of a class`FunctionElement` is a our abstract representation of functions
 **/
class FunctionElement extends Block with Element {
  FunctionExpression ast;
  SourceElement sourceElement;
  
  
  bool get isSynthetic => ast.isSynthetic;
  

  dynamic accept(ElementVisitor visitor) => visitor.visitFunctionElement(this);
  
  FunctionElement(FunctionExpression this.ast, SourceElement this.sourceElement);
  
  String toString(){
    return "Func [${isSynthetic ? ' synthetic ' : ''}] annonymous";
  }
}

class NamedFunctionElement extends FunctionElement implements NamedElement {
  FunctionDeclaration decl;
  Name _name;
  Name get setterName => Name.SetterName(_name);
  Name get getterName => _name;
  bool get isPrivate => _name.isPrivate; 
  Name get name => isSetter ? setterName : getterName;
  bool get isGetter => decl.isGetter;
  bool get isSetter => decl.isSetter;
  
  NamedFunctionElement(FunctionDeclaration decl, SourceElement sourceElement) : super(decl.functionExpression, sourceElement) {
    this.decl = decl;
    _name = new Name.FromIdentifier(decl.name);
  }
}


abstract class ElementVisitor<R> {
  R visitElementAnalysis(ElementAnalysis node);
  
  R visitSourceElement(SourceElement node);
  R visitLibraryElement(LibraryElement node);
  
  R visitBlock(Block node);
  R visitClassElement(ClassElement node);
  R visitFunctionElement(FunctionElement node);
  R visitNamedFunctionElement(NamedFunctionElement node);
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
    node.declaredClasses.values.forEach(this.visitClassElement);
    return null;
  }
  
  A visitLibraryElement(LibraryElement node) {
    return null;
  }
  
  A visitClassElement(ClassElement node) {
    node.declaredFields.values.forEach(this.visitFieldElement);
    node.declaredMethods.values.forEach(this.visitMethodElement);
    return null;
  }
  
  A visitFunctionElement(FunctionElement node) {
    visitBlock(node);
    return null;
  }
  
  A visitNamedFunctionElement(NamedFunctionElement node){
    visitFunctionElement(node);
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
    node.declaredFunctions.values.forEach(this.visitFunctionElement);
    node.nestedBlocks.forEach(this.visitBlock);
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
  FunctionDeclaration _lastSeenFunctionDeclaration = null;
  Block _currentBlock = null;
  
  
  enterNewBlock(Block newBlock, k) {
    var oldBlock = _currentBlock,
        oldMethodElement = _currentMethodElement,
        isMethod = newBlock is MethodElement;
    
    newBlock.enclosingBlock = oldBlock;
    oldBlock.nestedBlocks.add(newBlock);

    _currentBlock = newBlock;
    if (isMethod) {
      _currentMethodElement = newBlock;
    }
    
    var ret = k();
    
    _currentBlock = oldBlock;
    if (isMethod) {
      _currentMethodElement = oldMethodElement;
        
    }
    return ret;
  }
  
  
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
    analysis.addLibrarySource(new Name.FromIdentifier(node.name), element);
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
    _currentClassElement.addMethod(_currentMethodElement.name, _currentMethodElement);

    _currentMethodElement.enclosingBlock = _currentBlock;
    _currentBlock.nestedBlocks.add(_currentMethodElement);
    _currentBlock = _currentMethodElement;
    
    super.visitMethodDeclaration(node);
    
    _currentBlock = _currentMethodElement.enclosingBlock;
    _currentMethodElement = null;
  }
  
  visitConstructorDeclaration(ConstructorDeclaration node){
    if (_currentClassElement == null)
          engine.errors.addError(new EngineError("Visited constructor declaration, but currentClass was null.", source, node.offset, node.length), true);
        
    if (_currentConstructorElement != null || _currentFieldDeclaration != null || _currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited constructor declaration, inside another class member.", source, node.offset, node.length), true);
    
    _currentConstructorElement = new ConstructorElement(node, _currentClassElement);
    _currentClassElement.addConstructor(_currentConstructorElement.name, _currentConstructorElement);

    _currentConstructorElement.enclosingBlock = _currentBlock;
    _currentBlock.nestedBlocks.add(_currentConstructorElement);
    _currentBlock = _currentConstructorElement;
    
    super.visitConstructorDeclaration(node);
    
    _currentBlock = _currentConstructorElement.enclosingBlock;
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
  
  visitVariableDeclaration(VariableDeclaration node) {
    if (_currentFieldDeclaration != null) {
      if (_currentClassElement == null)
         engine.errors.addError(new EngineError("Visited variable decl inside a field declaration, but currentClass was null.", source, node.offset, node.length), true);
      
      FieldElement field = new FieldElement(_currentFieldDeclaration, node, _currentClassElement);
      _currentClassElement.addField(field.name, field);
      super.visitVariableDeclaration(node);
      return;
    }
    
    if (_currentBlock != null) {
      VariableElement variable = new VariableElement(node, _currentBlock, element);
      _currentBlock.addVariable(variable);
      super.visitVariableDeclaration(node);
      return;
    } else {
      engine.errors.addError(new EngineError("The current block is not set, so the variable cannot be associated with any.", source, node.offset, node.length), true);
    }
  }
  
  visitFunctionDeclaration(FunctionDeclaration node) {
    _lastSeenFunctionDeclaration = node;
    super.visitFunctionDeclaration(node);
  }

  visitFunctionExpression(FunctionExpression node) {
    if (_currentBlock == null){
      engine.errors.addError(new EngineError("The current block is not set, so the function cannot be associated with any.", source, node.offset, node.length), true);
    }
    
    FunctionElement functionElement;
    if (_lastSeenFunctionDeclaration != null){
      functionElement = new NamedFunctionElement(_lastSeenFunctionDeclaration, element);
      _lastSeenFunctionDeclaration = null;
      _currentBlock.addFunction(functionElement);
    } else {
      functionElement = new FunctionElement(node, element);
    }
    
    enterNewBlock(functionElement, (){
      super.visitFunctionExpression(node);
    });
   
    
/*  
    functionElement.enclosingBlock = _currentBlock;
    _currentBlock.nestedBlocks.add(functionElement);
    _currentBlock = functionElement;
    
    
    _currentBlock = functionElement.enclosingBlock;
*/
    }
  
  visitFormalParameterList(FormalParameterList node){
    enterNewBlock(new Block(), (){
      super.visitFormalParameterList(node);
    });
  }
  
  visitFormalParameter(FormalParameter node){
    if (_currentBlock == null) {
      engine.errors.addError(new EngineError("The current block is not set, so the variable cannot be associated with any.", source, node.offset, node.length), true);
    }
    
    VariableElement variable = new VariableElement(null, _currentBlock, element, node);

    _currentBlock.addVariable(variable);
    super.visitFormalParameter(node);  
  }
}

