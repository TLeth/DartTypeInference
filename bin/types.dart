library typeanalysis.types;

import 'element.dart';


class InstrumentedType {
  Map<Name, DartType> fields = <Name, DartType>{};
  
  DartType type;
  
  InstrumentedType(DartType this.type);
}


abstract class DartType {
  
}

class FunctionType implements DartType {
  
  List<DartType> normalParameterTypes;
  List<DartType> optionalParameterTypes;
  Map<Name, DartType> namedParameterTypes;
  DartType returnType;
  
  FunctionType(List<DartType> this.normalParameterTypes, DartType this.returnType, [List<DartType> optionalParameterTypes = null, Map<Name, DartType> namedParameterTypes = null ] ) :
    this.optionalParameterTypes = optionalParameterTypes,
    this.namedParameterTypes = namedParameterTypes;
}

class ObjectType implements DartType {
  String typeName;
  
  ObjectType(String this.typeName);
}