library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'engine.dart';
import 'element.dart';
import 'types.dart';
import 'util.dart';


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
  
  TypeVariable _lookup(TypeIdentifier ident, SourceElement source){
    if (containsKey(ident))
      return _typeMap[ident];
    
    if (ident.isPropertyLookup && ident.propertyIdentifierType is NominalType){
      NominalType type = ident.propertyIdentifierType;
      ClassMember member = type.element.lookup(ident.propertyIdentifierName);
    
      if (member != null)
        return _typeMap[ident] = _typeMap[constraintAnalysis.elementTyper.typeClassMember(member, type.element.sourceElement.library)];
    } else if (ident is ExpressionTypeIdentifier && source.resolvedIdentifiers.containsKey(ident.exp)){
      NamedElement namedElement = source.resolvedIdentifiers[ident.exp];
      return _typeMap[ident] = _typeMap[constraintAnalysis.elementTyper.typeNamedElement(namedElement, namedElement.sourceElement.library)];
    }
    
    
    
    if (!containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    
    return _typeMap[ident];
  }
  
  TypeVariable getter(dynamic i, SourceElement source) {
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    return _lookup(ident, source);
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
  Map<NotifyFunc,FilterFunc> _filters = <NotifyFunc, FilterFunc>{};
  
  bool _changed = false;
  
  void add(AbstractType t) {
    //TODO (jln) If the type added is a free-type check if there already exists a free type and merge them.
    if (_types.add(t)) {
      _changed = true;
      trigger(t);
      _changed = false;
    }
  }
  
  List<AbstractType> get allTypes => new List.from(_types); 
  
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
    for(NotifyFunc func in _event_listeners){
      if (_filters[func] == null || _filters[func](type))
        func(type);
    }
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
  
  void update(NotifyFunc func){
    if (_lastTypeIdentifier != null){
      TypeIdentifier identifier = _lastTypeIdentifier;
      FilterFunc filter = _lastWhere;
      
      _lastTypeIdentifier = null;
      _lastWhere = null;
      types.getter(identifier, source).notify(func, filter);
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
  Engine get engine => constraintAnalysis.engine;
  
  ConstraintGeneratorVisitor(SourceElement this.source, ConstraintAnalysis this.constraintAnalysis) {
    source.ast.accept(this);
  }
  
  Expression _normalizeIdentifiers(Expression exp){
    if (exp is SimpleIdentifier && source.resolvedIdentifiers.containsKey(exp))
      return source.resolvedIdentifiers[exp].identifier;
    else
      return exp;
  }
  
  void _equalConstraint(TypeIdentifier a, TypeIdentifier b){
    _subsetConstraint(a, b);
    _subsetConstraint(b, a);
  }
  
  void _subsetConstraint(TypeIdentifier a, TypeIdentifier b) {
    if (a != b)
      foreach(a).update((AbstractType type) => types.put(b, type));
  }
  
  visitIntegerLiteral(IntegerLiteral n) {
    super.visitIntegerLiteral(n);
    // {int} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("int"), constraintAnalysis.dartCore, source)));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    // {double} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("double"), constraintAnalysis.dartCore, source)));
  }
  
  visitStringLiteral(StringLiteral n){
    super.visitStringLiteral(n);
    // {String} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("String"), constraintAnalysis.dartCore, source)));
    
  }
  
  visitBooleanLiteral(BooleanLiteral n){
    super.visitBooleanLiteral(n);
    // {String} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("bool"), constraintAnalysis.dartCore, source)));
  }
  
  visitSymbolLiteral(SymbolLiteral n){
    super.visitSymbolLiteral(n);
    // {String} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("Symbol"), constraintAnalysis.dartCore, source)));
  }  
  
  visitListLiteral(ListLiteral n){
    super.visitListLiteral(n);
    // {String} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("List"), constraintAnalysis.dartCore, source)));
  }
  
  visitMapLiteral(MapLiteral n){
    super.visitMapLiteral(n);
    // {String} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement(new Name("Map"), constraintAnalysis.dartCore, source)));
  }
  
  
  visitInstanceCreationExpression(InstanceCreationExpression n){
    super.visitInstanceCreationExpression(n);
    // new ClassName(arg_1,..., arg_n);
    TypeName classType = n.constructorName.type;
    
    Identifier className = classType.name;
    
    //TODO (jln): What about generics.
    
    if (className != null){
      // {ClassName} \in [n]
      TypeIdentifier returnIdent = new ExpressionTypeIdentifier(n);
      ClassElement classElement = elementAnalysis.resolveClassElement(new Name.FromIdentifier(className), source.library, source);
      
      if (classElement != null){
        Name constructorName = null;
        if (n.constructorName.name != null)
          constructorName = new PrefixedName.FromIdentifier(classElement.identifier, new Name.FromIdentifier(n.constructorName.name));
        else
          constructorName = new Name.FromIdentifier(classElement.identifier);
        
        AbstractType classType = new NominalType(classElement);
        TypeIdentifier constructorIdent = new PropertyTypeIdentifier(classType, constructorName);
        _methodCall(constructorIdent, n.argumentList.arguments, returnIdent);
        
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
       _equalConstraint(v, new ExpressionTypeIdentifier(vd.name));
     }
     
     // v = exp;
     _assignmentExpression(vd.name, vd.initializer);
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    
    // v = exp;
    _assignmentExpression(node.leftHandSide, node.rightHandSide);
    
    TypeIdentifier exp = new ExpressionTypeIdentifier(node.rightHandSide);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    // [exp] \subseteq [v = exp]
    _subsetConstraint(exp, nodeIdent);
  }
  
  _assignmentExpression(Expression leftHandSide, Expression rightHandSide){
    TypeIdentifier v = new ExpressionTypeIdentifier(leftHandSide);
    TypeIdentifier exp = new ExpressionTypeIdentifier(rightHandSide);
    
    if (leftHandSide is SimpleIdentifier || leftHandSide is PrefixedIdentifier){
      // v = exp;
      
      // [exp] \subseteq [v]
      _subsetConstraint(exp, v);
    } else {
      //TODO (jln): assigment to a non identifier on left hand side (example v[i]).
    }
  }
  
  visitSimpleIdentifier(SimpleIdentifier n){
    super.visitSimpleIdentifier(n);
    SimpleIdentifier ident = _normalizeIdentifiers(n);
    
    if (ident != n){
      //TODO (jln): A possible speedup would be changing the simpleidentifiers to the identifier used in the variable decl.
      // This can be done in a previous AST-gothrough
      _equalConstraint(new ExpressionTypeIdentifier(ident), new ExpressionTypeIdentifier(n));
    }
  }
  
  visitPrefixedIdentifier(PrefixedIdentifier n){
    super.visitPrefixedIdentifier(n);
    SimpleIdentifier prefix = n.prefix;
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(prefix);
    //TODO (jln): This does not take library prefix into account.
    foreach(prefixIdent).update((AbstractType alpha) {
      TypeIdentifier alphaFld = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(n.identifier));
      _equalConstraint(nodeIdent, alphaFld);
    });
  }

  visitThisExpression(ThisExpression n) {
    // this
    super.visitThisExpression(n);
    ClassElement classElement = source.thisReferences[n];
    types.put(n, new NominalType(classElement));
  }
  

  visitMethodInvocation(MethodInvocation node){
    super.visitMethodInvocation(node);

    TypeIdentifier returnIdent = new ExpressionTypeIdentifier(node);
    if (node.target == null){
      //Call without any prefix
      TypeIdentifier methodIdent = new ExpressionTypeIdentifier(node.methodName);
      _methodCall(methodIdent, node.argumentList.arguments, returnIdent);
    } else {
      //Called with a prefix
      //TODO (jln): This does not take library prefix into account.
      TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.target);
      foreach(targetIdent).update((AbstractType type) { 
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(type, new Name.FromIdentifier(node.methodName)); 
        _methodCall(methodIdent, node.argumentList.arguments, returnIdent);
      });
    }
  }
  
  _methodCall(TypeIdentifier method, List<Expression> argumentList, TypeIdentifier returnIdent){
    // method(arg_1,...,arg_n) : return
    List<TypeIdentifier> parameters = <TypeIdentifier>[];
    Map<Name, TypeIdentifier> namedParameters = <Name, TypeIdentifier>{};
    
    if (argumentList != null){
      for(Expression arg in argumentList){
        if (arg is NamedExpression)
          namedParameters[new Name.FromIdentifier(arg.name.label)] = new ExpressionTypeIdentifier(arg.expression);
        else
          parameters.add(new ExpressionTypeIdentifier(arg));
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
              _subsetConstraint(parameters[i], func.normalParameterTypes[i]);              
            else
              _subsetConstraint(parameters[i], func.optionalParameterTypes[i - func.normalParameterTypes.length]);
          }
          for(Name name in namedParameters.keys){
            _subsetConstraint(namedParameters[name], func.namedParameterTypes[name]);
          }
          if (returnIdent != null) _subsetConstraint(func.returnType, returnIdent);
        }
      }); 
  }
  
  visitReturnStatement(ReturnStatement node){
    super.visitReturnStatement(node);
    if (node.expression != null){
      if (!elementAnalysis.containsElement(node) && elementAnalysis.elements[node] is ReturnElement)
        engine.errors.addError(new EngineError("A ReturnStatement was visited, but didn't have a associated elemenet.", source.source, node.offset, node.length ), true);
    
      ReturnElement returnElement = elementAnalysis.elements[node];
    
      _subsetConstraint(new ExpressionTypeIdentifier(node.expression), new ReturnTypeIdentifier(returnElement.function));
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
  
}

