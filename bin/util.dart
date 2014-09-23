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
  
  static bool equal(Map a, Map b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    List keys = ListUtil.union(a.keys, b.keys);
    for (var key in keys) {
     if (!a.containsKey(key) || !b.containsKey(key) || a[key] != b[key])
       return false;
    }
    return true;
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
  
  static List union(Iterable a, Iterable b) {
    List res = new List.from(a);
    res.addAll(b);
    return res;
  }
  
  static bool equal(List a, List b){
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for(var i = 0; i < a.length; i++){
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  
  
}