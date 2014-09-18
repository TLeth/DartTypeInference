library typanalysis.util;

class MapUtil {
  
  static dynamic fold(Map map, dynamic initial, dynamic func(dynamic acc, k, v) ) {
    dynamic res = initial;
    map.forEach((k,v) => res = func(res, k, v));
    return res;
  }

  static Map mapKeys(Map map, f(k)) {
    Map res = {};
    map.forEach((k, v) => res[f(k)] = v);
    return res;
  }
  
  static Map mapValues(Map map, f(v)) {
    Map res = {};
    map.forEach((k, v) => res[k] = f(v));
    return res;
  }
  
  static Map filter(Map map, bool func(k, v)) {
    Map res = {};
    map.forEach((k,v) => func(k, v) ? res[k] = v : null);
    return res;
  }
  
  static Map filterKeys(Map map, Iterable keys){
    return MapUtil.filter(map, (k,v) => keys.contains(k));
  }
  
  static Map filterValues(Map map, Iterable values){
    return MapUtil.filter(map, (k,v) => values.contains(v));
  } 

  static Map union(Map a, Map b) {
    Map res = {};
    res.addAll(a);
    res.addAll(b);
    return res;
  }
}

class ListUtil {
  
  static List filter(Iterable list, bool func(v)){
    List res = [];
    list.forEach((v) => func(v) ? res.add(v) : null);
    return res;
  }
  
  static List intersection(Iterable a, Iterable b){
    return ListUtil.filter(a, b.contains);
  }
  
  static List complement(Iterable a, Iterable b){
    return ListUtil.filter(a, (v) => !b.contains(v));
  }
  
  
}