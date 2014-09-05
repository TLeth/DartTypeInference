import 'package:analyzer/src/generated/ast.dart';
import 'element.dart';


class VariableVisitor extends GeneralizingAstVisitor {

  Map<String, VariableElement> scope = {};

  resolveVariables(ElementAnalysis analysis) {
    var result = {};
    analysis.forEach((k, v) => result.add(k, v));
    
  }

  @override
    visitSimpleIdentifier(SimpleIdentifier node) {
    print('${node.toString()} -> ${scope[node.toString()]}');
    visitIdentifier(node);
  }

  @override
    visitPrefixedIdentifier(PrefixedIdentifier node) {
    visitIdentifier(node);
  }
    
  @override
    visitVariableDeclaration(VariableDeclaration node) {
    scope[node.name.toString()] = 123;
    visitDeclaration(node);
  }

  @override
    visitVariableDeclarationList(VariableDeclarationList node) {
    visitNode(node);
  }

  @override
    visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    visitStatement(node);
  }

}