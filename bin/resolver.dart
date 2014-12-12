library typeanalysis.resolve;

import 'dart:collection';
import 'package:analyzer/src/generated/ast.dart' hide Block, ClassMember;
import 'package:analyzer/src/generated/source.dart';
import 'element.dart';
import 'engine.dart';
import 'util.dart';
import 'types.dart';
/** The library resolution step is seperated into tree steps:
 * Resolving local scope
 * Resolving export scope
 * Resolving import scope.
 * Resolving identifier scope.
 */ 



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
      exportSourceElement.library.addDependedExport(source.library);
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

    for(FunctionAliasElement alias in source.declaredFunctionAlias.values) {
      _checkScopeDuplicate(alias.name, alias.ast, source);
      lib.addElement(alias.name, alias);

      if (!alias.isPrivate) 
        lib.addExport(alias.name, alias);
      
      lib.addDefined(alias.name);
    }
    
    //Since 'part of' elements cannot have any other directives we only do this if they dont have a partOf. 
    if (source.partOf == null) {
      _setLibraryOnPartOf(source);
    }
  }
}

/** `ExportResolver` resolves the exports of each library, it is done using a queue since the dependency can be circular */ 
class ExportResolver {
  
  Engine engine;
  ElementAnalysis analysis;
  Queue<LibraryElement> _queue = new Queue<LibraryElement>();
  
  ExportResolver(Engine this.engine, ElementAnalysis this.analysis) {
    analysis.sources.values.forEach((SourceElement source) {
      if (source.library == null)
        engine.errors.addError(new EngineError("A SourceElement ${source} was missing its library, this should not be possible in ExportResolver.", source.source, source.ast.offset, source.ast.length), true);
      _queue.add(source.library);
    });
    
    while(!_queue.isEmpty){
      LibraryElement library = _queue.removeFirst();
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
  Set<ClassElement> generatedOverrides = new Set<ClassElement>();
  
  ClassHierarchyResolver(Engine this.engine, ElementAnalysis this.analysis) {
    objectClassElement = analysis.resolveClassElement(new Name("Object"), analysis.dartCore, analysis.dartCore.source);
    if (objectClassElement == null){
      engine.errors.addError(new EngineError("`Object` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", analysis.dartCore.source.source, analysis.dartCore.source.ast.offset, analysis.dartCore.source.ast.length), true);
    }
    
    analysis.sources.values.forEach((SourceElement source) {
      source.declaredClasses.values.forEach(_createClassHierarchy);
    });
    analysis.sources.values.forEach((SourceElement source) {
      source.declaredClasses.values.forEach(_createOverridesHierarchy);
      source.declaredTypeParameters.forEach(_createTypeParameterBound);
    });
  }
  
  void _createOverridesHierarchy(ClassElement classElement){    
    List<ClassMember> elements = [classElement.declaredFields.values, classElement.declaredMethods.values, classElement.declaredConstructors.values].reduce(ListUtil.union);
    
    elements.forEach((ClassMember el){
      classElement.lookup(el.name, interfaces: true).forEach((ClassMember overwritten) {
        if (el != overwritten) el.overrides.add(overwritten);
      });
    });
  }
  
  void _createClassHierarchy(ClassElement classElement){
    SourceElement sourceElement = classElement.sourceElement;
    LibraryElement libraryElement = sourceElement.library;
    if (classElement.extendsElement == null){
      //They extendsClause is empty, so instead set Object as the extendedclass (implicit setup i Dart), except if it is the Object it self.
      if (classElement.superclass == null){
        if (classElement != objectClassElement) {
          classElement.extendsElement = objectClassElement;
          objectClassElement.extendsSubClasses.add(classElement);
        }
      } else {
        ClassElement extendClass = analysis.resolveClassElement(new Name.FromIdentifier(classElement.superclass.name), libraryElement, sourceElement);
        if (extendClass == null)
          engine.errors.addError(new EngineError("`${classElement.superclass.name.toString()}` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", sourceElement.source, sourceElement.ast.offset, sourceElement.ast.length), true);
        else {
          classElement.extendsElement = extendClass;
          extendClass.extendsSubClasses.add(classElement);
        }
      }
    }
    
    classElement.implementElements = classElement.implements.fold([], (List a, TypeName implementsType) {
      ClassElement implementsElement = analysis.resolveClassElement(new Name.FromIdentifier(implementsType.name), libraryElement, sourceElement);
      if (implementsElement == null) 
        engine.errors.addError(new EngineError("`${implementsType.name.toString()}` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", sourceElement.source, sourceElement.ast.offset, sourceElement.ast.length), true);
      else {
        a.add(implementsElement);
        implementsElement.interfaceSubClasses.add(classElement);
      }
      return a;
    });

    classElement.mixinElements = classElement.mixins.fold([], (List a, TypeName mixinType) {
      ClassElement mixinElement = analysis.resolveClassElement(new Name.FromIdentifier(mixinType.name), libraryElement, sourceElement);
      if (mixinElement == null) 
        engine.errors.addError(new EngineError("`${mixinType.name.toString()}` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", sourceElement.source, sourceElement.ast.offset, sourceElement.ast.length), true);
      else { 
        a.add(mixinElement);
        mixinElement.mixinSubClasses.add(classElement);
      }
      return a;
    });
  }
  
  void _createTypeParameterBound(TypeParameterElement paramElement){
    SourceElement sourceElement = paramElement.sourceElement;
    LibraryElement libraryElement = sourceElement.library;
    if (paramElement.boundElement == null){
      if (paramElement.ast.bound == null){
        paramElement.boundElement = objectClassElement;
      } else {
        ClassElement boundClass = analysis.resolveClassElement(new Name.FromIdentifier(paramElement.ast.bound.name), libraryElement, sourceElement);
        if (boundClass == null)
            engine.errors.addError(new EngineError("`${paramElement.ast.bound.name}` ClassElement could not be resolved, therefore the implicit extends couldnt be made.", sourceElement.source, sourceElement.ast.offset, sourceElement.ast.length), true);
        else
          paramElement.boundElement= boundClass; 
      }
    }
  }
}
