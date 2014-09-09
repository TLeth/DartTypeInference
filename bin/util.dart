library typanalysis.util;

class MapUtil {
  
  static dynamic fold(Map map, dynamic initial, dynamic func(dynamic acc, k, v) ) {
    dynamic res = initial;
    map.forEach((k,v) => res = func(res, k, v));
    return res;
  }
  
  static Map filter(Map map, bool func(k, v)) {
    Map res = {};
    map.forEach((k,v) => func(k, v) ? res[k] = v : null);
    return res;
  }
  
  static Map filterKeys(Map map, List keys){
    return MapUtil.filter(map, (k,v) => keys.contains(k));
  }
  
  static Map filterValues(Map map, List values){
    return MapUtil.filter(map, (k,v) => values.contains(v));
  }  
}