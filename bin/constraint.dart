library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'package:analyzer/src/generated/scanner.dart';
import 'engine.dart';
import 'element.dart';
import 'types.dart';
import 'util.dart';
import 'generics.dart';
import 'dart:collection';

class ConstraintAnalysis {
  TypeMap typeMap;
  

  LibraryElement get dartCore => elementAnalysis.dartCore;
  Engine engine;
  ElementAnalysis elementAnalysis;
  
  ConstraintAnalysis(Engine this.engine, ElementAnalysis this.elementAnalysis) { 
    typeMap = new TypeMap();
  }
}

/************* Type maps ********************/
class TypeMap {
  Map<TypeIdentifier, TypeVariable> _typeMap = <TypeIdentifier, TypeVariable>{};
  
  TypeVariable operator [](TypeIdentifier ident) => containsKey(ident) ? _typeMap[ident] : _typeMap[ident] = new TypeVariable();
  
  Iterable<TypeIdentifier> get keys => _typeMap.keys;
  
  bool containsKey(TypeIdentifier ident) => _typeMap.containsKey(ident);  
  
  void add(dynamic i, AbstractType t){
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    if (!_typeMap.containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    _typeMap[ident].add(t);
  }
  
  void create(dynamic i){
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    if (!_typeMap.containsKey(ident))
      _typeMap[ident] = new TypeVariable();
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
  AbstractType getLeastUpperBound(Engine engine) {
    if (_types.length == 0) return new DynamicType();
    Queue<AbstractType> queue = new Queue<AbstractType>.from(_types);
    AbstractType res = queue.removeFirst();
    res = queue.fold(res, (AbstractType res, AbstractType t) => res.getLeastUpperBound(t, engine));
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
  GenericMapGenerator get genericMapGenerator;
  TypeMap get types;
  
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
      types[identifier].onChange((AbstractType t) {
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
      foreach(a).update((AbstractType type) => types.add(b, type));
  }
    
  void subsetConstraintWithBind(TypeIdentifier a, TypeIdentifier b, Map<ParameterType, AbstractType> genericTypeMap){ 
    foreach(a).update((AbstractType type) {
      if (type is ParameterType){
        if (genericTypeMap.containsKey(type))
          types.add(b, genericTypeMap[type]);
        else
          types.add(b, type);
      } else if (type is NominalType){
        types.add(b, genericMapGenerator.createInstanceWithBinds(type, genericTypeMap));
      } else
        types.add(b, type);
    });
  }
}

/* 
 * `RichTypeGenerator` generated types for the structural types including the ones made on user annotations.
 * 
 */ 
class RichTypeGenerator extends RecursiveElementVisitor with ConstraintHelper {
  
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  ConstraintAnalysis constraintAnalysis;
  GenericMapGenerator get genericMapGenerator => engine.genericMapGenerator;
  Engine get engine => elementAnalysis.engine;
  TypeMap get types => constraintAnalysis.typeMap;
  
  AbstractType resolveType(TypeName type, SourceElement source){
    if (type == null || type.name.toString() == 'void' || type.name.toString() == 'dynamic')
      return null;
    
    NamedElement namedElement = source.resolvedIdentifiers[type.name];
    if (namedElement is ClassElement)
      return new NominalType.makeInstance(namedElement, genericMapGenerator.create(namedElement, type.typeArguments, source));
    if (namedElement is TypeParameterElement)
      return new ParameterType(namedElement);
    
    return null;
  }
  
  
  bool returnsVoid(CallableElement node) {
    if (node.isExternal)
      return false;
    else if (node is MethodElement && (node.isAbstract || node.isGetter))
      return false;
    else if (node is NamedFunctionElement && node.isGetter)
      return false;
    else if (node is FunctionParameterElement)
      return false;
    else
      return node.returns.fold(true, (bool res, ReturnElement r) => res && r.ast.expression == null);
  }
  
  TypeIdentifier typeReturn(CallableElement element, SourceElement source){
    TypeIdentifier ident = new ReturnTypeIdentifier(element);
    AbstractType type;
    
    types.create(ident);
    
    type = resolveType(element.returnType, source);
    if (type != null)
      types.add(ident, type);
    else if (returnsVoid(element))
      types.add(ident, new VoidType());
    
    return ident;
  }
  
  RichTypeGenerator(ConstraintAnalysis this.constraintAnalysis){
    visitElementAnalysis(elementAnalysis);
  }
  
  visitClassElement(ClassElement node){
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
    types.create(elementTypeIdent);
    types.add(elementTypeIdent, new NominalType(node));
    
    //Make inheritance
    if (node.extendsElement != null){
      Map<Name, NamedElement> classElements = node.classElements;
      List<Name> inheritedElements = ListUtil.complement(node.classElements.keys, node.declaredElements.keys);
      for(Name n in inheritedElements){
        TypeIdentifier parentTypeIdent = new PropertyTypeIdentifier(new NominalType(node.extendsElement), n);
        TypeIdentifier thisTypeIdent = new PropertyTypeIdentifier(new NominalType(node), n);
        equalConstraint(parentTypeIdent, thisTypeIdent);
      }
    }
    
    super.visitClassElement(node);
    
  }
  
  visitMethodElement(MethodElement node){
    super.visitMethodElement(node); //Visit parameters
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
    
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement);
    if (node.isGetter){
      equalConstraint(elementTypeIdent, returnIdent);
    } else if (node.isSetter){
      if (paramIdents.normalParameterTypes.length == 1)
        equalConstraint(elementTypeIdent, paramIdents.normalParameterTypes[0]);  
      else
        engine.errors.addError(new EngineError("A setter method was found, but did not have 1 parameter.", node.sourceElement.source, node.identifier.offset, node.identifier.length), true);
    } else {
      types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));  
    }    
    
    //Class members needs to be bound to the class property as well.
    if (node.isSetter)
      equalConstraint(elementTypeIdent, new PropertyTypeIdentifier(new NominalType(node.classDecl), node.getterName));
    else
      equalConstraint(elementTypeIdent, new PropertyTypeIdentifier(new NominalType(node.classDecl), node.name));
  }
  
  visitNamedFunctionElement(NamedFunctionElement node) {
    super.visitNamedFunctionElement(node); //Visit parameters
        
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
    
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement);
    
    if (node.isGetter){
      equalConstraint(elementTypeIdent, returnIdent);
    } else if (node.isSetter){
      if (paramIdents.normalParameterTypes.length == 1){
        equalConstraint(elementTypeIdent, paramIdents.normalParameterTypes[0]);  
      } else {
        engine.errors.addError(new EngineError("A function method was found, but did not have 1 parameter.", node.sourceElement.source, node.identifier.offset, node.identifier.length), true);
      }
    } else {
      types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));  
    }
  }
  
  visitConstructorElement(ConstructorElement node){
    super.visitConstructorElement(node); //Visit parameters
    
    TypeIdentifier elementTypeIdent = new PropertyTypeIdentifier(new NominalType(node.classDecl), node.name);
        
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement);
    
    types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));

    //TODO (jln): check if this is correct.
    //equalConstraint(elementTypeIdent, new PropertyTypeIdentifier(new NominalType(node.classDecl), node.name));
  }
  
  visitFunctionParameterElement(FunctionParameterElement node){
    super.visitFunctionParameterElement(node); //Visit parameters
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
        
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement);
    types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));
  }

  
  visitFunctionElement(FunctionElement node){
    super.visitFunctionElement(node); // visit parameters

    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.ast);
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement);
    
    types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));
  }
  
  visitFieldElement(FieldElement node){
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
    
    AbstractType elementType = resolveType(node.annotatedType, node.sourceElement);
    types.create(elementTypeIdent);
    
    if (elementType != null)
      types.add(elementTypeIdent, elementType);
    
    //Class members needs to be bound to the class property as well.
    equalConstraint(elementTypeIdent, new PropertyTypeIdentifier(new NominalType(node.classDecl), node.name));
  }
  
  visitParameterElement(ParameterElement node){
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
        
    AbstractType elementType = resolveType(node.annotatedType, node.sourceElement);
    types.create(elementTypeIdent);
    
    if (elementType != null)
      types.add(elementTypeIdent, elementType);
  }
  
  visitFieldParameterElement(FieldParameterElement node){
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
            
    AbstractType elementType = resolveType(node.annotatedType, node.sourceElement);
    types.create(elementTypeIdent);
    
    if (elementType != null)
      types.add(elementTypeIdent, elementType);
    
    //Binds fieldParameters to the fields.
    TypeIdentifier fieldTypeIdent = new PropertyTypeIdentifier(new NominalType(node.classElement), node.name);
    equalConstraint(elementTypeIdent, fieldTypeIdent);
  }
  
  visitVariableElement(VariableElement node){
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
            
    AbstractType elementType = resolveType(node.annotatedType, node.sourceElement);
    types.create(elementTypeIdent);
    
    if (elementType != null)
      types.add(elementTypeIdent, elementType);
  }
}


class ConstraintGenerator extends GeneralizingAstVisitor with ConstraintHelper {
  ElementAnalysis get elementAnalysis => constraintAnalysis.elementAnalysis;
  ConstraintAnalysis constraintAnalysis;
  TypeMap get types => constraintAnalysis.typeMap;
  SourceElement source;
  Engine get engine => constraintAnalysis.engine;
  GenericMapGenerator get genericMapGenerator => engine.genericMapGenerator;

  ClassElement _currentClassElement = null;
  
  static void Generate(ConstraintAnalysis constraintAnalysis) {
    constraintAnalysis.elementAnalysis.sources.values.forEach((SourceElement source) {
      new ConstraintGenerator._internal(source, constraintAnalysis);
    });
  }
  
  ConstraintGenerator._internal(SourceElement this.source, ConstraintAnalysis this.constraintAnalysis){
    source.ast.accept(this);
  }
  
  /****************************************/
  /************ Helper methods ************/
  /****************************************/
  
  AbstractType getAbstractType(Name className, LibraryElement library, SourceElement source){
    ClassElement classElement = elementAnalysis.resolveClassElement(className, library, source);
    if (classElement != null){
      return new NominalType(classElement);
    } else {
      if (className.toString() == 'dynamic')
        return new DynamicType();
      else if (className.toString() == 'void')
        return new VoidType();
      else {
        engine.errors.addError(new EngineError("getAbstractType was called and the classElement could not be found: ${className}", source.source));
        return null;
      }
    }
  }
  
  functionCall(TypeIdentifier functionIdent, List argumentList, [TypeIdentifier returnIdent = null]){
    // function(arg_1,...,arg_n) : return
    List<TypeIdentifier> arguments = <TypeIdentifier>[];
    Map<Name, TypeIdentifier> namedArguments = <Name, TypeIdentifier>{};
    
    if (argumentList != null){
      for(var arg in argumentList){
        if (arg is NamedExpression)
          namedArguments[new Name.FromIdentifier(arg.name.label)] = new ExpressionTypeIdentifier(arg.expression);
        else if (arg is Expression)
          arguments.add(new ExpressionTypeIdentifier(arg));
        else if (arg is TypeIdentifier)
          arguments.add(arg);
        else
          engine.errors.addError(new EngineError("functionCall in constraint.dart was called with a unreal argument: `${arg.runtimeType}`", source.source), true);
      }
    }
    
    if (isNumberBinaryFunctionCall(functionIdent, arguments, namedArguments, returnIdent))
      numberBinaryFunctionCall(functionIdent, arguments[0], returnIdent);
    else {

      Map<ParameterType, AbstractType> genericTypeMap = {};
      if (functionIdent is PropertyTypeIdentifier) {
        AbstractType prefixType = functionIdent.propertyIdentifierType; 
        if (prefixType is NominalType)
          genericTypeMap = prefixType.getGenericTypeMap(genericMapGenerator);
      }
      
      foreach(functionIdent)
        /*
         * Checks if the type is a function and matches the call with respect to arguments.
         */
        .where((AbstractType func) {
            return func is FunctionType && 
            MapUtil.submap(namedArguments, func.namedParameterTypes) &&
            func.optionalParameterTypes.length + func.normalParameterTypes.length >= arguments.length; })
            
        /*
         * Binds each of the arguments to the parameter.
         */          
        .update((AbstractType func) {
          if (func is FunctionType) {
            for (var i = 0; i < arguments.length;i++){
              if (i < func.normalParameterTypes.length)
                subsetConstraint(arguments[i], func.normalParameterTypes[i]);              
              else
                subsetConstraint(arguments[i], func.optionalParameterTypes[i - func.normalParameterTypes.length]);
            }
            for(Name name in namedArguments.keys){
              subsetConstraint(namedArguments[name], func.namedParameterTypes[name]);
            }
            if (returnIdent != null) subsetConstraintWithBind(func.returnType, returnIdent, genericTypeMap);
          }
        }); 
    }
  }
  

  /*
   * +, -, *, and % have special status in the Dart type checker - this is replicated here.
   * Sections 15.26 and 15.27 has more info on this.
   * This function checks if this is a special case, if not it returns false.  
   */
  bool isNumberBinaryFunctionCall(TypeIdentifier functionIdent, List<TypeIdentifier> arguments, Map<Name, TypeIdentifier> namedArguments, TypeIdentifier returnIdent){
    AbstractType intElem = getAbstractType(new Name("int"), constraintAnalysis.dartCore, source);
    var numberMethods = [TokenType.PLUS, TokenType.MINUS, TokenType.STAR, TokenType.PERCENT].map(
        (token) => new Name(token.lexeme));
    
    return functionIdent is PropertyTypeIdentifier &&
           functionIdent.propertyIdentifierType == intElem &&
           numberMethods.contains(functionIdent.propertyIdentifierName) &&
           arguments.length == 1 && returnIdent != null && namedArguments.isEmpty;
  }
  
  numberBinaryFunctionCall(TypeIdentifier functionIdent, TypeIdentifier argument, TypeIdentifier returnIdent){
    AbstractType intElem = getAbstractType(new Name("int"), constraintAnalysis.dartCore, source);
    AbstractType numElem = getAbstractType(new Name("num"), constraintAnalysis.dartCore, source);
    AbstractType doubleElem = getAbstractType(new Name("double"), constraintAnalysis.dartCore, source);
    List<AbstractType> numberTypes = [intElem, doubleElem];
    
    foreach(argument).update((AbstractType type) {
      if (numberTypes.contains(type))
        types.add(returnIdent, type);
      else
        types.add(returnIdent, numElem);
    });
  }

  /*
   * Method only keeps track of the _currentClassElement, this is needed because of this and super expressions needs to be resolved.
   */
  visitClassDeclaration(ClassDeclaration node){
    if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! ClassElement)
      engine.errors.addError(new EngineError("A ClassDeclaration was visited, but didn't have a associated ClassElement.", source.source, node.offset, node.length ), true);
    _currentClassElement = elementAnalysis.elements[node];
    super.visitClassDeclaration(node);
    _currentClassElement = null;
  }
  
  /****************************************/
  /************ Literals       ************/
  /****************************************/
  
  visitIntegerLiteral(IntegerLiteral n) {
    super.visitIntegerLiteral(n);
    // {int} \in [n]
    types.add(n, getAbstractType(new Name("int"), constraintAnalysis.dartCore, source));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    // {double} \in [n]
    types.add(n, getAbstractType(new Name("double"), constraintAnalysis.dartCore, source));
  }
  
  visitStringLiteral(StringLiteral n){
    super.visitStringLiteral(n);
    // {String} \in [n]
    types.add(n, getAbstractType(new Name("String"), constraintAnalysis.dartCore, source));    
  }
  
  visitBooleanLiteral(BooleanLiteral n){
    super.visitBooleanLiteral(n);
    // {bool} \in [n]
    types.add(n, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitSymbolLiteral(SymbolLiteral n){
    super.visitSymbolLiteral(n);
    // {Symbol} \in [n]
    types.add(n, getAbstractType(new Name("Symbol"), constraintAnalysis.dartCore, source));
  }  
  
  visitListLiteral(ListLiteral n){
    super.visitListLiteral(n);
    // {List} \in [n]
    types.add(n, getAbstractType(new Name("List"), constraintAnalysis.dartCore, source));
  }
  
  visitMapLiteral(MapLiteral n){
    super.visitMapLiteral(n);
    // {Map} \in [n]
    types.add(n, getAbstractType(new Name("Map"), constraintAnalysis.dartCore, source));
  }
  
  visitExpressionFunctionBody(ExpressionFunctionBody node){
    super.visitExpressionFunctionBody(node);
    if (!elementAnalysis.containsElement(node) && elementAnalysis.elements[node] is ReturnElement)
      engine.errors.addError(new EngineError("A ExpressionFunctionBody was visited, but didn't have a associated ReturnElement.", source.source, node.offset, node.length ), true);
    ReturnElement returnElement = elementAnalysis.elements[node];
    subsetConstraint(new ExpressionTypeIdentifier(node.expression), new ReturnTypeIdentifier(returnElement.function));
  }
  
  /****************************************/
  /************ Calls          ************/
  /****************************************/
  visitInstanceCreationExpression(InstanceCreationExpression n){
    super.visitInstanceCreationExpression(n);
    // new ClassName(arg_1,..., arg_n);
    Identifier className = n.constructorName.type.name;
    Identifier constructorIdentifier = n.constructorName.name;
    
    NamedElement element;
    if (className is PrefixedIdentifier){
      element = source.resolvedIdentifiers[className.prefix];
      if (constructorIdentifier == null)
        constructorIdentifier = className.identifier;
    } else if (className is SimpleIdentifier)
      element = source.resolvedIdentifiers[className];
    
    if (element != null && element is ClassElement){
      ClassElement classElement = element;
      //{ClassName} \in [n]
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
      
      NominalType classType = new NominalType.makeInstance(classElement, genericMapGenerator.create(classElement, n.constructorName.type.typeArguments, source));
      //The class did not have any constructors so just make a object of the given class-type. (asserting the program is not failing) 
      if (classElement.declaredConstructors.isEmpty)
        types.add(nodeIdent, classType);
      else {
        Name constructorName = null;
        // Unnamed constructors gets the constructorName from the class. 
        if (constructorIdentifier == null) 
          constructorName = new Name.FromIdentifier(classElement.identifier);
        else 
          constructorName = new PrefixedName.FromIdentifier(classElement.identifier, new Name.FromIdentifier(constructorIdentifier));
      
        TypeIdentifier constructorIdent = new PropertyTypeIdentifier(classType, constructorName);
        functionCall(constructorIdent, n.argumentList.arguments, null);
        types.add(nodeIdent, classType);
      }
    }
  }
  
  
  visitFunctionExpressionInvocation(FunctionExpressionInvocation node){
    super.visitFunctionExpressionInvocation(node);
    
    TypeIdentifier returnIdent = new ExpressionTypeIdentifier(node);
    TypeIdentifier functionIdent = new ExpressionTypeIdentifier(node.function);
    functionCall(functionIdent, node.argumentList.arguments, returnIdent);
  }

  visitMethodInvocation(MethodInvocation node){
    super.visitMethodInvocation(node);

    TypeIdentifier returnIdent = new ExpressionTypeIdentifier(node);
    /*
     * Determins the the functionIdentifier depending on the realTarget.
     * If none, this is just a normal function call.
     */
    if (node.realTarget == null){
      TypeIdentifier functionIdent = new ExpressionTypeIdentifier(node.methodName);
      functionCall(functionIdent, node.argumentList.arguments, returnIdent);
    } else {
      //TODO (jln): Does this take library prefix into account?
      TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.realTarget);
      foreach(targetIdent).update((AbstractType type) { 
        TypeIdentifier functionIdent = new PropertyTypeIdentifier(type, new Name.FromIdentifier(node.methodName));
        functionCall(functionIdent, node.argumentList.arguments, returnIdent);
      });
    }
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
  
  visitSuperConstructorInvocation(SuperConstructorInvocation node){
    super.visitSuperConstructorInvocation(node);
    if (_currentClassElement == null || _currentClassElement.extendsElement == null)
      engine.errors.addError(new EngineError("A SuperConstructorInvocation was visited, but _currentClassElement extendsElement was null.", source.source, node.offset, node.length ), true);
    
    ClassElement element = _currentClassElement.extendsElement;
    TypeIdentifier constructorIdent;
    if (!element.declaredConstructors.isEmpty){
      if (node.constructorName == null)
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), element.name);
      else
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), new PrefixedName(element.name, new Name.FromIdentifier(node.constructorName)));
      functionCall(constructorIdent, node.argumentList.arguments);
    }
  }
  
  visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node){
    super.visitRedirectingConstructorInvocation(node);
    if (_currentClassElement == null)
      engine.errors.addError(new EngineError("A RedirectingConstructorInvocation was visited, but _currentClassElement was null.", source.source, node.offset, node.length ), true);
    
    ClassElement element = _currentClassElement;
    TypeIdentifier constructorIdent;
    if (!element.declaredConstructors.isEmpty){
      if (node.constructorName == null)
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), element.name);
      else
        constructorIdent = new PropertyTypeIdentifier(new NominalType(element), new PrefixedName(element.name, new Name.FromIdentifier(node.constructorName)));
      functionCall(constructorIdent, node.argumentList.arguments);
    }
  }
  
  /*
   * When a functionTypedFormalParameter gets a abstractType, it needs to check if it matches a functionType with the same number of parameters.
   * If so bind these function parameters to the arguments and bind the return type.
   */
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node){
      super.visitFunctionTypedFormalParameter(node);
      if (!elementAnalysis.containsElement(node) || elementAnalysis.elements[node] is! CallableElement)
        engine.errors.addError(new EngineError("A FunctionTypedFormalParameter was visited, but didn't have a associated Callablelement.", source.source, node.offset, node.length ), true);
      CallableElement callableElement = elementAnalysis.elements[node];
      
      TypeIdentifier funcIdent = new ExpressionTypeIdentifier(node.identifier);
      TypeIdentifier returnIdent = new ReturnTypeIdentifier(callableElement);
      ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(callableElement, source.library, source);
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
  
  visitDefaultFormalParameter(DefaultFormalParameter node){
    super.visitDefaultFormalParameter(node);
    
    if (node.defaultValue != null)
      assignmentExpression(node.identifier, node.defaultValue);
  }
  
  
  /****************************************/
  /************ Assignments    ************/
  /****************************************/
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    
    Expression leftHandSide = node.leftHandSide;
    Expression rightHandSide = node.rightHandSide;
    
    /*
     * Determins if the assignment is a simple assignment,
     * If not the desugaring of the assignment is made
     */
    if (node.operator.type == TokenType.EQ){
      // Case: v = exp
      assignmentExpression(leftHandSide, rightHandSide);
      
      TypeIdentifier exp = new ExpressionTypeIdentifier(rightHandSide);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      
      // [exp] \subseteq [v = exp]
      subsetConstraint(exp, nodeIdent);
    } else {
      // Case: v op= exp
      /*
       * Desugaring is needed, first we find the function that is used, 
       * call it and then makes a normal assignments.
       */
      String operator = node.operator.toString();
      operator = operator.substring(0, operator.length - 1);
    
      TypeIdentifier vIdent = new ExpressionTypeIdentifier(leftHandSide);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
      foreach(vIdent).update((AbstractType alpha) {
        TypeIdentifier functionIdent = new PropertyTypeIdentifier(alpha, new Name(operator));
        TypeIdentifier returnIdent = new SyntheticTypeIdentifier(functionIdent);
        functionCall(functionIdent, <Expression>[rightHandSide], returnIdent);
      
      //Result of (leftHandSide op RightHandSide) should be the result of the hole node.
      subsetConstraint(returnIdent, nodeIdent);
      
      //Make the assignment from the returnIdent to the leftHandSide.
      assignmentExpression(leftHandSide, returnIdent);
    });
    }
  }

  visitVariableDeclaration(VariableDeclaration node){
    super.visitVariableDeclaration(node);
    /*
     * The variable is already created from the previous step,
     * so the only thing to do is make the assignment if a initial value is used.
     */
     if (node.initializer != null)
      // v = exp;
      assignmentExpression(node.name, node.initializer);
  }
  
  visitConstructorFieldInitializer(ConstructorFieldInitializer node){
    super.visitConstructorFieldInitializer(node);
    assignmentExpression(node.fieldName, node.expression);
  }
  
  // v = exp
  assignmentExpression(Expression leftHandSide, dynamic rightHandSide){
    TypeIdentifier expIdent = null;
    if (rightHandSide is Expression)
      expIdent = new ExpressionTypeIdentifier(rightHandSide);
    else if (rightHandSide is TypeIdentifier)
      expIdent = rightHandSide;
    
    if (expIdent == null)
      engine.errors.addError(new EngineError("assignmentExpression in constraint was called with a bad rightHandSide `${rightHandSide.runtimeType}`", source.source), true);
      
    if (leftHandSide is SimpleIdentifier)
      assignmentSimpleIdentifier(leftHandSide, expIdent);
    else if (leftHandSide is PrefixedIdentifier)
      assignmentPrefixedIdentifier(leftHandSide, expIdent);
    else if (leftHandSide is PropertyAccess)
      assignmentPropertyAccess(leftHandSide, expIdent);
    else if (leftHandSide is IndexExpression)
      assignmentIndexExpression(leftHandSide, expIdent);
    else 
      engine.errors.addError(new EngineError("assignmentExpression was called with a bad leftHandSide: `${leftHandSide.runtimeType}`", source.source), true);
  }
  
   // v = exp;
   // [exp] \subseteq [v]
  assignmentSimpleIdentifier(SimpleIdentifier leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier vIdent = new ExpressionTypeIdentifier(leftHandSide);
    subsetConstraint(expIdent, vIdent);
  }
  
  // v.prop = exp;
  // \alpha \in [v] => [exp] \subseteq [\alpha.prop]
  assignmentPropertyAccess(PropertyAccess leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(leftHandSide.realTarget);
    foreach(targetIdent).update((AbstractType alpha){
      TypeIdentifier alphapropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(leftHandSide.propertyName));
      subsetConstraint(expIdent, alphapropertyIdent);
    });
  }

  // v.prop = exp;
  // \alpha \in [v] => [exp] \subseteq [\alpha.prop]
  assignmentPrefixedIdentifier(PrefixedIdentifier leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(leftHandSide.prefix);
    
    foreach(prefixIdent).update((AbstractType alpha){
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(leftHandSide.identifier));
      subsetConstraint(expIdent, alphaPropertyIdent);
    });

  }
  
  // v[i] = exp;
  // \alpha \in [v] => (\beta => \gamma => void) \in [v.[]=] => [i] \subseteq [\beta] && [exp] \subseteq [\gamma]
  assignmentIndexExpression(IndexExpression leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(leftHandSide.realTarget);
    foreach(targetIdent).update((AbstractType alpha) {
      TypeIdentifier indexEqualMethodIdent = new PropertyTypeIdentifier(alpha, new Name("[]="));
      functionCall(indexEqualMethodIdent, [leftHandSide.index, expIdent], null);
    });
  }

  /********************************************/
  /************ Simple expressions ************/
  /********************************************/
  visitParenthesizedExpression(ParenthesizedExpression node){
    super.visitParenthesizedExpression(node);
    //(exp)
    // [exp] \subseteq [(exp)]
    
    TypeIdentifier expIdent = new ExpressionTypeIdentifier(node.expression);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    subsetConstraint(expIdent, nodeIdent);
  }
  
  visitSimpleIdentifier(SimpleIdentifier n){
    super.visitSimpleIdentifier(n);
    
    /*
     * Make relation between this simpleIdentifier and the simple identifier it is resolved to. 
     */
    if (source.resolvedIdentifiers.containsKey(n)){
      Identifier ident = source.resolvedIdentifiers[n].identifier;
      if (ident != n)
        /*
         * TODO (jln): A possible speedup would be changing the simpleidentifiers to the identifier used in the variable decl.
         * This can be done in a previous AST-gothrough
         */
        equalConstraint(new ExpressionTypeIdentifier(ident), new ExpressionTypeIdentifier(n));
    }
  }
  
  visitPrefixedIdentifier(PrefixedIdentifier n){
    super.visitPrefixedIdentifier(n);
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(n.prefix);
    
    //TODO (jln): Does this take library prefix into account?
    foreach(prefixIdent).update((AbstractType alpha) {
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(n.identifier));
      if (alpha is NominalType && alpha.genericMap != null)
        subsetConstraintWithBind(alphaPropertyIdent, nodeIdent, alpha.getGenericTypeMap(genericMapGenerator)); 
      else
        subsetConstraint(alphaPropertyIdent, nodeIdent);
    });
  }
  
  visitPropertyAccess(PropertyAccess n){
    super.visitPropertyAccess(n);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(n.realTarget);
    
    //TODO (jln): Does this take library prefix into account?
    foreach(targetIdent).update((AbstractType alpha) {
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(n.propertyName));
      if (alpha is NominalType && alpha.genericMap != null)
        subsetConstraintWithBind(alphaPropertyIdent, nodeIdent, alpha.getGenericTypeMap(genericMapGenerator)); 
      else
        subsetConstraint(alphaPropertyIdent, nodeIdent);
    });
  }
  
  visitIndexExpression(IndexExpression n){
    super.visitIndexExpression(n);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(n.realTarget);
        
    //TODO (jln): Does this take library prefix into account?
    foreach(targetIdent).update((AbstractType alpha) {
      TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, new Name("[]"));
      functionCall(methodIdent, <Expression>[n.index], nodeIdent);
    });
  }

  visitThisExpression(ThisExpression n) {
    // this
    super.visitThisExpression(n);
    if (_currentClassElement == null)
          engine.errors.addError(new EngineError("thisExpression was visited but the CurrentClassElement was null.", source.source, n.offset, n.length), true);
    else
      types.add(n, new NominalType(_currentClassElement));
  }
  
  visitSuperExpression(SuperExpression n){
    // super
    super.visitSuperExpression(n);
    if (_currentClassElement == null || _currentClassElement.extendsElement == null)
      engine.errors.addError(new EngineError("superExpression was visited but the parent _currentClassElement parnet was null.", source.source, n.offset, n.length), true);
    else
      types.add(n, new NominalType(_currentClassElement.extendsElement));
  }
  
  visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);
    types.add(node.condition, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }

  visitForStatement(ForStatement node) {
    super.visitForStatement(node);
    types.add(node.condition, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }

  visitDoStatement(DoStatement node) {
    super.visitDoStatement(node);
    types.add(node.condition, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitWhileStatement(WhileStatement node) {
    super.visitWhileStatement(node);
    types.add(node.condition, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }  
  
  visitPostfixExpression(PostfixExpression node){
    super.visitPostfixExpression(node);
    //The postfix is just keeping the type for the expression. 
    
    //(exp)
    // [exp] \subseteq [exp op]
    TypeIdentifier expIdent = new ExpressionTypeIdentifier(node.operand);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    subsetConstraint(expIdent, nodeIdent);
  }
  
  visitConditionalExpression(ConditionalExpression node){
    super.visitConditionalExpression(node);
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node); 
    
    // exp1 ? exp2 : exp3
    // [exp2] \union [exp3] \subseteq [exp1 ? exp2 : exp3]
    subsetConstraint(new ExpressionTypeIdentifier(node.thenExpression), nodeIdent);
    subsetConstraint(new ExpressionTypeIdentifier(node.elseExpression), nodeIdent);

    types.add(node.condition, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitIsExpression(IsExpression node){
    super.visitIsExpression(node);

    // {bool} \in [e is T]
    types.add(node, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
  }
  
  visitAsExpression(AsExpression node){
    super.visitAsExpression(node);

    AbstractType castType = getAbstractType(new Name.FromIdentifier(node.type.name), source.library, source);

    /*
     * If the cast was for dynamic, or the castType could not be resolved,
     * we just make a subset constraint. Otherwise the type is the more specific type. 
     */
    if (node.type.name.toString() == 'dynamic' || castType == null) {
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      TypeIdentifier expIdent = new ExpressionTypeIdentifier(node.expression);
      subsetConstraint(expIdent, nodeIdent);
    } else {
      // {T} \in [e as T]
      types.add(node, castType);
    }
  } 
  
  visitCascadeExpression(CascadeExpression node){
    super.visitCascadeExpression(node);
    
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.target);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    subsetConstraint(targetIdent, nodeIdent);
  }
  

  /*
   * Binary expressions in dart is in most cases handled as method calls,
   * The desugaring is made here.
   */
  visitBinaryExpression(BinaryExpression node) {
    super.visitBinaryExpression(node);
    
    if (node.operator.type == TokenType.AMPERSAND_AMPERSAND ||
        node.operator.type == TokenType.BAR_BAR)
      logicalBinaryExpression(node);
    else {
      
      /*
       * Desugaring is made
       */
      TypeIdentifier leftIdent = new ExpressionTypeIdentifier(node.leftOperand);
      TypeIdentifier rightIdent = new ExpressionTypeIdentifier(node.rightOperand);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      
      
      //  Binop handled as method call
      //  \forall \gamma \in [exp1], 
      //  \forall (\alpha -> \beta) \in [ \gamma .op ] => 
      //      \alpha \in [exp2] && \beta \in [exp1 op exp2].
      foreach(leftIdent).update((AbstractType gamma) {
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(gamma, new Name.FromToken(node.operator));
        functionCall(methodIdent, [rightIdent], nodeIdent);
      });
    }
  }
  
  /*
   * If the operator was && or ||. 
   */
  logicalBinaryExpression(BinaryExpression node){
    TypeIdentifier leftIdent = new ExpressionTypeIdentifier(node.leftOperand);
    TypeIdentifier rightIdent = new ExpressionTypeIdentifier(node.rightOperand);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    types.add(leftIdent, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
    types.add(rightIdent, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source));
    types.add(nodeIdent, getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source)); 
  }
  
  /*
   * Prefix expressions needs to be desugared
   */
  visitPrefixExpression(PrefixExpression node){
    super.visitPrefixExpression(node);
    
    if (node.operator.type == TokenType.MINUS_MINUS || node.operator.type == TokenType.PLUS_PLUS){
      incrementDecrementPrefixExpression(node);
    } else if (node.operator.type == TokenType.BANG){
      /*
       * In cases where the negate(!) operator was used, the result will be a bool for surtain. 
       */
      AbstractType bool = getAbstractType(new Name("bool"), constraintAnalysis.dartCore, source);
      types.add(node, bool);
      types.add(node.operand, bool);
    } else {
      /* 
       * In other cases the desugaring is like calling the method on the element and then assign the result into the node.
       */
      Name operator;
      if (node.operator.toString() == '-') operator = Name.UnaryMinusName();
      else operator = new Name.FromToken(node.operator);
      
      TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.operand);
      TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
      foreach(targetIdent).update((AbstractType type) { 
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(type, operator); 
        functionCall(methodIdent, [], nodeIdent);
      });
    }
  }
  
  /*
   * Desugaring for prefix expressions using ++ or --.
   */
  incrementDecrementPrefixExpression(PrefixExpression node){
    String operator = null;
    if (node.operator.type == TokenType.MINUS_MINUS)
      operator = '-';
    else if (node.operator.type == TokenType.PLUS_PLUS)
      operator = '+';
    
    if (operator == null)
      engine.errors.addError(new EngineError("incrementDecrementPrefixExpression was called but the operator was neither MINUS_MINUS or PLUS_PLUS.", source.source, node.offset, node.length), true);
        
    TypeIdentifier vIdent = new ExpressionTypeIdentifier(node.operand);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    //Make the operation
    foreach(vIdent).update((AbstractType alpha) {
      TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, new Name(operator));
      TypeIdentifier returnIdent = new SyntheticTypeIdentifier(methodIdent);
      functionCall(methodIdent, <Expression>[new IntegerLiteral(new StringToken(TokenType.INT, "1", 0), 1)], returnIdent);
      //Result of (leftHandSide op RightHandSide) should be the result of the hole node.
      subsetConstraint(returnIdent, nodeIdent);
      
      //Make the assignment from the returnIdent to the leftHandSide.
      assignmentExpression(node.operand, returnIdent);
    });
  }
}
