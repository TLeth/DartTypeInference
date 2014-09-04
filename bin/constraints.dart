library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart';
import 'dart:collection';


class Type {
  
}

class ConcreteType extends Type {
  String _type;
  ConcreteType(this._type);
}

class AbstractType extends Type {
  Expression _exp;  
  AbstractType(this._exp);
}

class FreeType extends Type {
  static int _counter = 0;
  
  int _typeID;
  
  FreeType() {
    this._typeID = _counter++;
  }
}


class Constraint {
  Expression _exp;
  
  Constraint(this._exp);
}

class EqualityConstraint extends Constraint {
  Type _t;
  
  EqualityConstraint(Expression exp,this._t): super(exp);
}

class MethodConstraint extends Constraint {
  String _method;
  List<Expression> _args;
  Type _return;
  
  MethodConstraint(Expression exp, this._method, this._args, this._return): super(exp);
}

class Constraints {
  HashMap<Expression, List<Constraint>> _constraints = new HashMap<Expression, List<Constraint>>();
  
  operator []=(Expression exp, Constraint arg) {
    if (!_constraints.containsKey(exp)) _constraints[exp] = <Constraint>[];
    _constraints[exp].add(arg);
  }
  
  operator [](Expression exp) => _constraints[exp];
}


class ConstraintVisitor extends GeneralizingAstVisitor {
  
  Constraints _constraints = new Constraints();
  
  visitIntegerLiteral(IntegerLiteral n) {
    _constraints[n] = new EqualityConstraint(n, new ConcreteType("int"));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    _constraints[n] = new EqualityConstraint(n, new ConcreteType("double"));
  }
  
  visitBinaryExpression(BinaryExpression be) {
    Type return_type = new FreeType();
    _constraints[be.leftOperand] = new MethodConstraint(be.leftOperand, "+", [be.rightOperand], return_type);
    _constraints[be] = new EqualityConstraint(be, return_type);
  }
}