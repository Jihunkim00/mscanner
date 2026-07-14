import 'package:cloud_functions/cloud_functions.dart';
import 'package:mscanner/models/order_phrase_models.dart';
import 'package:mscanner/services/firebase_functions_config.dart';

class OrderPhraseService {
  OrderPhraseService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctionsConfig.instance;

  final FirebaseFunctions _functions;

  Future<GenerateOrderPhraseResponse> generate(
    GenerateOrderPhraseRequest request,
  ) async {
    final callable = _functions.httpsCallable('generateOrderPhrase');
    final response =
        await callable.call<Map<String, dynamic>>(request.toJson());
    final data =
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return GenerateOrderPhraseResponse.fromJson(data);
  }
}
