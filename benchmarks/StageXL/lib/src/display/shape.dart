part of stagexl.display;

class Shape extends DisplayObject {

  Graphics _graphics = new Graphics();

  Graphics get graphics => _graphics;
  set graphics(Graphics value) => _graphics = value;

  //-----------------------------------------------------------------------------------------------

  Rectangle<num> getBoundsTransformed(Matrix matrix, [Rectangle<num> returnRectangle]) {
    if (_graphics == null) {
      return super.getBoundsTransformed(matrix, returnRectangle);
    } else {
      return _graphics._getBoundsTransformed(matrix);
    }
  }

  //-----------------------------------------------------------------------------------------------

  DisplayObject hitTestInput(num localX, num localY) {
    if (_graphics == null) {
      return null;
    } else {
      return _graphics._hitTestInput(localX, localY) ? this : null;
    }
  }

  //-----------------------------------------------------------------------------------------------

  void render(RenderState renderState) {
    if (_graphics != null) _graphics.render(renderState);
  }

}
