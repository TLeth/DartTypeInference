library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/source.dart';
import 'engine.dart';
import 'element.dart';
import 'types.dart';
import 'util.dart';
import 'generics.dart';
import 'dart:collection';
import 'restrict.dart';

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
  
  TypeVariable operator [](TypeIdentifier ident) {
    return containsKey(ident) ? _typeMap[ident] : _typeMap[ident] = new TypeVariable();
  }
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

typedef bool FilterFunc(AbstractType t);
typedef dynamic NotifyFunc(AbstractType t);
typedef Iterable<AbstractType> ExpandFunc(AbstractType t);

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
  
  void onChange(NotifyFunc func) {
    
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
  }
  
  bool remove(void func(AbstractType)){
    return _event_listeners.remove(func);
  }
  
  /**
   * Return the least upper bound of this type and the given type, or `dynamic` if there is no
   * least upper bound.
   *
   */
  AbstractType getLeastUpperBound(Engine engine) {
    return AbstractType.LeastUpperBound(_types, engine);
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
  ExpandFunc _expandFunc = null;
  GenericMapGenerator get genericMapGenerator;
  TypeMap get types;
  Engine get engine;
    
  ConstraintHelper foreach(dynamic ident) {
    _lastTypeIdentifier = TypeIdentifier.ConvertToTypeIdentifier(ident);
    return this;
  }
  
  ConstraintHelper where(FilterFunc func){
    _lastWhere = func;
    return this;
  }
  
  ConstraintHelper expand(ExpandFunc func){
    _expandFunc = func;
    return this;
  }
  
  
  bool updating = false;
  List<Function> rem = [];  
  void update(NotifyFunc func, [bool stop = false]){
    
    if (_lastTypeIdentifier != null){
      TypeIdentifier identifier = _lastTypeIdentifier;
      FilterFunc filter = _lastWhere;
      ExpandFunc expand = _expandFunc;
      
      _lastTypeIdentifier = null;
      _lastWhere = null;
      _expandFunc = null;
      
      if (expand == null){
        rem.add((){
          types[identifier].onChange((AbstractType t) {
            if (filter == null || filter(t))
               func(t);
          });                    
        });
      } else {
        rem.add((){
          types[identifier].onChange((AbstractType t) {
            expand(t).forEach((AbstractType t) {
              if (filter == null || filter(t))
                func(t);  
            });
          });
        });
      }
      
      if (!updating){
         updating = true;
         while(!rem.isEmpty){
           Function f = rem.removeLast();
           f();
         }
         updating = false;
      }
    }
  }
  
  void equalConstraint(TypeIdentifier a, TypeIdentifier b){
    subsetConstraint(a, b);
    subsetConstraint(b, a);
  }
  
  HashMap<TypeIdentifier, HashSet<TypeIdentifier>> checked = new HashMap<TypeIdentifier, HashSet<TypeIdentifier>>();
  
  void subsetConstraint(TypeIdentifier a, TypeIdentifier b, {FilterFunc filter: null, Map<ParameterType, AbstractType> binds: null}) {
    if (a == b)
      return;
    
    if (checked.containsKey(a) && checked[a].contains(b))
      return;
    
    if (!checked.containsKey(a))
      checked[a] = new HashSet();
    
    checked[a].add(b);
    
    
    // If the binds is bound, then the subset should first resolve the binding.
    Function bindFunction;
    if (binds != null && !binds.isEmpty && engine.options.iteration >= 2){
      bindFunction = (AbstractType type) {
        if (type is ParameterType){
          if (binds.containsKey(type))
            types.add(b, binds[type]);
          else
            types.add(b, type);
        } else if (type is NominalType){          
          types.add(b, genericMapGenerator.createInstanceWithBinds(type, binds));
        } else
          types.add(b, type);
      };
    } else {
      bindFunction = (AbstractType type) => types.add(b, type);
    }
    
    if (filter == null)
      foreach(a).update(bindFunction);
    else
      foreach(a).where(filter).update(bindFunction);
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
    if (namedElement is ClassElement) {
      if (engine.options.iteration >= 2)
        return new NominalType.makeInstance(namedElement, genericMapGenerator.create(namedElement, type.typeArguments, source));
      else
        return new NominalType(namedElement);
    } else if (namedElement is TypeParameterElement)
      return new ParameterType(namedElement);
    
    engine.errors.addError(new EngineError("Unable to resolve type: ${type}.", source.source, type.offset, type.length),false);
    return null;
  }
  
  
  bool returnsVoid(CallableElement node) {
    if ((node is MethodElement && node.isSetter) || (node is NamedFunctionElement && node.isSetter))
      return true;
    if (node.isExternal)
      return false;
    else if (node is MethodElement && (node.isAbstract || node.isGetter || node.isNative))
      return false;
    else if (node is NamedFunctionElement && (node.isGetter || node.isNative))
      return false;
    else if (node is FunctionParameterElement)
      return false;
    else
      return node.returns.fold(true, (bool res, ReturnElement r) => res && r.ast.expression == null);
  }
  
  // Fix to accommondate: https://github.com/dart-lang/bleeding_edge/commit/7190ce054cd4477e4c48fc0ea68a1e7fabd6c914
  TypeName _fixFutureMethodInCompleter(CallableElement node){
    if (node is MethodElement && 
       node.sourceElement.source.shortName == 'future.dart' && 
       node.sourceElement.source.uriKind == UriKind.DART_URI &&
       node.classDecl.identifier.toString() == 'Completer' && 
       node.classDecl.typeParameters.length == 1 &&
       node.identifier.toString() == 'future' && 
       node.isGetter &&
       node.returnType.name.toString() =='Future' &&
       node.returnType.typeArguments == null &&
       engine.options.iteration >= 3){
      Identifier typeName = node.returnType.name;
      Identifier typeArgument = node.classDecl.typeParameters[0].ast.name;
      TypeArgumentList typeArguments = new TypeArgumentList(new Token(TokenType.LT, typeName.end + 1), 
          [new TypeName(typeArgument, null)], new Token(TokenType.GT, typeName.end + typeArgument.length + 2));
      return new TypeName(typeName, typeArguments); 
    }
    return node.returnType;
  }
  
  TypeIdentifier typeReturn(CallableElement element, SourceElement source){
    TypeIdentifier ident = new ReturnTypeIdentifier(element);
    TypeName returnType = element.returnType;
    AbstractType type;
    
    
    types.create(ident);
    
    returnType = _fixFutureMethodInCompleter(element);
    
    type = resolveType(returnType, source);
    
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
    Map<Name, ClassMember> classMembers = node.classMembers;
    List<Name> inheritedElements = ListUtil.complement(node.classMembers.keys, node.declaredElements.keys);
    for(Name n in inheritedElements){
      ClassMember member  = node.classMembers[n];
      TypeIdentifier parentTypeIdent = new PropertyTypeIdentifier(new NominalType(member.classDecl), n);
      TypeIdentifier thisTypeIdent = new PropertyTypeIdentifier(new NominalType(node), n);
      equalConstraint(parentTypeIdent, thisTypeIdent);
    }

    node.declaredElements.values.forEach((NamedElement n) {
      if (n is MethodElement) {
        n.overrides.forEach((p) {
          if (p is MethodElement && p.isAbstract && p.ast.returnType == null) {
            TypeIdentifier parentTypeIdent = new ReturnTypeIdentifier(p);
            TypeIdentifier thisTypeIdent = new ReturnTypeIdentifier(n);
            subsetConstraint(thisTypeIdent, parentTypeIdent, filter: (e) => !(e is ParameterType));
          }
        });
      }

      if (n is FieldElement) {
        n.overrides.forEach((p) {
          if (p is FieldElement && p.varDecl.initializer == null) {
            TypeIdentifier parentTypeIdent = new PropertyTypeIdentifier(new NominalType(p.classDecl), n.name);
            TypeIdentifier thisTypeIdent   = new PropertyTypeIdentifier(new NominalType(n.classDecl), n.name);            
            subsetConstraint(thisTypeIdent, parentTypeIdent, filter: (e) => !(e is ParameterType));
          }
        });
      }
    
    });
        
    super.visitClassElement(node);
    
    node.implementElements.forEach((ClassElement implementsElement){
      implementsElement.declaredElements.forEach((Name n, NamedElement e){
        if (node.lookup(n).isEmpty){
          TypeIdentifier parentTypeIdent = new PropertyTypeIdentifier(new NominalType(implementsElement), n);
          TypeIdentifier thisTypeIdent = new PropertyTypeIdentifier(new NominalType(node), n);
          equalConstraint(parentTypeIdent, thisTypeIdent);
        }
      });
    });
    
  }
  
  visitMethodElement(MethodElement node){
    super.visitMethodElement(node); //Visit parameters
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
    
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    
    
    
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement, elementAnalysis);
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
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement, elementAnalysis);
    
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
    
    if (node.name.toString() == 'main' && node.decl.parent is CompilationUnit && paramIdents.normalParameterTypes.length == 1 && engine.options.iteration >= 2){
      ClassElement listClass = elementAnalysis.resolveClassElement(new Name("List"), constraintAnalysis.dartCore, node.sourceElement);
      ClassElement stringClass = elementAnalysis.resolveClassElement(new Name("String"), constraintAnalysis.dartCore, node.sourceElement);
      NominalType listStringType = genericMapGenerator.createInstanceWithBinds(new NominalType(listClass), {new ParameterType(listClass.typeParameters[0]): new NominalType(stringClass)});
      types.add(paramIdents.normalParameterTypes[0], listStringType);
    }
  }
  
  visitConstructorElement(ConstructorElement node){
    super.visitConstructorElement(node); //Visit parameters
    
    TypeIdentifier elementTypeIdent = new PropertyTypeIdentifier(new NominalType(node.classDecl), node.name);
        
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement, elementAnalysis);
    
    types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));
  }
  
  visitFunctionParameterElement(FunctionParameterElement node){
    super.visitFunctionParameterElement(node); //Visit parameters
    
    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.identifier);
    elementTypeIdent.functionParameterElement = node;    
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement, elementAnalysis);    
    types.add(elementTypeIdent, new FunctionType.FromIdentifiers(returnIdent, paramIdents));
  }

  
  visitFunctionElement(FunctionElement node){
    super.visitFunctionElement(node); // visit parameters

    TypeIdentifier elementTypeIdent = new ExpressionTypeIdentifier(node.ast);
    TypeIdentifier returnIdent = typeReturn(node, node.sourceElement);
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(node, node.sourceElement.library, node.sourceElement, elementAnalysis);
    
    
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
  
  bool _overrideSubsetConstraint(ClassMember element){
    if (element.sourceElement.source.uriKind != UriKind.FILE_URI)
      return false;
    if (element is FieldElement)
      return !element.isInitialized && element.classDecl.isAbstract;
    if (element is MethodElement)
      return element.isAbstract && element.classDecl.isAbstract;
    return false;
  }
  
  visitClassMember(ClassMember node){
    super.visitClassMember(node);
    TypeIdentifier memberIdent = new ExpressionTypeIdentifier(node.identifier);
    TypeIdentifier overrideIdent;
    node.overrides.forEach((ClassMember override) {
      if (_overrideSubsetConstraint(override)){
        overrideIdent = new ExpressionTypeIdentifier(override.identifier);
        subsetConstraint(memberIdent, overrideIdent);
      }
    });
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
  Restriction get restrict => engine.restrict;

  ClassElement _currentClassElement = null;
  
  static void Generate(ConstraintAnalysis constraintAnalysis) {
    constraintAnalysis.elementAnalysis.sources.values.forEach((SourceElement source) {
      UriKind kind = source.source.uriKind;
      if (kind == UriKind.FILE_URI ||
         (kind == UriKind.PACKAGE_URI && constraintAnalysis.engine.options.analyzePackages) ||
         (kind == UriKind.DART_URI && constraintAnalysis.engine.options.analyzeSDK))                  
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

      Map<ParameterType, AbstractType> genericTypeMap = null;
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
              TypeIdentifier parameter = (i < func.normalParameterTypes.length ? func.normalParameterTypes[i] : func.optionalParameterTypes[i - func.normalParameterTypes.length]);
              if (parameter.functionParameterElement != null && engine.options.iteration >= 3)
               bindFunctionParameterElement(parameter, arguments[i], genericTypeMap);
               
              subsetConstraint(arguments[i], parameter);
            }
            for(Name name in namedArguments.keys){
              subsetConstraint(namedArguments[name], func.namedParameterTypes[name]);
            }
            if (returnIdent != null) subsetConstraint(func.returnType, returnIdent, binds: genericTypeMap);
          }
        }); 
    }
  }

  bindFunctionParameterElement(TypeIdentifier parameterIdentifier, TypeIdentifier argumentIdentifier, Map<ParameterType, AbstractType> binds){
    if (parameterIdentifier.functionParameterElement == null)
      return;
    
    if (binds == null)
      return;
    
    FunctionParameterElement funcElement = parameterIdentifier.functionParameterElement;
    ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(funcElement, source.library, source, elementAnalysis);
    
    FilterFunc isParameterType = (AbstractType t) => t is ParameterType && binds.containsKey(t);
    
    foreach(argumentIdentifier)
    .where((AbstractType func) {
          return func is FunctionType && 
          MapUtil.submap(func.namedParameterTypes, paramIdents.namedParameterTypes) &&
          paramIdents.optionalParameterTypes.length >= func.optionalParameterTypes.length &&
          paramIdents.normalParameterTypes.length == func.normalParameterTypes.length; })
    .update((AbstractType func) {
        if (func is FunctionType) {
          for (var i = 0; i < paramIdents.normalParameterTypes.length;i++)
            subsetConstraint(paramIdents.normalParameterTypes[i], func.normalParameterTypes[i], filter: isParameterType, binds: binds);
            
          for (var i = 0; i < func.optionalParameterTypes.length;i++)
            subsetConstraint(paramIdents.optionalParameterTypes[i], func.optionalParameterTypes[i], filter: isParameterType, binds: binds);
          
          for(Name name in func.namedParameterTypes.keys)
            subsetConstraint(paramIdents.namedParameterTypes[name], func.namedParameterTypes[name], filter: isParameterType, binds: binds);
        }
     });
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
    ClassElement listClass = elementAnalysis.resolveClassElement(new Name("List"), constraintAnalysis.dartCore, source); 
    if (listClass == null)
      engine.errors.addError(new EngineError("A list literal was used, but could not find List in the dartCore.", source.source, n.offset, n.length ), true);
    if (engine.options.iteration >= 2)
      types.add(n, new NominalType.makeInstance(listClass, genericMapGenerator.create(listClass, n.typeArguments, source)));
    else
      types.add(n, new NominalType(listClass));
  }
  
  visitMapLiteral(MapLiteral n){
    super.visitMapLiteral(n);
    // {Map} \in [n]
    ClassElement mapClass = elementAnalysis.resolveClassElement(new Name("Map"), constraintAnalysis.dartCore, source);
    if (mapClass == null)
      engine.errors.addError(new EngineError("A map literal was used, but could not find Map in the dartCore.", source.source, n.offset, n.length ), true);
    if (engine.options.iteration >= 2)
      types.add(n, new NominalType.makeInstance(mapClass, genericMapGenerator.create(mapClass, n.typeArguments, source)));
    else
      types.add(n, new NominalType(mapClass));
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
    if (source.resolvedIdentifiers[className] is ClassElement)
      element = source.resolvedIdentifiers[className];
    else if (className is PrefixedIdentifier){
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
      
      if (classElement.declaredConstructors.isEmpty)
        //The class did not have any constructors so just make a object of the given class-type. (asserting the program is not failing)
        types.add(nodeIdent, classType);
      else {
        Name constructorName = null;
        // Unnamed constructors gets the constructorName from the class. 
        if (constructorIdentifier == null) 
          constructorName = new Name.FromIdentifier(classElement.identifier);
        else 
          constructorName = new PrefixedName.FromIdentifier(classElement.identifier, new Name.FromIdentifier(constructorIdentifier));
      
        TypeIdentifier constructorIdent = new PropertyTypeIdentifier(classType, constructorName);


        // handle as function call
        if (engine.options.iteration >= 4){
          functionCall(constructorIdent, n.argumentList.arguments, null);
          types.add(nodeIdent, classType);
        } else {
          functionCall(constructorIdent, n.argumentList.arguments, nodeIdent);
        }
      }
    } else {
      engine.errors.addError(new EngineError("Unable to find the class the instance creation: ${n}, was referencing", source.source, n.offset, n.length), false);
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
      Name property = new Name.FromIdentifier(node.methodName);
      
      TypeIdentifier targetIdent = new ExpressionTypeIdentifier(node.realTarget);
      foreach(targetIdent).expand(propertyRestrict(property)).update((AbstractType type) { 
        TypeIdentifier functionIdent = new PropertyTypeIdentifier(type, property);
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
      ParameterTypeIdentifiers paramIdents = new ParameterTypeIdentifiers.FromCallableElement(callableElement, source.library, source, elementAnalysis);
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
              subsetConstraint(func.optionalParameterTypes[i], paramIdents.optionalParameterTypes[i]);
            
            for(Name name in func.namedParameterTypes.keys)
              subsetConstraint(func.namedParameterTypes[name], paramIdents.namedParameterTypes[name]);
            
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
        TypeIdentifier returnIdent = new SyntheticTypeIdentifier(vIdent);
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
  
  visitVariableDeclarationList(VariableDeclarationList node){
    super.visitVariableDeclarationList(node);
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    for(VariableDeclaration v in node.variables){
      Element variableElement = elementAnalysis.elements[v];
      if (variableElement is NamedElement){
        subsetConstraint(new ExpressionTypeIdentifier(variableElement.identifier), nodeIdent);   
      } else {
        engine.errors.addError(new EngineError("A VariableDeclaration was not mapped to a NamedElement", source.source, v.offset, v.length), false);
      }
    }
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
    
    Name property = new Name.FromIdentifier(leftHandSide.propertyName);
    foreach(targetIdent).expand(propertyRestrict(property)).update((AbstractType alpha){
      TypeIdentifier alphapropertyIdent = new PropertyTypeIdentifier(alpha, property);
      subsetConstraint(expIdent, alphapropertyIdent);
    });
  }

  // v.prop = exp;
  // \alpha \in [v] => [exp] \subseteq [\alpha.prop]
  assignmentPrefixedIdentifier(PrefixedIdentifier leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(leftHandSide.prefix);
    
    Name property = new Name.FromIdentifier(leftHandSide.identifier);
    foreach(prefixIdent).expand(propertyRestrict(property)).update((AbstractType alpha){
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, property);
      subsetConstraint(expIdent, alphaPropertyIdent);
    });

  }
  
  // v[i] = exp;
  // \alpha \in [v] => (\beta => \gamma => void) \in [v.[]=] => [i] \subseteq [\beta] && [exp] \subseteq [\gamma]
  assignmentIndexExpression(IndexExpression leftHandSide, TypeIdentifier expIdent){
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(leftHandSide.realTarget);
    Name property = new Name("[]=");
    foreach(targetIdent).expand(propertyRestrict(property)).update((AbstractType alpha) {
      TypeIdentifier indexEqualMethodIdent = new PropertyTypeIdentifier(alpha, property);
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
    if (source.resolvedIdentifiers[n] is List)
      return;

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
  
  ExpandFunc propertyRestrict(Name property) {
    if (engine.options.iteration < 5)
      return (AbstractType type) => <AbstractType>[type];
    else
      return (AbstractType type) => restrict.restrict(type, property, source.source);
  }
  
  visitPrefixedIdentifier(PrefixedIdentifier n){
    if (source.resolvedIdentifiers[n] != null ){
      Identifier ident = source.resolvedIdentifiers[n].identifier;
      if (ident != n)
        equalConstraint(new ExpressionTypeIdentifier(ident), new ExpressionTypeIdentifier(n));
      return;
    }

    super.visitPrefixedIdentifier(n);
    
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier prefixIdent = new ExpressionTypeIdentifier(n.prefix);
    
    Name property = new Name.FromIdentifier(n.identifier);
    
    foreach(prefixIdent).expand(propertyRestrict(property)).update((AbstractType alpha) {
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, property);
      
      if (alpha is NominalType)
        subsetConstraint(alphaPropertyIdent, nodeIdent, binds: alpha.getGenericTypeMap(genericMapGenerator)); 
      else
        subsetConstraint(alphaPropertyIdent, nodeIdent);
    });
  }
  
  visitPropertyAccess(PropertyAccess n){
    super.visitPropertyAccess(n);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(n.realTarget);
    
    Name property = new Name.FromIdentifier(n.propertyName);
    foreach(targetIdent).expand(propertyRestrict(property)).update((AbstractType alpha) {
      TypeIdentifier alphaPropertyIdent = new PropertyTypeIdentifier(alpha, property);
      if (alpha is NominalType && alpha.genericMap != null)
        subsetConstraint(alphaPropertyIdent, nodeIdent, binds: alpha.getGenericTypeMap(genericMapGenerator)); 
      else
        subsetConstraint(alphaPropertyIdent, nodeIdent);
    });
  }
  
  visitIndexExpression(IndexExpression n){
    super.visitIndexExpression(n);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(n);
    TypeIdentifier targetIdent = new ExpressionTypeIdentifier(n.realTarget);
    
    Name property = new Name("[]");
        
    foreach(targetIdent).expand(propertyRestrict(property)).update((AbstractType alpha) {
      TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, property);
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
      
      Name operator = new Name.FromToken(node.operator);
      if (node.operator.type == TokenType.BANG_EQ)
        operator = new Name("==");
      
      foreach(leftIdent).expand(propertyRestrict(operator)).update((AbstractType gamma) {
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(gamma, operator);
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
      foreach(targetIdent).expand(propertyRestrict(operator)).update((AbstractType type) { 
        TypeIdentifier methodIdent = new PropertyTypeIdentifier(type, operator); 
        functionCall(methodIdent, [], nodeIdent);
      });
    }
  }
  
  /*
   * Desugaring for prefix expressions using ++ or --.
   */
  incrementDecrementPrefixExpression(PrefixExpression node){
    Name operator = null;
    if (node.operator.type == TokenType.MINUS_MINUS)
      operator = new Name('-');
    else if (node.operator.type == TokenType.PLUS_PLUS)
      operator = new Name('+');
    
    if (operator == null)
      engine.errors.addError(new EngineError("incrementDecrementPrefixExpression was called but the operator was neither MINUS_MINUS or PLUS_PLUS.", source.source, node.offset, node.length), true);
        
    TypeIdentifier vIdent = new ExpressionTypeIdentifier(node.operand);
    TypeIdentifier nodeIdent = new ExpressionTypeIdentifier(node);
    
    //Make the operation
    foreach(vIdent).expand(propertyRestrict(operator)).update((AbstractType alpha) {
      TypeIdentifier methodIdent = new PropertyTypeIdentifier(alpha, operator);
      TypeIdentifier returnIdent = new SyntheticTypeIdentifier(vIdent);
      functionCall(methodIdent, <Expression>[new IntegerLiteral(new StringToken(TokenType.INT, "1", 0), 1)], returnIdent);
      //Result of (leftHandSide op RightHandSide) should be the result of the hole node.
      subsetConstraint(returnIdent, nodeIdent);
      
      //Make the assignment from the returnIdent to the leftHandSide.
      assignmentExpression(node.operand, returnIdent);
    });
  }
}
