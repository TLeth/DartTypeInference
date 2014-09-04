library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart';
import 'dart:collection';


class Type {
  
}

class ConcreteType extends Type {
  String _type;
  ConcreteType(this._type);
  
  String toString() => _type;
}

class AbstractType extends Type {
  Expression _exp;
  AbstractType(this._exp);
  
  String toString() => "[${_exp} (${_exp.hashCode})]";
}

class FreeType extends Type {
  static int _counter = 0;
  
  int _typeID;
  
  FreeType() {
    this._typeID = _counter++;
  }
  
  String toString() => "\u{03b1}${_typeID}";
}


class Constraint {
  Expression _exp;
  
  Constraint(this._exp);
}

class EqualityConstraint extends Constraint {
  Type _t;
  
  EqualityConstraint(Expression exp,this._t): super(exp);
  
  String toString() => " = ${_t}";
}

class MethodConstraint extends Constraint {
  String _method;
  List<Expression> _args;
  Type _return;
  
  MethodConstraint(Expression exp, this._method, this._args, this._return): super(exp);
  
  String toString() => " contains method: '${_method}', with return '${_return}'";
}

class Constraints {
  HashMap<Expression, List<Constraint>> _constraints = new HashMap<Expression, List<Constraint>>();
  
  operator []=(Expression exp, Constraint arg) {
    if (!_constraints.containsKey(exp)) _constraints[exp] = <Constraint>[];
    _constraints[exp].add(arg);
  }
  
  operator [](Expression exp) => _constraints[exp];
  
  String toString(){
    StringBuffer sb = new StringBuffer();
    _constraints.forEach((Expression exp, List<Constraint> constraints) =>
        constraints.forEach((Constraint c) => sb.writeln("[${exp} (${exp.hashCode})]: ${c}"))
    );
    return sb.toString();  
  }
}

class ConstraintGeneratorVisitor extends GeneralizingAstVisitor {
  
  Constraints constraints = new Constraints();
  
  visitIntegerLiteral(IntegerLiteral n) {
    super.visitIntegerLiteral(n);
    constraints[n] = new EqualityConstraint(n, new ConcreteType("int"));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    constraints[n] = new EqualityConstraint(n, new ConcreteType("double"));
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    Type return_type = new FreeType();
    constraints[be.leftOperand] = new MethodConstraint(be.leftOperand, "+", [be.rightOperand], return_type);
    constraints[be] = new EqualityConstraint(be, return_type);
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
    super.visitVariableDeclaration(vd);
    constraints[vd.name] = new EqualityConstraint(vd.name, new AbstractType(vd.initializer)); 
    //constraints[vd.initializer] = new EqualityConstraint(vd.initializer, new AbstractType(vd.name));
  }
}