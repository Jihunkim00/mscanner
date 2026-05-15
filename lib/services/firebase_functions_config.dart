import 'package:cloud_functions/cloud_functions.dart';

class FirebaseFunctionsConfig {
  FirebaseFunctionsConfig._();

  static const String region = 'asia-northeast3';

  static FirebaseFunctions get instance =>
      FirebaseFunctions.instanceFor(region: region);
}