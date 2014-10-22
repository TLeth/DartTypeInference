#!/usr/bin/env dart

import 'package:args/args.dart';
import 'dart:io';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import '../bin/engine.dart';
import '../bin/analyze.dart';
import 'package:analyzer/src/generated/java_io.dart';

void main(List<String> args){
  var parser = new ArgParser(); 
  
  parser..addOption('dart-sdk', help: 'The path to the Dart SDK')
        ..addFlag('dartcore' , abbr: 'c', defaultsTo: false, negatable: false)
        ..addFlag('package' ,abbr: 'p', defaultsTo: false, negatable: false);
  var options = parser.parse(args);
  if (options.rest.length != 1){
    print("Only one entry file should be given");
    return;
  }
  var file = options.rest[0];
  
  CommandLineOptions clt = new CommandLineOptions(sourceFiles: options.rest, dartSdkPath: options['dart-sdk']);
  
  var sdk = new DirectoryBasedDartSdk(new JavaFile(options['dart-sdk']));
  file = file.trim();
  // check that file exists
  if (!new File(file).existsSync()) {
    print('File not found: $file');
    return;
  }
  // check that file is Dart file
  if (!AnalysisEngine.isDartFileName(file)) {
    print('$file is not a Dart file');
    return;
  }
  
  JavaFile sourceFile = new JavaFile(file);
  Uri uri = UriUtil.GetUri(sourceFile, sdk);
  List<Source> sources = Engine.GetDependencies(clt, sdk, uri, sourceFile);
  for (Source s in sources){
    if ( s.uriKind == UriKind.FILE_URI ||
        (s.uriKind == UriKind.DART_URI && options['dartcore']) ||
        (s.uriKind == UriKind.PACKAGE_URI && options['package']))
      print(s);
  }
}