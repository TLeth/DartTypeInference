library list;


class List {
  var head = null;
  var tail = null;

  Empty(ifTrue, ifFalse) {
    if (head == null && tail == null) ifTrue(); else ifFalse();
  }

  List();

  append(el) {
    if (head == null) {
      head = el;
      return this;
    } else {
      var res = new List();
      res.tail = this;
      res.head = el;
      return res;
    }
  }
  
}

class Element {
  Element();
}
test(var a){
  return a;
}

var a = 40;


main() {
  var xs = new List();
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  var ys = test(3.0);
  var a = "str";
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
}