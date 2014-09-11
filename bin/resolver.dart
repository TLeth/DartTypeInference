library typeanalysis.resolve;

import 'dart:collection';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/source.dart';
import 'element.dart';
import 'engine.dart';
import 'util.dart';

/** The library resolution step is seperated into tree steps:
 * Resolving local scope
 * Resolving export scope
 * Resolving import scope.
 */ 

class LibraryElement {
  Map<String, Element> scope = <String, Element>{};
  Map<String, Element> exports = <String, Element>{};
  
  List<String> imports = <String>[];
  List<String> defined = <String>[];
  
  SourceElement source;
  
  //This list of library elements is all elements that is dependend on what the current library exports.
  List<LibraryElement> depended_exports = <LibraryElement>[];
  
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
  
  void addDependedExport(LibraryElement library) => depended_exports.add(library);
  bool containsDependedExport(LibraryElement library) => depended_exports.contains(library);
  
}



/**
 * `ScopeResolver` resolves the local scope.
 * */

class ScopeResolver {
  Engine engine;
  ElementAnalysis analysis;
  SourceElement source;
  
  ScopeResolver(Engine this.engine, SourceElement this.source, ElementAnalysis this.analysis) {
    if (source.library == null){
      //If the entrySource is part of some bigger library, go to the root of the library and resolve the import.
      if (source.partOf != null) {
        new ScopeResolver(engine, source.partOf, analysis); 
      } else {
        //Create a LibraryElement and let this LibraryElement
        source.library = new LibraryElement(source);
        _createScope(source);
        _makeExportLibraries(source);
        _makeImportLibraries(source);
      }
    }
  }
  
  static bool isPrivate(String ident) => Identifier.isPrivateName(ident);
  
  static Iterable<String> filterCombinators(Iterable<String> idents, NodeList<Combinator> combinators) {
    return combinators.fold(idents, (Iterable<String> idents, Combinator c) {
      if (c is ShowCombinator) {
        Iterable<String> names = c.shownNames.map((SimpleIdentifier name) => name.toString());
        return ListUtil.intersection(idents, names);
      } else if (c is HideCombinator){
        Iterable<String> names = c.hiddenNames.map((SimpleIdentifier name) => name.toString());
        return ListUtil.complement(idents, names);
      }
    });
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
  
  void _makeExportLibraries(SourceElement source){
    source.exports.forEach((Source exportSource, NamespaceDirective directive) {
      SourceElement exportSourceElement = analysis.getSource(exportSource);
      new ScopeResolver(this.engine, exportSourceElement, this.analysis);
      source.library.addDependedExport(exportSourceElement.library);
    });
  }
  
  void _makeImportLibraries(SourceElement source){
    source.imports.forEach((Source importSource, NamespaceDirective directive) {
      SourceElement importSourceElement = analysis.getSource(importSource);
      new ScopeResolver(this.engine, importSourceElement, this.analysis);
    });
  }
  
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
    }
  }
}

/** `ExportResolver` resolves the exports of each library, it is done using a queue since the dependency can be circular */ 
class ExportResolver {
  
  Engine engine;
  ElementAnalysis analysis;
  LinkedHashSet<LibraryElement> _queue = new LinkedHashSet<LibraryElement>();
  
  ExportResolver(Engine this.engine, ElementAnalysis this.analysis) {
    analysis.sources.values.forEach((SourceElement source) {
      if (source.library == null)
        engine.errors.addError(new EngineError("A SourceElement ${source} was missing its library, this should not be possible in ExportResolver.", source.source, source.ast.offset, source.ast.length), true);
      _queue.add(source.library);
    });
    
    while(!_queue.isEmpty){
      LibraryElement library = _queue.first;
      _queue.remove(library);
      _createExportScope(library);
    }
  }
  
  void _createExportScope(LibraryElement library) {
    SourceElement source = library.source;
    
    bool exportsChange = false;
    source.exports.forEach((Source exportSource, NamespaceDirective directive) {
      SourceElement exportSourceElement = analysis.getSource(exportSource);
      LibraryElement exportLibrary = exportSourceElement.library;
      Iterable<String> exportIdents = ScopeResolver.filterCombinators(exportLibrary.exports.keys, directive.combinators);
      
      Map<String, Element> exports = MapUtil.filterKeys(exportLibrary.exports, exportIdents);
      
      exports.forEach((ident, element) {
        if (source.library.containsExport(ident) && source.library.exports[ident] != element)
          engine.errors.addError(new EngineError("Exported a element: ${element} with the same identifier from two different origins", source.source, directive.offset, directive.length), true);
        if (!source.library.containsExport(ident)){
          exportsChange = true;
          source.library.addExport(ident, element);
        }
      });
    });
    
    if (exportsChange) _queue.addAll(library.depended_exports);
  }
}
/*
/**
 * `ImportResolver` resolves the import statements.
 * */
class ImportResolver {
  Engine engine;
    ElementAnalysis analysis;
    SourceElement source;
    
    ImportResolver(Engine this.engine, SourceElement this.source, ElementAnalysis this.analysis) {
      if (!source.library.importResolved){
        //If the entrySource is part of some bigger library, go to the root of the library and resolve the import.
        if (source.partOf != null) {
          new ImportResolver(engine, source.partOf, analysis);
        } else {
          //Create a LibraryElement and let this LibraryElement
          _createImport(source);
        }
      }
    }
    
    _makeExportImports(source){
      
    }
    
    void _createImport(SourceElement source) {
        _makeExportImports(source);
    }
}*/
