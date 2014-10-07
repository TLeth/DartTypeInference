import 'package:analyzer/options.dart';
import 'dart:io';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'annotate.dart';
import 'engine.dart';

DartSdk sdk;
const int _MAX_CACHE_SIZE = 512;

void main(args){
  CommandLineOptions options = CommandLineOptions.parse(args);
  sdk = new DirectoryBasedDartSdk(new JavaFile(options.dartSdkPath));
  
  _typeAnnotate(options);
}



_typeAnnotate(CommandLineOptions options){
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
      
      Engine e = new Engine(options, sdk);
      JavaFile sourceFile = new JavaFile(sourcePath);
      Uri uri = UriUtil.GetUri(sourceFile, sdk);
      e.analyze(uri, sourceFile);
      
      //Annotate the files.
      new Annotator(e);
  }

}