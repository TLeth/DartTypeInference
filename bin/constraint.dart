library typeanalysis.constraints;

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'engine.dart';
import 'element.dart';
import 'util.dart';

class ConstraintAnalysis {
  Map<Source, Constraints> constraints = <Source, Constraints>{};
  Map<Source, Substitutions> substitutions = <Source, Substitutions>{};
}

abstract class ConstraintType {
  ConstraintType replace(Expression expression, ConstraintType type);
  ConstraintType addProperty(Name name, ConstraintType type);
  ConstraintType union(ConstraintType type);
}

class ObjectType extends ConstraintType {
  Map<Name, ConstraintType> properties = <Name, ConstraintType>{};
  
  ConstraintType type;
  
  ObjectType(ConstraintType this.type);
  
  ConstraintType replace(Expression exp, ConstraintType type) {
    properties.keys.forEach((Name ident) => properties[ident] = properties[ident].replace(exp, type) );
    this.type = this.type.replace(exp, type);
    return this;
  }
  
  ConstraintType addProperty(Name name, ConstraintType type) {
    if (properties.containsKey(name))
      properties[name] = properties[name].union(type);
    else
      properties[name] = type;
    
    return this;
  }
  
  ConstraintType union(ConstraintType type) {
    if (type == this) 
      return this;
    else if (type is ObjectType){
      type.properties.forEach((Name ident, ConstraintType type) {
        if (properties.containsKey(ident))
          properties[ident] = properties[ident].union(type);
        else
          properties[ident] = type;
      });
      this.type = this.type.union(type.type);
    } else {
      this.type = this.type.union(type);
    }
    return this;
  }
  
  String toString(){
    StringBuffer sb = new StringBuffer();
    sb.writeln("${type}, with properties: {");
    properties.forEach((Name ident, ConstraintType type) => sb.writeln("${ident}: ${type}"));
    sb.write("}");
    return sb.toString();
  }
}

class UnionType extends ConstraintType {
  List<ConstraintType> types;
  
  UnionType(List<ConstraintType> this.types);
  
  ConstraintType replace(Expression exp, ConstraintType type) {
    for (var i = 0; i < types.length; i++)
      types[i] = types[i].replace(exp, type);
    return this;
  }
  
  ConstraintType union(ConstraintType type){
    if (type == this) 
      return this;
    else if (type is UnionType){
      types.addAll(type.types);
      return this;
    } else if (type is ObjectType) {
      return type.union(this);
    } else {
      types.add(type);
      return this;
    }
  }
  
  ConstraintType addProperty(Name name, ConstraintType type) {
     ConstraintType res = new ObjectType(this);
     res.addProperty(name, type);
     return res;
  }
  
  String toString() => types.toString(); 
}

abstract class SimpleType extends ConstraintType { 
  ConstraintType union(ConstraintType type) {
    if (type == this) 
      return this;
    else if (type is ObjectType)
      return type.union(this);
    else if (type is UnionType)
      return type.union(this);
    else
      return new UnionType(<ConstraintType>[this, type]);
  }
    
  ConstraintType addProperty(Name name, ConstraintType type) {
    ConstraintType res = new ObjectType(this);
    res.addProperty(name, type);
    return res;
  }
  
  ConstraintType replace(Expression expression, ConstraintType type) => this;
}

class ConcreteType extends SimpleType {
  String type;
  ConcreteType(String this.type);
  
  String toString() => type; 
}

class AbstractType extends SimpleType {
  Expression expression;
  AbstractType(this.expression);
  
  String toString() => "[${expression} (${expression.hashCode})]";
  
  ConstraintType replace(Expression expression, ConstraintType type) => 
      (this.expression == expression ? type : this);
  
}

class FreeType extends SimpleType {
  static int _counter = 0;
  
  int _typeID;
  
  int get typeID => _typeID;
  
  FreeType() {
    this._typeID = _counter++;
  }
  
  String toString() => "\u{03b1}${_typeID}"; 
}

class FunctionType extends SimpleType {
  List<ConstraintType> normalParameterTypes;
  List<ConstraintType> optionalParameterTypes;
  Map<Name, ConstraintType> namedParameterTypes;
  ConstraintType returnType;
  
  FunctionType(List<ConstraintType> this.normalParameterTypes, ConstraintType this.returnType, 
              [List<ConstraintType> optionalParameterTypes = null, Map<Name, ConstraintType> namedParameterTypes = null ] ) :
                this.optionalParameterTypes = (optionalParameterTypes == null ? <ConstraintType>[] : optionalParameterTypes),
                this.namedParameterTypes = (namedParameterTypes == null ? <Name, ConstraintType>{} : namedParameterTypes);
  

  String toString() {
    String res = "";
    res = normalParameterTypes.fold(res, (String res, ConstraintType type) => res + "${type} -> ");
    if (optionalParameterTypes.length > 0){
      optionalParameterTypes.fold(res + "[", (String res, ConstraintType type) => res + "${type} -> ");
      res = res.substring(0, res.length - 4) + "] -> ";
    }
    if (namedParameterTypes.length > 0){
      MapUtil.fold(namedParameterTypes, res + "{", (String res, Name ident, ConstraintType type) => res + "${ident}: ${type} -> ");
      res = res.substring(0, res.length - 4) + "} -> "; 
    }
    return res + "${returnType}";
  }
  
  ConstraintType replace(Expression exp, ConstraintType type) {
    for (var i = 0; i < normalParameterTypes.length; i++)
      normalParameterTypes[i] = normalParameterTypes[i].replace(exp, type);
    for (var i = 0; i < optionalParameterTypes.length; i++)
      optionalParameterTypes[i] = optionalParameterTypes[i].replace(exp, type);
    namedParameterTypes.keys.forEach((Name ident) => namedParameterTypes[ident] = namedParameterTypes[ident].replace(exp, type));
    returnType = returnType.replace(exp, type);
    return this;
  }
}


abstract class Constraint {
  Expression expression;
  
  Constraint(this.expression);
  dynamic accept(ConstraintVisitor visitor);
  void replace(Expression expression, ConstraintType type);
}

class EqualityConstraint extends Constraint {
  ConstraintType type;
  
  EqualityConstraint(Expression expression,this.type): super(expression);
  
  String toString() => "[${expression}] = ${type}";
  
  dynamic accept(ConstraintVisitor visitor) => visitor.visitEqualityConstraint(this);
  
  void replace(Expression expression, ConstraintType type){ 
    this.type = this.type.replace(expression, type);
  }
}

class MethodConstraint extends Constraint {
  Name method;
  List<ConstraintType> normalParameterTypes;
  List<ConstraintType> optionalParameterTypes;
  Map<Name, ConstraintType> namedParameterTypes;
  ConstraintType returnType;
  
  MethodConstraint(Expression expression, this.method, List<SimpleType> this.normalParameterTypes, this.returnType, [List<SimpleType> optionalParameterTypes = null, Map<Name, SimpleType> namedParameterTypes = null ] ) :
    super(expression),
    this.optionalParameterTypes = (optionalParameterTypes == null ? <ConstraintType>[] : optionalParameterTypes),
    this.namedParameterTypes = (namedParameterTypes == null ? <Name, ConstraintType>{} : namedParameterTypes);
  
  String toString() => "[${expression}] contains method: '${method}', with return '${returnType}', normalParameters: ${normalParameterTypes}, optionalParameters: ${optionalParameterTypes}, namedParameters: ${namedParameterTypes}.";
  
  dynamic accept(ConstraintVisitor visitor) => visitor.visitMethodConstraint(this);
  
  void replace(Expression exp, ConstraintType type) {
    for (var i = 0; i < normalParameterTypes.length; i++)
      normalParameterTypes[i] = normalParameterTypes[i].replace(exp, type);
    for (var i = 0; i < optionalParameterTypes.length; i++)
      optionalParameterTypes[i] = optionalParameterTypes[i].replace(exp, type);
    namedParameterTypes.keys.forEach((Name ident) => namedParameterTypes[ident] = namedParameterTypes[ident].replace(exp, type));
    returnType = returnType.replace(exp, type);
  }
}

class Constraints {
  List<Constraint> _constraints = <Constraint>[];
  
  String toString(){
    StringBuffer sb = new StringBuffer();
    _constraints.forEach(sb.writeln);
    return sb.toString();  
  }
  
  void add(Constraint c) => _constraints.add(c);
  
  
  bool get isEmpty => _constraints.isEmpty;
  
  Constraint pop() {
    Constraint constraint = null;
    if (!isEmpty){
      constraint = _constraints[0];
      _constraints.remove(constraint);
    }
    return constraint;
  }
  
  void replace(Expression expression, ConstraintType type){
    _constraints.forEach((Constraint constraint) => constraint.replace(expression, type));
  }
}

class ConstraintGenerator {
  Engine engine;
  
  ElementAnalysis elementAnalysis;
  ConstraintAnalysis constraintAnalysis;
  
  ConstraintGenerator(Engine this.engine, ElementAnalysis this.elementAnalysis, ConstraintAnalysis this.constraintAnalysis) {
    elementAnalysis.sources.values.forEach((SourceElement source) {
      ConstraintGeneratorVisitor constraintVisitor = new ConstraintGeneratorVisitor(source);
      constraintAnalysis.constraints[ source.source ] = constraintVisitor.constraints;
    });
  }
}

class ConstraintGeneratorVisitor extends GeneralizingAstVisitor {
  
  Constraints constraints = new Constraints();
  
  SourceElement source;
  
  ConstraintGeneratorVisitor(SourceElement this.source) {
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
    constraints.add(new EqualityConstraint(n, new ConcreteType("int")));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    constraints.add(new EqualityConstraint(n, new ConcreteType("double")));
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    ConstraintType return_type = new FreeType();
    Expression leftOperand = _normalizeIdentifiers(be.leftOperand);
    Expression rightOperand = _normalizeIdentifiers(be.rightOperand);
    ConstraintType rightOperandType = new AbstractType(rightOperand);
    constraints.add(new EqualityConstraint(rightOperand, rightOperandType));
    constraints.add(new MethodConstraint(leftOperand, new Name("+"), [rightOperandType], return_type));
    constraints.add(new EqualityConstraint(be, return_type));
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
    super.visitVariableDeclaration(vd);
    Expression name = _normalizeIdentifiers(vd.name);
    constraints.add(new EqualityConstraint(name, new AbstractType(vd.initializer)));
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    Expression leftHandSide = _normalizeIdentifiers(node.leftHandSide);
    constraints.add(new EqualityConstraint(leftHandSide, new AbstractType(node.rightHandSide)));
  }
}

abstract class ConstraintVisitor<R> {
  R visitEqualityConstraint(EqualityConstraint node);
  R visitMethodConstraint(MethodConstraint node);
  R visitConstraint(Constraint node) => node.accept(this);
}

class Substitutions {
  Map<Expression, ConstraintType> substitutions = <Expression, ConstraintType>{};
  
  ConstraintType operator [](Expression e) => substitutions[e];
  void operator []=(Expression e, ConstraintType type) {
    if (substitutions.containsKey(e))
      substitutions[e] = substitutions[e].union(type);
    else
      substitutions[e] = type;
  }
  
  void replace(Expression expression, ConstraintType type) {
    substitutions.keys.forEach((Expression key) {
      substitutions[key] = substitutions[key].replace(expression, type);
    });
  }
  
  void addProperty(Expression e, Name property, ConstraintType type) {
    if (!substitutions.containsKey(e))
      substitutions[e] = new AbstractType(e);
    substitutions[e] = substitutions[e].addProperty(property, type);
  }
  
  String toString(){
    StringBuffer sb = new StringBuffer();
    substitutions.forEach((Expression exp, ConstraintType type) => sb.writeln("[${exp}]: $type"));
    return sb.toString();  
  }
}

class SubstitutionGenerator {
  ConstraintAnalysis constraintAnalysis;
  Engine engine;
  
  SubstitutionGenerator(Engine this.engine, ConstraintAnalysis this.constraintAnalysis) {
    constraintAnalysis.constraints.keys.forEach((Source source) {
      ConstraintSolver constraintSolver = new ConstraintSolver(constraintAnalysis.constraints[source]);
      constraintAnalysis.substitutions[source] = constraintSolver.substitutions;
    });
  }
}

class ConstraintSolver extends ConstraintVisitor {
  Constraints queue;
  Substitutions substitutions = new Substitutions();
  
  
  ConstraintSolver(Constraints this.queue) {
    substitutions = new Substitutions();
    _solve();
  }
  
  void _solve() {
    while(!queue.isEmpty) 
      queue.pop().accept(this);
  }
  
  void visitEqualityConstraint(EqualityConstraint node){
    substitutions[node.expression] = node.type;
    queue.replace(node.expression, substitutions[node.expression]); 
    substitutions.replace(node.expression, substitutions[node.expression]);
  }
  
  void visitMethodConstraint(MethodConstraint node){
    var method = new FunctionType(node.normalParameterTypes, node.returnType, node.optionalParameterTypes, node.namedParameterTypes);
    substitutions.addProperty(node.expression, node.method, method);
  }
}