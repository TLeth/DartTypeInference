library typeanalysis.resolve;

import 'dart:collection';
import 'package:analyzer/src/generated/ast.dart' hide Block;
import 'package:analyzer/src/generated/source.dart';
import 'element.dart';
import 'engine.dart';
import 'util.dart';
/** The library resolution step is seperated into tree steps:
 * Resolving local scope
 * Resolving export scope
 * Resolving import scope.
 * Resolving identifier scope.
 */ 


//TODO (tlj): private names should be shared within a library element
class LibraryElement {
  Map<Name, List<NamedElement>> scope = <Name, List<NamedElement>>{};
  Map<Name, NamedElement> exports = <Name, NamedElement>{};
  
  List<Name> imports = <Name>[];
  List<Name> defined = <Name>[];
  
  SourceElement source;
  Engine engine;
  
  //This list of library elements is all elements that is dependend on what the current library exports.
  List<LibraryElement> depended_exports = <LibraryElement>[];
  
  LibraryElement(SourceElement this.source, Engine this.engine);
 
  NamedElement addExport(Name name, NamedElement element) => exports[name] = element;
  bool containsExport(Name name) => exports.containsKey(name);
  
  void addImport(Name name) => imports.add(name);
  bool containsImport(Name name) => imports.contains(name);
  
  void addDefined(Name name) => defined.add(name);
  bool containsDefined(Name name) => defined.contains(name);
  
  bool containsElement(Name name) => scope.containsKey(name);
  void addElement(Name name, NamedElement element) { scope.containsKey(name) ? scope[name].add(element) : scope[name] = <NamedElement>[element]; }
  void addElements(Name name, List<NamedElement> elements) => elements.forEach((NamedElement e) => addElement(name,e));
  void addElementMap(Map<Name, NamedElement> pairs) => scope.forEach(addElements);
  void containsElements(List<Name> names) => names.fold(false, (prev, name) => prev || scope.containsKey(name));
  
  void addDependedExport(LibraryElement library) => depended_exports.add(library);
  bool containsDependedExport(LibraryElement library) => depended_exports.contains(library);
  
  //Lookup method used for making proper lookup in the scope.
  NamedElement lookup(Name name, [bool noFatalError = true]) {
    if (!scope.containsKey(name)){
      if (noFatalError) engine.errors.addError(new EngineError("An element with name: '${name}' didn't exists in the scope", source.source), true);
      return null;
    }
    
    if (scope[name].length > 1){
      if (noFatalError) engine.errors.addError(new EngineError("Multiple elements with name: '${name}' existed in scope", source.source), true);
      return null;
    }
    
    NamedElement element = scope[name][0];
    if (element is NamedFunctionElement && (element.isGetter || element.isSetter)){
      if ((element.isGetter && (!containsElement(element.setterName) || 
                               (scope[element.setterName].length == 1 && scope[element.setterName][0].librarySource == element.librarySource))) ||
          (element.isSetter && (!containsElement(element.getterName) || 
                               (scope[element.getterName].length == 1 && scope[element.getterName][0].librarySource == element.librarySource)))) {
        return element;
      } else {
        if (noFatalError) engine.errors.addError(new EngineError("The element: '${name}' did exist but its coresponding getter/setter was from another library.", source.source), true);
        return null;
      }
    } else if (element is VariableElement) {
      if (scope.containsKey(element.name) && scope[element.name].length == 1 && scope.containsKey(Name.SetterName(element.name)) && scope[Name.SetterName(element.name)].length == 1){
        return element;
      } else {
        if (noFatalError) engine.errors.addError(new EngineError("The variable element: '${name}' did exist but the coresponding getter/setter was not unique represented.", source.source), true);
        return null;
      }
    }else {
      return element;
    }
  }
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
        source.library = new LibraryElement(source, engine);
        _createScope(source);
        _makeExportLibraries(source);
        _makeImportLibraries(source);
      }
    }
  }
  
  static Iterable<Name> filterCombinators(Iterable<Name> names, NodeList<Combinator> combinators) {
    return combinators.fold(names, (Iterable<Name> names, Combinator c) {
      if (c is ShowCombinator) {
        Iterable<Name> namesToShow = c.shownNames.map((SimpleIdentifier name) => new Name.FromIdentifier(name));
        return ListUtil.intersection(names, namesToShow);
      } else if (c is HideCombinator){
        Iterable<Name> namesToHide = c.hiddenNames.map((SimpleIdentifier name) => new Name.FromIdentifier(name));
        return ListUtil.complement(names, namesToHide);
      }
    });
  }
  
  static Map<Name, Element> applyPrefix(Map<Name, Element> import, ImportDirective directive){
    if (directive.prefix == null) 
      return import;
    
    Map<Name, Element> res = <Name, Element>{};
    import.forEach((Name name, Element e) => res[new PrefixedName.FromIdentifier(directive.prefix, name)] = e);
    return res;
  }
  
  void _checkScopeDuplicate(Name name, AstNode ast, SourceElement source){
    if (source.library.containsElement(name))
      engine.errors.addError(new EngineError("An element with name: '${name}' already existed in scope", source.source, ast.offset, ast.length), true);
  }
  
  void _setLibraryOnPartOf(SourceElement source){
    source.parts.values.forEach((SourceElement partSource) {
      partSource.library = source.library;
      _createScope(partSource);
    });
  }
  
  void _makeExportLibraries(SourceElement source){
    source.exports.forEach((NamespaceDirective directive, Source exportSource) {
      SourceElement exportSourceElement = analysis.getSource(exportSource);
      new ScopeResolver(this.engine, exportSourceElement, this.analysis);
      source.library.addDependedExport(exportSourceElement.library);
    });
  }
  
  void _makeImportLibraries(SourceElement source){
    source.imports.forEach((NamespaceDirective directive, Source importSource) {
      SourceElement importSourceElement = analysis.getSource(importSource);
      new ScopeResolver(this.engine, importSourceElement, this.analysis);
    });
  }
  
  void _createScope(SourceElement source) {
    LibraryElement lib = source.library;
    
    for(ClassElement classElement in source.declaredClasses.values) {
      _checkScopeDuplicate(classElement.name, classElement.ast, source);
      lib.addElement(classElement.name, classElement);
      
      if (!classElement.isPrivate) 
        lib.addExport(classElement.name, classElement);
      
      lib.addDefined(classElement.name);
    }
    
    for(VariableElement varElement in source.declaredVariables.values) {
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
    
    for(NamedFunctionElement funcElement in source.declaredFunctions.values) {
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
    source.exports.forEach((NamespaceDirective directive, Source exportSource) {
      SourceElement exportSourceElement = analysis.getSource(exportSource);
      LibraryElement exportLibrary = exportSourceElement.library;
      Iterable<Name> exportNames = ScopeResolver.filterCombinators(exportLibrary.exports.keys, directive.combinators);
      
      Map<Name, Element> exports = MapUtil.filterKeys(exportLibrary.exports, exportNames);
      
      exports.forEach((name, element) {
        if (library.containsExport(name) && !library.containsDefined(name) && library.exports[name] != element){
          engine.errors.addError(new EngineError("Exported a element: ${element} with the same identifier from two different origins", source.source, directive.offset, directive.length), true);
        }
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
     
    source.imports.forEach((ImportDirective directive, Source importSource) {
      SourceElement importSourceElement = analysis.getSource(importSource);
      LibraryElement importLibrary = importSourceElement.library;
      Map<Name, Element> imports;
      
      //If the library is dart core library, and it is auto generated, no directive is created, in these cases just add all keys.
      if (directive == null)
        imports = MapUtil.filterKeys(importLibrary.exports, importLibrary.exports.keys);
      else {
        Iterable<Name> importNames = ScopeResolver.filterCombinators(importLibrary.exports.keys, directive.combinators);
        //Todo hidding the getter hides also the the setter.
        imports = MapUtil.filterKeys(importLibrary.exports, importNames);
        imports = ScopeResolver.applyPrefix(imports, directive);
      }
      
      imports.forEach((name, element) {
        if (!library.containsDefined(name)){
          if (element is VariableElement) {
            if ((Name.IsSetterName(name) && !library.containsDefined(Name.GetterName(name))) ||
               (!Name.IsSetterName(name) && !library.containsDefined(Name.SetterName(name)))) {
              if (!library.containsElement(name) || !library.scope[name].contains(element)) {                
                library.addImport(name);
                library.addElement(name, element);
              }
            }  
          } else {  
            if (!library.containsElement(name) || !library.scope[name].contains(element)){
              library.addImport(name);
              library.addElement(name, element);
            }
          }
        }
      });
    });
  }
}

/**
 * `ClassHierarchyResolver` resolves the class hirarchy.
 **/

class ClassHierarchyResolver {
  Engine engine;
  ElementAnalysis analysis;
  ClassElement objectClassElement; 
  
  ClassHierarchyResolver(Engine this.engine, ElementAnalysis this.analysis) {
    objectClassElement = analysis.resolveClassElement(new Name("Object"), analysis.dartCore, analysis.dartCore.source);
    if (objectClassElement == null){
      engine.errors.addError(new EngineError("`Object` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", analysis.dartCore.source.source, analysis.dartCore.source.ast.offset, analysis.dartCore.source.ast.length), true);
    }
    
    analysis.sources.values.forEach((SourceElement source) {
      source.declaredClasses.values.forEach(_createClassHierarchy);
    });
  }
  
  
  void _createClassHierarchy(ClassElement classElement){
    SourceElement sourceElement = classElement.sourceElement;
    LibraryElement libraryElement = sourceElement.library;
    if (classElement.extendsElement == null){
      //They extendsClause is empty, so instead set Object as the extendedclass (implicit setup i Dart), except if it is the Object it self.
      if (classElement.superclass == null){
        if (classElement != objectClassElement)
          classElement.extendsElement = objectClassElement;
      } else {
        ClassElement extendClass = analysis.resolveClassElement(new Name.FromIdentifier(classElement.superclass.name), libraryElement, sourceElement);
        if (extendClass == null)
          engine.errors.addError(new EngineError("`${classElement.superclass.name.toString()}` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", sourceElement.source, sourceElement.ast.offset, sourceElement.ast.length), true);
        else
          classElement.extendsElement = extendClass;
      }
    }
  }
}

class IdentifierResolver extends RecursiveElementVisitor {
  Engine engine;
  ElementAnalysis analysis;
  SourceElement source;
  Map<String, NamedElement> scope;
  Block _currentBlock;
  
  
  IdentifierResolver(Engine this.engine, ElementAnalysis this.analysis) {
    analysis.sources.values.forEach(visitSourceElement);
  }
  
  void visitSourceElement(SourceElement sourceElement){
    source = sourceElement;
    scope = <String, NamedElement>{};
    super.visitSourceElement(sourceElement);
  }
  
  void visitBlock(Block block){
    _currentBlock = block;
    Map<String, NamedElement> parent_scope = scope;
    scope = <String, NamedElement>{};
    scope.addAll(parent_scope);
    for (Name name in block.declaredElements.keys){
      scope[name.toString()] = block.declaredElements[name];
    }
    
    //block.referenceNodes = ListUtil.filter(block.referenceNodes, resolveSimpleIdentifier);
    //block.referenceNodes = ListUtil.filter(block.referenceNodes, resolvePrefixedIdentifier);
    //block.referenceNodes = ListUtil.filter(block.referenceNodes, resolveConstructorName);
    if (block.referenceNodes.length > 0){
      print("Unresolved Elements:");
      block.referenceNodes.forEach(unresolvedElements);
    }
    super.visitBlock(block);
    scope = parent_scope;
    _currentBlock = block.enclosingBlock;
  }
  
  bool resolveSimpleIdentifier(AstNode node){
    if (node is SimpleIdentifier){
      if (scope.containsKey(node.toString())){
        source.resolvedIdentifiers[node] = scope[node.toString()];
        return false;
      }
    }
    return true;
  }
  
  bool resolvePrefixedIdentifier(AstNode node){
    if (node is PrefixedIdentifier){
      //First part already resolved so try to check if the last part can be resolved.
      if (source.resolvedIdentifiers.containsKey(node.prefix)){
         NamedElement namedElement = source.resolvedIdentifiers[node.prefix];
         //Only classes can we resolve statically
         Name postfixName = new Name.FromIdentifier(node.identifier);
         if (namedElement is ClassElement && namedElement.declaredElements.containsKey(postfixName)){
          source.resolvedIdentifiers[node] = namedElement.declaredElements[postfixName];
         }
         //Cannot be resolved further so it is fine.
         return false;  
      }
      
      //Nothing is resolved, so check the library.
      NamedElement element = source.library.lookup(new Name.FromIdentifier(node), false);
      if (element != null){
        source.resolvedIdentifiers[node] = element;
        return false;
      }
      
      //Nothing else to do.
      return false;
    }
    return true;
  }
  
  bool resolveConstructorName(AstNode node){
    if (node is ConstructorName){
      if (node.type.name is PrefixedIdentifier){
        
        PrefixedIdentifier ident = node.type.name;
        
        //If the hole thing already is resolved, this is fine.
        if (source.resolvedIdentifiers.containsKey(ident))
          return false;
        
        if (source.resolvedIdentifiers.containsKey(ident.prefix)){
          NamedElement namedElement = source.resolvedIdentifiers[ident.prefix];
          if (namedElement is ClassElement){
            node.name = ident.identifier;
            node.type.name = ident.prefix;
            return false;
          }
        } else {
          //Is prefixed identifier, and the identifier prefix cannot be resolved. 
          return true;
        }
      } else if (node.type.name is SimpleIdentifier) {
        if (source.resolvedIdentifiers.containsKey(node.type.name)){
          return false;
        } else {
          //Is simple identifier, and the identifier cannot be resolved.
          return true;
        }
      }
      return false;
    }
    return true;
  }
  
  void unresolvedElements(AstNode node){
    print("${node.runtimeType}: ${node}");
  }
}
