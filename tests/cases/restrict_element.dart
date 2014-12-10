library tests.restrict_element;

import 'dart:html';

void foo() {
  Element a = querySelector("...");
  if (a is CanvasElement) {
    Function b = a.getContext;
    CanvasRenderingContext c = b("test");
  }
}
