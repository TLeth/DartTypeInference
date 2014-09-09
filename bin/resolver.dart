library typeanalysis.resolve;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/source.dart';
import 'element.dart';
import 'engine.dart';




class LibraryElement {
  Map<String, Element> scope = <String, Element>{};
  Map<String, Element> exports = <String, Element>{};
  
  List<String> imports = <String>[];
  List<String> defined = <String>[];
  
  SourceElement source;
  
  bool importResolved = false;
  
  LibraryElement(SourceElement this.source);
 
  Element addExport(String ident, Element element) => exports[ident] = element;
  bool containsExport(String ident) => exports.containsKey(ident);
  
  void addImport(String ident) => imports.add(ident);
  bool containsImport(String ident) => imports.contains(ident);
  
  void addDefined(String ident) => defined.add(ident);
  bool containsDefined(String ident) => defined.contains(ident);
  
  bool containsElement(String ident) => scope.containsKey(ident);
  Element addElement(String ident, Element element) => scope[ident] = element;
  void addElements(Map<String, Element> pairs) => scope.addAll(pairs);
  void containsElements(List<String> idents) => idents.fold(false, (prev, ident) => prev || scope.containsKey(ident));
}


/**
 * `ScopeAndExportResolver` resolves the scope and export statements first.
 *  This is done since imports is depended on exports but exports is not depended on imports.
 * */
class ScopeAndExportResolver {
  
  Engine engine;
  ElementAnalysis analysis;
  SourceElement source;
  
  ScopeAndExportResolver(Engine this.engine, SourceElement this.source, ElementAnalysis this.analysis) {
    if (source.library == null){
      //If the entrySource is part of some bigger library, go to the root of the library and resolve the import.
      if (source.partOf != null) {
        new ScopeAndExportResolver(engine, source.partOf, analysis);
      } else {
        //Create a LibraryElement and let this LibraryElement
        source.library = new LibraryElement(source);
        _createScope(source);
      }
    }
  }
  
  void _checkScopeDuplicate(String ident, AstNode ast, SourceElement source){
    if (source.library.containsElement(ident))
      
      engine.errors.addError(new EngineError("An element with name: '"+ident+"' already existed in scope", source.source, ast.offset, ast.length), true);
  }
  
  void _setLibraryOnPartOf(SourceElement source){
    source.parts.values.forEach((SourceElement partSource) {
      partSource.library = source.library;
      _createScope(partSource);
    });
  }
  
  List<String> _filterCombinators(List<String> idents, List<Combinator> combinators) {
    return idents;
  }
  
  void _makeExportLibraries(SourceElement source){
    source.exports.forEach((Source exportSource, NamespaceDirective directive) {
      SourceElement exportSourceElement = analysis.getSource(exportSource);
      new ScopeAndExportResolver(this.engine, exportSourceElement, this.analysis);
    });
  }
  
  void _makeImportLibraries(SourceElement source){
    source.imports.forEach((Source importSource, NamespaceDirective directive) {
      SourceElement importSourceElement = analysis.getSource(importSource);
      new ScopeAndExportResolver(this.engine, importSourceElement, this.analysis);
    });
  }
  
  void _createExportScope(SourceElement source) {
    source.exports.forEach((Source exportSource, NamespaceDirective directive) {
      SourceElement exportSourceElement = analysis.getSource(exportSource);
      LibraryElement exportLibrary = exportSourceElement.library;
      List<String> exportIdents = _filterCombinators(exportLibrary.exports.keys, directive.combinators);
      //print(directive.combinators);
      //SourceElement exportSourceElement = analysis.getSource(exportSource);
    });
  }
  
  static bool isPrivate(String ident) => Identifier.isPrivateName(ident);
  
  void _createScope(SourceElement source) {
    LibraryElement lib = source.library;
    
    for(ClassElement classElement in source.classes) {
      _checkScopeDuplicate(classElement.ident, classElement.ast, source);
      lib.addElement(classElement.ident, classElement);
      
      if (!isPrivate(classElement.ident)) 
        lib.addExport(classElement.ident, classElement);
      
      lib.addDefined(classElement.ident);
    }
    
    for(VariableElement varElement in source.top_variables.values) {
      _checkScopeDuplicate(varElement.ident, varElement.ast, source);
      lib.addElement(varElement.ident, varElement);
      
      if (!isPrivate(varElement.ident)) 
        lib.addExport(varElement.ident, varElement);

      lib.addDefined(varElement.ident);
    }
    
    for(FunctionElement funcElement in source.functions.values) {
      _checkScopeDuplicate(funcElement.ident, funcElement.ast, source);
      lib.addElement(funcElement.ident, funcElement);
      
      if (!isPrivate(funcElement.ident)) 
        lib.addExport(funcElement.ident, funcElement);
      
      lib.addDefined(funcElement.ident);
    }
    
    //Since part of elements cannot have any other directives we only do this if they dont have a partOf. 
    if (source.partOf == null) {
      _setLibraryOnPartOf(source);
      _makeExportLibraries(source);
      _makeImportLibraries(source);
      _createExportScope(source);
    }
  }
}