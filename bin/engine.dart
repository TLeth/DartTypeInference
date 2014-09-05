library typeanalysis.engine;

import 'package:analyzer/options.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/analyzer_impl.dart';

import 'element.dart';
import 'dart:io';

import 'LocalVariableVisitor.dart';

const int MAX_CACHE_SIZE = 512;
const String DART_EXT_SCHEME = "dart-ext:";

class Error {
  String msg;
  Source file;
  int offset;
  int length;
  
  Error(this.msg, [this.file = null, this.offset = null, this.length]);
  
  String toString() {
    if (this.file == null || this.offset == null || this.length == null)
      return "Error msg: ${this.msg}.";
    
    return "Error msg: ${this.msg}. (File: ${this.file}, offset: ${this.offset}, length: ${this.length})"; 
  }
}

class ErrorCollector {
  List<Error> _errors = <Error>[];
  
  addError(Error err, [bool faliure = false]) {
    _errors.add(err);
    if (faliure) {
      print(this);
      exit(0);
    }
  }
  
  String toString() {
    StringBuffer sb = new StringBuffer();
    _errors.forEach((err) => sb.writeln(err));
    return sb.toString();
  }
}

class Engine {
  
  Source _entrySource;
  JavaFile _entryFile;
  DartSdk _sdk;
  CommandLineOptions _options;
  SourceFactory _sourceFactory;
  AnalysisContextImpl _analysisContext;
  ErrorCollector errors = new ErrorCollector();
  
  Engine(CommandLineOptions this._options, DartSdk this._sdk);
  
  
  analyze(Source source, JavaFile sourceFile) {
    _entrySource = source;
    _entryFile = sourceFile;
    
    _setupSourceFactory();
    _setupAnalaysisContext();
    _elementAnalysis();
  }
 
  
  _setupSourceFactory() {
    List<UriResolver> resolvers = [new DartUriResolver(_sdk), new FileUriResolver()];
      {
        JavaFile packageDirectory;
        if (_options.packageRootPath != null) {
          packageDirectory = new JavaFile(_options.packageRootPath);
        } else {
          packageDirectory = AnalyzerImpl.getPackageDirectoryFor(_entryFile);
        }
        if (packageDirectory != null) {
          resolvers.add(new PackageUriResolver([packageDirectory]));
        }
      }
      _sourceFactory = new SourceFactory(resolvers);
  }
  
  _setupAnalaysisContext(){
    _analysisContext = new AnalysisContextImpl();
    _analysisContext.sourceFactory = _sourceFactory;
    Map<String, String> definedVariables = _options.definedVariables;
    if (!definedVariables.isEmpty) {
      DeclaredVariables declaredVariables = _analysisContext.declaredVariables;
      definedVariables.forEach((String variableName, String value) {
        declaredVariables.define(variableName, value);
      });
    }

    // set options for context
    AnalysisOptionsImpl contextOptions = new AnalysisOptionsImpl();
    contextOptions.cacheSize = MAX_CACHE_SIZE;
    contextOptions.hint = !_options.disableHints;
    contextOptions.enableAsync = _options.enableAsync;
    contextOptions.enableEnum = _options.enableEnum;
    _analysisContext.analysisOptions = contextOptions;
  }
  
  /** Creates a new compilation unit, given a source **/
  CompilationUnit getCompilationUnit(Source source) {
    ResolvableCompilationUnit resolveUnit = _analysisContext.computeResolvableCompilationUnit(_entrySource);
    return resolveUnit.compilationUnit;
  }
  
  _elementAnalysis() {
    GeneralizingAstVisitor visitor = new GeneralizingAstVisitor();
    CompilationUnit unit = this.getCompilationUnit(_entrySource);
    visitor.visitCompilationUnit(unit);
    
    ElementAnalysis elementAnalysis = new ElementAnalysis();
    new ElementGenerator(this, _entrySource, elementAnalysis);
  }
  

  Source getSource(Source source, UriBasedDirective directive) {
    StringLiteral uriLiteral = directive.uri;
    if (uriLiteral is StringInterpolation) 
      errors.addError(new Error("StringInterprolation used in a UriBasedDirective.", source, uriLiteral.offset, uriLiteral.length), true);
    
    String uriContent = uriLiteral.stringValue.trim();
    uriContent = Uri.encodeFull(uriContent);
    
    if (directive is ImportDirective && uriContent.startsWith(DART_EXT_SCHEME)) 
      errors.addError(new Error("Import directive of extension scheme", source, uriLiteral.offset, uriLiteral.length), true);
  
    if (UriUtil.ParseUriWithException(uriContent) == null)
      errors.addError(new Error("Faliure parsing Uri", source, uriLiteral.offset, uriLiteral.length), true);
    
    Source res = _sourceFactory.resolveUri(source, uriContent);
    if (res.exists())
      errors.addError(new Error("Source was found: ${res} but didn't exists", source, uriLiteral.offset, uriLiteral.length), true);
       
    return res;
  }
}

class UriUtil {
  static Uri ParseUriWithException(String str) {
    Uri uri = Uri.parse(str);
    if (uri.path.isEmpty) return null;
    return uri;
  }
  
  static Uri GetUri(JavaFile file, DartSdk sdk) {
     // may be file in SDK
     {
       Source source = sdk.fromFileUri(file.toURI());
       if (source != null) {
         return source.uri;
       }
     }
     // some generic file
     return file.toURI();
   }
}