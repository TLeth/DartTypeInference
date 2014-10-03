library test.Scoping;



var foo;


test(foo) {
  print(foo);
}

test2(){
  var foo;
  return foo;
}


main(){
  foo = 3;
}