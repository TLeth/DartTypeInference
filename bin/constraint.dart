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
    return types[element.ast] = new NominalType(element, constraintAnalysis);
  }
  
  AbstractType resolveType(TypeName type, LibraryElement library, SourceElement source){
    return new NominalType(elementAnalysis.resolveClassElement(type.name.toString(), library, source), constraintAnalysis);
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
    String res = "(";
    res = normalParameterTypes.fold(res, (String res, AbstractType type) => res + "${type} -> ");

    if (optionalParameterTypes.length > 0){
      optionalParameterTypes.fold(res + "[", (String res, AbstractType type) => res + "${type} -> ");
      res = res.substring(0, res.length - 4) + "] -> ";
    }

    if (namedParameterTypes.length > 0){
      MapUtil.fold(namedParameterTypes, res + "{", (String res, Name ident, AbstractType type) => res + "${ident}: ${type} -> ");
      res = res.substring(0, res.length - 4) + "} -> "; 
    }

    return res + "${returnType})";
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
  ConstraintAnalysis constraintAnalysis;
    
  
  NominalType(ClassElement this.element, ConstraintAnalysis this.constraintAnalysis);
 
  
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
  
  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write("{");
    var i = 0;
    types.forEach((AbstractType t) {
      sb.write("${i > 0 ? " + " : ""}${t}");
      i++;
    });
    sb.write("}");    
    return sb.toString();
  }
  
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
  Map<Source, TypeMap> typeMap = <Source, TypeMap>{};
  

  LibraryElement get dartCore => elementAnalysis.dartCore;
  Engine engine;
  ElementAnalysis elementAnalysis;
  ElementTyper elementTyper;
  
  ConstraintAnalysis(Engine this.engine, ElementAnalysis this.elementAnalysis) {
    elementTyper = new ElementTyper(this); 
  }
}

/************ TypeIdentifiers *********************/
abstract class TypeIdentifier {}


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


/************* Type maps ********************/
class TypeMap {
  Map<TypeIdentifier, TypeVariable> _typeMap = <TypeIdentifier, TypeVariable>{};
  
  TypeVariable operator [](TypeIdentifier ident) => (containsKey(ident) ? _typeMap[ident] : addEmpty(ident));
  
  bool containsKey(TypeIdentifier ident) => _typeMap.containsKey(ident);
  TypeVariable addEmpty(TypeIdentifier ident) => _typeMap[ident] = new TypeVariable();
  
  void operator []=(TypeIdentifier ident, AbstractType t) {
    if (!_typeMap.containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    _typeMap[ident].add(t);
  }
  
  String toString() {
    StringBuffer sb = new StringBuffer();
    
    for(Expression exp in _typeMap.keys){
      sb.writeln("${exp}: ${_typeMap[exp]}");
    }
    
    return sb.toString();
  }
}


class TypeVariable {
  List<AbstractType> types = <AbstractType>[];
  
  List<Function> event_listeners = <Function>[];
  bool _changed = false;
  
  void add(AbstractType t) {
    //TODO (jln) If the type added is a free-type check if there already exists a free type and merge them. 
    if (!types.contains(t)) {
      _changed = true;
      types.add(t);
      trigger(t);
      _changed = false;
    }
  }
  
  Function notify(void f(TypeVariable, AbstractType)) {
    event_listeners.add(f);
    
    bool reset;
    do {
      reset = false;
      for(var i= 0; i < types.length; i++){
          if (_changed) {
            reset = true;
            break;
          } else 
            f(this, types[i]);
      }
    } while(reset);
    return (() => event_listeners.remove(f));
  }
  
  void trigger(AbstractType t){
    for(Function f in event_listeners)
      f(this, t);
  }
  
  bool has_listener(void f(TypeVariable, AbstractType)) => event_listeners.contains(f);
      
  factory TypeVariable.With(AbstractType type) {
    TypeVariable t = new TypeVariable();
    t.add(type);
    return t;
  }
  
  TypeVariable();
  
  String toString() => types.toString();
}


class ConstraintGenerator {
  
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  ConstraintAnalysis constraintAnalysis;
  
  ConstraintGenerator(ConstraintAnalysis this.constraintAnalysis) {
    elementAnalysis.sources.values.forEach((SourceElement source) {
      ConstraintGeneratorVisitor constraintVisitor = new ConstraintGeneratorVisitor(source, this.constraintAnalysis);
      constraintAnalysis.typeMap[ source.source ] = constraintVisitor.types;
    });
  }
}

class ConstraintGeneratorVisitor extends GeneralizingAstVisitor {
  
  TypeMap types = new TypeMap();
  
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
    types[n] = new NominalType(elementAnalysis.resolveClassElement("int", constraintAnalysis.dartCore, source), this.constraintAnalysis);
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    // {double} \subseteq [n]
    types[n] = new NominalType(elementAnalysis.resolveClassElement("double", constraintAnalysis.dartCore, source), this.constraintAnalysis);
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
    // var v;
    super.visitVariableDeclaration(vd);
    Expression name = _normalizeIdentifiers(vd.name);
    
    if ((name is Identifier)){
      TypeVariable nodeType = types[name];
      TypeVariable setNameType = types.setter(name);
      TypeVariable getNameType = types.getter(name);
      
      // [v] \subseteq [get:v]
      getNameType.notify((TypeVariable getNameType, AbstractType alpha) => nodeType.add(alpha));
      nodeType.notify((TypeVariable nodeType, AbstractType alpha) => getNameType.add(alpha));
      
      // \forall \alpha \in [get:v] => (\alpha -> void) \in [set:v]
      getNameType.notify((TypeVariable getNameType, AbstractType alpha) => setNameType.add(new FunctionType(<AbstractType>[alpha], new VoidType())));
      
      // \forall (\alpha -> void) \in [set:v] => \alpha \in [get:v] 
      setNameType.notify((TypeVariable setNameType, AbstractType func) => 
          (FunctionType.FunctionMatch(func, 1, new VoidType()) && func is FunctionType ? getNameType.add(func.normalParameterTypes[0]) : null));
      
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
     
    TypeVariable rightType = types[rightHandSide];
    
    if (leftHandSide is Identifier){
      // \forall \alpha \in {exp} => (\alpha -> void) \in {set:v}
      TypeVariable setLeftType = types.setter(leftHandSide);
      rightType.notify((TypeVariable rightType, AbstractType alpha) => setLeftType.add(new FunctionType(<AbstractType>[alpha], new VoidType())));
    } else {
      //TODO (jln): assigment to a non identifier on left hand side.
    }
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    
    // v = exp;
    _assignmentExpression(node.leftHandSide, node.rightHandSide);
    
    // {exp} \subseteq {v = exp}
    Expression rightHandSide = _normalizeIdentifiers(node.rightHandSide);
    TypeVariable rightType = types[rightHandSide];
    
    TypeVariable nodeType = types[node];
    rightType.notify((TypeVariable rightType, AbstractType alpha) => nodeType.add(alpha));
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    
    
    Expression leftOperand = _normalizeIdentifiers(be.leftOperand);
    Expression rightOperand = _normalizeIdentifiers(be.rightOperand);
    
    // exp1 op exp2
    TypeVariable leftType = types[leftOperand];
    TypeVariable rightType = types[rightOperand];
    TypeVariable nodeType = types[be];
    

    // \forall \gamma \in [exp1], \forall \alpha, \beta \in [ \gamma .op ] => \alpha \in [exp2] && \beta \in [exp1 op exp2].
    var onUpdate;
    onUpdate = (TypeVariable propType, AbstractType func) {
      if (func is FunctionType && FunctionType.FunctionMatch(func, 1)) {
        rightType.add(func.normalParameterTypes[0]);
        nodeType.add(func.returnType);
      }
    };
    
    leftType.notify((TypeVariable leftType, AbstractType type) {
      TypeVariable propType = type.property(be.operator.toString());
      if (!propType.has_listener(onUpdate)) propType.notify(onUpdate);
    });
  }
}

