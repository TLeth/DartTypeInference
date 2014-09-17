library typeanalysis.engine;

import 'dart:io';
import 'package:analyzer/options.dart';
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

import 'identifierResolver.dart';
import 'element.dart';
import 'constraint.dart';
import 'resolver.dart';
import 'printer.dart';


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
      print(this);
      exit(0);
    }
  }
  
  void reset() => _errors.removeRange(0, _errors.length-1);
  
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
  CommandLineOptions _options;
  SourceFactory _sourceFactory;
  AnalysisContextImpl _analysisContext;
  ErrorCollector errors;
  
  ElementAnalysis _elementAnalysis;
  ConstraintAnalysis _constraintAnalysis;
  
  Source get entrySource => _entrySource;
  
  Engine(CommandLineOptions this._options, DartSdk this._sdk) {
    errors = new ErrorCollector(this);
  }
  
  
  analyze(Uri uri, JavaFile sourceFile) {
    _entryFile = sourceFile;    
    _setupSourceFactory();
    _entrySource = _sourceFactory.forUri2(uri);
    
    _setupAnalaysisContext();
    _makeElementAnalysis();
    _printErrorsAndReset();
    
    _makeConstraintAnalysis();
    
  }
 
  void _printErrorsAndReset() {
    print(this.errors);
    this.errors.reset();
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
    
    _elementAnalysis = new ElementAnalysis();
    new ElementGenerator(this, _entrySource, _elementAnalysis);
    //_elementAnalysis.accept(new PrintElementVisitor());
    new ScopeResolver(this, _elementAnalysis.getSource(_entrySource), _elementAnalysis);
    new ExportResolver(this, _elementAnalysis);
    new ImportResolver(this, _elementAnalysis);
    //_elementAnalysis.accept(new PrintLibraryVisitor(scope: true, import: true, export: true, defined: true));
    new IdentifierResolver(this, _elementAnalysis);
    //unit.accept(new PrintAstVisitor());
  }
  
  _makeConstraintAnalysis(){
    _constraintAnalysis = new ConstraintAnalysis();
    new ConstraintGenerator(this, _elementAnalysis, _constraintAnalysis);
    //print(_constraintAnalysis.constraints[_entrySource]);
    new SubstitutionGenerator(this, _constraintAnalysis);
    //ConstraintSolver solver = new ConstraintSolver(_elementAnalysis.sources[_entrySource].constraints);    
    print(_constraintAnalysis.substitutions[_entrySource]);
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