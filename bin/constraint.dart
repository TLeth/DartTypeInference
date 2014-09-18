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

abstract class AbstractType {
  AbstractType replace(AbstractType from, AbstractType to);
  AbstractType addProperty(Name name, AbstractType type);
  AbstractType union(AbstractType type);
}

class ObjectType extends AbstractType {
  Map<Name, AbstractType> properties = <Name, AbstractType>{};
  
  AbstractType type;
  
  ObjectType(AbstractType this.type);
  
  AbstractType replace(AbstractType from, AbstractType to) {
    if (from == this) return to;
    properties.keys.forEach((Name ident) => properties[ident] = properties[ident].replace(from, to) );
    this.type = this.type.replace(from, to);
    return this;
  }
  
  AbstractType addProperty(Name name, AbstractType type) {
    if (properties.containsKey(name))
      properties[name] = properties[name].union(type);
    else
      properties[name] = type;
    
    return this;
  }
  
  AbstractType union(AbstractType type) {
    if (type == this) 
      return this;
    else if (type is ObjectType){
      type.properties.forEach((Name ident, AbstractType type) {
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
    if (properties.length > 0){
      StringBuffer sb = new StringBuffer();
      sb.writeln("${type}, with properties: {");
      properties.forEach((Name ident, AbstractType type) => sb.writeln("${ident}: ${type}"));
      sb.write("}");
      return sb.toString();
    } else {
      return type.toString();
    }
  }
}

class UnionType extends AbstractType {
  List<AbstractType> types;
  
  UnionType(List<AbstractType> this.types);
  
  AbstractType replace(AbstractType from, AbstractType to) {
    for (var i = 0; i < types.length; i++)
      types[i] = types[i].replace(from, to);
    return this;
  }
  
  AbstractType union(AbstractType type){
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
  
  AbstractType addProperty(Name name, AbstractType type) {
     AbstractType res = new ObjectType(this);
     res.addProperty(name, type);
     return res;
  }
  
  String toString() => types.toString(); 
}

abstract class SimpleType extends AbstractType {
 
  AbstractType union(AbstractType type) {
    if (type == this) 
      return this;
    else if (type is ObjectType)
      return type.union(this);
    else if (type is UnionType)
      return type.union(this);
    else
      return new UnionType(<AbstractType>[this, type]);
  }
    
  AbstractType addProperty(Name name, AbstractType type) {
    AbstractType res = new ObjectType(this);
    res.addProperty(name, type);
    return res;
  }
  
  AbstractType replace(AbstractType from, AbstractType to) => (from == this ? to : this);
}

class ConcreteType extends SimpleType {
  String type;
  ConcreteType(String this.type);
  
  String toString() => type; 
  bool operator ==(Object other) => other is ConcreteType && type == other.type;
}

class TypeVariable extends SimpleType {
  Expression expression;
  TypeVariable(this.expression);
  
  String toString() => "[${expression}]";
  
  bool operator ==(Object other) => other is TypeVariable && expression == other.expression;
}

class FreeType extends SimpleType {
  static int _counter = 0;
  
  int _typeID;
  
  int get typeID => _typeID;
  
  FreeType() {
    this._typeID = _counter++;
  }
  
  String toString() => "\u{03b1}${_typeID}"; 
  bool operator ==(Object other) => other is FreeType && _typeID == other._typeID;
}

class FunctionType extends SimpleType {
  List<AbstractType> normalParameterTypes;
  List<AbstractType> optionalParameterTypes;
  Map<Name, AbstractType> namedParameterTypes;
  AbstractType returnType;
  
  FunctionType(List<AbstractType> this.normalParameterTypes, AbstractType this.returnType, 
              [List<AbstractType> optionalParameterTypes = null, Map<Name, AbstractType> namedParameterTypes = null ] ) :
                this.optionalParameterTypes = (optionalParameterTypes == null ? <AbstractType>[] : optionalParameterTypes),
                this.namedParameterTypes = (namedParameterTypes == null ? <Name, AbstractType>{} : namedParameterTypes);
  

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
  
  AbstractType replace(AbstractType from, AbstractType to) {
    for (var i = 0; i < normalParameterTypes.length; i++)
      normalParameterTypes[i] = normalParameterTypes[i].replace(from, to);
    for (var i = 0; i < optionalParameterTypes.length; i++)
      optionalParameterTypes[i] = optionalParameterTypes[i].replace(from, to);
    namedParameterTypes.keys.forEach((Name ident) => namedParameterTypes[ident] = namedParameterTypes[ident].replace(from, to));
    returnType = returnType.replace(from, to);
    return this;
  }
}


abstract class Constraint {
  dynamic accept(ConstraintVisitor visitor);
  void replace(AbstractType from, AbstractType to);
}

class EqualityConstraint extends Constraint {
  AbstractType leftHandSide;
  AbstractType rightHandSide;
  
  
  EqualityConstraint(AbstractType this.leftHandSide,AbstractType this.rightHandSide);
  
  String toString() => "${this.leftHandSide} = ${this.rightHandSide}";
  
  dynamic accept(ConstraintVisitor visitor) => visitor.visitEqualityConstraint(this);
  
  void replace(AbstractType from, AbstractType to){
    leftHandSide = leftHandSide.replace(from, to);
    rightHandSide = rightHandSide.replace(from, to);
  }
}

class MethodConstraint extends Constraint {
  Name method;
  AbstractType object;
  List<AbstractType> normalParameterTypes;
  List<AbstractType> optionalParameterTypes;
  Map<Name, AbstractType> namedParameterTypes;
  AbstractType returnType;
  
  MethodConstraint(AbstractType this.object, this.method, List<SimpleType> this.normalParameterTypes, this.returnType, [List<SimpleType> optionalParameterTypes = null, Map<Name, SimpleType> namedParameterTypes = null ] ) :
    this.optionalParameterTypes = (optionalParameterTypes == null ? <AbstractType>[] : optionalParameterTypes),
    this.namedParameterTypes = (namedParameterTypes == null ? <Name, AbstractType>{} : namedParameterTypes);
  
  String toString() => "${object} contains method: '${method}', with return '${returnType}', normalParameters: ${normalParameterTypes}, optionalParameters: ${optionalParameterTypes}, namedParameters: ${namedParameterTypes}.";
  
  dynamic accept(ConstraintVisitor visitor) => visitor.visitMethodConstraint(this);
  
  void replace(AbstractType from, AbstractType to) {
    object = object.replace(from, to);
    for (var i = 0; i < normalParameterTypes.length; i++)
      normalParameterTypes[i] = normalParameterTypes[i].replace(from, to);
    for (var i = 0; i < optionalParameterTypes.length; i++)
      optionalParameterTypes[i] = optionalParameterTypes[i].replace(from, to);
    namedParameterTypes.keys.forEach((Name ident) => namedParameterTypes[ident] = namedParameterTypes[ident].replace(from, to));
    returnType = returnType.replace(from, to);
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
  
  void replace(AbstractType from, AbstractType to){
    _constraints.forEach((Constraint constraint) => constraint.replace(from, to));
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
    constraints.add(new EqualityConstraint(new TypeVariable(n), new ConcreteType("int")));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    constraints.add(new EqualityConstraint(new TypeVariable(n), new ConcreteType("double")));
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    Expression leftOperand = _normalizeIdentifiers(be.leftOperand);
    Expression rightOperand = _normalizeIdentifiers(be.rightOperand);
    AbstractType return_type = new FreeType();

    constraints.add(new MethodConstraint(new TypeVariable(leftOperand), new Name("+"), [new TypeVariable(rightOperand)], return_type));
    constraints.add(new EqualityConstraint(new TypeVariable(be), return_type));
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
    super.visitVariableDeclaration(vd);
    Expression name = _normalizeIdentifiers(vd.name);
    Expression initializer = _normalizeIdentifiers(vd.initializer);
    constraints.add(new EqualityConstraint(new TypeVariable(name), new TypeVariable(initializer)));
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    Expression leftHandSide = _normalizeIdentifiers(node.leftHandSide);
    Expression rightHandSide = _normalizeIdentifiers(node.rightHandSide);
    constraints.add(new EqualityConstraint(new TypeVariable(leftHandSide), new TypeVariable(rightHandSide)));
  }
}

abstract class ConstraintVisitor<R> {
  R visitEqualityConstraint(EqualityConstraint node);
  R visitMethodConstraint(MethodConstraint node);
  R visitConstraint(Constraint node) => node.accept(this);
}

class Substitutions {
  Map<TypeVariable, AbstractType> substitutions = <TypeVariable, AbstractType>{};
  
  AbstractType operator [](TypeVariable key) => substitutions[key];
  void operator []=(TypeVariable key, AbstractType type) {
    if (substitutions.containsKey(key))
      substitutions[key] = substitutions[key].union(type);
    else if (type is ObjectType)
      substitutions[key] = type;
    else 
      substitutions[key] = new ObjectType(type);
  }
  
  void replace(AbstractType from, AbstractType to) {
    substitutions.keys.forEach((TypeVariable key) {
      substitutions[key] = substitutions[key].replace(from, to);
    });
  }
  
  void addProperty(TypeVariable key, Name property, AbstractType type) {
    if (!substitutions.containsKey(key))
      substitutions[key] = key;
    substitutions[key] = substitutions[key].addProperty(property, type);
  }
  
  String toString(){
    StringBuffer sb = new StringBuffer();
    substitutions.forEach((TypeVariable key, AbstractType type) => sb.writeln("${key}: $type"));
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
    if (node.leftHandSide == node.rightHandSide) return;
    else if (node.leftHandSide is TypeVariable){
      substitutions[node.leftHandSide] = node.rightHandSide;
      queue.replace(node.leftHandSide, substitutions[node.leftHandSide]); 
      substitutions.replace(node.leftHandSide, substitutions[node.leftHandSide]);
    } else if (node.rightHandSide is TypeVariable){
      substitutions[node.rightHandSide] = node.leftHandSide;
      queue.replace(node.rightHandSide, substitutions[node.rightHandSide]); 
      substitutions.replace(node.rightHandSide, substitutions[node.rightHandSide]);
    } else
      print("NOT POSSIBLE, no typevariables in constraint. ${node}.");
  }
  
  void visitMethodConstraint(MethodConstraint node){
    var method = new FunctionType(node.normalParameterTypes, node.returnType, node.optionalParameterTypes, node.namedParameterTypes);
    if (node.object is TypeVariable){
      substitutions.addProperty(node.object, node.method, method);  
    } else {
      //The object is already converted.
      node.object.addProperty(node.method, method);
    }
  }
}