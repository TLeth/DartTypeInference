library list;

class List {
  Element head = null;
  List tail = null;
  
  void Empty(Function ifTrue,Function ifFalse) {
    if (head == null && tail == null)
      ifTrue();
    else
      ifFalse();
  }
  
  List();
  
  List append(Element el){
    if (head == null) {
      head = el;
      return this;
    } else {
      List res = new List();
      res.tail = this;
      res.head = el;
      return res;
    }
  }
  
  /*String toString(){
    String res = "[";
    List l = this;
    while(l != null && l.head != null){
      res += "${l.head.hashCode}, ";
      l = l.tail;
    }
    return res.substring(0, res.length-2) + "]";
  }*/
}

class Element {
  
}


void main() {
  List xs = new List();
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
  xs = xs.append(new Element());
}