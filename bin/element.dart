library typeanalysis.element;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/ast.dart' as astElement show Block;
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'engine.dart';
import 'resolver.dart';
import 'util.dart';
import 'printer.dart';

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
  
  // Mapping from each ast node to the Element
  Map<AstNode, Element> elements = <AstNode, Element>{};
  
  Engine engine;
  
  bool containsSource(Source source) => sources.containsKey(source);
  SourceElement addSource(Source source, SourceElement element) => sources[source] = element;
  SourceElement getSource(Source source) => sources[source];
  
  bool containsLibrarySource(Name lib) => librarySources.containsKey(lib);
  SourceElement addLibrarySource(Name lib, SourceElement element) => librarySources[lib] = element;
  SourceElement getLibrarySource(Name lib) => librarySources[lib];
  
  bool containsElement(AstNode e) => elements.containsKey(e);
  Element addElement(AstNode ast, Element e) => elements[ast] = e;
  Element getElement(AstNode ast) => elements[ast];

  dynamic accept(ElementVisitor visitor) => visitor.visitElementAnalysis(this);
  
  ElementAnalysis(Engine this.engine);
  
  LibraryElement get dartCore {
    var coreName = new Name("dart.core");
    if (librarySources.containsKey(coreName))
      return librarySources[coreName].library;
    else
      return null;
  }

  ClassElement resolveClassElement(Name name, LibraryElement library, SourceElement source) {
    if (library.scope.containsKey(name)){
      List<NamedElement> elements = library.scope[name];
      if (elements.length == 1 && elements[0] is ClassElement)
        return elements[0];
      else
        engine.errors.addError(new EngineError("Resolving classElement could find: `${name}` in `${library.source}` but it didn´t have type ClassElement.", source.source, source.ast.offset, source.ast.length));
    } else {
      engine.errors.addError(new EngineError("Resolving classElement could not find: `${name}` in `${library.source}`.", source.source, source.ast.offset, source.ast.length));
    }
      
    return null; 
  }
}

class Name {
  String _name;
  
  Name(String this._name);
  
  factory Name.FromIdentifier(Identifier name){
    if (name is PrefixedIdentifier){
      return new PrefixedName.FromPrefixedIdentifier(name); 
    } else {
      return new Name(name.toString());
    }
  }
  
  factory Name.FromToken(Token name) => new Name(name.toString());
  
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
  Name _prefix;
  Name _postfixName;
  
  PrefixedName(Name this._prefix, Name this._postfixName);
  factory PrefixedName.FromIdentifier(Identifier prefix, Name postfixName) => new PrefixedName(new Name.FromIdentifier(prefix), postfixName);
  factory PrefixedName.FromPrefixedIdentifier(PrefixedIdentifier ident) => new PrefixedName(new Name.FromIdentifier(ident.prefix), new Name.FromIdentifier(ident.identifier));
  
  bool get isPrivate => Identifier.isPrivateName(_postfixName.toString()) || Identifier.isPrivateName(_prefix.toString());
  
  String get _name => _prefix.name + "." + _postfixName.name;
  void set _name(String name) { _postfixName._name = name; }
  String get name => _name;
  bool get isSetterName => Name.IsSetterName(this);
  
 int get hashCode => _prefix.hashCode + _postfixName.hashCode;
      
  bool operator ==(Object other){
    return other is PrefixedName && this._prefix == other._prefix && _postfixName == other._postfixName; 
  }
  
  String toString() => "${_prefix}.${_postfixName}";
}

/*
 * Instances of the class `Block` represents a static scope of the program. 
 * it could be a Library, a Class, a Method etc.
 */ 

abstract class Block extends Element {
  Block enclosingBlock = null;
  List<Block> nestedBlocks = <Block>[];
  
  AstNode get ast;


  List<AstNode> referenceNodes = <AstNode>[];
  Map<Name, NamedElement> get declaredElements => MapUtil.union(declaredVariables, declaredFunctions);
  Map<Name, VariableElement> declaredVariables = <Name, VariableElement>{};
  Map<Name, NamedFunctionElement> declaredFunctions = <Name, NamedFunctionElement>{};
  
  void addReferenceNode(SimpleIdentifier ident) => referenceNodes.add(ident);
  VariableElement addVariable(VariableElement variable) => declaredVariables[variable.name] = variable; 
  VariableElement lookupVariableElement(Name name) => declaredVariables[name];

  NamedFunctionElement addFunction(NamedFunctionElement func) => declaredFunctions[func.name] = func;
  NamedFunctionElement lookupFunctionElement(Name name) => declaredFunctions[name];
}

class BlockElement extends Block {
  astElement.Block ast;
  SourceElement sourceElement;
  
  BlockElement(astElement.Block this.ast, SourceElement this.sourceElement);
  dynamic accept(ElementVisitor visitor) => visitor.visitBlockElement(this);
}

abstract class Element {
  Source get librarySource => sourceElement.librarySource;
  SourceElement get sourceElement;
  
  bool get fromSystemLibrary => librarySource.isInSystemLibrary;
  AstNode get ast;


  dynamic accept(ElementVisitor visitor);
}

abstract class NamedElement extends Element {
  Name get name;
  Identifier get identifier;
  bool get isPrivate => name.isPrivate;
  
  Name get getterName => name;
  Name get setterName => Name.SetterName(name);
}

abstract class AnnotatedElement extends NamedElement {
  AstNode get ast;
  TypeName get annotatedType => null;
}

/**
 * Instances of the class `SourceElement` represents a source file and contains all the the information reguarding its content
 **/
class SourceElement extends Block {
  
  CompilationUnit ast;
  //If library is `null` it means that the library is implicit named. This means the library name is: ''.
  String libraryName = null;
  SourceElement partOf = null;
  Source source;
  Source get librarySource => (partOf == null ? source : partOf.source);
  SourceElement get sourceElement => this;
  

  Map<Name, NamedElement> get declaredElements => [declaredVariables, declaredFunctions, declaredClasses].reduce(MapUtil.union);
  Map<Source, SourceElement> parts = <Source, SourceElement>{};
  
  Map<ImportDirective, Source> imports = <ImportDirective, Source>{};
  Map<ExportDirective, Source> exports = <ExportDirective, Source>{};
  Map<Name, ClassElement> declaredClasses = <Name, ClassElement>{};
  
  Map<ThisExpression, ClassElement> thisReferences = <ThisExpression, ClassElement>{};
  Map<Identifier, NamedElement> resolvedIdentifiers = <Identifier, NamedElement>{};
  
  bool implicitImportedDartCore = false;
  
  LibraryElement library = null;
   
  SourceElement(Source this.source, CompilationUnit this.ast);
  
  Source addImport(Source source, ImportDirective directive) => imports[directive] = source;
  Source addExport(Source source, ExportDirective directive) => exports[directive] = source;
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
class ClassElement extends Block implements NamedElement {
  Map<Name, FieldElement> declaredFields = <Name, FieldElement>{};
  Map<Name, MethodElement> declaredMethods = <Name, MethodElement>{};
  Map<Name, ConstructorElement> declaredConstructors = <Name, ConstructorElement>{};

  Map<Name, NamedElement> get declaredElements => [declaredFields, declaredMethods].reduce(MapUtil.union);
  
  ClassDeclaration _decl;
  
  SourceElement sourceElement;
  
  Name name;
  bool get isPrivate => name.isPrivate;
  
  Name get getterName => name;
  Name get setterName => Name.SetterName(name);
  
  ClassElement extendsElement = null;
  Identifier get identifier => _decl.name;
  
  AstNode get ast => _decl;
  bool get isAbstract => _decl.isAbstract;
  bool get isSynthetic => _decl.isSynthetic;
  TypeName get superclass => _decl.extendsClause == null ? null : _decl.extendsClause.superclass;
  
  ClassElement._WithName(ClassDeclaration this._decl, SourceElement this.sourceElement, Name this.name);
  
  factory ClassElement(ClassDeclaration _decl, SourceElement sourceElement) =>
    new ClassElement._WithName(_decl, sourceElement, new Name.FromIdentifier(_decl.name));
  
  dynamic accept(ElementVisitor visitor) => visitor.visitClassElement(this);

  FieldElement addField(Name name, FieldElement field) => declaredFields[name] = field;
  MethodElement addMethod(Name name, MethodElement method) => declaredMethods[name] = method;
  ConstructorElement addConstructor(Name name, ConstructorElement constructor) => declaredConstructors[name] = constructor;

  String toString() {
    return "Class [${isAbstract ? ' abstract' : ''}"+
            "${isSynthetic ? ' synthetic' : ''}] ${name}${extendsElement != null ? ' extends ${extendsElement.name}' : ''}";
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
    else if (res.length == 0 && extendsElement != null)
      return extendsElement.lookup(name);
    else
      return null;
  }
}

class ClassAliasElement extends ClassElement {
  
  ClassTypeAlias _alias;
  TypeName get superclass => _alias.superclass;
  bool get isAbstract => _alias.isAbstract;
  bool get isSynthetic => _alias.isSynthetic;
  Identifier get identifier => _alias.name;
  AstNode get ast => _alias;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitClassAliasElement(this);
  
  ClassAliasElement(ClassTypeAlias _alias, SourceElement sourceElement) : 
    super._WithName(null, sourceElement, new Name.FromIdentifier(_alias.name)) {
    this._alias = _alias;
  }
}


/** 
 * Instance of a `VariableElement` is our abstract representation of a variable.
 **/
class VariableElement extends AnnotatedElement {
  Block enclosingBlock = null;
  VariableDeclaration variableAst;
  
  dynamic get ast => variableAst;
  bool get isSynthetic => variableAst.isSynthetic;
  bool get isConst => variableAst.isConst;
  bool get isFinal => variableAst.isFinal;
  Name name;
  Identifier get identifier => variableAst.name;
  
  TypeName annotatedType;
  
  SourceElement sourceElement;

  dynamic accept(ElementVisitor visitor) => visitor.visitVariableElement(this);

  VariableElement(VariableDeclaration this.variableAst, Block this.enclosingBlock, TypeName this.annotatedType, SourceElement this.sourceElement) {
    if (variableAst != null)
      name = new Name.FromIdentifier(variableAst.name);
  }
  
  String toString() {
    return "Var ${annotatedType} [${isConst ? ' const ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${name}";
  }
}

class ParameterElement extends VariableElement {
  FormalParameter parameterAst;
  dynamic get ast => parameterAst;
  bool get isSynthetic => parameterAst.isSynthetic;
  bool get isConst => parameterAst.isConst;
  bool get isFinal => parameterAst.isFinal;
  Identifier get identifier => parameterAst.identifier;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitParameterElement(this);
  
  ParameterElement(FormalParameter this.parameterAst, Block enclosingBlock, TypeName annotatedType, SourceElement sourceElement) : super(null, enclosingBlock, annotatedType, sourceElement) {
    if (parameterAst != null)
      name = new Name.FromIdentifier(parameterAst.identifier);
  }
  
  String toString() {
    return "Param ${annotatedType} [${isConst ? ' const ' : ''}"+
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
 * instance of the class `Callable` is our abstraction of an element that can be invoked.
 */
abstract class CallableElement extends Element {
  TypeName get returnType;
  FormalParameterList get parameters;
  List<ReturnElement> get returns;
  void addReturn(ReturnElement);
}


/**
 * Instances of a class`FieldElement` is a our abstract representation of fields
 **/
class FieldElement extends AnnotatedElement with ClassMember {
  FieldDeclaration ast;
  VariableDeclaration varDecl;
  ClassElement classDecl;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
  bool get isConst => varDecl.isConst;
  bool get isFinal => varDecl.isFinal;
  
  Name name;
  Identifier get identifier => this.varDecl.name;
  
  TypeName annotatedType;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitFieldElement(this);

  FieldElement(FieldDeclaration this.ast,VariableDeclaration this.varDecl, TypeName this.annotatedType, ClassElement this.classDecl) {
    name = new Name.FromIdentifier(this.varDecl.name);
  }
  
  String toString() {
    return "Field ${annotatedType} [${isConst ? ' const ' : ''}"+
            "${isStatic ? ' static ' : ''}"+
            "${isFinal ? ' final ' : ''}"+
            "${isSynthetic ? ' synthetic ' : ''}] ${name}";
  }
}

/**
 * Instances of a class`MethodElement` is a our abstract representation of methods
 **/
class MethodElement extends Block with ClassMember implements CallableElement, NamedElement {
  MethodDeclaration ast;
  ClassElement classDecl;
  
  Name _name;
  Name get setterName => Name.SetterName(_name);
  Name get getterName => _name;

  Name get name => isSetter ? setterName : getterName;
  Identifier get identifier => this.ast.name;
  bool get isAbstract => ast.isAbstract;
  bool get isGetter => ast.isGetter;
  bool get isOperator => ast.isOperator;
  bool get isSetter => ast.isSetter;
  bool get isStatic => ast.isStatic;
  bool get isSynthetic => ast.isSynthetic;
  bool get isPrivate => name.isPrivate;

  
  TypeName get returnType => ast.returnType;
  FormalParameterList get parameters => ast.parameters;
  List<ReturnElement> _returns = <ReturnElement>[];
  List<ReturnElement> get returns => _returns;
  void addReturn(ReturnElement r) => _returns.add(r); 
    
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
class ConstructorElement extends Block with ClassMember implements NamedElement, CallableElement{
  ConstructorDeclaration ast;
  ClassElement classDecl;
  
  Name name; 
  bool get isPrivate => name.isPrivate;
  
  Name get getterName => name;
  Name get setterName => Name.SetterName(name);
  Identifier get identifier => (this.ast.name != null ? this.ast.name : this.ast.returnType);
  bool get isSynthetic => ast.isSynthetic;
  bool get isFactory => ast.factoryKeyword != null;
  bool get isExternal => ast.externalKeyword != null;
  TypeName _returnType;
  TypeName get returnType => _returnType;
  FormalParameterList get parameters => ast.parameters;
  List<ReturnElement> _returns = <ReturnElement>[];
  List<ReturnElement> get returns => _returns;
  void addReturn(ReturnElement r) => _returns.add(r);
    
  dynamic accept(ElementVisitor visitor) => visitor.visitConstructorElement(this);

  ConstructorElement(ConstructorDeclaration this.ast, ClassElement this.classDecl) {
    if (this.ast.name != null)
      name = new PrefixedName.FromIdentifier(this.ast.returnType, new Name.FromIdentifier(this.ast.name));
    else
      name = new Name.FromIdentifier(this.ast.returnType);
    
    _returnType = new TypeName(ast.returnType, null);
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
class FunctionElement extends Block with Element implements CallableElement {
  FunctionExpression ast;
  SourceElement sourceElement;

  TypeName get returnType => null;
  FormalParameterList get parameters => ast.parameters;
  List<ReturnElement> _returns = <ReturnElement>[];
  List<ReturnElement> get returns => _returns;
  void addReturn(ReturnElement r) => _returns.add(r);
  bool get isSynthetic => ast.isSynthetic;
  

  dynamic accept(ElementVisitor visitor) => visitor.visitFunctionElement(this);
  
  FunctionElement(FunctionExpression this.ast, SourceElement this.sourceElement);
  
  String toString() => "Func [${isSynthetic ? ' synthetic ' : ''}] annonymous";
}

class FunctionParameterElement extends ParameterElement implements CallableElement {
  FunctionTypedFormalParameter formalParamAst;
  FormalParameterList get parameters => formalParamAst.parameters;
  List<ReturnElement> get returns => [];
  void addReturn(ReturnElement r) => null;
  TypeName get returnType => formalParamAst.returnType;
  
  
  FunctionParameterElement(FunctionTypedFormalParameter ast, Block enclosingBlock, TypeName annotatedType, SourceElement sourceElement) 
  : super(ast, enclosingBlock, annotatedType, sourceElement) {
    formalParamAst = ast;
  }
}

class NamedFunctionElement extends FunctionElement implements NamedElement {
  FunctionDeclaration decl;
  Name _name;
  Name get setterName => Name.SetterName(_name);
  Name get getterName => _name;
  bool get isPrivate => _name.isPrivate; 
  Name get name => isSetter ? setterName : getterName;
  Identifier get identifier => decl.name;
  bool get isGetter => decl.isGetter;
  bool get isSetter => decl.isSetter;
  AstNode get ast => decl;
  FormalParameterList get parameters => decl.functionExpression.parameters;
  bool get isSynthetic => decl.functionExpression.isSynthetic;

  TypeName get returnType => decl.returnType;
  
  dynamic accept(ElementVisitor visitor) => visitor.visitNamedFunctionElement(this);
  
  NamedFunctionElement(FunctionDeclaration decl, SourceElement sourceElement) : super(decl.functionExpression, sourceElement) {
    this.decl = decl;
    _name = new Name.FromIdentifier(decl.name);
  }
  
  String toString() => "Func [${isSynthetic ? ' synthetic ' : ''}] ${name}";
}

class ReturnElement extends Element {
  SourceElement sourceElement;
  ReturnStatement ast;
  CallableElement function;

  dynamic accept(ElementVisitor visitor) => visitor.visitReturnElement(this);
  ReturnElement(ReturnStatement this.ast, CallableElement this.function, SourceElement this.sourceElement);
}


abstract class ElementVisitor<R> {
  R visitElementAnalysis(ElementAnalysis node);
  
  R visitSourceElement(SourceElement node);
  R visitLibraryElement(LibraryElement node);
  
  R visitBlock(Block node);
  R visitClassElement(ClassElement node);
  R visitClassAliasElement(ClassAliasElement node);
  R visitReturnElement(ReturnElement node);
  R visitFunctionElement(FunctionElement node);
  R visitNamedFunctionElement(NamedFunctionElement node);
  R visitVariableElement(VariableElement node);
  R visitParameterElement(ParameterElement node);
  R visitFunctionParameterElement(FunctionParameterElement node);
  
  R visitClassMember(ClassMember node);
  R visitFieldElement(FieldElement node);
  R visitMethodElement(MethodElement node);
  R visitConstructorElement(ConstructorElement node);
  R visitCallableElement(CallableElement node);
  R visitNamedElement(NamedElement node);
  R visitAnnotatedElement(AnnotatedElement node);
  R visitBlockElement(BlockElement node);
}

class RecursiveElementVisitor<A> implements ElementVisitor<A> {
  A visitElementAnalysis(ElementAnalysis node) {
    node.librarySources.values.forEach(visit);
    return null;
  }
  
  A visitSourceElement(SourceElement node) {
    if (node.library != null) this.visitLibraryElement(node.library);
    visitBlock(node);
    node.declaredClasses.values.forEach(visit);    
    return null;
  }
  
  A visitLibraryElement(LibraryElement node) {
    return null;
  }
  
  A visitClassElement(ClassElement node) {
    visitNamedElement(node);
    visitBlock(node);
    node.declaredFields.values.forEach(visit);
    node.declaredMethods.values.forEach(visit);
    return null;
  }
  
  A visitBlockElement(BlockElement node){
    visitBlock(node);
    return null;
  }
  
  A visit(Element node) {
    node.accept(this);
    return null;
  }
  
  A visitNamedElement(NamedElement node){
    return null;
  }
  
  A visitParameterElement(ParameterElement node){
    visitAnnotatedElement(node);
    return null;
  }
  
  A visitFunctionParameterElement(FunctionParameterElement node){
    visitAnnotatedElement(node);
    visitCallableElement(node);
    return null;
  }
  
  A visitCallableElement(CallableElement node) {
    node.returns.forEach(visit);
    return null;
  }
  
  A visitReturnElement(ReturnElement node) {
    return null;
  }
  
  A visitClassAliasElement(ClassAliasElement node){
    visitNamedElement(node);
    visitBlock(node);
    return null;
  }
  
  A visitFunctionElement(FunctionElement node) {
    visitCallableElement(node);
    visitBlock(node);
    return null;
  }
  
  A visitAnnotatedElement(AnnotatedElement node) {
    visitNamedElement(node);
    return null;
  }
  
  A visitNamedFunctionElement(NamedFunctionElement node){
    visitNamedElement(node);
    visitCallableElement(node);
    visitBlock(node);
    return null;
  }
  
  A visitVariableElement(VariableElement node) {    
    visitAnnotatedElement(node);
    return null;
  }
  
  A visitClassMember(ClassMember node) {
    return null;
  }
  
  A visitBlock(Block node){
    node.declaredFunctions.values.forEach(visit);
    node.declaredVariables.values.forEach(visit);
    node.nestedBlocks.forEach((Block b){
      if (!node.declaredFunctions.containsValue(b))  //Dont visit functions twice.
        visitBlock(b);
    });
    return null;
  }
  
  A visitMethodElement(MethodElement node) {
    visitNamedElement(node);
    visitCallableElement(node);
    visitClassMember(node);
    visitBlock(node);
    return null;
  }
  
  A visitConstructorElement(ConstructorElement node) {
    visitNamedElement(node);
    visitCallableElement(node);
    visitClassMember(node);
    visitBlock(node);
    return null;
  }
  
  A visitFieldElement(FieldElement node) {
    visitNamedElement(node);
    visitAnnotatedElement(node);
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
  CallableElement _currentCallableElement = null; 
  FunctionDeclaration _lastSeenFunctionDeclaration = null;
  Block _currentBlock = null;
  TypeName _currentVariableType = null;
  
  
  _enterBlock(Block block) {
    block.enclosingBlock = _currentBlock;
    _currentBlock.nestedBlocks.add(block);
    _currentBlock = block;
  }
  
  _leaveBlock(){
    if (_currentBlock != null)
      _currentBlock = _currentBlock.enclosingBlock;
  }
  
  
  ElementGenerator(Engine this.engine, Source this.source, ElementAnalysis this.analysis) {
    //print("Generating elements for: ${source} (${source.hashCode}) which is ${analysis.containsSource(source) ? "in already" : "not in already"}");
    if (!analysis.containsSource(source)) {
      CompilationUnit unit = engine.getCompilationUnit(source);
      element = new SourceElement(source, unit);
      analysis.addElement(unit, element);
      analysis.addSource(source, element);
      
      Block oldBlock = _currentBlock;
      _currentBlock = element;
      
      element.implicitImportedDartCore = _checkForImplicitDartCoreImport(unit);
      if (element.implicitImportedDartCore){
        Source dart_core = engine.resolveUri(source, DartSdk.DART_CORE);
        new ElementGenerator(engine, dart_core, analysis);
        element.addImport(dart_core, null);
      }
      
      //unit.accept(new PrintAstVisitor());
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
  
  visitPrefixedIdentifier(PrefixedIdentifier node){
    //_currentBlock.addReferenceNode(node);
    _currentBlock.addReferenceNode(node.prefix);
  }
  
  visitSimpleIdentifier(SimpleIdentifier node){
    _currentBlock.addReferenceNode(node);
  }
  
  visitPropertyAcces(PropertyAccess node) {
    _currentBlock.addReferenceNode(node.target);
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
  }
  
  visitLibraryDirective(LibraryDirective node) {
    analysis.addLibrarySource(new Name.FromIdentifier(node.name), element);
    element.libraryName = node.name.toString();
  }
  
  visitClassDeclaration(ClassDeclaration node){
    _currentClassElement = new ClassElement(node, element);
    analysis.addElement(node, _currentClassElement);
    _enterBlock(_currentClassElement);
    
    element.addClass(_currentClassElement);
    
    super.visitClassDeclaration(node);
    _leaveBlock();
    _currentClassElement = null;
  }
  
  visitClassTypeAlias(ClassTypeAlias node){
    Element classElement = new ClassAliasElement(node, element);
    analysis.addElement(node, classElement);
    element.addClass(classElement);
    super.visitClassTypeAlias(node);
  }
  
  visitMethodDeclaration(MethodDeclaration node) {
    if (_currentClassElement == null)
      engine.errors.addError(new EngineError("Visited method declaration, but currentClass was null.", source, node.offset, node.length), true);
    
    if (_currentConstructorElement != null || _currentFieldDeclaration != null || _currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited method declaration, inside another method declaration.", source, node.offset, node.length), true);
    
    _currentMethodElement = new MethodElement(node, _currentClassElement);
    analysis.addElement(node, _currentMethodElement);
    _currentClassElement.addMethod(_currentMethodElement.name, _currentMethodElement);
    
    _currentCallableElement = _currentMethodElement;
    _enterBlock(_currentMethodElement);
    
    super.visitMethodDeclaration(node);
    
    _leaveBlock();
    _currentCallableElement = null;
    _currentMethodElement = null;
  }
  
  visitTypeName(TypeName node){
    //Dont do anything, this prevents types to be added to the referneceNodes.
  }
  
  visitConstructorDeclaration(ConstructorDeclaration node){
    if (_currentClassElement == null)
          engine.errors.addError(new EngineError("Visited constructor declaration, but currentClass was null.", source, node.offset, node.length), true);
        
    if (_currentConstructorElement != null || _currentFieldDeclaration != null || _currentMethodElement != null)
      engine.errors.addError(new EngineError("Visited constructor declaration, inside another class member.", source, node.offset, node.length), true);
    
    _currentConstructorElement = new ConstructorElement(node, _currentClassElement);
    analysis.addElement(node, _currentConstructorElement);
    _currentClassElement.addConstructor(_currentConstructorElement.name, _currentConstructorElement);

    _currentCallableElement = _currentConstructorElement;
    _enterBlock(_currentConstructorElement);
    
    super.visitConstructorDeclaration(node);
    _leaveBlock();
    _currentConstructorElement = null;
    _currentCallableElement = null;
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
  
  visitVariableDeclarationList(VariableDeclarationList node){
    _currentVariableType = node.type;
    super.visitVariableDeclarationList(node);
    _currentVariableType = null;
  }
  
  visitVariableDeclaration(VariableDeclaration node) {
    if (_currentFieldDeclaration != null && _currentBlock  == _currentClassElement) {
      if (_currentClassElement == null)
         engine.errors.addError(new EngineError("Visited variable decl inside a field declaration, but currentClass was null.", source, node.offset, node.length), true);
      
      FieldElement field = new FieldElement(_currentFieldDeclaration, node, _currentVariableType, _currentClassElement);
      analysis.addElement(node, field);
      _currentClassElement.addField(field.name, field);
      super.visitVariableDeclaration(node);
      return;
    }
    
    if (_currentBlock != null) {
      VariableElement variable = new VariableElement(node, _currentBlock, _currentVariableType, element);
      analysis.addElement(node, variable);
      _currentBlock.addVariable(variable);
      super.visitVariableDeclaration(node);
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
      analysis.addElement(_lastSeenFunctionDeclaration, functionElement);
      _lastSeenFunctionDeclaration = null;
      _currentBlock.addFunction(functionElement);
    } else {
      functionElement = new FunctionElement(node, element);
    }
    analysis.addElement(node, functionElement);
    
    CallableElement enclosingCallableElement = _currentCallableElement;
    _currentCallableElement = functionElement;
    
    _enterBlock(functionElement);
    super.visitFunctionExpression(node);
    _leaveBlock();
    
    _currentCallableElement = enclosingCallableElement;
  }
  
  visitBlock(astElement.Block node){
    BlockElement blockElement = new BlockElement(node, element);
    analysis.addElement(node, blockElement);
    _enterBlock(blockElement);
    super.visitBlock(node);
    _leaveBlock();
  }
  
  visitFunctionTypeAlias(FunctionTypeAlias node){
    //TODO (jln): Do something with the function alias'es.
  }
  
  visitThisExpression(ThisExpression node){
    if (_currentClassElement == null){
      engine.errors.addError(new EngineError("The current class element was not set but this was used.", source, node.offset, node.length), true);
    }
    element.thisReferences[node] = _currentClassElement;
  }
  
  visitConstructorName(ConstructorName node){
    //_currentBlock.addReferenceNode(node);
    super.visitConstructorName(node);
  }
  
  visitReturnStatement(ReturnStatement node){
    ReturnElement returnElement = new ReturnElement(node, _currentCallableElement, element);
    super.visitReturnStatement(node);
    _currentCallableElement.addReturn(returnElement);
    analysis.addElement(node, returnElement);
  }
  
  visitSimpleFormalParameter(SimpleFormalParameter node){
    _currentVariableType = node.type;
    super.visitSimpleFormalParameter(node);
    _currentVariableType = null;
  }
  
  visitFormalParameter(FormalParameter node){
    if (_currentBlock == null) {
      engine.errors.addError(new EngineError("The current block is not set, so the variable cannot be associated with any.", source, node.offset, node.length), true);
    }
    VariableElement variable;
    if (node is FunctionTypedFormalParameter){
      variable = new FunctionParameterElement(node, _currentBlock, _currentVariableType, element);
    } else {
      variable = new ParameterElement(node, _currentBlock, _currentVariableType, element);
    }

    analysis.addElement(node, variable);

    _currentBlock.addVariable(variable);
    super.visitFormalParameter(node);  
  }
}

