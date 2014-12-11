library tests.restrict_element;

import 'dart:html';

void foo() {
  CanvasElement a = querySelector("...");
  Function b = a.getContext;
  CanvasRenderingContext c = b("test");
}
