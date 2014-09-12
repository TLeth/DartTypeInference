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
 
  Element addExport(String name, Element element) => exports[name] = element;
  bool containsExport(String name) => exports.containsKey(name);
  
  void addImport(String name) => imports.add(name);
  bool containsImport(String name) => imports.contains(name);
  
  void addDefined(String name) => defined.add(name);
  bool containsDefined(String name) => defined.contains(name);
  
  bool containsElement(String name) => scope.containsKey(name);
  Element addElement(String name, Element element) => scope[name] = element;
  void addElements(Map<String, Element> pairs) => scope.addAll(pairs);
  void containsElements(List<String> names) => names.fold(false, (prev, name) => prev || scope.containsKey(name));
  
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
  
  static Iterable<String> filterCombinators(Iterable<String> names, NodeList<Combinator> combinators) {
    return combinators.fold(names, (Iterable<String> names, Combinator c) {
      if (c is ShowCombinator) {
        Iterable<String> namesToShow = c.shownNames.map((SimpleIdentifier name) => name.toString());
        return ListUtil.intersection(names, namesToShow);
      } else if (c is HideCombinator){
        Iterable<String> namesToHide = c.hiddenNames.map((SimpleIdentifier name) => name.toString());
        return ListUtil.complement(names, namesToHide);
      }
    });
  }
  
  static Map<String, Element> applyPrefix(Map<String, Element> import, ImportDirective directive){
    if (directive.prefix == null) 
      return import;
    
    Map<String, Element> res = <String, Element>{};
    import.forEach((String name, Element e) => res["${directive.prefix}.${name}"] = e);
    return res;
  }
  
  void _checkScopeDuplicate(String name, AstNode ast, SourceElement source){
    if (source.library.containsElement(name))
      engine.errors.addError(new EngineError("An element with name: '"+name+"' already existed in scope", source.source, ast.offset, ast.length), true);
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
      _checkScopeDuplicate(classElement.name, classElement.ast, source);
      lib.addElement(classElement.name, classElement);
      
      if (!classElement.isPrivate) 
        lib.addExport(classElement.name, classElement);
      
      lib.addDefined(classElement.name);
    }
    
    for(VariableElement varElement in source.top_variables.values) {
      _checkScopeDuplicate(varElement.name, varElement.ast, source);
      // Since variables implicitly makes getters and setters,
      // we add another setter if the element is not final (const is implicitly final). 
      lib.addElement(varElement.name, varElement);
      if (!varElement.isFinal && !varElement.isConst)
        lib.addElement(varElement.setterName, varElement);

      lib.addDefined(varElement.name);
      if (!varElement.isFinal && !varElement.isConst)
        lib.addDefined(varElement.setterName);
      
      if (!varElement.isPrivate) {
        lib.addExport(varElement.name, varElement);
        if (!varElement.isFinal && !varElement.isConst) 
          lib.addExport(varElement.setterName, varElement);
      }
    }
    
    for(FunctionElement funcElement in source.functions.values) {
      _checkScopeDuplicate(funcElement.name, funcElement.ast, source);
      lib.addElement(funcElement.name, funcElement);
      
      if (!funcElement.isPrivate) 
        lib.addExport(funcElement.name, funcElement);
      
      lib.addDefined(funcElement.name);
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
      Iterable<String> exportNames = ScopeResolver.filterCombinators(exportLibrary.exports.keys, directive.combinators);
      
      Map<String, Element> exports = MapUtil.filterKeys(exportLibrary.exports, exportNames);
      
      exports.forEach((name, element) {
        if (library.containsExport(name) && library.exports[name] != element)
          engine.errors.addError(new EngineError("Exported a element: ${element} with the same nameifier from two different origins", source.source, directive.offset, directive.length), true);
        if (!library.containsExport(name)){
          exportsChange = true;
          library.addExport(name, element);
        }
      });
    });
    
    if (exportsChange) _queue.addAll(library.depended_exports);
  }
}

/**
 * `ImportResolver` resolves the import statements.
 **/
class ImportResolver {
    Engine engine;
    ElementAnalysis analysis;
    LinkedHashSet<LibraryElement> _queue = new LinkedHashSet<LibraryElement>();
    
    ImportResolver(Engine this.engine, ElementAnalysis this.analysis) {
      analysis.sources.values.forEach((SourceElement source) {
        if (source.library == null)
          engine.errors.addError(new EngineError("A SourceElement ${source} was missing its library, this should not be possible in ExportResolver.", source.source, source.ast.offset, source.ast.length), true);
        _queue.add(source.library);
      });
      
      while(!_queue.isEmpty){
        LibraryElement library = _queue.first;
        _queue.remove(library);
        _createImportScope(library);
      }
    }
    
    void _createImportScope(LibraryElement library) {
      SourceElement source = library.source;
       
      source.imports.forEach((Source importSource, ImportDirective directive) {
        SourceElement importSourceElement = analysis.getSource(importSource);
        LibraryElement importLibrary = importSourceElement.library;
        Map<String, Element> imports;
        
        //If the library is dart core library, and it is auto generated, no directive is created, in these cases just add all keys.
        if (directive == null)
          imports = MapUtil.filterKeys(importLibrary.exports, importLibrary.exports.keys);
        else {
          Iterable<String> importNames = ScopeResolver.filterCombinators(importLibrary.exports.keys, directive.combinators);
          //Todo hidding the getter hides also the the setter.
          imports = MapUtil.filterKeys(importLibrary.exports, importNames);
          imports = ScopeResolver.applyPrefix(imports, directive);
        }
        
        imports.forEach((name, element) {
          if (!library.containsElement(name)) {
            // If the element is a function and that function is a getter and setter, extra checks is needed. 
            if (element is FunctionElement && (element.isGetter || element.isSetter)){
              // If the function is a setter and the the getter corresponding is not in the import 
              // or it comes from same sourceFile, add it to scope. And visa versa for getters.
              if ((element.isGetter && (!library.containsElement(element.setterName) || element.library_source == library.scope[element.setterName].library_source)) ||
                  (element.isSetter && (!library.containsElement(element.getterName) || element.library_source == library.scope[element.getterName].library_source))) {
                library.addImport(name);
                library.addElement(name, element);  
              }
            // if the element imported is a variable element, we need to check that the library not already contains
            // a getter or a setter hiding this variable.
            } else if (element is VariableElement){
              if (!library.containsElement(element.setterName) && !library.containsElement(element.getterName)){
                library.addImport(name);
                library.addElement(name, element);
              }
            } else {
              library.addImport(name);
              library.addElement(name, element);
            }
          } else if (!library.containsDefined(name)) {
            //If they are different, check if one of them is autohidden.
            if (library.scope[name] != element){
              if (source.implicitImportedDartCore && engine.isCore(library.scope[name].library_source)) {
                //The element currently in the scope is from the dart:core library and is imported implicit, so this is autohidden.
                library.addElement(name, element);
              } else if (source.implicitImportedDartCore && engine.isCore(element.library_source)){
                //The element we will import is from dart:core implicitly so it is autohidden.
              } else {
                //Both elements where imported but none of them was from implicit imported dart:core. So this means we have a clash.
                engine.errors.addError(new EngineError("Two elements were imported and none of them were from system libraries: ${library.scope[name]} and ${element}", source.source, directive.offset, directive.length), true);
              }
            }
          }
        });
      });
    }
}
