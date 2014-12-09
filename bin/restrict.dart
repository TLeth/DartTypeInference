library typeanalysis.restrict;

import 'engine.dart';
import 'element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'util.dart';

class UseAnalysis {

  Engine engine;
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  Map<Source, ElementRestrictionMap> restrictions = <Source, ElementRestrictionMap>{};
  
  UseAnalysis(Engine this.engine) {
    elementAnalysis.sources.forEach(_generateUseMap);
  }
  
  void _generateUseMap(Source source, SourceElement sourceElement){
    RestrictMapGenerator generator = new RestrictMapGenerator(engine, sourceElement);
    sourceElement.ast.accept(generator);
    restrictions[source] = generator.map;
  }
}

class ElementRestrictionMap {
  Map<Element, RestrictMap> map = <Element, RestrictMap>{};
  
  RestrictMap operator [](Element n) => map[n];
  operator []=(Element n, RestrictMap m) => map[n] = m;
  
  String toString() {
    if (map.isEmpty) 
      return "{}";
    String res = "{\n";
    res += MapUtil.join(map, "\n");
    res += "\n}";
    return res;
  }
}

class FieldElement extends RestrictElement {
  FieldElement(String name) : super(name);
  FieldElement.FromIdentifier(SimpleIdentifier ident) : super(ident.name);
  String toString() => name;
  
  bool operator ==(Object other) => other is FieldElement && name == other.name;
  int get hashCode => name.hashCode;
}

class MethodElement extends RestrictElement {
  MethodElement(String name) : super(name);
  MethodElement.FromIdentifier(SimpleIdentifier ident) : super(ident.name);
  String toString() => name + "()";
  
  bool operator ==(Object other) => other is MethodElement && name == other.name;
  int get hashCode => name.hashCode * 31; 
}

class RestrictElement {
  String name;
  
  RestrictElement(String this.name);
}

class RestrictMap {
  static int _printIdent = 0;
  String toString() => "?";
  
  static RestrictMap Union(RestrictMap a, RestrictMap b){
    if (a == null && b == null)
      return new RestrictMap();
    if (a == null || a is! ActualRestrictMap)
      return b;
    if (b == null || b is! ActualRestrictMap)
      return a;
    
    ActualRestrictMap aa = a as ActualRestrictMap;
    ActualRestrictMap bb = b as ActualRestrictMap;
    
    List<RestrictElement> elements = ListUtil.union(aa.map.keys, bb.map.keys);
    ActualRestrictMap res = new ActualRestrictMap();
    elements.forEach((RestrictElement el) => 
        res[el] = RestrictMap.Union(aa[el], bb[el]));
    return res;
  }
}

class ActualRestrictMap extends RestrictMap {
  Map<RestrictElement, RestrictMap> map = <RestrictElement, RestrictMap>{};
  
  RestrictMap operator [](RestrictElement n) => map[n];
  operator []=(RestrictElement n, RestrictMap m) => map[n] = m;
  
  Iterable<RestrictElement> get keys => map.keys;
  
  String toString() {
    if (map.isEmpty) 
      return "{}";
    String res = "{\n";
    RestrictMap._printIdent++;
    res += (" " * RestrictMap._printIdent);
    res += MapUtil.join(map, "\n" + (" " * RestrictMap._printIdent));
    RestrictMap._printIdent--;
    res += "\n" +(" " * RestrictMap._printIdent) + "}";
    return res;
  }
}

class RestrictMapGenerator extends GeneralizingAstVisitor {
  
  ElementRestrictionMap map = new ElementRestrictionMap();
  ActualRestrictMap currentPropertyMap = null;
  Engine engine;
  ElementAnalysis get elementAnalysis => engine.elementAnalysis;
  SourceElement currentSourceElement;
  Map<Identifier, NamedElement> get resolvedIdentifiers => currentSourceElement.resolvedIdentifiers;
  
  bool _assignmentBracket = false;
  
  RestrictMapGenerator(Engine this.engine, SourceElement this.currentSourceElement);
  
  visitPrefixedIdentifier(PrefixedIdentifier node){
    //If the identifier is written within a comment dont look into it.
    if (node.parent != null && node.parent.runtimeType.toString() == 'CommentReference'){
      currentPropertyMap = null;
      return;
    }
    
    if (resolvedIdentifiers[node] != null) {
      map[resolvedIdentifiers[node]] = currentPropertyMap;
    } else {
      ActualRestrictMap lastPropertyMap = currentPropertyMap;
      RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
      currentPropertyMap = new ActualRestrictMap();
      currentPropertyMap[new FieldElement.FromIdentifier(node.identifier)] = property;
      
      node.prefix.accept(this);
      
      currentPropertyMap = lastPropertyMap;
    }
  }
  
  visitSimpleIdentifier(SimpleIdentifier node){
    if (currentPropertyMap == null)
      return;
    
    //If the identifier is written within a label, dont look into it.
    if (node.parent != null && node.parent.runtimeType.toString() == 'Label'){
      currentPropertyMap = null;
      return;
    }
    
    if (resolvedIdentifiers[node] == null){
      engine.errors.addError(new EngineError("The identifier: ${node} could not be resolved in the restrict pre-fase.", currentSourceElement.source, node.offset, node.length));
    }
    
    map[resolvedIdentifiers[node]] = RestrictMap.Union(map[resolvedIdentifiers[node]], currentPropertyMap);
    currentPropertyMap = null;
    
    super.visitSimpleIdentifier(node);
  }
  
  visitMethodInvocation(MethodInvocation node){
    if (node.realTarget == null){
      if (currentPropertyMap == null)
        return;
      
      if (resolvedIdentifiers[node.methodName] == null)
        engine.errors.addError(new EngineError("The identifier: ${node.methodName} could not be resolved in the restrict pre-fase.", currentSourceElement.source, node.methodName.offset, node.methodName.length));
      
      map[resolvedIdentifiers[node.methodName]] = RestrictMap.Union(map[resolvedIdentifiers[node.methodName]], currentPropertyMap);
      currentPropertyMap = null;
    } else {
      if (resolvedIdentifiers[node.methodName] != null){
        map[resolvedIdentifiers[node.methodName]] = RestrictMap.Union(map[resolvedIdentifiers[node.methodName]], currentPropertyMap);
        currentPropertyMap = null;
      } else {
        ActualRestrictMap lastPropertyMap = currentPropertyMap;
        RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
        currentPropertyMap = new ActualRestrictMap();
        currentPropertyMap[new MethodElement.FromIdentifier(node.methodName)] = property;
        node.realTarget.accept(this);
        currentPropertyMap = lastPropertyMap;
      }
    }
  }
  
  visitIsExpression(IsExpression node){
    node.expression.accept(this);
  }
  
  visitAsExpression(AsExpression node){
    node.expression.accept(this);
  }
  
  visitInstanceCreationExpression(InstanceCreationExpression node){
    currentPropertyMap = null;
    return null;
  }
  
  visitFunctionExpression(FunctionExpression node){
    if (elementAnalysis.elements[node] != null)
      map[elementAnalysis.elements[node]] = RestrictMap.Union(map[elementAnalysis.elements[node]], currentPropertyMap);
    currentPropertyMap = null;
    super.visitFunctionExpression(node);
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    bool prevAssignmentBracket = _assignmentBracket;
    if (node.leftHandSide is IndexExpression)
      _assignmentBracket = true;
    node.leftHandSide.accept(this);
    _assignmentBracket = prevAssignmentBracket;
  }
  
  visitPropertyAccess(PropertyAccess node) {
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
    
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    currentPropertyMap[new FieldElement.FromIdentifier(node.propertyName)] = property;
    node.realTarget.accept(this);
    currentPropertyMap = lastPropertyMap;
  }
  
  visitBinaryExpression(BinaryExpression node){
    //<, >, <=, >=, ==, -, +, /, /, *, %, |, ˆ, &, <<, >>
    
    List<TokenType> overriableOperators = [TokenType.LT, TokenType.GT, TokenType.LT_EQ, TokenType.GT_EQ, 
                                           TokenType.EQ_EQ, TokenType.MINUS, TokenType.PLUS, TokenType.SLASH, 
                                           TokenType.TILDE_SLASH, TokenType.STAR, TokenType.PERCENT, TokenType.BAR, 
                                           TokenType.CARET, TokenType.AMPERSAND, TokenType.LT_LT, TokenType.GT_GT];
    if (!overriableOperators.contains(node.operator.type)){
      currentPropertyMap = null;
      return;
    }
    
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
        
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    currentPropertyMap[new MethodElement(node.operator.type.lexeme)] = property;
    node.leftOperand.accept(this);
    currentPropertyMap = lastPropertyMap;
  }
  
  visitPostfixExpression(PostfixExpression node){
    List<TokenType> overriableOperators = [TokenType.PLUS_PLUS, TokenType.MINUS_MINUS];
    if (!overriableOperators.contains(node.operator.type)){
      currentPropertyMap = null;
      return;
    }
    
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
            
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    currentPropertyMap[new MethodElement(node.operator.type.lexeme[0])] = property;
    node.operand.accept(this);
    currentPropertyMap = lastPropertyMap;
    
  }
  
  visitPrefixExpression(PrefixExpression node){
    List<TokenType> overriableOperators = [TokenType.PLUS_PLUS, TokenType.MINUS_MINUS];
    if (!overriableOperators.contains(node.operator.type)){
      currentPropertyMap = null;
      return;
    }
    
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
    
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    currentPropertyMap[new MethodElement(node.operator.type.lexeme[0])] = property;
    node.operand.accept(this);
    currentPropertyMap = lastPropertyMap;
  }
  
  visitLiteral(Literal node){
    currentPropertyMap = null;
    return;
  }
  
  
  visitIndexExpression(IndexExpression node){
    ActualRestrictMap lastPropertyMap = currentPropertyMap;
    RestrictMap property = lastPropertyMap == null ? new RestrictMap() : lastPropertyMap;
    currentPropertyMap = new ActualRestrictMap();
    if (_assignmentBracket){
      currentPropertyMap[new MethodElement("[]=")] = property;
    } else {
      currentPropertyMap[new MethodElement("[]")] = property;
    }
    _assignmentBracket = false;
    node.realTarget.accept(this);
    currentPropertyMap = lastPropertyMap; 
  }
}