library test.Scoping;



var foo;


test(foo) {
  print(foo);
}

test2(){
  var foo = foo;
  return foo;
}

test3(foo){
  print(foo);
  var foo = foo;
  return foo;
}

main(){
  foo = 3;
}