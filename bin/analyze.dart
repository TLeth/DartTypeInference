  import 'package:args/args.dart';
import 'dart:io';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'engine.dart';

import 'package:stack_trace/stack_trace.dart';


DartSdk sdk;
const int _MAX_CACHE_SIZE = 512;
const _BINARY_NAME = 'dartannotate';

class CommandLineOptions {
  /** The path to the dart SDK */
  final String dartSdkPath;

  /** For benchmark puposes: Path to root dir of expected output */
  final String expectedRootPath;

  /** For benchmark purposes: Path to root dir of input */
  final String actualRootPath;
  
  /** For benchmark purposes: The complete path to benchmark root. */
  final String benchmarkRootPath;
  
  /** true if actual and expected are present */
  bool get compareTypes => actualRootPath != null && expectedRootPath != null;
  final bool emitJSON;
  
  /** Whether to log additional analysis messages and exceptions */
  final bool log;

  /** The path to the package root */
  final String packageRootPath;

  /** The source files to analyze */
  final List<String> sourceFiles;
  
  /** Wheather to override the local files */
  final bool overrideFiles; 

  /** Whether to report hints */
  final bool disableHints;

  /** Whether to display version information */
  final bool displayVersion;

  /** Whether to enable support for the proposed async feature. */
  final bool enableAsync;

  /** Whether to enable support for the proposed enum feature. */
  final bool enableEnum;
  
  /** Whether to enable debug printing of block structure. */
  final bool printBlock;
  
  /** Whether to enable debug printing of resolved names. */
  final bool printNameResolving;
  
  /** Whether to enable debug printing of constraint stucture. */
  final bool printConstraints;
  
  /** Whether to enable debug printing of Ast nodes. */
  final bool printAstNodes;

  /** Whether to enable debug printing of element nodes. */
  final bool printElementNodes;
  
  /** Whether to enable debug printing of restriction nodes. */
  final bool printRestrictNodes;
  
  /** Whether to enable debug printing of use analysis nodes. */
  final bool printUseAnalysisNodes;
  
  /** What iteration there is about to be runned */ 
  final int iteration;
  
    
  bool analyzeSDK;
  bool analyzePackages;

  /**
   * Initialize options from the given parsed [args].
   */
  CommandLineOptions._fromArgs(ArgResults args)
    : overrideFiles = args['override'],
      disableHints = args['no-hints'],
      displayVersion = args['version'],
      enableAsync = args['enable-async'],
      enableEnum = args['enable-enum'],
      dartSdkPath = args['dart-sdk'],
      iteration = (args['iteration'] != null ? int.parse(args['iteration']) : 9999),
      log = args['log'],
      packageRootPath = args['package-root'],
      printBlock = args['debug-block'],
      printNameResolving = args['debug-name'],
      printConstraints = args['debug-constraint'],
      printAstNodes = args['debug-ast'],
      printElementNodes = args['debug-element'],
      printRestrictNodes = args['debug-restrict'],
      printUseAnalysisNodes = args['debug-use'],
      expectedRootPath = args['expected-basedir'],
      actualRootPath = args['actual-basedir'],
      emitJSON = args['json'],
      analyzePackages = !args['skip-packages'],
      analyzeSDK = !args['skip-sdk'],
      benchmarkRootPath = (new JavaFile(args['benchmarkdir'])).getAbsolutePath(),
      sourceFiles = args.rest {
    if (args['iteration'] != null){
      if (this.iteration < 3){
        analyzeSDK = true;
        analyzePackages = true;
      } else {
        analyzeSDK = false;
        analyzePackages = false;  
      }
    } else {
      
    }
  
  }
  
  CommandLineOptions({bool this.overrideFiles: false,
    bool this.disableHints: false,
    bool this.displayVersion: false,
    bool this.enableAsync: false,
    bool this.enableEnum: false,
    String this.dartSdkPath: null, 
    bool this.log: false,
    String this.packageRootPath: null,
    int this.iteration: null,
    bool this.printBlock: false,
    bool this.printNameResolving: false,
    bool this.printConstraints: false,
    bool this.printAstNodes: false,
    bool this.printRestrictNodes: false,
    bool this.printUseAnalysisNodes: false,
    bool this.printElementNodes: false,
    String this.expectedRootPath: null,
    String this.actualRootPath: null,
    String this.benchmarkRootPath: null,
    bool this.emitJSON: false,
    bool this.analyzePackages: true,
    bool this.analyzeSDK: true,
    List<String> this.sourceFiles: null}) {
    {
      var sdkPath = this.dartSdkPath;
      // check that SDK is specified
      if (sdkPath == null) {
        print('Usage: $_BINARY_NAME: no Dart SDK found.');
        exit(15);
      }
      // check that SDK is existing directory
      if (!(new Directory(sdkPath)).existsSync()) {
        print('Usage: $_BINARY_NAME: invalid Dart SDK path: $sdkPath');
        exit(15);
      }
      
      if (this.iteration < 4 && this.iteration != null){
        analyzeSDK = true;
        analyzePackages = true;
      } else {
        analyzeSDK = false;
        analyzePackages = false;
      }
    }
  }

  /**
   * Parse [args] into [CommandLineOptions] describing the specified
   * analyzer options. In case of a format error, prints error and exists.
   */
  static CommandLineOptions parse(List<String> args) {
    CommandLineOptions options = _parse(args);
    // check SDK
    {
      var sdkPath = options.dartSdkPath;
      // check that SDK is specified
      if (sdkPath == null) {
        print('Usage: $_BINARY_NAME: no Dart SDK found.');
        exit(15);
      }
      // check that SDK is existing directory
      if (!(new Directory(sdkPath)).existsSync()) {
        print('Usage: $_BINARY_NAME: invalid Dart SDK path: $sdkPath');
        exit(15);
      }
    }
    // OK
    return options;
  }

  static CommandLineOptions _parse(List<String> args) {
    args = args.expand((String arg) => arg.split('=')).toList();
    
    var parser = new ArgParser()
      ..addOption('dart-sdk', help: 'The path to the Dart SDK')
      ..addOption('package-root', abbr: 'p',
          help: 'The path to the package root')
      ..addOption('expected-basedir', help: 'Path to expected output')
      ..addOption('actual-basedir', help: 'Basedir, used to find correct expected files')
      ..addOption('benchmarkdir', help: 'Benchmark dir, only used when together with json.')
      ..addOption('iteration', help: 'Overrules all flags to setup for the given iteration')
      ..addFlag('json', help: 'Emit JSON formatted results', negatable: false)
      ..addFlag('version', help: 'Print the analyzer version',
          defaultsTo: false, negatable: false)
      ..addFlag('override', help: 'Override files.', 
          abbr: 'w', defaultsTo: false, negatable: false)
      ..addFlag('help', abbr: 'h', help: 'Display this help message',
          defaultsTo: false, negatable: false)
      ..addFlag('log', help: 'Log additional messages and exceptions',
          defaultsTo: false, negatable: false, hide: true)
      ..addFlag('enable-async',
                help: 'Enable support for the proposed async feature',
                defaultsTo: false, negatable: false, hide: true)
      ..addFlag('no-hints', help: 'Do not show hint results',
          defaultsTo: false, negatable: false)
      ..addFlag('enable-enum',
          help: 'Enable support for the proposed enum feature',
          defaultsTo: false, negatable: false, hide: true)
      ..addFlag('debug-block', defaultsTo: false, negatable: false, help: 'Debug print; prints the block structure.')
      ..addFlag('debug-constraint', defaultsTo: false, negatable: false, help: 'Debug print; prints the contraints.')
      ..addFlag('debug-name', defaultsTo: false, negatable: false, help: 'Debug print; prints a version of the program where the names are changed to show name resolving.')
      ..addFlag('debug-ast', defaultsTo: false, negatable: false, help: 'Debug print; prints the names of the AST nodes visited.')
      ..addFlag('debug-element', defaultsTo: false, negatable: false, help: 'Debug print; prints the element hirarchy.')
      ..addFlag('debug-restrict', defaultsTo: false, negatable: false, help: 'Debug print; prints the restrict nodes.')
      ..addFlag('debug-use', defaultsTo: false, negatable: false, help: 'Debug print; prints the use analysis nodes.')
      ..addFlag('skip-sdk', defaultsTo: false, negatable: false, help: 'Skip analyzing SDK, only use annotation')
      ..addFlag('skip-packages', defaultsTo: false, negatable: false, help: 'Skip analyzing packages, only use annotation');


    try {
      var results = parser.parse(args);
      // help requests
      if (results['help']) {
        _showUsage(parser);
        exit(0);
      } else if (results['version']) {
        print('$_BINARY_NAME version ${_getVersion()}');
        exit(0);
      } else {
        if (results.rest.isEmpty) {
          _showUsage(parser);
          exit(15);
        }
      }
      return new CommandLineOptions._fromArgs(results);
    } on FormatException catch (e) {
      print(e.message);
      _showUsage(parser);
      exit(15);
    }

  }

  static _showUsage(parser) {
    print('Usage: $_BINARY_NAME [options...] <libraries to analyze...>');
    print(parser.getUsage());
    print('');
    print('For more information, see https://github.com/TLeth/DartTypeInference.');
  }

  static String _getVersion() {
    try {
      // This is relative to bin/snapshot, so ../..
      String versionPath =
          Platform.script.resolve('../../version').toFilePath();
      File versionFile = new File(versionPath);
      return versionFile.readAsStringSync().trim();
    } catch (_) {
      // This happens when the script is not running in the context of an SDK.
      return "<unknown>";
    }
  }
}

void main(args){
  CommandLineOptions options = CommandLineOptions.parse(args);
  sdk = new DirectoryBasedDartSdk(new JavaFile(options.dartSdkPath));
  try {
    _typeAnnotate(options);
  } catch (e, stackTrace){
    print(e);
    print(stackTrace);
  }
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
  }

}