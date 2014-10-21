// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dart2js.ir_builder;

/**
 * This task iterates through all resolved elements and builds [ir.Node]s. The
 * nodes are stored in the [nodes] map and accessible through [hasIr] and
 * [getIr].
 *
 * The functionality of the IrNodes is added gradually, therefore elements might
 * have an IR or not, depending on the language features that are used. For
 * elements that do have an IR, the tree [ast.Node]s and the [Token]s are not
 * used in the rest of the compilation. This is ensured by setting the element's
 * cached tree to `null` and also breaking the token stream to crash future
 * attempts to parse.
 *
 * The type inferrer works on either IR nodes or tree nodes. The IR nodes are
 * then translated into the SSA form for optimizations and code generation.
 * Long-term, once the IR supports the full language, the backend can be
 * re-implemented to work directly on the IR.
 */
class IrBuilderTask extends CompilerTask {
  final Map<Element, ir.FunctionDefinition> nodes =
      <Element, ir.FunctionDefinition>{};

  IrBuilderTask(Compiler compiler) : super(compiler);

  String get name => 'IR builder';

  bool hasIr(Element element) => nodes.containsKey(element.implementation);

  ir.FunctionDefinition getIr(Element element) => nodes[element.implementation];

  void buildNodes({bool useNewBackend: false}) {
    if (!irEnabled(useNewBackend: useNewBackend)) return;
    measure(() {
      Set<Element> resolved = compiler.enqueuer.resolution.resolvedElements;
      resolved.forEach((AstElement element) {
        if (canBuild(element)) {
          TreeElements elementsMapping = element.resolvedAst.elements;
          element = element.implementation;
          compiler.withCurrentElement(element, () {
            SourceFile sourceFile = elementSourceFile(element);
            IrBuilderVisitor builder =
                new IrBuilderVisitor(elementsMapping, compiler, sourceFile);
            ir.FunctionDefinition function;
            function = builder.buildFunction(element);

            if (function != null) {
              nodes[element] = function;
              compiler.tracer.traceCompilation(element.name, null);
              compiler.tracer.traceGraph("IR Builder", function);
            }
          });
        }
      });
    });
  }

  bool irEnabled({bool useNewBackend: false}) {
    // TODO(sigurdm,kmillikin): Support checked-mode checks.
    return (useNewBackend || const bool.fromEnvironment('USE_NEW_BACKEND')) &&
        compiler.backend is DartBackend &&
        !compiler.enableTypeAssertions &&
        !compiler.enableConcreteTypeInference;
  }

  bool canBuild(Element element) {
    FunctionElement function = element.asFunctionElement();
    // TODO(kmillikin,sigurdm): support lazy field initializers.
    if (function == null) return false;

    if (!compiler.backend.shouldOutput(function)) return false;

    assert(invariant(element, !function.isNative));

    // TODO(kmillikin,sigurdm): Support constructors.
    if (function is ConstructorElement) return false;

    return true;
  }

  bool get inCheckedMode {
    bool result = false;
    assert((result = true));
    return result;
  }

  SourceFile elementSourceFile(Element element) {
    if (element is FunctionElement) {
      FunctionElement functionElement = element;
      if (functionElement.patch != null) element = functionElement.patch;
    }
    return element.compilationUnit.script.file;
  }
}

class _GetterElements {
  ir.Primitive result;
  ir.Primitive index;
  ir.Primitive receiver;

  _GetterElements({this.result, this.index, this.receiver}) ;
}

/**
 * A tree visitor that builds [IrNodes]. The visit methods add statements using
 * to the [builder] and return the last added statement for trees that represent
 * an expression.
 */
class IrBuilderVisitor extends ResolvedVisitor<ir.Primitive>
    with IrBuilderMixin {
  final Compiler compiler;
  final SourceFile sourceFile;

  // In SSA terms, join-point continuation parameters are the phis and the
  // continuation invocation arguments are the corresponding phi inputs.  To
  // support name introduction and renaming for source level variables, we use
  // nested (delimited) visitors for constructing subparts of the IR that will
  // need renaming.  Each source variable is assigned an index.
  //
  // Each nested visitor maintains a list of free variable uses in the body.
  // These are implemented as a list of parameters, each with their own use
  // list of references.  When the delimited subexpression is plugged into the
  // surrounding context, the free occurrences can be captured or become free
  // occurrences in the next outer delimited subexpression.
  //
  // Each nested visitor maintains a list that maps indexes of variables
  // assigned in the delimited subexpression to their reaching definition ---
  // that is, the definition in effect at the hole in 'current'.  These are
  // used to determine if a join-point continuation needs to be passed
  // arguments, and what the arguments are.

  /// Construct a top-level visitor.
  IrBuilderVisitor(TreeElements elements, this.compiler, this.sourceFile)
      : super(elements);

  /**
   * Builds the [ir.FunctionDefinition] for a function element. In case the
   * function uses features that cannot be expressed in the IR, this function
   * returns `null`.
   */
  ir.FunctionDefinition buildFunction(FunctionElement functionElement) {
    return nullIfGiveup(() => buildFunctionInternal(functionElement));
  }

  ir.FunctionDefinition buildFunctionInternal(FunctionElement element) {
    assert(invariant(element, element.isImplementation));
    ast.FunctionExpression function = element.node;
    assert(function != null);
    assert(!function.modifiers.isExternal);
    assert(elements[function] != null);

    DetectClosureVariables closureLocals = new DetectClosureVariables(elements);
    closureLocals.visit(function);

    return withBuilder(
        new IrBuilder(compiler.backend.constantSystem,
                      element, closureLocals.usedFromClosure),
        () {
      FunctionSignature signature = element.functionSignature;
      signature.orderedForEachParameter((ParameterElement parameterElement) {
        irBuilder.createParameter(
            parameterElement,
            isClosureVariable: isClosureVariable(parameterElement));
      });

      List<ConstantExpression> defaults = new List<ConstantExpression>();
      signature.orderedOptionalParameters.forEach((ParameterElement element) {
        defaults.add(getConstantForVariable(element));
      });

      visit(function.body);
      return irBuilder.buildFunctionDefinition(element, defaults);
    });
  }

  ir.Primitive visit(ast.Node node) => node.accept(this);

  // ==== Statements ====
  // Build(Block(stamements), C) = C'
  //   where C' = statements.fold(Build, C)
  ir.Primitive visitBlock(ast.Block node) {
    assert(irBuilder.isOpen);
    for (ast.Node n in node.statements.nodes) {
      visit(n);
      if (!irBuilder.isOpen) return null;
    }
    return null;
  }

  ir.Primitive visitBreakStatement(ast.BreakStatement node) {
    if (!irBuilder.buildBreak(elements.getTargetOf(node))) {
      compiler.internalError(node, "'break' target not found");
    }
    return null;
  }

  ir.Primitive visitContinueStatement(ast.ContinueStatement node) {
    if (!irBuilder.buildContinue(elements.getTargetOf(node))) {
      compiler.internalError(node, "'continue' target not found");
    }
    return null;
  }

  // Build(EmptyStatement, C) = C
  ir.Primitive visitEmptyStatement(ast.EmptyStatement node) {
    assert(irBuilder.isOpen);
    return null;
  }

  // Build(ExpressionStatement(e), C) = C'
  //   where (C', _) = Build(e, C)
  ir.Primitive visitExpressionStatement(ast.ExpressionStatement node) {
    assert(irBuilder.isOpen);
    visit(node.expression);
    return null;
  }

  /// Invoke a join-point continuation that contains arguments for all local
  /// variables.
  ///
  /// Given the continuation and a list of uninitialized invocations, fill
  /// in each invocation with the continuation and appropriate arguments.
  void invokeFullJoin(ir.Continuation join,
                      JumpCollector jumps,
                      {recursive: false}) {
    join.isRecursive = recursive;
    for (int i = 0; i < jumps.length; ++i) {
      Environment currentEnvironment = jumps.environments[i];
      ir.InvokeContinuation invoke = jumps.invocations[i];
      invoke.continuation = new ir.Reference(join);
      invoke.arguments = new List<ir.Reference>.generate(
          join.parameters.length,
          (i) => new ir.Reference(currentEnvironment[i]));
      invoke.isRecursive = recursive;
    }
  }

  ir.Primitive visitFor(ast.For node) {
    assert(irBuilder.isOpen);
    // TODO(kmillikin,sigurdm): Handle closure variables declared in a for-loop.
    if (node.initializer is ast.VariableDefinitions) {
      ast.VariableDefinitions definitions = node.initializer;
      for (ast.Node definition in definitions.definitions.nodes) {
        Element element = elements[definition];
        if (isClosureVariable(element)) {
          return giveup(definition, 'Closure variable in for loop initializer');
        }
      }
    }

    // For loops use four named continuations: the entry to the condition,
    // the entry to the body, the loop exit, and the loop successor (break).
    // The CPS translation of
    // [[for (initializer; condition; update) body; successor]] is:
    //
    // [[initializer]];
    // let cont loop(x, ...) =
    //     let prim cond = [[condition]] in
    //     let cont break() = [[successor]] in
    //     let cont exit() = break(v, ...) in
    //     let cont body() =
    //       let cont continue(x, ...) = [[update]]; loop(v, ...) in
    //       [[body]]; continue(v, ...) in
    //     branch cond (body, exit) in
    // loop(v, ...)
    //
    // If there are no breaks in the body, the break continuation is inlined
    // in the exit continuation (i.e., the translation of the successor
    // statement occurs in the exit continuation).  If there is only one
    // invocation of the continue continuation (i.e., no continues in the
    // body), the continue continuation is inlined in the body.

    if (node.initializer != null) visit(node.initializer);

    IrBuilder condBuilder = new IrBuilder.recursive(irBuilder);
    ir.Primitive condition;
    if (node.condition == null) {
      // If the condition is empty then the body is entered unconditionally.
      condition = irBuilder.makePrimConst(
          irBuilder.state.constantSystem.createBool(true));
      condBuilder.add(new ir.LetPrim(condition));
    } else {
      condition = withBuilder(condBuilder, () => visit(node.condition));
    }

    JumpTarget target = elements.getTargetDefinition(node);
    JumpCollector breakCollector = new JumpCollector(target);
    JumpCollector continueCollector = new JumpCollector(target);
    irBuilder.state.breakCollectors.add(breakCollector);
    irBuilder.state.continueCollectors.add(continueCollector);

    IrBuilder bodyBuilder = new IrBuilder.delimited(condBuilder);
    withBuilder(bodyBuilder, () => visit(node.body));
    assert(irBuilder.state.breakCollectors.last == breakCollector);
    assert(irBuilder.state.continueCollectors.last == continueCollector);
    irBuilder.state.breakCollectors.removeLast();
    irBuilder.state.continueCollectors.removeLast();

    // The binding of the continue continuation should occur as late as
    // possible, that is, at the nearest common ancestor of all the continue
    // sites in the body.  However, that is difficult to compute here, so it
    // is instead placed just outside the body of the body continuation.
    bool hasContinues = !continueCollector.isEmpty;
    IrBuilder updateBuilder = hasContinues
        ? new IrBuilder.recursive(condBuilder)
        : bodyBuilder;
    for (ast.Node n in node.update) {
      if (!updateBuilder.isOpen) break;
      withBuilder(updateBuilder, () => visit(n));
    }

    // Create body entry and loop exit continuations and a branch to them.
    ir.Continuation bodyContinuation = new ir.Continuation([]);
    ir.Continuation exitContinuation = new ir.Continuation([]);
    ir.LetCont branch =
        new ir.LetCont(exitContinuation,
            new ir.LetCont(bodyContinuation,
                new ir.Branch(new ir.IsTrue(condition),
                              bodyContinuation,
                              exitContinuation)));
    // If there are breaks in the body, then there must be a join-point
    // continuation for the normal exit and the breaks.
    bool hasBreaks = !breakCollector.isEmpty;
    ir.LetCont letJoin;
    if (hasBreaks) {
      letJoin = new ir.LetCont(null, branch);
      condBuilder.add(letJoin);
      condBuilder._current = branch;
    } else {
      condBuilder.add(branch);
    }
    ir.Continuation continueContinuation;
    if (hasContinues) {
      // If there are continues in the body, we need a named continue
      // continuation as a join point.
      continueContinuation = new ir.Continuation(updateBuilder._parameters);
      if (bodyBuilder.isOpen) continueCollector.addJump(bodyBuilder);
      invokeFullJoin(continueContinuation, continueCollector);
    }
    ir.Continuation loopContinuation =
        new ir.Continuation(condBuilder._parameters);
    if (updateBuilder.isOpen) {
      JumpCollector backEdges = new JumpCollector(null);
      backEdges.addJump(updateBuilder);
      invokeFullJoin(loopContinuation, backEdges, recursive: true);
    }

    // Fill in the body and possible continue continuation bodies.  Do this
    // only after it is guaranteed that they are not empty.
    if (hasContinues) {
      continueContinuation.body = updateBuilder._root;
      bodyContinuation.body =
          new ir.LetCont(continueContinuation, bodyBuilder._root);
    } else {
      bodyContinuation.body = bodyBuilder._root;
    }

    loopContinuation.body = condBuilder._root;
    irBuilder.add(new ir.LetCont(loopContinuation,
            new ir.InvokeContinuation(loopContinuation,
                irBuilder.environment.index2value)));
    if (hasBreaks) {
      irBuilder._current = branch;
      irBuilder.environment = condBuilder.environment;
      breakCollector.addJump(irBuilder);
      letJoin.continuation =
          irBuilder.createJoin(irBuilder.environment.length, breakCollector);
      irBuilder._current = letJoin;
    } else {
      irBuilder._current = condBuilder._current;
      irBuilder.environment = condBuilder.environment;
    }
    return null;
  }

  ir.Primitive visitIf(ast.If node) {
    assert(irBuilder.isOpen);
    ir.Primitive condition = visit(node.condition);

    // The then and else parts are delimited.
    IrBuilder thenBuilder = new IrBuilder.delimited(irBuilder);
    IrBuilder elseBuilder = new IrBuilder.delimited(irBuilder);
    withBuilder(thenBuilder, () => visit(node.thenPart));
    if (node.hasElsePart) {
      withBuilder(elseBuilder, () => visit(node.elsePart));
    }

    // Build the term
    // (Result =) let cont then() = [[thenPart]] in
    //            let cont else() = [[elsePart]] in
    //              if condition (then, else)
    ir.Continuation thenContinuation = new ir.Continuation([]);
    ir.Continuation elseContinuation = new ir.Continuation([]);
    ir.Expression letElse =
        new ir.LetCont(elseContinuation,
          new ir.Branch(new ir.IsTrue(condition),
                        thenContinuation,
                        elseContinuation));
    ir.Expression letThen = new ir.LetCont(thenContinuation, letElse);
    ir.Expression result = letThen;

    ir.Continuation joinContinuation;  // Null if there is no join.
    if (thenBuilder.isOpen && elseBuilder.isOpen) {
      // There is a join-point continuation.  Build the term
      // 'let cont join(x, ...) = [] in Result' and plug invocations of the
      // join-point continuation into the then and else continuations.
      JumpCollector jumps = new JumpCollector(null);
      jumps.addJump(thenBuilder);
      jumps.addJump(elseBuilder);
      joinContinuation =
          irBuilder.createJoin(irBuilder.environment.length, jumps);
      result = new ir.LetCont(joinContinuation, result);
    }

    // The then or else term root could be null, but not both.  If there is
    // a join then an InvokeContinuation was just added to both of them.  If
    // there is no join, then at least one of them is closed and thus has a
    // non-null root by the definition of the predicate isClosed.  In the
    // case that one of them is null, it must be the only one that is open
    // and thus contains the new hole in the context.  This case is handled
    // after the branch is plugged into the current hole.
    thenContinuation.body = thenBuilder._root;
    elseContinuation.body = elseBuilder._root;

    irBuilder.add(result);
    if (joinContinuation == null) {
      // At least one subexpression is closed.
      if (thenBuilder.isOpen) {
        irBuilder._current =
            (thenBuilder._root == null) ? letThen : thenBuilder._current;
        irBuilder.environment = thenBuilder.environment;
      } else if (elseBuilder.isOpen) {
        irBuilder._current =
            (elseBuilder._root == null) ? letElse : elseBuilder._current;
        irBuilder.environment = elseBuilder.environment;
      } else {
        irBuilder._current = null;
      }
    }
    return null;
  }

  ir.Primitive visitLabeledStatement(ast.LabeledStatement node) {
    ast.Statement body = node.statement;
    return body is ast.Loop
        ? visit(body)
        : giveup(node, 'labeled statement');
  }

  ir.Primitive visitWhile(ast.While node) {
    assert(irBuilder.isOpen);
    // While loops use four named continuations: the entry to the body, the
    // loop exit, the loop back edge (continue), and the loop exit (break).
    // The CPS translation of [[while (condition) body; successor]] is:
    //
    // let cont continue(x, ...) =
    //     let prim cond = [[condition]] in
    //     let cont break() = [[successor]] in
    //     let cont exit() = break(v, ...) in
    //     let cont body() = [[body]]; continue(v, ...) in
    //     branch cond (body, exit) in
    // continue(v, ...)
    //
    // If there are no breaks in the body, the break continuation is inlined
    // in the exit continuation (i.e., the translation of the successor
    // statement occurs in the exit continuation).

    // The condition and body are delimited.
    IrBuilder condBuilder = new IrBuilder.recursive(irBuilder);
    ir.Primitive condition =
        withBuilder(condBuilder, () => visit(node.condition));

    JumpTarget target = elements.getTargetDefinition(node);
    JumpCollector breakCollector = new JumpCollector(target);
    JumpCollector continueCollector = new JumpCollector(target);
    irBuilder.state.breakCollectors.add(breakCollector);
    irBuilder.state.continueCollectors.add(continueCollector);

    IrBuilder bodyBuilder = new IrBuilder.delimited(condBuilder);
    withBuilder(bodyBuilder, () => visit(node.body));
    assert(irBuilder.state.breakCollectors.last == breakCollector);
    assert(irBuilder.state.continueCollectors.last == continueCollector);
    irBuilder.state.breakCollectors.removeLast();
    irBuilder.state.continueCollectors.removeLast();

    // Create body entry and loop exit continuations and a branch to them.
    ir.Continuation bodyContinuation = new ir.Continuation([]);
    ir.Continuation exitContinuation = new ir.Continuation([]);
    ir.LetCont branch =
        new ir.LetCont(exitContinuation,
            new ir.LetCont(bodyContinuation,
                new ir.Branch(new ir.IsTrue(condition),
                              bodyContinuation,
                              exitContinuation)));
    // If there are breaks in the body, then there must be a join-point
    // continuation for the normal exit and the breaks.
    bool hasBreaks = !breakCollector.isEmpty;
    ir.LetCont letJoin;
    if (hasBreaks) {
      letJoin = new ir.LetCont(null, branch);
      condBuilder.add(letJoin);
      condBuilder._current = branch;
    } else {
      condBuilder.add(branch);
    }
    ir.Continuation loopContinuation =
        new ir.Continuation(condBuilder._parameters);
    if (bodyBuilder.isOpen) continueCollector.addJump(bodyBuilder);
    invokeFullJoin(loopContinuation, continueCollector, recursive: true);
    bodyContinuation.body = bodyBuilder._root;

    loopContinuation.body = condBuilder._root;
    irBuilder.add(new ir.LetCont(loopContinuation,
            new ir.InvokeContinuation(loopContinuation,
                                      irBuilder.environment.index2value)));
    if (hasBreaks) {
      irBuilder._current = branch;
      irBuilder.environment = condBuilder.environment;
      breakCollector.addJump(irBuilder);
      letJoin.continuation =
          irBuilder.createJoin(irBuilder.environment.length, breakCollector);
      irBuilder._current = letJoin;
    } else {
      irBuilder._current = condBuilder._current;
      irBuilder.environment = condBuilder.environment;
    }
    return null;
  }

  ir.Primitive visitForIn(ast.ForIn node) {
    // The for-in loop
    //
    // for (a in e) s;
    //
    // Is compiled analogously to:
    //
    // a = e.iterator;
    // while (a.moveNext()) {
    //   var n0 = a.current;
    //   s;
    // }

    // The condition and body are delimited.
    IrBuilder condBuilder = new IrBuilder.recursive(irBuilder);

    ir.Primitive expressionReceiver = visit(node.expression);
    List<ir.Primitive> emptyArguments = new List<ir.Primitive>();

    ir.Parameter iterator = new ir.Parameter(null);
    ir.Continuation iteratorInvoked = new ir.Continuation([iterator]);
    irBuilder.add(new ir.LetCont(iteratorInvoked,
        new ir.InvokeMethod(expressionReceiver,
            new Selector.getter("iterator", null), iteratorInvoked,
            emptyArguments)));

    ir.Parameter condition = new ir.Parameter(null);
    ir.Continuation moveNextInvoked = new ir.Continuation([condition]);
    condBuilder.add(new ir.LetCont(moveNextInvoked,
        new ir.InvokeMethod(iterator,
            new Selector.call("moveNext", null, 0),
            moveNextInvoked, emptyArguments)));

    JumpTarget target = elements.getTargetDefinition(node);
    JumpCollector breakCollector = new JumpCollector(target);
    JumpCollector continueCollector = new JumpCollector(target);
    irBuilder.state.breakCollectors.add(breakCollector);
    irBuilder.state.continueCollectors.add(continueCollector);

    IrBuilder bodyBuilder = new IrBuilder.delimited(condBuilder);
    ast.Node identifier = node.declaredIdentifier;
    Element variableElement = elements.getForInVariable(node);
    Selector selector = elements.getSelector(identifier);

    // node.declaredIdentifier can be either an ast.VariableDefinitions
    // (defining a new local variable) or a send designating some existing
    // variable.
    ast.Node declaredIdentifier = node.declaredIdentifier;

    if (declaredIdentifier is ast.VariableDefinitions) {
      withBuilder(bodyBuilder, () => visit(declaredIdentifier));
    }

    ir.Parameter currentValue = new ir.Parameter(null);
    ir.Continuation currentInvoked = new ir.Continuation([currentValue]);
    bodyBuilder.add(new ir.LetCont(currentInvoked,
        new ir.InvokeMethod(iterator, new Selector.getter("current", null),
            currentInvoked, emptyArguments)));
    if (Elements.isLocal(variableElement)) {
      withBuilder(bodyBuilder, () => setLocal(variableElement, currentValue));
    } else if (Elements.isStaticOrTopLevel(variableElement)) {
      withBuilder(bodyBuilder,
          () => setStatic(variableElement, selector, currentValue));
    } else {
      ir.Primitive receiver =
          withBuilder(bodyBuilder, () => lookupThis());
      withBuilder(bodyBuilder,
          () => setDynamic(null, receiver, selector, currentValue));
    }

    withBuilder(bodyBuilder, () => visit(node.body));
    assert(irBuilder.state.breakCollectors.last == breakCollector);
    assert(irBuilder.state.continueCollectors.last == continueCollector);
    irBuilder.state.breakCollectors.removeLast();
    irBuilder.state.continueCollectors.removeLast();

    // Create body entry and loop exit continuations and a branch to them.
    ir.Continuation bodyContinuation = new ir.Continuation([]);
    ir.Continuation exitContinuation = new ir.Continuation([]);
    ir.LetCont branch =
        new ir.LetCont(exitContinuation,
            new ir.LetCont(bodyContinuation,
                new ir.Branch(new ir.IsTrue(condition),
                              bodyContinuation,
                              exitContinuation)));
    // If there are breaks in the body, then there must be a join-point
    // continuation for the normal exit and the breaks.
    bool hasBreaks = !breakCollector.isEmpty;
    ir.LetCont letJoin;
    if (hasBreaks) {
      letJoin = new ir.LetCont(null, branch);
      condBuilder.add(letJoin);
      condBuilder._current = branch;
    } else {
      condBuilder.add(branch);
    }
    ir.Continuation loopContinuation =
        new ir.Continuation(condBuilder._parameters);
    if (bodyBuilder.isOpen) continueCollector.addJump(bodyBuilder);
    invokeFullJoin(loopContinuation, continueCollector, recursive: true);
    bodyContinuation.body = bodyBuilder._root;

    loopContinuation.body = condBuilder._root;
    irBuilder.add(new ir.LetCont(loopContinuation,
            new ir.InvokeContinuation(loopContinuation,
                                      irBuilder.environment.index2value)));
    if (hasBreaks) {
      irBuilder._current = branch;
      irBuilder.environment = condBuilder.environment;
      breakCollector.addJump(irBuilder);
      letJoin.continuation =
          irBuilder.createJoin(irBuilder.environment.length, breakCollector);
      irBuilder._current = letJoin;
    } else {
      irBuilder._current = condBuilder._current;
      irBuilder.environment = condBuilder.environment;
    }
    return null;
  }

  ir.Primitive visitVariableDefinitions(ast.VariableDefinitions node) {
    assert(irBuilder.isOpen);
    if (node.modifiers.isConst) {
      for (ast.SendSet definition in node.definitions.nodes) {
        assert(!definition.arguments.isEmpty);
        assert(definition.arguments.tail.isEmpty);
        VariableElement element = elements[definition];
        ConstantExpression value = getConstantForVariable(element);
        irBuilder.declareLocalConstant(element, value);
      }
    } else {
      for (ast.Node definition in node.definitions.nodes) {
        Element element = elements[definition];
        ir.Primitive initialValue;
        // Definitions are either SendSets if there is an initializer, or
        // Identifiers if there is no initializer.
        if (definition is ast.SendSet) {
          assert(!definition.arguments.isEmpty);
          assert(definition.arguments.tail.isEmpty);
          initialValue = visit(definition.arguments.head);
        } else {
          assert(definition is ast.Identifier);
        }
        irBuilder.declareLocalVariable(element,
            initialValue: initialValue,
            isClosureVariable: isClosureVariable(element));
      }
    }
    return null;
  }

  // Build(Return(e), C) = C'[InvokeContinuation(return, x)]
  //   where (C', x) = Build(e, C)
  //
  // Return without a subexpression is translated as if it were return null.
  ir.Primitive visitReturn(ast.Return node) {
    assert(irBuilder.isOpen);
    assert(invariant(node, node.beginToken.value != 'native'));
    if (node.expression == null) {
      irBuilder.buildReturn();
    } else {
      irBuilder.buildReturn(visit(node.expression));
    }
    return null;
  }

  // ==== Expressions ====
  ir.Primitive visitConditional(ast.Conditional node) {
    assert(irBuilder.isOpen);
    ir.Primitive condition = visit(node.condition);

    // The then and else expressions are delimited.
    IrBuilder thenBuilder = new IrBuilder.delimited(irBuilder);
    IrBuilder elseBuilder = new IrBuilder.delimited(irBuilder);
    ir.Primitive thenValue =
        withBuilder(thenBuilder, () => visit(node.thenExpression));
    ir.Primitive elseValue =
        withBuilder(elseBuilder, () => visit(node.elseExpression));

    // Treat the values of the subexpressions as named values in the
    // environment, so they will be treated as arguments to the join-point
    // continuation.
    assert(irBuilder.environment.length == thenBuilder.environment.length);
    assert(irBuilder.environment.length == elseBuilder.environment.length);
    thenBuilder.environment.extend(null, thenValue);
    elseBuilder.environment.extend(null, elseValue);
    JumpCollector jumps = new JumpCollector(null);
    jumps.addJump(thenBuilder);
    jumps.addJump(elseBuilder);
    ir.Continuation joinContinuation =
        irBuilder.createJoin(irBuilder.environment.length + 1, jumps);

    // Build the term
    //   let cont join(x, ..., result) = [] in
    //   let cont then() = [[thenPart]]; join(v, ...) in
    //   let cont else() = [[elsePart]]; join(v, ...) in
    //     if condition (then, else)
    ir.Continuation thenContinuation = new ir.Continuation([]);
    ir.Continuation elseContinuation = new ir.Continuation([]);
    thenContinuation.body = thenBuilder._root;
    elseContinuation.body = elseBuilder._root;
    irBuilder.add(new ir.LetCont(joinContinuation,
            new ir.LetCont(thenContinuation,
                new ir.LetCont(elseContinuation,
                    new ir.Branch(new ir.IsTrue(condition),
                                  thenContinuation,
                                  elseContinuation)))));
    return (thenValue == elseValue)
        ? thenValue
        : joinContinuation.parameters.last;
  }

  // For all simple literals:
  // Build(Literal(c), C) = C[let val x = Constant(c) in [], x]
  ir.Primitive visitLiteralBool(ast.LiteralBool node) {
    assert(irBuilder.isOpen);
    return translateConstant(node);
  }

  ir.Primitive visitLiteralDouble(ast.LiteralDouble node) {
    assert(irBuilder.isOpen);
    return translateConstant(node);
  }

  ir.Primitive visitLiteralInt(ast.LiteralInt node) {
    assert(irBuilder.isOpen);
    return translateConstant(node);
  }

  ir.Primitive visitLiteralNull(ast.LiteralNull node) {
    assert(irBuilder.isOpen);
    return translateConstant(node);
  }

  ir.Primitive visitLiteralString(ast.LiteralString node) {
    assert(irBuilder.isOpen);
    return translateConstant(node);
  }

  ConstantExpression getConstantForNode(ast.Node node) {
    ConstantExpression constant =
        compiler.backend.constantCompilerTask.compileNode(node, elements);
    assert(invariant(node, constant != null,
        message: 'No constant computed for $node'));
    return constant;
  }

  ConstantExpression getConstantForVariable(VariableElement element) {
    ConstantExpression constant =
        compiler.backend.constants.getConstantForVariable(element);
    assert(invariant(element, constant != null,
            message: 'No constant computed for $element'));
    return constant;
  }

  ir.Primitive visitLiteralList(ast.LiteralList node) {
    assert(irBuilder.isOpen);
    if (node.isConst) {
      return translateConstant(node);
    }
    List<ir.Primitive> values = node.elements.nodes.mapToList(visit);
    GenericType type = elements.getType(node);
    ir.Primitive result = new ir.LiteralList(type, values);
    irBuilder.add(new ir.LetPrim(result));
    return result;
  }

  ir.Primitive visitLiteralMap(ast.LiteralMap node) {
    assert(irBuilder.isOpen);
    if (node.isConst) {
      return translateConstant(node);
    }
    List<ir.Primitive> keys = new List<ir.Primitive>();
    List<ir.Primitive> values = new List<ir.Primitive>();
    node.entries.nodes.forEach((ast.LiteralMapEntry node) {
      keys.add(visit(node.key));
      values.add(visit(node.value));
    });
    GenericType type = elements.getType(node);
    ir.Primitive result = new ir.LiteralMap(type, keys, values);
    irBuilder.add(new ir.LetPrim(result));
    return result;
  }

  ir.Primitive visitLiteralSymbol(ast.LiteralSymbol node) {
    assert(irBuilder.isOpen);
    return translateConstant(node);
  }

  ir.Primitive visitIdentifier(ast.Identifier node) {
    assert(irBuilder.isOpen);
    // "this" is the only identifier that should be met by the visitor.
    assert(node.isThis());
    return lookupThis();
  }

  ir.Primitive visitParenthesizedExpression(
      ast.ParenthesizedExpression node) {
    assert(irBuilder.isOpen);
    return visit(node.expression);
  }

  // Stores the result of visiting a CascadeReceiver, so we can return it from
  // its enclosing Cascade.
  ir.Primitive _currentCascadeReceiver;

  ir.Primitive visitCascadeReceiver(ast.CascadeReceiver node) {
    assert(irBuilder.isOpen);
    return _currentCascadeReceiver = visit(node.expression);
  }

  ir.Primitive visitCascade(ast.Cascade node) {
    assert(irBuilder.isOpen);
    var oldCascadeReceiver = _currentCascadeReceiver;
    // Throw away the result of visiting the expression.
    // Instead we return the result of visiting the CascadeReceiver.
    this.visit(node.expression);
    ir.Primitive receiver = _currentCascadeReceiver;
    _currentCascadeReceiver = oldCascadeReceiver;
    return receiver;
  }

  ir.Primitive lookupThis() {
    ir.Primitive result = new ir.This();
    irBuilder.add(new ir.LetPrim(result));
    return result;
  }

  // ==== Sends ====
  ir.Primitive visitAssert(ast.Send node) {
    assert(irBuilder.isOpen);
    return giveup(node, 'Assert');
  }

  ir.Primitive visitNamedArgument(ast.NamedArgument node) {
    assert(irBuilder.isOpen);
    return visit(node.expression);
  }

  ir.Primitive translateClosureCall(ir.Primitive receiver,
                                    Selector closureSelector,
                                    ast.NodeList arguments) {
    Selector namedCallSelector = new Selector(closureSelector.kind,
                     "call",
                     closureSelector.library,
                     closureSelector.argumentCount,
                     closureSelector.namedArguments);
    List<ir.Primitive> args = arguments.nodes.mapToList(visit, growable:false);
    return irBuilder.continueWithExpression(
        (k) => new ir.InvokeMethod(receiver, namedCallSelector, k, args));
  }

  ir.Primitive visitClosureSend(ast.Send node) {
    assert(irBuilder.isOpen);
    Element element = elements[node];
    ir.Primitive closureTarget;
    if (element == null) {
      closureTarget = visit(node.selector);
    } else if (isClosureVariable(element)) {
      LocalElement local = element;
      closureTarget = new ir.GetClosureVariable(local);
      irBuilder.add(new ir.LetPrim(closureTarget));
    } else {
      assert(Elements.isLocal(element));
      closureTarget = irBuilder.environment.lookup(element);
    }
    Selector closureSelector = elements.getSelector(node);
    return translateClosureCall(closureTarget, closureSelector,
        node.argumentsNode);
  }

  /// If [node] is null, returns this.
  /// If [node] is super, returns null (for special handling)
  /// Otherwise visits [node] and returns the result.
  ir.Primitive visitReceiver(ast.Expression node) {
    if (node == null) return lookupThis();
    if (node.isSuper()) return null;
    return visit(node);
  }

  /// Makes an [InvokeMethod] unless [node.receiver.isSuper()], in that case
  /// makes an [InvokeSuperMethod] ignoring [receiver].
  ir.Expression createDynamicInvoke(ast.Send node,
                                    Selector selector,
                                    ir.Definition receiver,
                                    ir.Continuation k,
                                    List<ir.Definition> arguments) {
    return node != null && node.receiver != null && node.receiver.isSuper()
        ? new ir.InvokeSuperMethod(selector, k, arguments)
        : new ir.InvokeMethod(receiver, selector, k, arguments);
  }

  ir.Primitive visitDynamicSend(ast.Send node) {
    assert(irBuilder.isOpen);
    Selector selector = elements.getSelector(node);
    ir.Primitive receiver = visitReceiver(node.receiver);
    List<ir.Primitive> arguments = new List<ir.Primitive>();
    for (ast.Node n in node.arguments) {
      arguments.add(visit(n));
    }
    return irBuilder.buildDynamicInvocation(receiver, selector, arguments);
  }

  _GetterElements translateGetter(ast.Send node, Selector selector) {
    Element element = elements[node];
    ir.Primitive result;
    ir.Primitive receiver;
    ir.Primitive index;

    if (element != null && element.isConst) {
      // Reference to constant local, top-level or static field
      result = translateConstant(node);
    } else if (isClosureVariable(element)) {
      LocalElement local = element;
      result = new ir.GetClosureVariable(local);
      irBuilder.add(new ir.LetPrim(result));
    } else if (Elements.isLocal(element)) {
      // Reference to local variable
      result = irBuilder.buildLocalGet(element);
    } else if (element == null ||
               Elements.isInstanceField(element) ||
               Elements.isInstanceMethod(element) ||
               selector.isIndex ||
               // TODO(johnniwinther): clean up semantics of resolution.
               node.isSuperCall) {
      // Dynamic dispatch to a getter. Sometimes resolution will suggest a
      // target element, but in these cases we must still emit a dynamic
      // dispatch. The target element may be an instance method in case we are
      // converting a method to a function object.

      receiver = visitReceiver(node.receiver);
      List<ir.Primitive> arguments = new List<ir.Primitive>();
      if (selector.isIndex) {
        index = visit(node.arguments.head);
        arguments.add(index);
      }

      assert(selector.kind == SelectorKind.GETTER ||
             selector.kind == SelectorKind.INDEX);
      result = irBuilder.continueWithExpression(
          (k) => createDynamicInvoke(node, selector, receiver, k, arguments));
    } else if (element.isField || element.isGetter || element.isErroneous ||
               element.isSetter) {
      // TODO(johnniwinther): Change handling of setter selectors.
      // Access to a static field or getter (non-static case handled above).
      // Even if there is only a setter, we compile as if it was a getter,
      // so the vm can fail at runtime.
      assert(selector.kind == SelectorKind.GETTER ||
             selector.kind == SelectorKind.SETTER);
      result = irBuilder.buildStaticGet(element, selector);
    } else if (Elements.isStaticOrTopLevelFunction(element)) {
      // Convert a top-level or static function to a function object.
      result = translateConstant(node);
    } else {
      throw "Unexpected SendSet getter: $node, $element";
    }
    return new _GetterElements(
        result: result,index: index, receiver: receiver);
  }

  ir.Primitive visitGetterSend(ast.Send node) {
    assert(irBuilder.isOpen);
    return translateGetter(node, elements.getSelector(node)).result;

  }

  ir.Primitive translateLogicalOperator(ast.Operator op,
                                        ast.Expression left,
                                        ast.Expression right) {
    ir.Primitive leftValue = visit(left);

    ir.Primitive buildRightValue(IrBuilder rightBuilder) {
      return withBuilder(rightBuilder, () => visit(right));
    }

    return irBuilder.buildLogicalOperator(
        leftValue, buildRightValue, isLazyOr: op.source == '||');
  }

  ir.Primitive visitOperatorSend(ast.Send node) {
    assert(irBuilder.isOpen);
    ast.Operator op = node.selector;
    if (isUserDefinableOperator(op.source)) {
      return visitDynamicSend(node);
    }
    if (op.source == '&&' || op.source == '||') {
      assert(node.receiver != null);
      assert(!node.arguments.isEmpty);
      assert(node.arguments.tail.isEmpty);
      return translateLogicalOperator(op, node.receiver, node.arguments.head);
    }
    if (op.source == "!") {
      assert(node.receiver != null);
      assert(node.arguments.isEmpty);
      return irBuilder.buildNegation(visit(node.receiver));
    }
    if (op.source == "!=") {
      assert(node.receiver != null);
      assert(!node.arguments.isEmpty);
      assert(node.arguments.tail.isEmpty);
      return irBuilder.buildNegation(visitDynamicSend(node));
    }
    assert(invariant(node, op.source == "is" || op.source == "as",
           message: "unexpected operator $op"));
    DartType type = elements.getType(node.typeAnnotationFromIsCheckOrCast);
    ir.Primitive receiver = visit(node.receiver);
    ir.Primitive check = irBuilder.continueWithExpression(
        (k) => new ir.TypeOperator(op.source, receiver, type, k));
    return node.isIsNotCheck ? irBuilder.buildNegation(check) : check;
  }

  // Build(StaticSend(f, arguments), C) = C[C'[InvokeStatic(f, xs)]]
  //   where (C', xs) = arguments.fold(Build, C)
  ir.Primitive visitStaticSend(ast.Send node) {
    assert(irBuilder.isOpen);
    Element element = elements[node];
    assert(!element.isConstructor);
    // TODO(lry): support foreign functions.
    if (element.isForeign(compiler.backend)) {
      return giveup(node, 'StaticSend: foreign');
    }

    Selector selector = elements.getSelector(node);

    // TODO(lry): support default arguments, need support for locals.
    List<ir.Definition> arguments = node.arguments.mapToList(visit,
                                                             growable:false);
    return irBuilder.buildStaticInvocation(element, selector, arguments);
  }


  ir.Primitive visitSuperSend(ast.Send node) {
    assert(irBuilder.isOpen);
    if (node.isPropertyAccess) {
      return visitGetterSend(node);
    } else {
      Selector selector = elements.getSelector(node);
      List<ir.Primitive> arguments = new List<ir.Primitive>();
      for (ast.Node n in node.arguments) {
        arguments.add(visit(n));
      }
      return irBuilder.buildSuperInvocation(selector, arguments);
    }
  }

  visitTypePrefixSend(ast.Send node) {
    compiler.internalError(node, "visitTypePrefixSend should not be called.");
  }

  ir.Primitive visitTypeLiteralSend(ast.Send node) {
    assert(irBuilder.isOpen);
    // If the user is trying to invoke the type literal or variable,
    // it must be treated as a function call.
    if (node.argumentsNode != null) {
      // TODO(sigurdm): Handle this to match proposed semantics of issue #19725.
      return giveup(node, 'Type literal invoked as function');
    }

    DartType type = elements.getTypeLiteralType(node);
    if (type is TypeVariableType) {
      ir.Primitive prim = new ir.ReifyTypeVar(type.element);
      irBuilder.add(new ir.LetPrim(prim));
      return prim;
    } else {
      return translateConstant(node);
    }
  }

  /// True if [element] is a local variable, local function, or parameter that
  /// is accessed from an inner function. Recursive self-references in a local
  /// function count as closure accesses.
  ///
  /// If `true`, [element] is a [LocalElement].
  bool isClosureVariable(Element element) {
    return irBuilder.state.closureLocals.contains(element);
  }

  void setLocal(Element element, ir.Primitive valueToStore) {
    if (isClosureVariable(element)) {
      LocalElement local = element;
      irBuilder.add(new ir.SetClosureVariable(local, valueToStore));
    } else {
      valueToStore.useElementAsHint(element);
      irBuilder.environment.update(element, valueToStore);
    }
  }

  void setStatic(Element element,
                 Selector selector,
                 ir.Primitive valueToStore) {
    assert(element.isErroneous || element.isField || element.isSetter);
    irBuilder.continueWithExpression(
        (k) => new ir.InvokeStatic(element, selector, k, [valueToStore]));
  }

  void setDynamic(ast.Node node,
                  ir.Primitive receiver, Selector selector,
                  ir.Primitive valueToStore) {
    List<ir.Definition> arguments = [valueToStore];
    irBuilder.continueWithExpression(
        (k) => createDynamicInvoke(node, selector, receiver, k, arguments));
  }

  void setIndex(ast.Node node,
                ir.Primitive receiver,
                Selector selector,
                ir.Primitive index,
                ir.Primitive valueToStore) {
    List<ir.Definition> arguments = [index, valueToStore];
    irBuilder.continueWithExpression(
        (k) => createDynamicInvoke(node, selector, receiver, k, arguments));
  }

  ir.Primitive visitSendSet(ast.SendSet node) {
    assert(irBuilder.isOpen);
    Element element = elements[node];
    ast.Operator op = node.assignmentOperator;
    // For complex operators, this is the result of getting (before assigning)
    ir.Primitive originalValue;
    // For []+= style operators, this saves the index.
    ir.Primitive index;
    ir.Primitive receiver;
    // This is what gets assigned.
    ir.Primitive valueToStore;
    Selector selector = elements.getSelector(node);
    Selector operatorSelector =
        elements.getOperatorSelectorInComplexSendSet(node);
    Selector getterSelector =
        elements.getGetterSelectorInComplexSendSet(node);
    assert(
        // Indexing send-sets have an argument for the index.
        (selector.isIndexSet ? 1 : 0) +
        // Non-increment send-sets have one more argument.
        (ast.Operator.INCREMENT_OPERATORS.contains(op.source) ? 0 : 1)
            == node.argumentCount());

    ast.Node getAssignArgument() {
      assert(invariant(node, !node.arguments.isEmpty,
                       message: "argument expected"));
      return selector.isIndexSet
          ? node.arguments.tail.head
          : node.arguments.head;
    }

    // Get the value into valueToStore
    if (op.source == "=") {
      if (selector.isIndexSet) {
        receiver = visitReceiver(node.receiver);
        index = visit(node.arguments.head);
      } else if (element == null || Elements.isInstanceField(element)) {
        receiver = visitReceiver(node.receiver);
      }
      valueToStore = visit(getAssignArgument());
    } else {
      // Get the original value into getter
      assert(ast.Operator.COMPLEX_OPERATORS.contains(op.source));

      _GetterElements getterResult = translateGetter(node, getterSelector);
      index = getterResult.index;
      receiver = getterResult.receiver;
      originalValue = getterResult.result;

      // Do the modification of the value in getter.
      ir.Primitive arg;
      if (ast.Operator.INCREMENT_OPERATORS.contains(op.source)) {
        arg = irBuilder.makePrimConst(
            irBuilder.state.constantSystem.createInt(1));
        irBuilder.add(new ir.LetPrim(arg));
      } else {
        arg = visit(getAssignArgument());
      }
      valueToStore = new ir.Parameter(null);
      ir.Continuation k = new ir.Continuation([valueToStore]);
      ir.Expression invoke =
          new ir.InvokeMethod(originalValue, operatorSelector, k, [arg]);
      irBuilder.add(new ir.LetCont(k, invoke));
    }

    if (Elements.isLocal(element)) {
      setLocal(element, valueToStore);
    } else if ((!node.isSuperCall && Elements.isErroneousElement(element)) ||
                Elements.isStaticOrTopLevel(element)) {
      setStatic(element, elements.getSelector(node), valueToStore);
    } else {
      // Setter or index-setter invocation
      Selector selector = elements.getSelector(node);
      assert(selector.kind == SelectorKind.SETTER ||
          selector.kind == SelectorKind.INDEX);
      if (selector.isIndexSet) {
        setIndex(node, receiver, selector, index, valueToStore);
      } else {
        setDynamic(node, receiver, selector, valueToStore);
      }
    }

    if (node.isPostfix) {
      assert(originalValue != null);
      return originalValue;
    } else {
      return valueToStore;
    }
  }

  ir.Primitive visitNewExpression(ast.NewExpression node) {
    assert(irBuilder.isOpen);
    if (node.isConst) {
      return translateConstant(node);
    }
    FunctionElement element = elements[node.send];
    Selector selector = elements.getSelector(node.send);
    ast.Node selectorNode = node.send.selector;
    DartType type = elements.getType(node);
    List<ir.Primitive> args =
        node.send.arguments.mapToList(visit, growable:false);
    return irBuilder.continueWithExpression(
        (k) => new ir.InvokeConstructor(type, element,selector, k, args));
  }

  ir.Primitive visitStringJuxtaposition(ast.StringJuxtaposition node) {
    assert(irBuilder.isOpen);
    ir.Primitive first = visit(node.first);
    ir.Primitive second = visit(node.second);
    return irBuilder.continueWithExpression(
        (k) => new ir.ConcatenateStrings(k, [first, second]));
  }

  ir.Primitive visitStringInterpolation(ast.StringInterpolation node) {
    assert(irBuilder.isOpen);
    List<ir.Primitive> arguments = [];
    arguments.add(visitLiteralString(node.string));
    var it = node.parts.iterator;
    while (it.moveNext()) {
      ast.StringInterpolationPart part = it.current;
      arguments.add(visit(part.expression));
      arguments.add(visitLiteralString(part.string));
    }
    return irBuilder.continueWithExpression(
        (k) => new ir.ConcatenateStrings(k, arguments));
  }

  ir.Primitive translateConstant(ast.Node node, [ConstantExpression constant]) {
    assert(irBuilder.isOpen);
    if (constant == null) {
      constant = getConstantForNode(node);
    }
    ir.Primitive primitive = irBuilder.makeConst(constant);
    irBuilder.add(new ir.LetPrim(primitive));
    return primitive;
  }

  ir.FunctionDefinition makeSubFunction(ast.FunctionExpression node) {
    // TODO(johnniwinther): Share the visitor.
    return new IrBuilderVisitor(elements, compiler, sourceFile)
           .buildFunctionInternal(elements[node]);
  }

  ir.Primitive visitFunctionExpression(ast.FunctionExpression node) {
    FunctionElement element = elements[node];
    ir.FunctionDefinition inner = makeSubFunction(node);
    ir.CreateFunction prim = new ir.CreateFunction(inner);
    irBuilder.add(new ir.LetPrim(prim));
    return prim;
  }

  ir.Primitive visitFunctionDeclaration(ast.FunctionDeclaration node) {
    LocalFunctionElement element = elements[node.function];
    ir.FunctionDefinition inner = makeSubFunction(node.function);
    if (isClosureVariable(element)) {
      irBuilder.add(new ir.DeclareFunction(element, inner));
    } else {
      ir.CreateFunction prim = new ir.CreateFunction(inner);
      irBuilder.add(new ir.LetPrim(prim));
      irBuilder.environment.extend(element, prim);
      prim.useElementAsHint(element);
    }
    return null;
  }

  static final String ABORT_IRNODE_BUILDER = "IrNode builder aborted";

  dynamic giveup(ast.Node node, [String reason]) {
    throw ABORT_IRNODE_BUILDER;
  }

  ir.FunctionDefinition nullIfGiveup(ir.FunctionDefinition action()) {
    try {
      return action();
    } catch(e, tr) {
      if (e == ABORT_IRNODE_BUILDER) {
        return null;
      }
      rethrow;
    }
  }

  void internalError(String reason, {ast.Node node}) {
    giveup(node);
  }
}

/// Classifies local variables and local functions as 'closure variables'.
/// A closure variable is one that is accessed from an inner function nested
/// one or more levels inside the one that declares it.
class DetectClosureVariables extends ast.Visitor {
  final TreeElements elements;
  DetectClosureVariables(this.elements);

  FunctionElement currentFunction;
  Set<Local> usedFromClosure = new Set<Local>();
  Set<FunctionElement> recursiveFunctions = new Set<FunctionElement>();

  bool isClosureVariable(Entity entity) => usedFromClosure.contains(entity);

  void markAsClosureVariable(Local local) {
    usedFromClosure.add(local);
  }

  visit(ast.Node node) => node.accept(this);

  visitNode(ast.Node node) {
    node.visitChildren(this);
  }

  visitSend(ast.Send node) {
    Element element = elements[node];
    if (Elements.isLocal(element) &&
        !element.isConst &&
        element.enclosingElement != currentFunction) {
      LocalElement local = element;
      markAsClosureVariable(local);
    }
    node.visitChildren(this);
  }

  visitFunctionExpression(ast.FunctionExpression node) {
    FunctionElement oldFunction = currentFunction;
    currentFunction = elements[node];
    visit(node.body);
    currentFunction = oldFunction;
  }

}
