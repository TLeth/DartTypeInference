library typeanalysis.engine;

import 'dart:io';
import 'dart:profiler';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/analyzer_impl.dart';

import 'analyze.dart';
import 'annotate.dart';
import 'name_resolver.dart';
import 'element.dart';
import 'constraint.dart';
import 'resolver.dart' hide IdentifierResolver;
import 'printer.dart';

//TODO (jln): split files into smaller ones.


const int MAX_CACHE_SIZE = 512;
const String DART_EXT_SCHEME = "dart-ext:";

class EngineError {
  String msg;
  Source file;
  int offset;
  int length;
  
  EngineError(this.msg, [this.file = null, this.offset = null, this.length = null]);
  
  String toCustomString(Engine engine) {
    
    if (this.file == null || this.offset == null || this.length == null)
      return this.toString();
    
    
    SourceElement element = engine._elementAnalysis.getSource(this.file);
    if (element == null)
      return this.toString();
    
    if (element.ast == null || element.ast.lineInfo == null)
      return this.toString();
    
    LineInfo_Location location = element.ast.lineInfo.getLocation(offset);
    return "Error msg: ${this.msg}. (File: ${this.file}, line: ${location.lineNumber}, column: ${location.columnNumber})"; 
  }
  
  String toString(){
    if (this.file == null || this.offset == null || this.length == null)
      return "Error msg: ${this.msg}.";
    return "Error msg: ${this.msg}. (File: ${this.file}, offset: ${this.offset}, length: ${this.length})";
  }
}

class ErrorCollector {
  List<EngineError> _errors = <EngineError>[];
  Engine _engine;
  
  
  ErrorCollector(Engine this._engine);
  
  addError(EngineError err, [bool faliure = false]) {
    _errors.add(err);
    if (faliure) {
      throw err;
    }
  }
  
  void reset() => _errors.clear();
  
  String toString() {
    StringBuffer sb = new StringBuffer();
    _errors.forEach((err) => sb.writeln(err.toCustomString(_engine)));
    return sb.toString();
  }
}

class Engine {
  
  Source _entrySource;
  JavaFile _entryFile;
  DartSdk _sdk;
  CommandLineOptions options;
  SourceFactory _sourceFactory;
  AnalysisContextImpl _analysisContext;
  ErrorCollector errors;
  
  ElementAnalysis _elementAnalysis;
  ElementAnalysis get elementAnalysis => _elementAnalysis;
  ConstraintAnalysis _constraintAnalysis;
  ConstraintAnalysis get constraintAnalysis => _constraintAnalysis;
  
  JavaFile get entryFile => _entryFile;
  Source get entrySource => _entrySource;
  
  Engine(CommandLineOptions this.options, DartSdk this._sdk) {
    errors = new ErrorCollector(this);
  }
  
  
  analyze(Uri uri, JavaFile sourceFile) {
    _entryFile = sourceFile;    
    _setupSourceFactory();
    _entrySource = _sourceFactory.forUri2(uri);
    
    UserTag last;
    
    last = new UserTag('Setup').makeCurrent();
    
    _setupAnalaysisContext();

    last.makeCurrent();
    last = new UserTag('ElementAnalysis').makeCurrent();
        
    _makeElementAnalysis();
    
    
    errors.reset();

    last.makeCurrent();
    last = new UserTag('ConstraintAnalysis').makeCurrent();
    
    
    _makeConstraintAnalysis();
    
    errors.reset();

    last.makeCurrent();
    last = new UserTag('Annotate').makeCurrent();
    
    
    _makeAnnotatedSource();
    
    last.makeCurrent();
   
    
    _printErrorsAndReset();
  }

  
  static List<Source> GetDependencies(CommandLineOptions options, DartSdk sdk, Uri uri, JavaFile sourceFile) {
   Engine engine = new Engine(options, sdk);
   engine._entryFile = sourceFile;    
   engine._setupSourceFactory();
   engine._entrySource = engine._sourceFactory.forUri2(uri);
   engine._setupAnalaysisContext();
   
   GeneralizingAstVisitor visitor = new GeneralizingAstVisitor();
   CompilationUnit unit = engine.getCompilationUnit(engine._entrySource);
   visitor.visitCompilationUnit(unit);
   
   engine._elementAnalysis = new ElementAnalysis(engine);
   new ElementGenerator(engine, engine._entrySource, engine._elementAnalysis);
   SourceElement entrySourceElement = engine._elementAnalysis.getSource(engine._entrySource);
   return new List<Source>.from(engine._elementAnalysis.sources.keys);
  }
  
  void _printErrorsAndReset() {
    print(this.errors);
    this.errors.reset();
  }
  
  
  _setupSourceFactory() {
    List<UriResolver> resolvers = [new DartUriResolver(_sdk), new FileUriResolver()];
      {
        JavaFile packageDirectory;
        if (options.packageRootPath != null) {
          packageDirectory = new JavaFile(options.packageRootPath);
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

    // set options for context
    AnalysisOptionsImpl contextOptions = new AnalysisOptionsImpl();
    contextOptions.cacheSize = MAX_CACHE_SIZE;
    contextOptions.hint = !options.disableHints;
    contextOptions.enableAsync = options.enableAsync;
    contextOptions.enableEnum = options.enableEnum;
    _analysisContext.analysisOptions = contextOptions;
  } 
  
  /** Creates a new compilation unit, given a source **/
  CompilationUnit getCompilationUnit(Source source) {
    RecordingErrorListener errorListener = new RecordingErrorListener();
    String content = source.contents.data;
    AnalysisOptions options = _analysisContext.analysisOptions;
    Scanner scanner = new Scanner(source, new CharSequenceReader(content), errorListener);
    scanner.preserveComments = options.preserveComments;
    Token tokenStream= scanner.tokenize();
    LineInfo lineInfo = new LineInfo(scanner.lineStarts);
    List<AnalysisError> errors = errorListener.getErrorsForSource(source);
    
    if (errors.length > 0) {
      print(errors);
      exit(0);
    }
   
    Parser parser = new Parser(source, errorListener);
    parser.parseFunctionBodies = options.analyzeFunctionBodies;
    parser.parseAsync = options.enableAsync;
    parser.parseDeferredLibraries = options.enableDeferredLoading;
    parser.parseEnum = options.enableEnum;
    CompilationUnit unit = parser.parseCompilationUnit(tokenStream);
    unit.lineInfo = lineInfo;
    
    errors = errorListener.getErrorsForSource(source);
    if (errors.length > 0) {
      print(errors);
      exit(0);
    }
    return unit;
  }
  
  _makeElementAnalysis() {
    GeneralizingAstVisitor visitor = new GeneralizingAstVisitor();
    CompilationUnit unit = this.getCompilationUnit(_entrySource);
    visitor.visitCompilationUnit(unit);
    
    _elementAnalysis = new ElementAnalysis(this);
    new ElementGenerator(this, _entrySource, _elementAnalysis);
    SourceElement entrySourceElement = _elementAnalysis.getSource(_entrySource); 

    new ScopeResolver(this, entrySourceElement, _elementAnalysis);
    new ExportResolver(this, _elementAnalysis);
    new ImportResolver(this, _elementAnalysis);
    
    new IdentifierResolver(this,  _elementAnalysis);
    new ClassHierarchyResolver(this, _elementAnalysis);

    if (this.options.printAstNodes) {
      unit.accept(new PrintAstVisitor());
    }
    
    if (this.options.printBlock) {
      _elementAnalysis.accept(new PrintScopeVisitor());
    }

    if (this.options.printNameResolving) {
      new PrintResolvedIdentifiers(this, _elementAnalysis);
    }

    //_elementAnalysis.accept(new PrintLibraryVisitor(scope: false, import: false, export: true, defined: false, depended_exports: true));
    if (this.options.printElementNodes)
      _elementAnalysis.accept(new PrintElementVisitor());
  }
  
  _makeConstraintAnalysis(){
    _constraintAnalysis = new ConstraintAnalysis(this, _elementAnalysis);
    new ConstraintGenerator(_constraintAnalysis);

    if (this.options.printConstraints) {
      new PrintConstraintVisitor(_constraintAnalysis, _entrySource);
    }
  }
  
  _makeAnnotatedSource() {
    new Annotator(this);
  }

  /*
  _makeInstrumentedTypeAnalysis() {
    new Convert
  }*/
  
  Source resolveUri(Source entrySource, String uri) {
    return _sourceFactory.resolveUri(entrySource, uri);
  }
  
  bool isCore(Source source){
    return source == getCore(source);
  }
  
  Source getCore(Source source){
    return resolveUri(source, DartSdk.DART_CORE); 
  }

  Source resolveDirective(Source entrySource, UriBasedDirective directive) {
    StringLiteral uriLiteral = directive.uri;
    String uriContent = uriLiteral.stringValue;
    if (uriContent != null) {
      uriContent = uriContent.trim();
      directive.uriContent = uriContent;
    }
    UriValidationCode code = directive.validate();
    if (code == null) {
      String encodedUriContent = Uri.encodeFull(uriContent);
      Source source = resolveUri(entrySource, encodedUriContent);
      directive.source = source;
      return source;
    }
    if (code == UriValidationCode.URI_WITH_DART_EXT_SCHEME) {
      return null;
    }
    if (code == UriValidationCode.URI_WITH_INTERPOLATION) {
      errors.addError(new EngineError("StringInterprolation used in a UriBasedDirective.", entrySource, uriLiteral.offset, uriLiteral.length), true);
      return null;
    }
    if (code == UriValidationCode.INVALID_URI) {
      errors.addError(new EngineError("Faliure parsing Uri", entrySource, uriLiteral.offset, uriLiteral.length), true);
      return null;
    }
    
    errors.addError(new EngineError("Unable to resolve directive, with uriValidationCode ${code}.", entrySource, uriLiteral.offset, uriLiteral.length), true);
    return null;
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