library typeanalysis.types;


import 'package:path/path.dart' as pathos;
import 'package:analyzer/options.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/analyzer_impl.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/error.dart';
import 'dart:io';

import 'parser.dart';


void main(args){
  CommandLineOptions options = CommandLineOptions.parse(args);
  TypeAnalysis analysis = new TypeAnalysis(options);
}

class ErrorCollector extends AnalysisErrorListener {
  final _errors = <AnalysisError>[];

  /// Whether any errors where collected.
  bool get hasErrors => !_errors.isEmpty;

  /// The group of errors collected.
  AnalyzerErrorGroup get group => new AnalyzerErrorGroup.fromAnalysisErrors(_errors);

 ErrorCollector();

  void onError(AnalysisError error) => _errors.add(error);
}


class TypeAnalysis {
  
  CommandLineOptions options;
  DartSdk sdk; 
  Parser parser;
  
  TypeAnalysis(this.options) {
    sdk = new DirectoryBasedDartSdk(new JavaFile(options.dartSdkPath));
    run();
  }
  
  void run(){
    for(String sourcePath in options.sourceFiles){
      sourcePath = sourcePath.trim();
      // check that file exists
      if (!new File(sourcePath).existsSync()) {
        print('File not found: $sourcePath');
        return;
      }
      // check that file is Dart file
      if (!AnalysisEngine.isDartFileName(sourcePath)) {
        print('$sourcePath is not a Dart file');
        return;
      }
      
      JavaFile sourceFile = new JavaFile(sourcePath);
      TypeAnalysisContext analysisContext = new TypeAnalysisContext(options, sdk, sourceFile);
      analysisContext.analyze();
    }
  }
}

class TypeAnalysisContext {
  
  DartSdk sdk;
  
  JavaFile _entryFile;
  Source _entrySource; 
  
  CommandLineOptions options;
  
  SourceFactory sourceFactory;
  
  ErrorCollector errorCollector;
  
  Source _coreLibrarySource;
  
  Parser _parser;
  Resolver _resolver;
  
  TypeAnalysisContext(this.options, this.sdk, this._entryFile) {
    _prepareAnalysisContext();
  }
  
  analyze(){
    String absolutePath = pathos.absolute(_entryFile.getAbsolutePath());
    _entrySource = new FileBasedSource.con1(_entryFile);
    
    if (_entrySource == null) throw Error.safeToString("The path given: ${absolutePath} could not be resolved.");
    if (!_entrySource.exists()) throw Error.safeToString("The path given: ${absolutePath} does not exists.");
    
    _parser.parseFile(_entrySource, _entryFile.readAsStringSync());
  }
  
  Uri getUri(JavaFile file) {
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
  
  _prepareAnalysisContext(){
    _setupSourceFactory();
    _coreLibrarySource = sourceFactory.forUri(DartSdk.DART_CORE);
    errorCollector = new ErrorCollector();
    _parser = new Parser(this);
  }
  
  _setupSourceFactory() {
    Uri uri = getUri(_entryFile);
    Source librarySource = new FileBasedSource.con2(uri, _entryFile);
    List<UriResolver> resolvers = [new DartUriResolver(sdk), new FileUriResolver()];
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
    sourceFactory = new SourceFactory(resolvers);
  }
  
  
}