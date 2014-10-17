library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'package:analyzer/src/generated/scanner.dart';
import 'engine.dart';
import 'element.dart';
import 'types.dart';
import 'util.dart';
import 'dart:collection';

class ConstraintAnalysis {
  TypeMap typeMap;
  

  LibraryElement get dartCore => elementAnalysis.dartCore;
  Engine engine;
  ElementAnalysis elementAnalysis;
  ElementTyper elementTyper;
  
  ConstraintAnalysis(Engine this.engine, ElementAnalysis this.elementAnalysis) {
    elementTyper = new ElementTyper(this); 
    typeMap = new TypeMap(this);
  }
}

/************* Type maps ********************/
class TypeMap {
  Map<TypeIdentifier, TypeVariable> _typeMap = <TypeIdentifier, TypeVariable>{};
  
  ConstraintAnalysis constraintAnalysis;
  
  TypeMap(ConstraintAnalysis this.constraintAnalysis);
  
  TypeVariable _lookup(TypeIdentifier ident, ConstraintHelper helper){
    if (containsKey(ident))
      return _typeMap[ident];
    if (ident.isPropertyLookup && ident.propertyIdentifierType is NominalType){
      NominalType type = ident.propertyIdentifierType;
      ClassMember member = type.element.lookup(ident.propertyIdentifierName);
    
      if (member != null)
        return _typeMap[ident] = _typeMap[constraintAnalysis.elementTyper.typeClassMember(member, type.element.sourceElement.library, helper)];
      else
        if (helper.source.source.shortName == 'test.dart')
          print("Didnt find the lookup: ${ident}");
    } else if (ident is ExpressionTypeIdentifier && helper.source.resolvedIdentifiers.containsKey(ident.exp)){

      NamedElement namedElement = helper.source.resolvedIdentifiers[ident.exp];
      return _typeMap[ident] = _typeMap[constraintAnalysis.elementTyper.typeNamedElement(namedElement, namedElement.sourceElement.library, helper)];
    }
    
    if (!containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    
    return _typeMap[ident];
  }
  
  TypeVariable getter(dynamic i, ConstraintHelper helper) {
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    return _lookup(ident, helper);
  }
  
  TypeVariable replace(TypeIdentifier i, TypeVariable v) => _typeMap[i] = v;
  
  TypeVariable operator [](TypeIdentifier ident) => _typeMap[ident];
  
  Iterable<TypeIdentifier> get keys => _typeMap.keys;
  
  bool containsKey(TypeIdentifier ident) => _typeMap.containsKey(ident);  
  
  void put(dynamic i, AbstractType t){
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    if (!_typeMap.containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    _typeMap[ident].add(t);
  }
  
  String toString() {
    StringBuffer sb = new StringBuffer();
    
    for(TypeIdentifier exp in _typeMap.keys){
      sb.writeln("${exp}: ${_typeMap[exp]}");
    }
    
    return sb.toString();
  }
}

typedef bool FilterFunc(AbstractType);
typedef dynamic NotifyFunc(AbstractType);

class TypeVariable {
  Set<AbstractType> _types = new Set<AbstractType>();
  
  List<NotifyFunc> _event_listeners = <NotifyFunc>[];
 // Map<NotifyFunc, FilterFunc> _filters = new HashMap<NotifyFunc, FilterFunc>();
  
  bool _changed = false;
  
  void add(AbstractType t) {
    if (_types.add(t))
      trigger(t);
  }
  
  void trigger(AbstractType type){
    List event_listeners = new List.from(_event_listeners);
    for(NotifyFunc func in event_listeners){
      //if (_filters[func] == null || _filters[func](type))
        func(type);
    }
  }
  
  List<AbstractType> get types => new List.from(_types); 
  
  Function onChange(NotifyFunc func) {
    
    /*
     *  TODO 
     *  This condition is never met, because dart basicly uses pointer comparison for function equality,
     *  so two calls with the syntacticly same lambda wont be considered equals.
     *
     * if (_event_listeners.contains(func)) {
     *   return (() => this.remove(func));
     * }
     */
    
    _event_listeners.add(func);
    
    bool reset;
    List current_types;
    do {
      reset = false;
      current_types = types;
      
      for(AbstractType type in current_types){
          func(type);
  
        if (_types.length != current_types.length){
          reset = true;
          break;
        }
      }
    } while(reset);
    
    return (() => this.remove(func));
  }
  
  bool remove(void func(AbstractType)){
    return _event_listeners.remove(func);
  }
  
  //TODO (jln): returning dynamic is maybe not the best solution.
  /**
   * Return the least upper bound of this type and the given type, or `dynamic` if there is no
   * least upper bound.
   *
   */
  AbstractType getLeastUpperBound() {
    if (_types.length == 0) return new DynamicType();
    Queue<AbstractType> queue = new Queue<AbstractType>.from(_types);
    AbstractType res = queue.removeFirst();
    res = queue.fold(res, (AbstractType res, AbstractType t) => res.getLeastUpperBound(t));
    if (res == null)
      return new DynamicType();
    else 
      return res;
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
  SourceElement get source;
  
  ConstraintHelper foreach(dynamic ident) {
    _lastTypeIdentifier = TypeIdentifier.ConvertToTypeIdentifier(ident);
    return this;
  }
  
  ConstraintHelper where(FilterFunc func){
    _lastWhere = func;
    return this;
  }
  
  void update(NotifyFunc func, [bool stop = false]){
    if (_lastTypeIdentifier != null){
      TypeIdentifier identifier = _lastTypeIdentifier;
      FilterFunc filter = _lastWhere;
      
      _lastTypeIdentifier = null;
      _lastWhere = null;
      types.getter(identifier, this).onChange((AbstractType t) {
        if (filter == null || filter(t))
           func(t);
      });
    }
  }
  
  void equalConstraint(TypeIdentifier a, TypeIdentifier b){
    subsetConstraint(a, b);
    subsetConstraint(b, a);
  }
  
  void subsetConstraint(TypeIdentifier a, TypeIdentifier b) {
    if (a != b)
      foreach(a).update((AbstractType type) => types.put(b, type));
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
  Engine get engine => constraintAnalysis.engine;
  
  ClassElement _currentClassElement = null;
  
  ConstraintGeneratorVisitor(SourceElement this.source, ConstraintAnalysis this.constraintAnalysis) {
    source.ast.accept(this);
  }
  
  Expression _normalizeIdentifiers(Expression exp){
    if (exp is SimpleIdentifier && source.resolvedIdentifiers.containsKey(exp)) {
      return source.resolvedIdentifiers[exp].identifier;
    } else
      return exp;
  }
  
  AbstractType _getAbstractType(Name className, LibraryElement library, SourceElement source){
    ClassElement classElement = elementAnalysis.resolveClassElement(className, library, source);
    if (classElement != null){
      return new NominalType(classElement);
    } else {
      if (className.toString() == 'dynamic')
        return new DynamicType();
      else if (className.toString() == 'void')
        return new VoidType();
      else {
        engine.errors.addError(new EngineError("_getAbstractType was called and the classElement could not be found: ${className}", source.source));
        return null;
      }
    }
  }
  
  TypeIdentifier _normalizeExpressionToTypeIdentifier(dynamic rightHandSide){
    if (rightHandSide is TypeIdentifier)
      return rightHandSide;
    else if (rightHandSide is Expression)
      return new ExpressionTypeIdentifier(rightHandSide);
    else
      engine.errors.addError(new EngineError("_normalizeRightHandSide in constraint was called with a bad rightHandSide `${rightHandSide.runtimeType}`", source.source), true);
    return null;
  }
  
  visitIntegerLiteral(IntegerLiteral n) {
    super.visitIntegerLiteral(n);
    // {int} \in [n]
    types.put(n, _getAbstractType(new Name('int'), constraintAnalysis.dartCore, source));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    // {double} \in [n]
    types.put(n, _getAbstractType(new Name("double"), constraintAnalysis.dartCore, source));
  }
  
  visitStringLiteral(StringLiteral n){
    super.visitStringLiteral(n);
    // {String} \in [n]
    types.put(n, _getAbstractType(new Name("String"), constraintAnalysis.dartCore, source));
    
  }
  
  visitBooleanLiteral(BooleanLiteral n){
    super.visitBooleanLiteral(n);
    // {String} \in [n]
    types.put(n, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitSymbolLiteral(SymbolLiteral n){
    super.visitSymbolLiteral(n);
    // {String} \in [n]
    types.put(n, _getAbstractType(new Name("Symbol"), constraintAnalysis.dartCore, source));
  }  
  
  visitListLiteral(ListLiteral n){
    super.visitListLiteral(n);
    // {String} \in [n]
    types.put(n, _getAbstractType(new Name("List"), constraintAnalysis.dartCore, source));
  }
  
  visitMapLiteral(MapLiteral n){
    super.visitMapLiteral(n);
    // {String} \in [n]
    types.put(n, _getAbstractType(new Name("Map"), constraintAnalysis.dartCore, source));
    ConstructorInitializer t;
  }
  
  visitInstanceCreationExpression(InstanceCreationExpression n){
    super.visitInstanceCreationExpression(n);
    // new ClassName(arg_1,..., arg_n);
    NamedElement element = source.resolvedIdentifiers[n.constructorName.type.name];
    
    //TODO (jln): What about generics.
    
    if (element != null){
      //{ClassName} \in [n]
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
      if (element is ClassElement) { //The constructor called is unnammed.
        AbstractType classType = new NominalType(element);
        if (element.declaredConstructors.isEmpty) {
          //Class does not contain a constructor, so use the implicit constructor. 
          types.put(nodeIdent, classType);
        } else {
          //Call the constructor like a function.
          AbstractType classType = new NominalType(element);
          TypeIdentifier constructorIdent = new PropertyTypeIdentifier(classType, element.name);
          _methodCall(constructorIdent, n.argumentList.arguments, nodeIdent);
        }
      } else if (element is ConstructorElement){
        //Call the constructor like a function.
        AbstractType classType = new NominalType(element.classDecl);
        TypeIdentifier constructorIdent = new PropertyTypeIdentifier(classType, element.name);
        _methodCall(constructorIdent, n.argumentList.arguments, nodeIdent);
      }
    }
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
     // var v;
     super.visitVariableDeclaration(vd);
     
     if (!elementAnalysis.containsElement(vd))
       engine.errors.addError(new EngineError("A VariableDeclaration was visited, but didn't have a associated elemenet.", source.source, vd.offset, vd.length ), true);
     
     Element element = elementAnalysis.elements[vd];
     if (element is FieldElement){
       ClassElement classElement = element.classDecl;
       TypeIdentifier v = new PropertyTypeIdentifier(new NominalType(classElement), element.name);
       equalConstraint(v, new ExpressionTypeIdentifier(vd.name));
     }
     
     
     if (vd.initializer != null){
       // v = exp;
      _assignmentExpression(vd.name, vd.initializer);
     }
  }
  
  visitParenthesizedExpression(ParenthesizedExpression node){
    super.visitParenthesizedExpression(node);
    //(exp)
    // [exp] \subseteq [(exp)]
    
    TypeIdentifier expIdent = new ExpressionTypeIdentifier(node.expression);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    subsetConstraint(expIdent, nodeIdent);
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    
    Expression leftHandSide = node.leftHandSide;
    Expression rightHandSide = node.rightHandSide;
    
    if (node.operator.toString() != '='){
      //Make method invocation for the node.operator.
      String operator = node.operator.toString();
      operator = operator.substring(0, operator.length - 1);
      
      TypeIdentifier vIdent = new ExpressionTypeIdentifier(leftHandSide);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      
      //Make the operation
      foreach(vIdent).update((AbstractType alpha) {
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, new Name(operator));
        TypeIdentifier returnIdent = new SyntheticTypeIdentifier(methodIdent);
        _methodCall(methodIdent, <Expression>[rightHandSide], returnIdent);
        
        //Result of (leftHandSide op RightHandSide) should be the result of the hole node.
        subsetConstraint(returnIdent, nodeIdent);
        
        //Make the assignment from the returnIdent to the leftHandSide.
        _assignmentExpression(leftHandSide, returnIdent);
      });
    } else {
      // In case of exp_1 = exp_2
      _assignmentExpression(leftHandSide, rightHandSide);
      
      TypeIdentifier exp = new ExpressionTypeIdentifier(rightHandSide);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      
      // [exp] \subseteq [v = exp]
      subsetConstraint(exp, nodeIdent);
    }
  }
  
  // v = exp
  _assignmentExpression(Expression leftHandSide, dynamic rightHandSide){
    TypeIdentifier expIdent = _normalizeExpressionToTypeIdentifier(rightHandSide);
    if (leftHandSide is SimpleIdentifier)
      _assignmentSimpleIdentifier(leftHandSide, expIdent);
    else if (leftHandSide is PrefixedIdentifier)
      _assignmentPrefixedIdentifier(leftHandSide, expIdent);
    else if (leftHandSide is PropertyAccess)
      _assignmentPropertyAccess(leftHandSide, expIdent);
    else if (leftHandSide is IndexExpression)
      _assignmentIndexExpression(leftHandSide, expIdent);
    else {
      engine.errors.addError(new EngineError("_assignmentExpression was called with a bad leftHandSide: `${leftHandSide.runtimeType}`", source.source), true);
      //TODO (jln): assigment to a non identifier on left hand side (example v[i]).
    }
  }
  
   // v = exp;
   // [exp] \subseteq [v]
  _assignmentSimpleIdentifier(SimpleIdentifier leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier vIdent = new ExpressionTypeIdentifier(leftHandSide);
    subsetConstraint(expIdent, vIdent);
  }
  
  // v.prop = exp;
  // \alpha \in [v] => [exp] \subseteq [\alpha.prop]
  _assignmentPropertyAccess(PropertyAccess leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(leftHandSide.realTarget);
    foreach(targetIdent).update((AbstractType alpha){
      TypeIdentifier alphapropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(leftHandSide.propertyName));
      subsetConstraint(expIdent, alphapropertyIdent);
    });
  }

  // v.prop = exp;
  // \alpha \in [v] => [exp] \subseteq [\alpha.prop]
  _assignmentPrefixedIdentifier(PrefixedIdentifier leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(leftHandSide.prefix);
    
    foreach(prefixIdent).update((AbstractType alpha){
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(leftHandSide.identifier));
      subsetConstraint(expIdent, alphaPropertyIdent);
    });

  }
  
  // v[i] = exp;
  // \alpha \in [v] => (\beta => \gamma => void) \in [v.[]=] => [i] \subseteq [\beta] && [exp] \subseteq [\gamma]
  _assignmentIndexExpression(IndexExpression leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(leftHandSide.realTarget);
    foreach(targetIdent).update((AbstractType alpha) {
      TypeIdentifier indexEqualMethodIdent = new PropertyTypeIdentifier(alpha, new Name("[]="));
      _methodCall(indexEqualMethodIdent, [leftHandSide.index, expIdent], null);
    });
  }
  
  visitSimpleIdentifier(SimpleIdentifier n){
    super.visitSimpleIdentifier(n);
    SimpleIdentifier ident = _normalizeIdentifiers(n);
    
    if (ident != n){
      //TODO (jln): A possible speedup would be changing the simpleidentifiers to the identifier used in the variable decl.
      // This can be done in a previous AST-gothrough
      equalConstraint(new ExpressionTypeIdentifier(ident), new ExpressionTypeIdentifier(n));
    }
  }
  
  visitPrefixedIdentifier(PrefixedIdentifier n){
    super.visitPrefixedIdentifier(n);
    SimpleIdentifier prefix = n.prefix;
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(prefix);
    //TODO (jln): This does not take library prefix into account.
    foreach(prefixIdent).update((AbstractType alpha) {
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(n.identifier));
      subsetConstraint(alphaPropertyIdent, nodeIdent);
    });
  }
  
  visitPropertyAccess(PropertyAccess n){
    super.visitPropertyAccess(n);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(n.realTarget);
    
    //TODO (jln): This does not take library prefix into account.
    foreach(targetIdent).update((AbstractType alpha) {
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(n.propertyName));
      subsetConstraint(alphaPropertyIdent, nodeIdent);
    });
  }
  
  visitIndexExpression(IndexExpression n){
    super.visitIndexExpression(n);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(n.realTarget);
        
    //TODO (jln): This does not take library prefix into account.
    foreach(targetIdent).update((AbstractType alpha) {
      TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, new Name("[]"));
      _methodCall(methodIdent, <Expression>[n.index], nodeIdent);
    });
  }

  visitThisExpression(ThisExpression n) {
    // this
    super.visitThisExpression(n);
    if (_currentClassElement == null)
          engine.errors.addError(new EngineError("thisExpression was visited but the CurrentClassElement was null.", source.source, n.offset, n.length), true);
    else
      types.put(n, new NominalType(_currentClassElement));
  }
  
  visitSuperExpression(SuperExpression n){
    // super
    super.visitSuperExpression(n);
    if (_currentClassElement == null || _currentClassElement.extendsElement == null)
      engine.errors.addError(new EngineError("superExpression was visited but the parent _currentClassElement parnet was null.", source.source, n.offset, n.length), true);
    else
      types.put(n, new NominalType(_currentClassElement.extendsElement));
  }  

  visitMethodInvocation(MethodInvocation node){
    super.visitMethodInvocation(node);

    TypeIdentifier returnIdent = new ExpressionTypeIdentifier(node);
    if (node.realTarget == null){
      //Call without any prefix
      TypeIdentifier methodIdent = new ExpressionTypeIdentifier(node.methodName);
      _methodCall(methodIdent, node.argumentList.arguments, returnIdent);
    } else {
      //Called with a prefix
      //TODO (jln): This does not take library prefix into account.
      TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.realTarget);
      foreach(targetIdent).update((AbstractType type) { 
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(type, new Name.FromIdentifier(node.methodName));
        _methodCall(methodIdent, node.argumentList.arguments, returnIdent);
      });
    }
  }
  
  _methodCall(TypeIdentifier method, List argumentList, [TypeIdentifier returnIdent = null]){
    // method(arg_1,...,arg_n) : return
    List<TypeIdentifier> parameters = <TypeIdentifier>[];
    Map<Name, TypeIdentifier> namedParameters = <Name, TypeIdentifier>{};
    
    if (argumentList != null){
      for(var arg in argumentList){
        if (arg is NamedExpression)
          namedParameters[new Name.FromIdentifier(arg.name.label)] = new ExpressionTypeIdentifier(arg.expression);
        else if (arg is Expression)
          parameters.add(new ExpressionTypeIdentifier(arg));
        else if (arg is TypeIdentifier)
          parameters.add(arg);
        else
          engine.errors.addError(new EngineError("_methodCall in constraint.dart was called with a unreal argument: `${arg.runtimeType}`", source.source), true);
      }
    }
    //\forall (\gamma_1 -> ... -> \gamma_n -> \beta) \in [method] =>
    //  \gamma_i \in [arg_i] &&  \beta \in [method]
    foreach(method)
      .where((AbstractType func) {
          return func is FunctionType && 
          MapUtil.submap(namedParameters, func.namedParameterTypes) &&
          func.optionalParameterTypes.length + func.normalParameterTypes.length >= parameters.length; })
      .update((AbstractType func) {
        if (func is FunctionType) {
          for (var i = 0; i < parameters.length;i++){
            if (i < func.normalParameterTypes.length)
              subsetConstraint(parameters[i], func.normalParameterTypes[i]);              
            else
              subsetConstraint(parameters[i], func.optionalParameterTypes[i - func.normalParameterTypes.length]);
          }
          for(Name name in namedParameters.keys){
            subsetConstraint(namedParameters[name], func.namedParameterTypes[name]);
          }
          if (returnIdent != null) subsetConstraint(func.returnType, returnIdent);
        }
      }); 
  }
  
  visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);
    types.put(node.condition, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }

  visitForStatement(ForStatement node) {
    super.visitForStatement(node);
    types.put(node.condition, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }

  visitDoStatement(DoStatement node) {
    super.visitDoStatement(node);
    types.put(node.condition, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitWhileStatement(WhileStatement node) {
    super.visitWhileStatement(node);
    types.put(node.condition, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }


  visitReturnStatement(ReturnStatement node){
    super.visitReturnStatement(node);
    if (node.expression != null){
      if (!elementAnalysis.containsElement(node) && elementAnalysis.elements[node] is ReturnElement)
        engine.errors.addError(new EngineError("A ReturnStatement was visited, but didn't have a associated ReturnElement.", source.source, node.offset, node.length ), true);
    
      ReturnElement returnElement = elementAnalysis.elements[node];
      subsetConstraint(new ExpressionTypeIdentifier(node.expression), new ReturnTypeIdentifier(returnElement.function));
    }
  }
  
  visitExpressionFunctionBody(ExpressionFunctionBody node){
    super.visitExpressionFunctionBody(node);
    if (!elementAnalysis.containsElement(node) && elementAnalysis.elements[node] is ReturnElement)
      engine.errors.addError(new EngineError("A ExpressionFunctionBody was visited, but didn't have a associated ReturnElement.", source.source, node.offset, node.length ), true);
    ReturnElement returnElement = elementAnalysis.elements[node];
    subsetConstraint(new ExpressionTypeIdentifier(node.expression), new ReturnTypeIdentifier(returnElement.function));
  }
  
  
  bool _returnsVoid(CallableElement node) {
    if (node.isExternal)
      return false;
    else if (node is MethodElement && (node.isAbstract || node.isGetter))
      return false;
    else if (node is NamedFunctionElement && node.isGetter)
      return false;
    else
      return node.returns.fold(true, (bool res, ReturnElement r) => res && r.ast.expression == null);
  }
  
  visitFunctionExpression(FunctionExpression node){
    super.visitFunctionExpression(node);
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! CallableElement)
      engine.errors.addError(new EngineError("A FunctionExpression was visited, but didn't have a associated CallableElement.", source.source, node.offset, node.length ), true);
      
    CallableElement callableElement = elementAnalysis.elements[node];
    types.put(new ExpressionTypeIdentifier(node), new FunctionType.FromCallableElement(callableElement, source.library, elementTyper));
    
    if (_returnsVoid(callableElement)) {
      types.put(new ReturnTypeIdentifier(callableElement), new VoidType());
    }
  }
  
  visitMethodDeclaration(MethodDeclaration node){
    super.visitMethodDeclaration(node);
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! MethodElement)
      engine.errors.addError(new EngineError("A MethodDeclaration was visited, but didn't have a associated MethodElement.", source.source, node.offset, node.length ), true);
        
    MethodElement methodElement = elementAnalysis.elements[node];
    
    if (methodElement.isSetter){
      TypeIdentifier methodIdent = elementTyper.typeMethodElement(methodElement, source.library, this);
      equalConstraint(new PropertyTypeIdentifier(new NominalType(_currentClassElement), methodElement.getterName), methodIdent);
    }
    
    if (_returnsVoid(methodElement)) {
      types.put(new ReturnTypeIdentifier(methodElement), new VoidType());
    }
  }

  
  visitFunctionDeclaration(FunctionDeclaration node){
    super.visitFunctionDeclaration(node);
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! NamedFunctionElement)
      engine.errors.addError(new EngineError("A FunctionDeclaration was visited, but didn't have a associated NamedFunctionElement.", source.source, node.offset, node.length ), true);
        
    NamedFunctionElement functionElement = elementAnalysis.elements[node];
    if (functionElement.isSetter){
      TypeIdentifier methodIdent = elementTyper.typeNamedFunctionElement(functionElement, source.library, this);
      NamedElement element = source.resolvedIdentifiers[functionElement.identifier];
      //Link the setter and getter together.
      if (element != functionElement)
        equalConstraint(new ExpressionTypeIdentifier(element.identifier), new ExpressionTypeIdentifier(functionElement.identifier));
    }
    
    if (_returnsVoid(functionElement)) {
      types.put(new ReturnTypeIdentifier(functionElement), new VoidType());
    }
  }
  
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node){
    super.visitFunctionTypedFormalParameter(node);
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! CallableElement)
      engine.errors.addError(new EngineError("A FunctionTypedFormalParameter was visited, but didn't have a associated Callablelement.", source.source, node.offset, node.length ), true);
    CallableElement callableElement = elementAnalysis.elements[node];
    
    TypeIdentifier funcIdent = new ExpressionTypeIdentifier(node.identifier);
    TypeIdentifier returnIdent = elementTyper.typeReturn(callableElement, source.library, source);
    ParameterTypes paramIdents = elementTyper.typeParameters(callableElement, source.library, source);
    foreach(funcIdent)
      .where((AbstractType func) {
          return func is FunctionType && 
          MapUtil.submap(func.namedParameterTypes, paramIdents.namedParameterTypes) &&
          paramIdents.optionalParameterTypes.length >= func.optionalParameterTypes.length &&
          paramIdents.normalParameterTypes.length == func.normalParameterTypes.length; })
      .update((AbstractType func) {
        if (func is FunctionType) {
          for (var i = 0; i < paramIdents.normalParameterTypes.length;i++)
            subsetConstraint(func.normalParameterTypes[i], paramIdents.normalParameterTypes[i]);
          for (var i = 0; i < func.optionalParameterTypes.length;i++)
            subsetConstraint(func.normalParameterTypes[i], paramIdents.normalParameterTypes[i]);
          
          for(Name name in func.namedParameterTypes.keys){
            subsetConstraint(func.namedParameterTypes[name], paramIdents.namedParameterTypes[name]);
          }
          subsetConstraint(func.returnType, returnIdent);
        }
     });
  }
  
  visitFieldFormalParameter(FieldFormalParameter node){
    super.visitFieldFormalParameter(node);
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! FieldParameterElement)
      engine.errors.addError(new EngineError("A FieldFormalParameter was visited, but didn't have a associated FieldParameterElement.", source.source, node.offset, node.length ), true);
    FieldParameterElement fieldParameter = elementAnalysis.elements[node];
    
    TypeIdentifier paramIdent = new ExpressionTypeIdentifier(node.identifier);
    TypeIdentifier fieldIdent = new PropertyTypeIdentifier(new NominalType(fieldParameter.classElement), new Name.FromIdentifier(node.identifier));
    equalConstraint(paramIdent, fieldIdent);
  }
  
  visitConditionalExpression(ConditionalExpression node){
    super.visitConditionalExpression(node);
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node); 
    
    // exp1 ? exp2 : exp3
    // [exp2] \union [exp3] \subseteq [exp1 ? exp2 : exp3]
    subsetConstraint(new ExpressionTypeIdentifier(node.thenExpression), nodeIdent);
    subsetConstraint(new ExpressionTypeIdentifier(node.elseExpression), nodeIdent);

    types.put(node.condition, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitClassDeclaration(ClassDeclaration node){
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! ClassElement)
      engine.errors.addError(new EngineError("A ClassDeclaration was visited, but didn't have a associated ClassElement.", source.source, node.offset, node.length ), true);
    _currentClassElement = elementAnalysis.elements[node];
    super.visitClassDeclaration(node);
    _currentClassElement = null;
  }
  
  visitConstructorFieldInitializer(ConstructorFieldInitializer node){
    super.visitConstructorFieldInitializer(node);
    _assignmentExpression(node.fieldName, node.expression);
  }
  
  visitSuperConstructorInvocation(SuperConstructorInvocation node){
    super.visitSuperConstructorInvocation(node);
    if (_currentClassElement == null || _currentClassElement.extendsElement == null)
      engine.errors.addError(new EngineError("A SuperConstructorInvocation was visited, but currentClassElement exntedsElement was null.", source.source, node.offset, node.length ), true);
    
    ClassElement element = _currentClassElement.extendsElement;
    TypeIdentifier constructorIdent;
    if (!element.declaredConstructors.isEmpty){
      if (node.constructorName == null)
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), element.name);
      else
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), new PrefixedName(element.name, new Name.FromIdentifier(node.constructorName)));
      _methodCall(constructorIdent, node.argumentList.arguments);
    }
  }
  
  visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node){
    super.visitRedirectingConstructorInvocation(node);
    if (_currentClassElement == null)
      engine.errors.addError(new EngineError("A RedirectingConstructorInvocation was visited, but currentClassElement was null.", source.source, node.offset, node.length ), true);
    
    ClassElement element = _currentClassElement;
    TypeIdentifier constructorIdent;
    if (!element.declaredConstructors.isEmpty){
      if (node.constructorName == null)
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), element.name);
      else
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), new PrefixedName(element.name, new Name.FromIdentifier(node.constructorName)));
      _methodCall(constructorIdent, node.argumentList.arguments);
    }
  }
  
  bool _isIncrementOperator(String operator) => operator == '--' || operator == '++';
  
  visitPostfixExpression(PostfixExpression node){
    super.visitPostfixExpression(node);
    //The postfix is just keeping the type for the expression. 
    
    //(exp)
    // [exp] \subseteq [exp op]
    TypeIdentifier expIdent = new ExpressionTypeIdentifier(node.operand);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    subsetConstraint(expIdent, nodeIdent);
  }
  
  // op v
  visitPrefixExpression(PrefixExpression node){
    super.visitPrefixExpression(node);
    
    // If increment operator (-- or ++)
    if (_isIncrementOperator(node.operator.toString())) {
      String operator = node.operator.toString();
      operator = operator.substring(0, operator.length - 1);
      
      TypeIdentifier vIdent = new ExpressionTypeIdentifier(node.operand);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      
      //Make the operation
      foreach(vIdent).update((AbstractType alpha) {
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, new Name(operator));
        TypeIdentifier returnIdent = new SyntheticTypeIdentifier(methodIdent);
        _methodCall(methodIdent, <Expression>[new IntegerLiteral(new StringToken(TokenType.INT, "1", 0), 1)], returnIdent);
        //Result of (leftHandSide op RightHandSide) should be the result of the hole node.
        subsetConstraint(returnIdent, nodeIdent);
        
        //Make the assignment from the returnIdent to the leftHandSide.
        _assignmentExpression(node.operand, returnIdent);
      });
      
    } else if (node.operator.toString() == '!'){
      //If the is a negate it is the same as writing (e ? false : true), the result will always be a bool.
      types.put(node, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source)); 
    } else {
      Name operator;
      if (node.operator.toString() == '-') operator = Name.UnaryMinusName();
      else operator = new Name.FromToken(node.operator);
      
      TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.operand);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      foreach(targetIdent).update((AbstractType type) { 
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(type, operator); 
        _methodCall(methodIdent, [], nodeIdent);
      });
    }
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    
    // exp1 op exp2
    TypeIdentifier leftIdent = new ExpressionTypeIdentifier(be.leftOperand);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(be);
    

    //  \forall \gamma \in [exp1], 
    //  \forall (\alpha -> \beta) \in [ \gamma .op ] => 
    //      \alpha \in [exp2] && \beta \in [exp1 op exp2].
    foreach(leftIdent).update((AbstractType gamma) {
      TypeIdentifier methodIdent = new PropertyTypeIdentifier(gamma, new Name.FromToken(be.operator));
      _methodCall(methodIdent, <Expression>[be.rightOperand], nodeIdent);
    });
  }
  
  visitIsExpression(IsExpression n){
    super.visitIsExpression(n);

    // {bool} \in [e is T]
    types.put(n, _getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitAsExpression(AsExpression n){
    super.visitAsExpression(n);

    AbstractType castType = _getAbstractType(new Name.FromIdentifier(n.type.name), source.library, source);

    
    if (n.type.name.toString() == 'dynamic' || castType == null) {
      //as dynamic doesn't give you any info, so just make them equal.
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
      TypeIdentifier expIdent = new ExpressionTypeIdentifier(n.expression);
      subsetConstraint(expIdent, nodeIdent);
    } else {
      // {T} \in [e as T]
      types.put(n, castType);
    }
  } 
  
  visitCascadeExpression(CascadeExpression node){
    super.visitCascadeExpression(node);
    
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.target);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    subsetConstraint(targetIdent, nodeIdent);
  }
}

