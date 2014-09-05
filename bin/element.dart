import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'engine.dart';

class ElementAnalysis {
  Map<Source, SourceElement> sources = <Source, SourceElement>{};
  
  bool containsSource(Source source) => sources.containsKey(source);
  SourceElement addSource(Source source, SourceElement element) => sources[source] = element;
  SourceElement getSource(Source source) => sources[source];
}

class SourceElement {
  Source source;
  CompilationUnit ast;
  List<Source> imports = <Source>[];
  List<ClassElement> classes = <ClassElement>[];
  List<FunctionElement> functions = <FunctionElement>[];
  List<VariableElement> top_variables = <VariableElement>[];
  
  SourceElement(Source this.source, CompilationUnit ast);
  
}

class ClassElement {
  List<FieldElement> fields = <FieldElement>[];
  List<MethodElement> methods = <MethodElement>[];
}

class VariableElement {
  List<SimpleIdentifier> references = <SimpleIdentifier>[];
  Block parent_block;
  
  bool doesReference(SimpleIdentifier ident) => references.contains(ident);
}

class FieldElement {
  List<Identifier> references = <Identifier>[];
  
  bool doesReference(Identifier ident) => references.contains(ident);
}

class Block {
  
}

class MethodElement implements Block {
  
  ClassElement parent_class;
  
  MethodElement(ClassElement this.parent_class);
}

class FunctionElement implements Block {
  List<VariableElement> variables = <VariableElement>[];
  
  VariableElement lookupVariableElement(SimpleIdentifier ident) => 
      variables.firstWhere((VariableElement v) => v.doesReference(ident));
}

class ElementGenerator extends GeneralizingAstVisitor {
  
  SourceElement element;
  Source source;
  ElementAnalysis analysis;
  Engine engine;
  
  ElementGenerator(Engine this.engine, Source this.source, ElementAnalysis this.analysis) {
    if (!analysis.containsSource(source)) {
      CompilationUnit unit = engine.getCompilationUnit(source); 
      element = new SourceElement(source, unit);
      this.visitCompilationUnit(unit);
    } else {
      element = analysis.getSource(source);
    }
  }
  
  visitImportDirective(ImportDirective node) {
    
  }
}