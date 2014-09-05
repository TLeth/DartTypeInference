library typeanalysis.engine;

import 'package:analyzer/options.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/analyzer_impl.dart';
import 'element.dart';


const int MAX_CACHE_SIZE = 512;

class Engine {
  
  Source _entrySource;
  JavaFile _entryFile;
  DartSdk _sdk;
  CommandLineOptions _options;
  SourceFactory _sourceFactory;
  AnalysisContextImpl _analysisContext;
  
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
  
  _elementAnalysis() {
    //ElementVisitor ev = new ElementVisitor();
    //ConstraintGeneratorVisitor cv = new ConstraintGeneratorVisitor();
    ResolvableCompilationUnit resolveUnit = _analysisContext.computeResolvableCompilationUnit(_entrySource);
    //resolveUnit.compilationUnit.visitChildren(cv);
    //print(cv.constraints);
  }
}