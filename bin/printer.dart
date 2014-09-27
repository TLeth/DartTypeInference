library typeanalysis.printer;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/source.dart';
import 'constraint.dart';
import 'element.dart' as analysis;

class PrintElementVisitor extends analysis.RecursiveElementVisitor {
  int _ident = 0;
  
  visitElementAnalysis(analysis.ElementAnalysis node) {
    node.librarySources.values.forEach(visitSourceElement);
  }
  
  visitFieldElement(analysis.FieldElement node) {
    print(("-" * _ident) + node.toString());
  }
  
  visitMethodElement(analysis.MethodElement node){
    print(("-" * _ident) + node.toString());
    visitBlock(node);
  }
  
  visitConstructorElement(analysis.ConstructorElement node){
    print(("-" * _ident) + node.toString());
    visitBlock(node);
  }
  
  visitVariableElement(analysis.VariableElement node){
    print(("-" * _ident) + node.toString());
  }
  

  visitClassElement(analysis.ClassElement node) {
    print(("-" * _ident) + node.toString());
    _ident++;
    if (node.declaredMethods.values.length > 0){
      print(("-" * _ident) + "methods: ");
      node.declaredMethods.values.forEach(visitMethodElement);
    }
    if (node.declaredFields.length > 0){
      print(("-" * _ident) + "fields: ");
      node.declaredFields.values.forEach(visitFieldElement);
    }
    _ident--;
  }
  
  visitNamedFunctionElement(analysis.NamedFunctionElement node){
    print(("-" * _ident) + node.toString());
    visitFunctionElement(node);
  }
  
  visitSourceElement(analysis.SourceElement node) {
    print(("-" * _ident) + node.toString());
    _ident++;
    if (node.parts.length > 0){
      print(("-" * _ident) + "parts: ");
      node.parts.values.forEach(visitSourceElement);
    }
    if (node.imports.keys.length >0){
      print(("-" * _ident) + "imports: ");
      node.imports.keys.forEach(print);
    }
    if (node.exports.keys.length >0){
      print(("-" * _ident) + "exports: ");
      node.exports.keys.forEach(print);
    }
    
    visitBlock(node);
    _ident++;
    if (node.declaredClasses.values.length > 0){
      print(("-" * _ident) + "classes: ");
      node.declaredClasses.values.forEach(visitClassElement);
    }
    print(" ");
    _ident--;
    _ident--;
  }
  
  visitBlock(analysis.Block node){    
    _ident++;
    if (node.declaredVariables.values.length > 0){
      print(("-" * _ident) + "variables: ");
      node.declaredVariables.values.forEach(visitVariableElement);
    }
    if (node.declaredFunctions.values.length > 0){
      print(("-" * _ident) + "functions: ");
      node.declaredFunctions.values.forEach(visitFunctionElement);
    }
    _ident--;
  }
}

class PrintAstVisitor implements GeneralizingAstVisitor {
  
  visitAnnotatedNode(AnnotatedNode node) {
    print('AnnotatedNode');
    print('  ${node}');
    visitNode(node);
  }

  visitClassMember(ClassMember node) {
    print('ClassMember');
    print('  ${node}');
    visitDeclaration(node);
  }

  @override
    visitAdjacentStrings(AdjacentStrings node) {
    print('AdjacentStrings');
    print('  ${node}');
    visitStringLiteral(node);
  }

  @override
    visitAnnotation(Annotation node) {
    print('Annotation');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitArgumentList(ArgumentList node) {
    print('ArgumentList');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitAsExpression(AsExpression node) {
    print('AsExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitAssertStatement(AssertStatement node) {
    print('AssertStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitAssignmentExpression(AssignmentExpression node) {
    print('AssignmentExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitAwaitExpression(AwaitExpression node) {
    print('AwaitExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitBinaryExpression(BinaryExpression node) {
    print('BinaryExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitBlock(Block node) {
    print('Block');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitBlockFunctionBody(BlockFunctionBody node) {
    print('BlockFunctionBody');
    print('  ${node}');
    visitFunctionBody(node);
  }

  @override
    visitBooleanLiteral(BooleanLiteral node) {
    print('BooleanLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  @override
    visitBreakStatement(BreakStatement node) {
    print('BreakStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitCascadeExpression(CascadeExpression node) {
    print('CascadeExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitCatchClause(CatchClause node) {
    print('CatchClause');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitClassDeclaration(ClassDeclaration node) {
    print('ClassDeclaration');
    print('  ${node}');
    visitCompilationUnitMember(node);
  }

  @override
    visitClassTypeAlias(ClassTypeAlias node) {
    print('ClassTypeAlias');
    print('  ${node}');
    visitTypeAlias(node);
  }

  visitCombinator(Combinator node) {
    print('Combinator');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitComment(Comment node) {
    print('Comment');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitCommentReference(CommentReference node) {
    print('CommentReference');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitCompilationUnit(CompilationUnit node) {
    print('CompilationUnit');
    print('  ${node}');
    visitNode(node);
  }

  visitCompilationUnitMember(CompilationUnitMember node) {
    print('CompilationUnitMember');
    print('  ${node}');
    visitDeclaration(node);
  }

  @override
    visitConditionalExpression(ConditionalExpression node) {
    print('ConditionalExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitConstructorDeclaration(ConstructorDeclaration node) {
    print('ConstructorDeclaration');
    print('  ${node}');
    visitClassMember(node);
  }

  @override
    visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    print('ConstructorFieldInitializer');
    print('  ${node}');
    visitConstructorInitializer(node);
  }

  visitConstructorInitializer(ConstructorInitializer node) {
    print('ConstructorInitializer');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitConstructorName(ConstructorName node) {
    print('ConstructorName');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitContinueStatement(ContinueStatement node) {
    print('ContinueStatement');
    print('  ${node}');
    visitStatement(node);
  }

  visitDeclaration(Declaration node) {
    print('Declaration');
    print('  ${node}');
    visitAnnotatedNode(node);
  }

  @override
    visitDeclaredIdentifier(DeclaredIdentifier node) {
    print('DeclaredIdentifier');
    print('  ${node}');
    visitDeclaration(node);
  }

  @override
    visitDefaultFormalParameter(DefaultFormalParameter node) {
    print('DefaultFormalParameter');
    print('  ${node}');
    visitFormalParameter(node);
  }

  visitDirective(Directive node) {
    print('Directive');
    print('  ${node}');
    visitAnnotatedNode(node);
  }

  @override
    visitDoStatement(DoStatement node) {
    print('DoStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitDoubleLiteral(DoubleLiteral node) {
    print('DoubleLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  @override
    visitEmptyFunctionBody(EmptyFunctionBody node) {
    print('EmptyFunctionBody');
    print('  ${node}');
    visitFunctionBody(node);
  }

  @override
    visitEmptyStatement(EmptyStatement node) {
    print('EmptyStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    print('EnumConstantDeclaration');
    print('  ${node}');
    visitDeclaration(node);
  }

  @override
    visitEnumDeclaration(EnumDeclaration node) {
    print('EnumDeclaration');
    print('  ${node}');
    visitCompilationUnitMember(node);
  }

  @override
    visitExportDirective(ExportDirective node) {
    print('ExportDirective');
    print('  ${node}');
    visitNamespaceDirective(node);
  }

  visitExpression(Expression node) {
    print('Expression');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitExpressionFunctionBody(ExpressionFunctionBody node) {
    print('ExpressionFunctionBody');
    print('  ${node}');
    visitFunctionBody(node);
  }

  @override
    visitExpressionStatement(ExpressionStatement node) {
    print('ExpressionStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitExtendsClause(ExtendsClause node) {
    print('ExtendsClause');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitFieldDeclaration(FieldDeclaration node) {
    print('FieldDeclaration');
    print('  ${node}');
    visitClassMember(node);
  }

  @override
    visitFieldFormalParameter(FieldFormalParameter node) {
    print('FieldFormalParameter');
    print('  ${node}');
    visitNormalFormalParameter(node);
  }

  @override
    visitForEachStatement(ForEachStatement node) {
    print('ForEachStatement');
    print('  ${node}');
    visitStatement(node);
  }

  visitFormalParameter(FormalParameter node) {
    print('FormalParameter');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitFormalParameterList(FormalParameterList node) {
    print('FormalParameterList');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitForStatement(ForStatement node) {
    print('ForStatement');
    print('  ${node}');
    visitStatement(node);
  }

  visitFunctionBody(FunctionBody node) {
    print('FunctionBody');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitFunctionDeclaration(FunctionDeclaration node) {
    print('FunctionDeclaration');
    print('  ${node}');
    visitCompilationUnitMember(node);
  }

  @override
    visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    print('FunctionDeclarationStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitFunctionExpression(FunctionExpression node) {
    print('FunctionExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    print('FunctionExpressionInvocation');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitFunctionTypeAlias(FunctionTypeAlias node) {
    print('FunctionTypeAlias');
    print('  ${node}');
    visitTypeAlias(node);
  }

  @override
    visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    print('FunctionTypedFormalParameter');
    print('  ${node}');
    visitNormalFormalParameter(node);
  }

  @override
    visitHideCombinator(HideCombinator node) {
    print('HideCombinator');
    print('  ${node}');
    visitCombinator(node);
  }

  visitIdentifier(Identifier node) {
    print('Identifier');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitIfStatement(IfStatement node) {
    print('IfStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitImplementsClause(ImplementsClause node) {
    print('ImplementsClause');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitImportDirective(ImportDirective node) {
    print('ImportDirective');
    print('  ${node}');
    visitNamespaceDirective(node);
  }

  @override
    visitIndexExpression(IndexExpression node) {
    print('IndexExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitInstanceCreationExpression(InstanceCreationExpression node) {
    print('InstanceCreationExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitIntegerLiteral(IntegerLiteral node) {
    print('IntegerLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  visitInterpolationElement(InterpolationElement node) {
    print('InterpolationElement');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitInterpolationExpression(InterpolationExpression node) {
    print('InterpolationExpression');
    print('  ${node}');
    visitInterpolationElement(node);
  }

  @override
    visitInterpolationString(InterpolationString node) {
    print('InterpolationString');
    print('  ${node}');
    visitInterpolationElement(node);
  }

  @override
    visitIsExpression(IsExpression node) {
    print('IsExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitLabel(Label node) {
    print('Label');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitLabeledStatement(LabeledStatement node) {
    print('LabeledStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitLibraryDirective(LibraryDirective node) {
    print('LibraryDirective');
    print('  ${node}');
    visitDirective(node);
  }

  @override
    visitLibraryIdentifier(LibraryIdentifier node) {
    print('LibraryIdentifier');
    print('  ${node}');
    visitIdentifier(node);
  }

  @override
    visitListLiteral(ListLiteral node) {
    print('ListLiteral');
    print('  ${node}');
    visitTypedLiteral(node);
  }

  visitLiteral(Literal node) {
    print('Literal');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitMapLiteral(MapLiteral node) {
    print('MapLiteral');
    print('  ${node}');
    visitTypedLiteral(node);
  }

  @override
    visitMapLiteralEntry(MapLiteralEntry node) {
    print('MapLiteralEntry');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitMethodDeclaration(MethodDeclaration node) {
    print('MethodDeclaration');
    print('  ${node}');
    visitClassMember(node);
  }

  @override
    visitMethodInvocation(MethodInvocation node) {
    print('MethodInvocation');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitNamedExpression(NamedExpression node) {
    print('NamedExpression');
    print('  ${node}');
    visitExpression(node);
  }

  visitNamespaceDirective(NamespaceDirective node) {
    print('NamespaceDirective');
    print('  ${node}');
    visitUriBasedDirective(node);
  }

  @override
    visitNativeClause(NativeClause node) {
    print('NativeClause');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitNativeFunctionBody(NativeFunctionBody node) {
    print('NativeFunctionBody');
    print('  ${node}');
    visitFunctionBody(node);
  }

  visitNode(AstNode node) {
    node.visitChildren(this);
    return null;
  }
  visitNormalFormalParameter(NormalFormalParameter node) {
    print('Node');
    print('  ${node}');
    visitFormalParameter(node);
  }

  @override
    visitNullLiteral(NullLiteral node) {
    print('NullLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  @override
    visitParenthesizedExpression(ParenthesizedExpression node) {
    print('ParenthesizedExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitPartDirective(PartDirective node) {
    print('PartDirective');
    print('  ${node}');
    visitUriBasedDirective(node);
  }

  @override
    visitPartOfDirective(PartOfDirective node) {
    print('PartOfDirective');
    print('  ${node}');
    visitDirective(node);
  }

  @override
    visitPostfixExpression(PostfixExpression node) {
    print('PostfixExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitPrefixedIdentifier(PrefixedIdentifier node) {
    print('PrefixedIdentifier');
    print('  ${node}');
    visitIdentifier(node);
  }

  @override
    visitPrefixExpression(PrefixExpression node) {
    print('PrefixExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitPropertyAccess(PropertyAccess node) {
    print('PropertyAccess');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node) {
    print('RedirectingConstructorInvocation');
    print('  ${node}');
    visitConstructorInitializer(node);
  }

  @override
    visitRethrowExpression(RethrowExpression node) {
    print('RethrowExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitReturnStatement(ReturnStatement node) {
    print('ReturnStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitScriptTag(ScriptTag node) {
    print('ScriptTag');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitShowCombinator(ShowCombinator node) {
    print('ShowCombinator');
    print('  ${node}');
    visitCombinator(node);
  }

  @override
    visitSimpleFormalParameter(SimpleFormalParameter node) {
    print('SimpleFormalParameter');
    print('  ${node}');
    visitNormalFormalParameter(node);
  }

  @override
    visitSimpleIdentifier(SimpleIdentifier node) {
    print('SimpleIdentifier');
    print('  ${node}');
    visitIdentifier(node);
  }

  @override
    visitSimpleStringLiteral(SimpleStringLiteral node) {
    print('SimpleStringLiteral');
    print('  ${node}');
    visitStringLiteral(node);
  }

  visitStatement(Statement node) {
    print('Statement');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitStringInterpolation(StringInterpolation node) {
    print('StringInterpolation');
    print('  ${node}');
    visitStringLiteral(node);
  }

  visitStringLiteral(StringLiteral node) {
    print('StringLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  @override
    visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    print('SuperConstructorInvocation');
    print('  ${node}');
    visitConstructorInitializer(node);
  }

  @override
    visitSuperExpression(SuperExpression node) {
    print('SuperExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitSwitchCase(SwitchCase node) {
    print('SwitchCase');
    print('  ${node}');
    visitSwitchMember(node);
  }

  @override
    visitSwitchDefault(SwitchDefault node) {
    print('SwitchDefault');
    print('  ${node}');
    visitSwitchMember(node);
  }

  visitSwitchMember(SwitchMember node) {
    print('SwitchMember');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitSwitchStatement(SwitchStatement node) {
    print('SwitchStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitSymbolLiteral(SymbolLiteral node) {
    print('SymbolLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  @override
    visitThisExpression(ThisExpression node) {
    print('ThisExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitThrowExpression(ThrowExpression node) {
    print('ThrowExpression');
    print('  ${node}');
    visitExpression(node);
  }

  @override
    visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    print('TopLevelVariableDeclaration');
    print('  ${node}');
    visitCompilationUnitMember(node);
  }

  @override
    visitTryStatement(TryStatement node) {
    print('TryStatement');
    print('  ${node}');
    visitStatement(node);
  }

  visitTypeAlias(TypeAlias node) {
    print('TypeAlias');
    print('  ${node}');
    visitCompilationUnitMember(node);
  }

  @override
    visitTypeArgumentList(TypeArgumentList node) {
    print('TypeArgumentList');
    print('  ${node}');
    visitNode(node);
  }

  visitTypedLiteral(TypedLiteral node) {
    print('TypedLiteral');
    print('  ${node}');
    visitLiteral(node);
  }

  @override
    visitTypeName(TypeName node) {
    print('TypeName');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitTypeParameter(TypeParameter node) {
    print('TypeParameter');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitTypeParameterList(TypeParameterList node) {
    print('TypeParameterList');
    print('  ${node}');
    visitNode(node);
  }

  visitUriBasedDirective(UriBasedDirective node) {
    print('UriBasedDirective');
    print('  ${node}');
    visitDirective(node);
  }

  @override
    visitVariableDeclaration(VariableDeclaration node) {
    print('VariableDeclaration');
    print('  ${node}');
    visitDeclaration(node);
  }

  @override
    visitVariableDeclarationList(VariableDeclarationList node) {
    print('VariableDeclarationList');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    print('VariableDeclarationStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitWhileStatement(WhileStatement node) {
    print('WhileStatement');
    print('  ${node}');
    visitStatement(node);
  }

  @override
    visitWithClause(WithClause node) {
    print('WithClause');
    print('  ${node}');
    visitNode(node);
  }

  @override
    visitYieldStatement(YieldStatement node) {
    print('YieldStatement');
    print('  ${node}');
    visitStatement(node);
  }

}

class PrintLibraryVisitor extends analysis.RecursiveElementVisitor {
  int _ident = 0;
  
  bool scope;
  bool import;
  bool export;
  bool defined;
  
  PrintLibraryVisitor({bool this.scope: true, bool this.export: false, bool this.import: false, this.defined: false}) ;
  
  visitElementAnalysis(analysis.ElementAnalysis node) {
    node.sources.values.forEach(visitSourceElement);
  //  node.librarySources.values.forEach(visitSourceElement);
  }
  
  visitSourceElement(analysis.SourceElement node) {
    if (node.partOf == null){
      print(("-" * _ident) + node.source.toString());
      _ident++;
      if (node.library == null) print("No library exists!!!");
      else this.visitLibraryElement(node.library);
      _ident--;
    }
  }
  
  visitLibraryElement(analysis.LibraryElement node) {
    if (scope){
      print(("-" * _ident) + "Scope: ");
      _ident++;
      node.scope.forEach((analysis.Name name, e) => print(("-"*_ident) + "${name}: ${e}"));
      _ident--;
    }
    if (export) {
      print(("-" * _ident) + "Exports: ");
      _ident++; 
      node.exports.forEach((analysis.Name name, e) => print(("-"*_ident) + "${name}: ${e}"));
      _ident--;
    }
    if (import) {
      print(("-" * _ident) + "Imports: ");
      _ident++; 
      node.imports.forEach((analysis.Name name) => print(("-"*_ident) + "${name}: ${node.scope[name]}"));
      _ident--;
    }
    if (defined){
      print(("-" * _ident) + "Defined: ");
      _ident++; 
      node.defined.forEach((analysis.Name name) => print(("-"*_ident) + "${name}: ${node.scope[name]}"));
      _ident--;
    }
  }
}

class PrintConstraintVisitor extends GeneralizingAstVisitor {
  
  ConstraintAnalysis constraintAnalaysis;
  TypeMap get types => constraintAnalaysis.typeMap;
  analysis.ElementAnalysis get elementAnalysis => constraintAnalaysis.elementAnalysis;
  Source source = null;
  analysis.SourceElement sourceElement;
  
  PrintConstraintVisitor(ConstraintAnalysis this.constraintAnalaysis, [Source this.source = null]) {
    if (source == null){
      elementAnalysis.sources.values.forEach((analysis.SourceElement sourceElement){
          this.sourceElement = sourceElement;
          this.sourceElement.ast.visitChildren(this);
      });
    } else {
      this.sourceElement = elementAnalysis.sources[source];
      this.sourceElement.ast.visitChildren(this);
    }
  }

  Expression _normalizeIdentifiers(Expression exp){
    if (exp is Identifier && sourceElement.resolvedIdentifiers.containsKey(exp))
      return sourceElement.resolvedIdentifiers[exp].identifier;
    else
      return exp;
  }
  
  visitIntegerLiteral(IntegerLiteral n) {    
    // {int} \subseteq [n]
    TypeIdentifier nodeTypeIdent = new ExpressionTypeIdentifier(n);
    //print("${n} // ${types.getter(nodeTypeIdent)}, ${types.setter(nodeTypeIdent)}");
    super.visitIntegerLiteral(n);
  }
  
  visitDoubleLiteral(DoubleLiteral n) {
    // {double} \subseteq [n]
    TypeIdentifier nodeTypeIdent = new ExpressionTypeIdentifier(n);
    //print("${n} // ${types.getter(nodeTypeIdent)}, ${types.setter(nodeTypeIdent)}");
    super.visitDoubleLiteral(n);
  }
  
  visitVariableDeclaration(VariableDeclaration vd){
    // var v = exp;
    Expression name = _normalizeIdentifiers(vd.name);
    Expression initializer = _normalizeIdentifiers(vd.initializer);
    TypeIdentifier vType = new ExpressionTypeIdentifier(name);
    TypeIdentifier expTyp = new ExpressionTypeIdentifier(initializer);
    print("${vd} // ${types.getter(vType)}, ${types.setter(vType)}");
    super.visitVariableDeclaration(vd);
  }
  
  visitAssignmentExpression(AssignmentExpression node){
    // v = exp;
    Expression leftHandSide = _normalizeIdentifiers(node.leftHandSide);
    Expression rightHandSide = _normalizeIdentifiers(node.rightHandSide);
    TypeIdentifier vType = new ExpressionTypeIdentifier(leftHandSide);
    print("${node} // ${types.getter(vType)}, ${types.setter(vType)}");
    super.visitAssignmentExpression(node);
  }
  
  visitBinaryExpression(BinaryExpression be) {
    super.visitBinaryExpression(be);
  }
  
  
  
}