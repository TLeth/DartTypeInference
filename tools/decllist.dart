#!/usr/bin/env dart

import 'package:analyzer/src/generated/java_io.dart';
import 'dart:io';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/error.dart';



CompilationUnit input;

main(List<String> args) {
    
  
  print(args[0]);
  input = getCompilationUnit(new FileBasedSource.con1(new JavaFile(args[0])));
  print(input.accept(new TwinVisitor()));
  
}

CompilationUnit getCompilationUnit(Source source) {
  RecordingErrorListener errorListener = new RecordingErrorListener();
  
  String content = source.contents.data;
  AnalysisOptions options = new AnalysisOptionsImpl();
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

class TwinVisitor extends GeneralizingAstVisitor {
  
  visitVariableDeclarationList(VariableDeclarationList node) {
    super.visitVariableDeclarationList(node);

    if (node.variables.length > 1) {
      var loc =  input.lineInfo.getLocation(node.offset);
      print('Long decl at ${loc.lineNumber}:${loc.columnNumber}');
    }
  }
}