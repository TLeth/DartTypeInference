library typeanalysis.constraints;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'engine.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'element.dart';
import 'util.dart';


/************** ElementTyper *****/
class ParameterTypes { 
  List<AbstractType> normalParameterTypes = <AbstractType>[];
  List<AbstractType> optionalParameterTypes = <AbstractType>[];
  Map<Name, AbstractType> namedParameterTypes = <Name, AbstractType>{};
}

class ElementTyper {
  Map<AstNode, AbstractType> types = <AstNode, AbstractType>{};
  
  
  ConstraintAnalysis constraintAnalysis;
  Engine get engine => constraintAnalysis.engine;
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  
  ElementTyper(ConstraintAnalysis this.constraintAnalysis);
  
  AbstractType typeClassMember(ClassMember element, LibraryElement library){
    if (element is MethodElement)
      return typeMethodElement(element, library);
    if (element is FieldElement)
      return typeFieldElement(element, library);
    if (element is ConstructorElement)
      return typeConstructorElement(element, library);
    
    return null;
  }
  
  AbstractType typeMethodElement(MethodElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    
    return types[element.ast] = new FunctionType.FromMethodElement(element, library, this);
  }
  
  AbstractType typeFieldElement(FieldElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    return types[element.ast] = resolveType(element.annotatedType, library, element.sourceElement);
  }
  
  AbstractType typeConstructorElement(ConstructorElement element,LibraryElement library){
    if (types.containsKey(element.ast))
      return types[element.ast];
    return types[element.ast] = new FunctionType.FromConstructorElement(element, library, this);
  }
  
  AbstractType typeClassElement(ClassElement element){
    if (types.containsKey(element.ast))
      return types[element.ast];
    return types[element.ast] = new NominalType(element);
  }
  
  AbstractType resolveType(TypeName type, LibraryElement library, SourceElement source){
    return new NominalType(elementAnalysis.resolveClassElement(type.name.toString(), library, source));
  }
  
  ParameterTypes resolveParameters(FormalParameterList paramList, LibraryElement library, SourceElement source){
    ParameterTypes types = new ParameterTypes();
    
    if (paramList.parameters == null || paramList.length == 0) 
      return types;
    
    NodeList<FormalParameter> params = paramList.parameters;
    
    for(FormalParameter param in params){
      NormalFormalParameter normalParam; 
      if (param is NormalFormalParameter) normalParam = param;
      else if (param is DefaultFormalParameter) normalParam = param.parameter;
      
      AbstractType type; 
      if (normalParam is SimpleFormalParameter || normalParam is FieldFormalParameter) {
        if (normalParam.type == null)
          type = new FreeType();
        else
          type = this.resolveType(normalParam.type, library, source);
      } else if (normalParam is FunctionTypedFormalParameter){
        type = new FunctionType.FromFunctionTypedFormalParameter(normalParam, library, this, source);
      }
      
      if (normalParam.kind == ParameterKind.REQUIRED)
        types.normalParameterTypes.add(type);
      else if (normalParam.kind == ParameterKind.POSITIONAL)
        types.optionalParameterTypes.add(type);
      else if (normalParam.kind == ParameterKind.REQUIRED)
        types.namedParameterTypes[new Name.FromIdentifier(normalParam.identifier)] = type;
    }
    
    return types;
  }
}


/***************** TYPES **************/
abstract class AbstractType {}

class FreeType extends AbstractType {
  static int _countID = 0;
  
  int _typeID;
  
  FreeType(): _typeID = _countID++;
  
  String toString() => "\u{03b1}${_typeID}";
  
  //TODO (jln): a free type is equal to any free type right?
  //bool operator ==(Object other) => other is FreeType;
}

class FunctionType extends AbstractType {
  List<AbstractType> normalParameterTypes;
  List<AbstractType> optionalParameterTypes;
  Map<Name, AbstractType> namedParameterTypes;
  AbstractType returnType;
  
  FunctionType(List<AbstractType> this.normalParameterTypes, AbstractType this.returnType, 
              [List<AbstractType> optionalParameterTypes = null, Map<Name, AbstractType> namedParameterTypes = null ] ) :
                this.optionalParameterTypes = (optionalParameterTypes == null ? <AbstractType>[] : optionalParameterTypes),
                this.namedParameterTypes = (namedParameterTypes == null ? <Name, AbstractType>{} : namedParameterTypes);
  
  
  factory FunctionType.FromElements(TypeName returnType, FormalParameterList paramList, LibraryElement library, SourceElement sourceElement, ElementTyper typer){
    AbstractType abstractReturnType = null;
    if (returnType == null)
      abstractReturnType = new FreeType();
    else
      abstractReturnType = typer.resolveType(returnType, library, sourceElement);
    
    if (paramList == null)
      return new FunctionType(<AbstractType>[], abstractReturnType);
    
    
    ParameterTypes params = typer.resolveParameters(paramList, library, sourceElement);
    return new FunctionType(params.normalParameterTypes, abstractReturnType, params.optionalParameterTypes, params.namedParameterTypes); 
  }

  factory FunctionType.FromFunctionTypedFormalParameter(FunctionTypedFormalParameter element, LibraryElement library, ElementTyper typer, SourceElement sourceElement){
    return new FunctionType.FromElements(element.returnType, element.parameters, library, sourceElement, typer);
  }
  
  factory FunctionType.FromMethodElement(MethodElement element, LibraryElement library, ElementTyper typer){
    return new FunctionType.FromElements(element.returnType, element.ast.parameters, library, element.sourceElement, typer);
  }
  
  factory FunctionType.FromConstructorElement(ConstructorElement element, LibraryElement library, ElementTyper typer){
    FunctionType functionType = new FunctionType.FromElements(null, element.ast.parameters, library, element.sourceElement, typer);
    functionType.returnType = typer.typeClassElement(element.classDecl);
    return functionType;
  }

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write("(");
    sb.write(ListUtil.join(normalParameterTypes, " -> "));

    if (optionalParameterTypes.length > 0){
      sb.write("[");
      sb.write(ListUtil.join(optionalParameterTypes, " -> "));
      sb.write("]");
    }

    if (namedParameterTypes.length > 0){
      sb.write("{");
      MapUtil.join(namedParameterTypes, " -> ");
      sb.write("}");
    }
    sb.write(" -> ${returnType})");
    return sb.toString();
  }
  
  int get hashCode {
    int h = returnType.hashCode;
    for(Name name in namedParameterTypes.keys)
      h = h + name.hashCode + namedParameterTypes[name].hashCode;
    for(AbstractType t in normalParameterTypes)
      h = 31*h + t.hashCode;
    for(AbstractType t in optionalParameterTypes)
      h = 31*h + t.hashCode;
    return h;
  }
  
  bool operator ==(Object other) => 
      other is FunctionType &&
      ListUtil.equal(other.normalParameterTypes, this.normalParameterTypes) &&
      ListUtil.equal(other.optionalParameterTypes, this.optionalParameterTypes) &&
      this.returnType == other.returnType &&
      MapUtil.equal(other.namedParameterTypes, this.namedParameterTypes);
  
  static bool FunctionMatch(AbstractType type, int normalParameters, [AbstractType returnType = null, int optionalParameters = 0, List<Name> namedParameters = null]) => 
      type is FunctionType &&
      (returnType == null || returnType == type.returnType) &&
      type.normalParameterTypes.length == normalParameters &&
      type.optionalParameterTypes.length == optionalParameters &&
      ( (namedParameters == null && type.namedParameterTypes.isEmpty) ||
        (namedParameters != null && ListUtil.complement(namedParameters, type.namedParameterTypes.keys).length == 0));  
}

class NominalType extends AbstractType {
  
  ClassElement element;
    
  
  NominalType(ClassElement this.element);
 
  
  String toString() => element.name.toString();
  
  bool operator ==(Object other) => other is NominalType && other.element == this.element;
  
  int get hashCode => element.hashCode;
}

class UnionType extends AbstractType {
  Set<AbstractType> types = new Set<AbstractType>();
  
  UnionType(Iterable<AbstractType> types) {
    for(AbstractType type in types){
      if (type is UnionType)
        this.types.addAll(type.types);
    }
    this.types.addAll(types);
  }
  
  String toString() => "{${ListUtil.join(types, " + ")}}";
  
  bool operator ==(Object other) => other is UnionType && other.types == this.types;
}

class VoidType extends AbstractType {

  static VoidType _instance = null;
  factory VoidType() => (_instance == null ? _instance = new VoidType._internal() : _instance);
  
  VoidType._internal();
  
  String toString() => "void";
  bool operator ==(Object other) => other is VoidType;
}

class ConstraintAnalysis {
  TypeMap typeMap;
  

  LibraryElement get dartCore => elementAnalysis.dartCore;
  Engine engine;
  ElementAnalysis elementAnalysis;
  ElementTyper elementTyper;
  
  ConstraintAnalysis(Engine this.engine, ElementAnalysis this.elementAnalysis) {
    elementTyper = new ElementTyper(this); 
    typeMap = new TypeMap();
  }
}

/************ TypeIdentifiers *********************/
abstract class TypeIdentifier {  
  static TypeIdentifier ConvertToTypeIdentifier(dynamic ident) {
    if (ident is TypeIdentifier)
      return ident;
    else if (ident is Expression)
      return new ExpressionTypeIdentifier(ident);
    return null;
  }
}


class ExpressionTypeIdentifier extends TypeIdentifier {
  Expression exp;
  
  ExpressionTypeIdentifier(Expression this.exp);
  
  int get hashCode => exp.hashCode;
}


class AbstractTypeIdentifier extends TypeIdentifier {
  AbstractType type;
  Name name;
  
  AbstractTypeIdentifier(AbstractType this.type, Name this.name);
  
  int get hashCode => type.hashCode + 31 * name.hashCode;
}

class SetTypeIdentifier extends TypeIdentifier {
  TypeIdentifier ident;
  
  SetTypeIdentifier(TypeIdentifier this.ident);
  
  int get hashCode => ident.hashCode * 37;
}


/************* Type maps ********************/
class TypeMap {
  Map<TypeIdentifier, TypeVariable> _typeMap = <TypeIdentifier, TypeVariable>{};
  
  TypeVariable getter(dynamic i) {
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    return (containsKey(ident) ? _typeMap[ident] : addEmpty(ident));
  }
  
  TypeVariable setter(dynamic i) {
    TypeIdentifier ident = new SetTypeIdentifier(TypeIdentifier.ConvertToTypeIdentifier(i));
    return (containsKey(ident) ? _typeMap[ident] : addEmpty(ident));
  }
  
  TypeVariable operator [](TypeIdentifier ident) => _typeMap[ident];
  
  Iterable<TypeIdentifier> get keys => _typeMap.keys;
  
  bool containsKey(TypeIdentifier ident) => _typeMap.containsKey(ident);
  TypeVariable addEmpty(TypeIdentifier ident) => _typeMap[ident] = new TypeVariable();  
  
  void put(dynamic i, AbstractType t){
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    if (!_typeMap.containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    _typeMap[ident].add(t);
  }
  
  String toString() {
    [new ExpressionTypeIdentifier(null)];
    StringBuffer sb = new StringBuffer();
    
    for(Expression exp in _typeMap.keys){
      sb.writeln("${exp}: ${_typeMap[exp]}");
    }
    
    return sb.toString();
  }
}

typedef bool FilterFunc(AbstractType);
typedef dynamic NotifyFunc(AbstractType);

class TypeVariable {
  Set<AbstractType> _types = new Set<AbstractType>();
  
  List<Function> _event_listeners = <Function>[];
  Map<Function,Function> _filters = <Function, Function>{};
  
  bool _changed = false;
  
  void add(AbstractType t) {
    //TODO (jln) If the type added is a free-type check if there already exists a free type and merge them. 
    if (!_types.add(t)) {
      _changed = true;
      trigger(t);
      _changed = false;
    }
  }
  
  Function notify(NotifyFunc func, [FilterFunc filter = null]) {
    if (_event_listeners.contains(func))
      return (() => this.remove(func));
    
    _event_listeners.add(func);
    _filters[func] = filter;
    
    bool reset;
    do {
      reset = false;
      for(AbstractType type in _types){
        if (_changed){
          reset = true;
          break;
        }
        
        if (filter == null || filter(type))
          func(type);
      }       
    } while(reset);
    return (() => this.remove(func));
  }
  
  bool remove(void func(AbstractType)){
    _filters.remove(func);
    return _event_listeners.remove(func);
  }
  
  void trigger(AbstractType type){
    for(Function func in _event_listeners)
      if (_filters[func] == null || _filters[func](type))
        func(type);
  }
  
  bool has_listener(void f(TypeVariable, AbstractType)) => _event_listeners.contains(f);
      
  factory TypeVariable.With(AbstractType type) {
    TypeVariable t = new TypeVariable();
    t.add(type);
    return t;
  }
  
  TypeVariable();
  
  String toString() => "{${ListUtil.join(_types, ", ")}}";
}



abstract class ConstraintHelper {
  TypeIdentifier _lastTypeIdentifier = null;
  FilterFunc _lastWhere = null;
  
  TypeMap get types;
  
  ConstraintHelper foreach(dynamic ident) {
    _lastTypeIdentifier = TypeIdentifier.ConvertToTypeIdentifier(ident);
    return this;
  }
  
  ConstraintHelper where(FilterFunc func){
    _lastWhere = func;
    return this;
  }
  
  void update(NotifyFunc func){
    if (_lastTypeIdentifier != null){
      TypeIdentifier identifier = _lastTypeIdentifier;
      FilterFunc filter = _lastWhere;
      
      _lastTypeIdentifier = null;
      _lastWhere = null;
      types.getter(identifier).notify(func, filter);
    }
  }
}


class ConstraintGenerator {
  
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  ConstraintAnalysis constraintAnalysis;
  
  ConstraintGenerator(ConstraintAnalysis this.constraintAnalysis) {
    elementAnalysis.sources.values.forEach((SourceElement source) {
      ConstraintGeneratorVisitor constraintVisitor = new ConstraintGeneratorVisitor(source, this.constraintAnalysis);
    });
  }
}

class ConstraintGeneratorVisitor extends GeneralizingAstVisitor with ConstraintHelper {
  
  TypeMap get types => constraintAnalysis.typeMap;
  
  bool operator [](TypeIdentifier e) => true; 
  
  SourceElement source;
  ConstraintAnalysis constraintAnalysis;
  ElementTyper get elementTyper => constraintAnalysis.elementTyper;
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  
  ConstraintGeneratorVisitor(SourceElement this.source, ConstraintAnalysis this.constraintAnalysis) {
    source.ast.accept(this);
  }
  
  Expression _normalizeIdentifiers(Expression exp){
    if (exp is Identifier && source.resolvedIdentifiers.containsKey(exp))
      return source.resolvedIdentifiers[exp].identifier;
    else
      return exp;
  }
  
  visitIntegerLiteral(IntegerLiteral n) {
    super.visitIntegerLiteral(n);
    // {double} \subseteq [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement("int", constraintAnalysis.dartCore, source)));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    // {double} \subseteq [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement("double", constraintAnalysis.dartCore, source)));
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
    // var v;
    super.visitVariableDeclaration(vd);
    Expression name = _normalizeIdentifiers(vd.name);
    
    if ((name is Identifier)){
      TypeIdentifier vGet = new ExpressionTypeIdentifier(name);
      TypeIdentifier vSet = new SetTypeIdentifier(vGet);
      
      // \forall \alpha \in [v] => (\alpha -> void) \in [v]=
      foreach(vGet).update((AbstractType alpha) => 
          types.put(vSet, new FunctionType(<AbstractType>[alpha], new VoidType())));

      // \forall (\alpha -> void) \in [v]= => \alpha \in [v]
      foreach(vSet)
        .where((AbstractType func) => FunctionType.FunctionMatch(func, 1, new VoidType()))
        .update((AbstractType func){
          if (func is FunctionType)
            types.put(vGet, func.normalParameterTypes[0]);
      });
    } else {
      //TODO (jln): assigment to a non identifier on left hand side.
    }

    // v = exp;
    _assignmentExpression(vd.name, vd.initializer);
  }
  
  _assignmentExpression(Expression leftHandSide, Expression rightHandSide){
    // v = exp;
    leftHandSide = _normalizeIdentifiers(leftHandSide);
    rightHandSide = _normalizeIdentifiers(rightHandSide);
    
    TypeIdentifier vGet = new ExpressionTypeIdentifier(leftHandSide);
    TypeIdentifier vSet = new SetTypeIdentifier(vGet);
    TypeIdentifier expGet = new ExpressionTypeIdentifier(rightHandSide);
    
    if (leftHandSide is Identifier){
      // \forall \alpha \in [exp] => (\alpha -> void) \in [v]=
      foreach(expGet)
        .update((AbstractType alpha) =>
            types.put(vSet, new FunctionType(<AbstractType>[alpha], new VoidType())));
    } else {
      //TODO (jln): assigment to a non identifier on left hand side.
    }
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    
    // v = exp;
    _assignmentExpression(node.leftHandSide, node.rightHandSide);
    
    
    Expression rightHandSide = _normalizeIdentifiers(node.rightHandSide);
    
    TypeIdentifier expGet = new ExpressionTypeIdentifier(rightHandSide);
    TypeIdentifier nodeGet = new ExpressionTypeIdentifier(node);
    
    // [exp] \subseteq [v = exp]
    foreach(expGet).update((AbstractType alpha) =>
        types.put(nodeGet, alpha));
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    
    // exp1 op exp2
    Expression leftOperand = _normalizeIdentifiers(be.leftOperand);
    Expression rightOperand = _normalizeIdentifiers(be.rightOperand);
    

    TypeIdentifier leftGet = new ExpressionTypeIdentifier(leftOperand);
    TypeIdentifier rightGet = new ExpressionTypeIdentifier(rightOperand);
    TypeIdentifier nodeGet = new ExpressionTypeIdentifier(be);
    

    //  \forall \gamma \in [exp1], 
    //  \forall (\alpha -> \beta) \in [ \gamma .op ] => 
    //      \alpha \in [exp2] && \beta \in [exp1 op exp2].
    foreach(leftGet).update((AbstractType gamma) {
      TypeIdentifier gammaOpGet = new AbstractTypeIdentifier(gamma, new Name.FromToken(be.operator));
      foreach(gammaOpGet)
      .where((AbstractType func) => FunctionType.FunctionMatch(func, 1))
      .update((AbstractType func){
        if (func is FunctionType){
          types.put(rightGet, func.normalParameterTypes[0]);
          types.put(nodeGet, func.returnType);
        }            
      });
    });
  }
}

