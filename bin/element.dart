import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';

class ElementAnalysis {
  Map<Source, SourceElement> sources = <Source, SourceElement>{};
}

class SourceElement {
  List<Source> imports = <Source>[];
  List<ClassElement> classes = <ClassElement>[];
  List<FunctionElement> functions = <FunctionElement>[];
  List<VariableElement> top_variables = <VariableElement>[];
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