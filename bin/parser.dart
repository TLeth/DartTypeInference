library typeanalysis.parser; 

import 'types.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';

import 'package:analyzer/src/generated/parser.dart' as analyzer;
import 'dart:collection';


class URISyntaxException implements Exception {
  String toString() => "URISyntaxException";
}

class Resolver {
  HashMap<UriBasedDirective, String> _directiveUris = new HashMap<UriBasedDirective, String>();
  
  TypeAnalysisContext _analysisContext;
  
  Resolver(this._analysisContext);
  static String _DART_EXT_SCHEME = "dart-ext:";
  
  
  Uri parseUriWithException(String str) {
    Uri uri = Uri.parse(str);
    if (uri.path.isEmpty) {
      throw new URISyntaxException();
    }
    return uri;
  }
  
  Source getSource(Source containingSource, UriBasedDirective directive) {
    StringLiteral uriLiteral = directive.uri;
    if (uriLiteral is StringInterpolation) return null;
    String uriContent = uriLiteral.stringValue.trim();
    _directiveUris[directive] = uriContent;
    uriContent = Uri.encodeFull(uriContent);
    if (directive is ImportDirective && uriContent.startsWith(_DART_EXT_SCHEME)) return null;
    try {
      parseUriWithException(uriContent);
      Source source = _analysisContext.sourceFactory.resolveUri(containingSource, uriContent);
      directive.source = source;
      if (!source.exists()) {
        return null;
      }
      return source;
    } on URISyntaxException catch (exception) { //Error dyring parsing 
      
    }
    return null;
  }

  /**
   * Returns the URI value of the given directive.
   */
  String getUri(UriBasedDirective directive) => _directiveUris[directive];
}

class Parser {
  TypeAnalysisContext _analysisContext;
  
  analyzer.Parser _internalParser;
  
  Resolver _resolver;
  
  Parser(this._analysisContext) {
    _resolver = new Resolver(this._analysisContext);
  }
  
  void parse(Source source, Token first_token) {
    _internalParser = new analyzer.Parser(source, _analysisContext.errorCollector);
    CompilationUnit unit = _internalParser.parseCompilationUnit(first_token);
    NodeList<Directive> list = unit.directives;
    for(Directive directive in list){
      if (directive is ImportDirective) {
        print(_resolver.getSource(source, directive));
        print(directive.source.contents.data);
      }
    }
  }
  
  
  void parseFile(Source source, String contents){
    var reader = new CharSequenceReader(contents);
    var scanner = new Scanner(source, reader, _analysisContext.errorCollector);
    var token = scanner.tokenize();
    parse(source, token);
  }
}