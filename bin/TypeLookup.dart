import 'package:analyzer/options.dart';
import 'dart:io';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/analyzer_impl.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/element.dart';

DartSdk sdk;
const int _MAX_CACHE_SIZE = 512;

void main(args){
  CommandLineOptions options = CommandLineOptions.parse(args);
  sdk = new DirectoryBasedDartSdk(new JavaFile(options.dartSdkPath));
  
  _TypeAnnotate(options);
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

_TypeAnnotate(CommandLineOptions options){
  for (String sourcePath in options.sourceFiles) {
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
      Uri uri = getUri(sourceFile);
      Source librarySource = new FileBasedSource.con2(uri, sourceFile);
      List<UriResolver> resolvers = [new DartUriResolver(sdk), new FileUriResolver()];
      {
        JavaFile packageDirectory;
        if (options.packageRootPath != null) {
          packageDirectory = new JavaFile(options.packageRootPath);
        } else {
          packageDirectory = AnalyzerImpl.getPackageDirectoryFor(sourceFile);
        }
        if (packageDirectory != null) {
          resolvers.add(new PackageUriResolver([packageDirectory]));
        }
      }
      SourceFactory sourceFactory = new SourceFactory(resolvers);
      AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
      context.sourceFactory = sourceFactory;
      Map<String, String> definedVariables = options.definedVariables;
      if (!definedVariables.isEmpty) {
        DeclaredVariables declaredVariables = context.declaredVariables;
        definedVariables.forEach((String variableName, String value) {
          declaredVariables.define(variableName, value);
        });
      }
      
      // Uncomment the following to have errors reported on stdout and stderr
      AnalysisEngine.instance.logger = new StdLogger(options.log);

      // set options for context
      AnalysisOptionsImpl contextOptions = new AnalysisOptionsImpl();
      contextOptions.cacheSize = _MAX_CACHE_SIZE;
      contextOptions.hint = !options.disableHints;
      contextOptions.enableAsync = options.enableAsync;
      contextOptions.enableEnum = options.enableEnum;
      context.analysisOptions = contextOptions;

      // Create and add a ChangeSet
      ChangeSet changeSet = new ChangeSet();
      changeSet.addedSource(librarySource);
      context.applyChanges(changeSet);
      
      if (context.computeKindOf(librarySource) == SourceKind.PART) {
        print("Only libraries can be analyzed.");
        print("$sourcePath is a part and can not be analyzed.");
        return;
      }
      
      LibraryElement libraryElement = context.computeLibraryElement(librarySource);
      
      
      print("FISSE");
  }
}