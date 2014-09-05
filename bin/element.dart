import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';

class ElementAnalysis {
  Map<Source, SourceElement> sources = <Source, SourceElement>{};
}

class Element {}
class Block {
  Map<SimpleIdentifier, Element> scope = <SimpleIdentifier, Element>{};
  
  /*
  VariableElement lookupVariableElement(SimpleIdentifier ident) => 
      variables.firstWhere((VariableElement v) => v.doesReference(ident)); 

 */
}


class SourceElement extends Block {
  List<Source> imports = <Source>[];
  List<ClassElement> classes = <ClassElement>[];
  List<FunctionElement> functions = <FunctionElement>[];
  List<VariableElement> top_variables = <VariableElement>[];
}

class ClassElement implements Element{
  List<FieldElement> fields = <FieldElement>[];
  List<MethodElement> methods = <MethodElement>[];
}

class VariableElement implements Element {
  List<SimpleIdentifier> references = <SimpleIdentifier>[];
  Block parent_block;
  
  bool doesReference(SimpleIdentifier ident) => references.contains(ident);
}


class ClassMember {
  ClassElement classDecl;
  ClassMember (ClassElement this.classDecl);
}

class FieldElement extends ClassMember {
  FieldElement(ClassElement classDecl):super(classDecl);
  List<Identifier> references = <Identifier>[];
  bool doesReference(Identifier ident) => references.contains(ident);
}


class MethodElement extends ClassMember with Block implements Element {
  MethodElement(ClassElement classDecl):super(classDecl); 
}

class FunctionElement extends Block implements Element { }