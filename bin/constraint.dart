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

/************ CONSTRAINT TYPES *************/
abstract class AbstractType {
  AbstractType replace(AbstractType from, AbstractType to);
  AbstractType addProperty(Name name, NonStructuralType type);
  AbstractType union(AbstractType type);
}

abstract class NonStructuralType extends AbstractType { 
  AbstractType addProperty(Name name, NonStructuralType type) {
    AbstractType res = new ObjectType(this);
    res.addProperty(name, type);
    return res;
  }
}

abstract class SimpleType extends NonStructuralType {
  AbstractType union(AbstractType type) {
    if (type is SimpleType)
      return new UnionType(<SimpleType>[this, type]);
    else
      return type.union(this);
  }
  
  AbstractType replace(AbstractType from, AbstractType to) => (from == this ? to : this);
}

class NominalType extends SimpleType {
  String type;
  NominalType(String this.type);
  
  String toString() => type; 
  bool operator ==(Object other) => other is NominalType && type == other.type;
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

class UnionType extends NonStructuralType {
  List<SimpleType> types;
  
  UnionType(List<SimpleType> this.types);
  
  AbstractType replace(AbstractType from, AbstractType to) {
    for (var i = 0; i < types.length; i++)
      types[i] = types[i].replace(from, to);
    return this;
  }
  
  AbstractType union(AbstractType type){
    if (type is SimpleType){
      types.add(type);
      return this;
    } else if (type is UnionType){
      types.addAll(type.types);
      return this;
    } else {
      return type.union(this);
    }
  }
  
  AbstractType addProperty(Name name, NonStructuralType type) {
     AbstractType res = new ObjectType(this);
     res.addProperty(name, type);
     return res;
  }
  
  String toString() => types.toString(); 
}

class FunctionType extends SimpleType {
  List<NonStructuralType> normalParameterTypes;
  List<NonStructuralType> optionalParameterTypes;
  Map<Name, NonStructuralType> namedParameterTypes;
  NonStructuralType returnType;
  
  FunctionType(List<NonStructuralType> this.normalParameterTypes, NonStructuralType this.returnType, 
              [List<NonStructuralType> optionalParameterTypes = null, Map<Name, NonStructuralType> namedParameterTypes = null ] ) :
                this.optionalParameterTypes = (optionalParameterTypes == null ? <NonStructuralType>[] : optionalParameterTypes),
                this.namedParameterTypes = (namedParameterTypes == null ? <Name, NonStructuralType>{} : namedParameterTypes);
  

  String toString() {
    String res = "(";
    res = normalParameterTypes.fold(res, (String res, NonStructuralType type) => res + "${type} -> ");

    if (optionalParameterTypes.length > 0){
      optionalParameterTypes.fold(res + "[", (String res, NonStructuralType type) => res + "${type} -> ");
      res = res.substring(0, res.length - 4) + "] -> ";
    }

    if (namedParameterTypes.length > 0){
      MapUtil.fold(namedParameterTypes, res + "{", (String res, Name ident, NonStructuralType type) => res + "${ident}: ${type} -> ");
      res = res.substring(0, res.length - 4) + "} -> "; 
    }

    return res + "${returnType})";
  }
  
  AbstractType replace(AbstractType from, AbstractType to) {
    if (from == this) return to;
    for (var i = 0; i < normalParameterTypes.length; i++)
      normalParameterTypes[i] = normalParameterTypes[i].replace(from, to);
    for (var i = 0; i < optionalParameterTypes.length; i++)
      optionalParameterTypes[i] = optionalParameterTypes[i].replace(from, to);
    namedParameterTypes.keys.forEach((Name ident) => namedParameterTypes[ident] = namedParameterTypes[ident].replace(from, to));
    returnType = returnType.replace(from, to);
    return this;
  }
}

class ObjectType extends AbstractType {
  Map<Name, NonStructuralType> properties = <Name, NonStructuralType>{};
  
  NonStructuralType type;
  
  ObjectType(NonStructuralType this.type);
  
  AbstractType replace(AbstractType from, AbstractType to) {
    if (from == this) return to;
    if (to is NonStructuralType){
      properties.keys.forEach((Name ident) => properties[ident] = properties[ident].replace(from, to) );
      this.type = this.type.replace(from, to);
    } else if (to is ObjectType){
      AbstractType newType = this.type.replace(from, to);
      if (newType is ObjectType){
        this.union(newType);
      }
    }
    return this;
  }
  
  AbstractType addProperty(Name name, NonStructuralType type) {
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
      type.properties.forEach((Name ident, NonStructuralType type) {
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
  List<SimpleType> normalParameterTypes;
  List<SimpleType> optionalParameterTypes;
  Map<Name, SimpleType> namedParameterTypes;
  SimpleType returnType;
  
  MethodConstraint(AbstractType this.object, this.method, List<SimpleType> this.normalParameterTypes, this.returnType, [List<SimpleType> optionalParameterTypes = null, Map<Name, SimpleType> namedParameterTypes = null ] ) :
    this.optionalParameterTypes = (optionalParameterTypes == null ? <SimpleType>[] : optionalParameterTypes),
    this.namedParameterTypes = (namedParameterTypes == null ? <Name, SimpleType>{} : namedParameterTypes);
  
  String toString() => "${object} contains method: '${method}', with return '${returnType}', normalParameters: ${normalParameterTypes}, optionalParameters: ${optionalParameterTypes}, namedParameters: ${namedParameterTypes}.";
  
  dynamic accept(ConstraintVisitor visitor) => visitor.visitMethodConstraint(this);
  
  void replace(AbstractType from, AbstractType to) {
    object = object.replace(from, to);
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
    constraints.add(new EqualityConstraint(new TypeVariable(n), new NominalType("int")));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    constraints.add(new EqualityConstraint(new TypeVariable(n), new NominalType("double")));
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
  Map<TypeVariable, ObjectType> substitutions = <TypeVariable, ObjectType>{};
  
  ObjectType operator [](TypeVariable key) => substitutions[key];
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
  
  void addProperty(TypeVariable key, Name property, NonStructuralType type) {
    if (!substitutions.containsKey(key))
      substitutions[key] = new ObjectType(key);
    substitutions[key] = substitutions[key].addProperty(property, type);
  }
  
  String toString(){
    StringBuffer sb = new StringBuffer();
    substitutions.forEach((TypeVariable key, ObjectType type) => sb.writeln("${key}: $type"));
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
      
      //If none of the sides where type variables just union the new element.
    } else if (node.leftHandSide is ObjectType) {
      node.leftHandSide.union(node.rightHandSide);
    } else if (node.rightHandSide is ObjectType) {
      node.rightHandSide.union(node.leftHandSide);
    } else if (node.leftHandSide is UnionType){
      node.leftHandSide.union(node.rightHandSide);
    } else if (node.rightHandSide is UnionType){
      node.rightHandSide.union(node.leftHandSide);
    } else {
      print("NOT POSSIBLE, no typevariables in constraint. ${node}.");
    }
  }
  
  void visitMethodConstraint(MethodConstraint node){
    var method = new FunctionType(node.normalParameterTypes, node.returnType, node.optionalParameterTypes, node.namedParameterTypes);
    if (node.object is TypeVariable){
      substitutions.addProperty(node.object, node.method, method);
      queue.replace(node.object, substitutions[node.object]); 
      substitutions.replace(node.object, substitutions[node.object]);  
    } else {
      //The object is already converted therefore it is already a object type.
      node.object.addProperty(node.method, method);
    }
  }
}