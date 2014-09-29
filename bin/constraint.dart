library typeanalysis.constraints;

import 'package:analyzer/src/generated/ast.dart' hide ClassMember;
import 'engine.dart';
import 'element.dart';
import 'element_typer.dart';
import 'util.dart';


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
    if (returnType != null)
      abstractReturnType = typer.resolveType(returnType, library, sourceElement);
    
    if (abstractReturnType == null) 
      abstractReturnType = new FreeType();
    
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
    StringBuffer sb = new StringBuffer();
    sb.write("(${ListUtil.join(normalParameterTypes, " -> ")}");

    if (optionalParameterTypes.length > 0)
      sb.write("[${ListUtil.join(optionalParameterTypes, " -> ")}]");

    if (namedParameterTypes.length > 0){
      sb.write("{${MapUtil.join(namedParameterTypes, " -> ")}}");
    }
    sb.write(" -> ${returnType})");
    return sb.toString();
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
    
  
  NominalType(ClassElement this.element);
 
  
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
  
  String toString() => "{${ListUtil.join(types, " + ")}}";
  
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

/************ TypeIdentifiers *********************/
abstract class TypeIdentifier {  
  static TypeIdentifier ConvertToTypeIdentifier(dynamic ident) {
    if (ident is TypeIdentifier)
      return ident;
    else if (ident is Expression)
      return new ExpressionTypeIdentifier(ident);
    return null;
  }
  
  bool get isPropertyLookup => false;
  Name get propertyIdentifierName => null;
  AbstractType get propertyIdentifierType => null;
}


class ExpressionTypeIdentifier extends TypeIdentifier {
  Expression exp;
  
  ExpressionTypeIdentifier(Expression this.exp);
  
  int get hashCode => exp.hashCode;
  
  String toString() => exp.toString(); 
  
  bool operator ==(Object other) => other is ExpressionTypeIdentifier && other.exp == exp;
}


class PropertyTypeIdentifier extends TypeIdentifier {
  AbstractType _type;
  Name _name;
  
  PropertyTypeIdentifier(AbstractType this._type, Name this._name);
  
  int get hashCode => _type.hashCode + 31 * _name.hashCode;
  
  bool operator ==(Object other) => other is PropertyTypeIdentifier && other._type == _type && other._name == _name;
  bool get isPropertyLookup => true;
  Name get propertyIdentifierName => _name;
  AbstractType get propertyIdentifierType => _type;
}

class SetterTypeIdentifier extends TypeIdentifier {
  TypeIdentifier ident;
  
  SetterTypeIdentifier(TypeIdentifier this.ident);
  
  int get hashCode => ident.hashCode * 37;
  
  bool operator ==(Object other) => other is SetterTypeIdentifier && other.ident == ident;
  bool get isPropertyLookup => ident.isPropertyLookup;
  //TODO (jln): Should this not add "=" to the name.
  Name get propertyIdentifierName => ident.propertyIdentifierName;
  AbstractType get propertyIdentifierType => ident.propertyIdentifierType;
}


/************* Type maps ********************/
class TypeMap {
  Map<TypeIdentifier, TypeVariable> _typeMap = <TypeIdentifier, TypeVariable>{};
  
  ConstraintAnalysis constraintAnalysis;
  
  TypeMap(ConstraintAnalysis this.constraintAnalysis);
  
  TypeVariable _lookup(TypeIdentifier ident){
    if (containsKey(ident))
      return _typeMap[ident];
    
    _typeMap[ident] = new TypeVariable();
    if (!ident.isPropertyLookup || !(ident.propertyIdentifierType is NominalType))
      return _typeMap[ident];
    
    NominalType type = ident.propertyIdentifierType;
    ClassMember member = type.element.lookup(ident.propertyIdentifierName);
    
    if (member != null)
      _typeMap[ident].add(constraintAnalysis.elementTyper.typeClassMember(member, type.element.sourceElement.library));
    
    return _typeMap[ident];
  }
  
  TypeVariable getter(dynamic i) {
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    return _lookup(ident);
  }
  
  TypeVariable setter(dynamic i) {
    TypeIdentifier ident = new SetterTypeIdentifier(TypeIdentifier.ConvertToTypeIdentifier(i));
    return _lookup(ident);
  }
  
  TypeVariable operator [](TypeIdentifier ident) => _typeMap[ident];
  
  Iterable<TypeIdentifier> get keys => _typeMap.keys;
  
  bool containsKey(TypeIdentifier ident) => _typeMap.containsKey(ident);
  //TypeVariable addEmpty(TypeIdentifier ident) => _typeMap[ident] = new TypeVariable();  
  
  void put(dynamic i, AbstractType t){
    TypeIdentifier ident = TypeIdentifier.ConvertToTypeIdentifier(i);
    if (!_typeMap.containsKey(ident))
      _typeMap[ident] = new TypeVariable();
    _typeMap[ident].add(t);
  }
  
  String toString() {
    [new ExpressionTypeIdentifier(null)];
    StringBuffer sb = new StringBuffer();
    
    for(Expression exp in _typeMap.keys){
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
      types.getter(identifier).notify(func, filter);
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
  
  FieldDeclaration _currentFieldDeclaration = null;
  ClassDeclaration _currentClassDeclaration = null;
  
  ConstraintGeneratorVisitor(SourceElement this.source, ConstraintAnalysis this.constraintAnalysis) {
    source.ast.accept(this);
  }
  
  Expression _normalizeIdentifiers(Expression exp){
    if (exp is SimpleIdentifier && source.resolvedIdentifiers.containsKey(exp))
      return source.resolvedIdentifiers[exp].identifier;
    else
      return exp;
  }
  
  void _equalConstraint(TypeIdentifier aGet, TypeIdentifier bGet){
    TypeIdentifier aSet = new SetterTypeIdentifier(aGet);
    TypeIdentifier bSet = new SetterTypeIdentifier(bGet);
    foreach(aGet).update((AbstractType type) => types.put(bGet, type));
    foreach(bGet).update((AbstractType type) => types.put(aGet, type));
    
    foreach(aSet).update((AbstractType type) => types.put(bSet, type));
    foreach(bSet).update((AbstractType type) => types.put(aSet, type));
  }
  
  visitIntegerLiteral(IntegerLiteral n) {
    super.visitIntegerLiteral(n);
    // {int} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement("int", constraintAnalysis.dartCore, source)));
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    super.visitDoubleLiteral(n);
    // {double} \in [n]
    types.put(n, new NominalType(elementAnalysis.resolveClassElement("double", constraintAnalysis.dartCore, source)));
  }
  
  visitInstanceCreationExpression(InstanceCreationExpression n){
    super.visitInstanceCreationExpression(n);
    // new ClassName(arg_1,..., arg_n);
    
    TypeName classType = n.constructorName.type;
    
    String className = null;
    String constructorName = null;
    if (classType.name is SimpleIdentifier){
      className = classType.name.toString();
      constructorName = className;
    } else {
      //TODO (jln): What about generics.
      //TODO (jln): Factory creations.
    }
    
    if (className != null && constructorName != null){
      // {ClassName} \in [n]
      types.put(n, new NominalType(elementAnalysis.resolveClassElement(className, source.library, source)));
            
    }
    //TODO (jln): constructor is a method call so bind arguments and return type.
  }
  
  visitFieldDeclaration(FieldDeclaration node) {
    _currentFieldDeclaration = node;
    super.visitFieldDeclaration(node);
    _currentFieldDeclaration = null;
  }
  
  visitClassDeclaration(ClassDeclaration node) {
    _currentClassDeclaration = node;
    super.visitClassDeclaration(node);
    _currentClassDeclaration = null;
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
     // var v;
     super.visitVariableDeclaration(vd);
     Expression name = vd.name;
     
     if ((name is SimpleIdentifier)){
       TypeIdentifier vGet;
       if (_currentFieldDeclaration == null) {
         //For variables
         vGet = new ExpressionTypeIdentifier(name);
       } else {
         //For fields
         ClassElement classElement = source.declaredClasses[new Name.FromIdentifier(_currentClassDeclaration.name)];
         vGet = new PropertyTypeIdentifier(new NominalType(classElement), new Name.FromIdentifier(name));
         _equalConstraint(vGet, new ExpressionTypeIdentifier(name));
       }
       TypeIdentifier vSet = new SetterTypeIdentifier(vGet);
       // \forall \alpha \in [v] => (\alpha -> void) \in [v]=
       foreach(vGet).update((AbstractType alpha) => 
           types.put(vSet, new FunctionType(<AbstractType>[alpha], new VoidType())));
    
       // \forall (\alpha -> void) \in [v]= => \alpha \in [v]
       foreach(vSet)
         .where((AbstractType func) {
         return FunctionType.FunctionMatch(func, 1, new VoidType()); })
         .update((AbstractType func){
           if (func is FunctionType)
             types.put(vGet, func.normalParameterTypes[0]);
       });
     } else {
       //TODO (jln): assigment to a non identifier on left hand side.
     }
     
     // v = exp;
     _assignmentExpression(vd.name, vd.initializer);
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    super.visitAssignmentExpression(node);
    
    // v = exp;
    _assignmentExpression(node.leftHandSide, node.rightHandSide);
    
    TypeIdentifier expGet = new ExpressionTypeIdentifier(node.rightHandSide);
    TypeIdentifier nodeGet = new ExpressionTypeIdentifier(node);
    
    // [exp] \subseteq [v = exp]
    foreach(expGet).update((AbstractType alpha) =>
        types.put(nodeGet, alpha));
  }
  
  _assignmentExpression(Expression leftHandSide, Expression rightHandSide){
    TypeIdentifier vGet = new ExpressionTypeIdentifier(leftHandSide);
    TypeIdentifier vSet = new SetterTypeIdentifier(vGet);
    TypeIdentifier expGet = new ExpressionTypeIdentifier(rightHandSide);
    
    if (leftHandSide is SimpleIdentifier || leftHandSide is PrefixedIdentifier){
      // v = exp;
      
      // \forall \alpha \in [exp] => (\alpha -> void) \in [v]=
      foreach(expGet)
        .update((AbstractType alpha) {
            types.put(vSet, new FunctionType(<AbstractType>[alpha], new VoidType()));
            
      });
    } else {
      //TODO (jln): assigment to a non identifier on left hand side (example v[i]).
    }
  }
  
  visitSimpleIdentifier(SimpleIdentifier n){
    super.visitSimpleIdentifier(n);
    SimpleIdentifier ident = _normalizeIdentifiers(n);
    
    if (ident != n){
      _equalConstraint(new ExpressionTypeIdentifier(ident), new ExpressionTypeIdentifier(n));
    }
  }
  
  visitPrefixedIdentifier(PrefixedIdentifier n){
    super.visitPrefixedIdentifier(n);
    SimpleIdentifier prefix = n.prefix;
    
    TypeIdentifier nGet = new ExpressionTypeIdentifier(n);
    TypeIdentifier nSet = new SetterTypeIdentifier(nGet);
    
    TypeIdentifier prefixGet = new ExpressionTypeIdentifier(prefix);
    
    foreach(prefixGet).update((AbstractType alpha) {
        TypeIdentifier alphaFldGet = new PropertyTypeIdentifier(alpha, new Name.FromIdentifier(n.identifier));
        _equalConstraint(nGet, alphaFldGet);
    });
  }

  visitThisExpression(ThisExpression n) {
    // this
    super.visitThisExpression(n);
    
    if (source.resolvedIdentifiers.containsKey(n)){
      NamedElement classElement = source.resolvedIdentifiers[n];
      if (classElement is ClassElement)
        types.put(n, new NominalType(classElement));
    } else {
      //TODO jln: Some times this is not bound correctly in resolvedIdentifiers.
    }
  }
  

  visitMethodInvocation(MethodInvocation node){
    super.visitMethodInvocation(node);

    TypeIdentifier returnGet = new ExpressionTypeIdentifier(node);
    
    if (node.target == null){
      //Call without any prefix
      TypeIdentifier methodGet = new ExpressionTypeIdentifier(node.methodName);
      _methodCall(methodGet, node.argumentList, returnGet);
    } else {
      TypeIdentifier targetGet = new ExpressionTypeIdentifier(node.target);
      foreach(targetGet).update((AbstractType type) { 
        TypeIdentifier methodGet = new PropertyTypeIdentifier(type, new Name.FromIdentifier(node.methodName)); 
        _methodCall(methodGet, node.argumentList, returnGet);
      });
    }
  }
  
  _methodCall(TypeIdentifier MethodGet, ArgumentList argumentList, TypeIdentifier returnGet){
    // method(arg_1,...,arg_n) : return
    List<TypeIdentifier> parameters = <TypeIdentifier>[];
    Map<Name, TypeIdentifier> namedParameters = <Name, TypeIdentifier>{};
    
    for(Expression arg in argumentList.arguments){
      if (arg is NamedExpression)
        namedParameters[new Name.FromIdentifier(arg.name.label)] = new ExpressionTypeIdentifier(arg.expression);
      else
        parameters.add(new ExpressionTypeIdentifier(arg));
    }
    
    //\forall (\gamma_1 -> ... -> \gamma_n -> \beta) \in [method] =>
    //  \gamma_i \in [arg_i] &&  \beta \in [method]
    foreach(MethodGet)
      .where((AbstractType func) => 
          func is FunctionType && 
          MapUtil.submap(namedParameters, func.namedParameterTypes) &&
          func.optionalParameterTypes.length + func.normalParameterTypes.length >= parameters.length)
      .update((AbstractType func) {
        if (func is FunctionType) {
          for (var i = 0; i < parameters.length;i++){
            if (i < func.normalParameterTypes.length)
              types.put(parameters[i], func.normalParameterTypes[i]);
            else
              types.put(parameters[i], func.optionalParameterTypes[i]);
          }
          for(Name name in namedParameters.keys){
            types.put(namedParameters[name], func.namedParameterTypes[name]);
          }
          types.put(returnGet, func.returnType);
        }
      });
    
    
    
    //TODO (jln): Problems when making the float back into the function, rules below needs to be implemented.
    // Det kan være smart at kunne linke et typeIdentifier med et funktionsparameter. 
    // Dette vil også gå fint i sync med hvordan vi opfatter union types nu.
    
    // \forall \gamm_i \in [arg_i] => \forall \beta \in [return] 
    // (\gamma_1 -> ... -> \gamma_n -> \beta) \in [method]
    
    // \forall \beta \in [return] => \forall \gamm_i \in [arg_i] 
    // (\gamma_1 -> ... -> \gamma_n -> \beta) \in [method]
 
    
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
    
    // exp1 op exp2
    TypeIdentifier leftGet = new ExpressionTypeIdentifier(be.leftOperand);
    TypeIdentifier rightGet = new ExpressionTypeIdentifier(be.rightOperand);
    TypeIdentifier nodeGet = new ExpressionTypeIdentifier(be);
    

    //  \forall \gamma \in [exp1], 
    //  \forall (\alpha -> \beta) \in [ \gamma .op ] => 
    //      \alpha \in [exp2] && \beta \in [exp1 op exp2].
    foreach(leftGet).update((AbstractType gamma) {
      TypeIdentifier gammaOpGet = new PropertyTypeIdentifier(gamma, new Name.FromToken(be.operator));
      foreach(gammaOpGet)
      .where((AbstractType func) => FunctionType.FunctionMatch(func, 1))
      .update((AbstractType func){
        if (func is FunctionType){
          types.put(rightGet, func.normalParameterTypes[0]);
          types.put(nodeGet, func.returnType);
        }            
      });
    });
  }
}

