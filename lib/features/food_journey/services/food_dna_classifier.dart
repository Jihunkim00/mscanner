import 'dart:convert';
import '../../../screens/result/result_parsing_service.dart';
import '../models/food_journey_summary.dart';

class FoodCategoryClassifier {
  const FoodCategoryClassifier();

  /// Dish names win over ingredients in descriptions. Specific composed dishes
  /// win over generic ingredient rules (seafood ramen is noodles, sushi seafood).
  FoodCategory classify(Map<String, dynamic>? food) {
    if (food == null) return FoodCategory.unknown;
    final names =
        [food['nameOriginal'], food['name']].whereType<String>().join(' ');
    final named = _match(names, _dishRules);
    if (named != FoodCategory.unknown) return named;
    final generic = _match(names, _typeRules);
    if (generic != FoodCategory.unknown) return generic;
    final tags = food['tags'];
    final description = [
      if (food['shortDesc'] is String) food['shortDesc'] as String,
      if (tags is List) ...tags.whereType<String>(),
      if (tags is String) tags,
    ].join(' ');
    return _match(description, _typeRules);
  }

  FoodCategory _match(String value, Map<FoodCategory, RegExp> rules) {
    final text = value.toLowerCase();
    for (final entry in rules.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return FoodCategory.unknown;
  }

  static Map<FoodCategory, RegExp> _compile(Map<FoodCategory, String> rules) =>
      {
        for (final entry in rules.entries)
          entry.key: RegExp(
              entry.value
                  .replaceAll(r'\b(', r'(?<![\p{L}\p{N}])(')
                  .replaceAll(r')\b', r')(?![\p{L}\p{N}])'),
              unicode: true),
      };
  static final _dishRules = _compile(_dishes);
  static final _typeRules = _compile(_types);

  // Stable priority: specific drinks/desserts, noodles, sushi, rice, soup,
  // vegetables, meat, seafood. Latin words use boundaries to avoid e.g. "tea"
  // matching "steak". Non-Latin terms can occur within compound dish names.
  static const _dishes = <FoodCategory, String>{
    FoodCategory.drinks:
        r'\b(cappuccino|espresso|latte|matcha latte|smoothie|mojito|lemonade)\b|카푸치노|에스프레소|카페라테|カプチーノ|拿铁|拿鐵',
    FoodCategory.dessert:
        r'\b(tiramisu|tiramisù|cheesecake|gelato|macaron|panna cotta|brownie|baklava)\b|티라미수|케이크|아이스크림|ティラミス|ケーキ|アイスクリーム|提拉米苏|提拉米蘇|冰淇淋',
    FoodCategory.noodles:
        r'\b(ramen|udon|soba|pasta|spaghetti|linguine|fettuccine|lasagna|lasagne|pad thai|pad see ew|pho|phở|bún|chow mein|laksa)\b|라멘|라면|우동|국수|냉면|파스타|짜장면|짬뽕|쌀국수|팟타이|ラーメン|らーめん|うどん|そば|焼きそば|拉面|拉麵|炒面|炒麵|米粉|ก๋วยเตี๋ยว|ผัดไทย|नूडल्स|رامن',
    FoodCategory.seafood:
        r'\b(sushi|sashimi|ceviche|poke bowl)\b|스시|초밥|사시미|寿司|壽司|刺身|ซูชิ|寿し|스시',
    FoodCategory.rice:
        r'\b(risotto|biryani|biriyani|bibimbap|paella|congee|pilaf|fried rice|nasi goreng|khao pad|arroz|cơm|cơm chiên)\b|리소토|비빔밥|볶음밥|덮밥|김밥|おにぎり|チャーハン|炒饭|炒飯|丼|ข้าวผัด|बिरयानी|बिर्याणी|بریانی',
    FoodCategory.soup:
        r'\b(tom yum|tom kha|bouillabaisse|borscht|borsch|gazpacho|chowder|minestrone)\b|찌개|설렁탕|갈비탕|미역국|된장국|김치국|味噌汁|みそ汁|火锅|火鍋|ต้มยำ|ต้มข่า',
    FoodCategory.vegetables:
        r'\b(salad|ratatouille|falafel|hummus|tabbouleh)\b|샐러드|나물|サラダ|沙拉|สลัด|सलाद|سلطة',
    FoodCategory.meat:
        r'\b(steak|bulgogi|galbi|schnitzel|tonkatsu|yakitori|kebab|hamburger|burger)\b|스테이크|불고기|삼겹살|돈까스|돈가스|갈비|ステーキ|とんかつ|焼き鳥|牛排|烤肉|สเต๊ก|كباب',
  };
  static const _types = <FoodCategory, String>{
    FoodCategory.drinks:
        r'\b(coffee|tea|juice|beer|wine|cocktail|beverage|café|caffè|thé|chá|kaffee|saft|jus|kopi|teh|çay|kahve)\b|커피|음료|맥주|주스|コーヒー|ジュース|ビール|咖啡|果汁|啤酒|กาแฟ|น้ำผลไม้|चाय|कॉफी|চা|কফি|چائے|قهوة|شاي|కాఫీ',
    FoodCategory.dessert:
        r'\b(dessert|cake|ice cream|pudding|pastry|chocolate|gâteau|kuchen|pastel|helado|sorvete|tatlı)\b|디저트|푸딩|デザート|プリン|甜点|甜點|布丁|ของหวาน|मिठाई|মিষ্টি|حلوى|میٹھا',
    FoodCategory.noodles:
        r'\b(noodles?|nouilles|nudeln|fideos|macarrão|erişte|mie)\b|면 요리|면요리|麺|麵|面条|नूडल|নুডল|نوڈلز|معكرونة|నూడుల్స్',
    FoodCategory.rice:
        r'\b(rice|riz|reis|arroz|nasi|pirinç)\b|밥|쌀 요리|ご飯|米饭|米飯|ข้าว|चावल|भात|ভাত|چاول|أرز|అన్నం',
    FoodCategory.soup:
        r'\b(soup|stew|broth|soupe|suppe|sopa|çorba|sup)\b|수프|스프|국물|찌개|スープ|煮込み|汤|湯|ซุป|सूप|স্যুপ|سوپ|حساء|شوربة|సూప్',
    FoodCategory.vegetables:
        r'\b(vegetable dish|vegetable salad|ensalada|salade|salat|salada|sayur|sebze)\b|채소 요리|야채 요리|蔬菜沙拉|野菜料理|सब्जी|সবজি|سبزی|خضار|కూరగాయ',
    FoodCategory.meat:
        r'\b(beef|pork|chicken|lamb|duck|meat|bœuf|boeuf|poulet|rindfleisch|hähnchen|pollo|carne|frango|ayam|daging|tavuk)\b|쇠고기|소고기|돼지고기|닭고기|양고기|牛肉|豚肉|鶏肉|猪肉|豬肉|鸡肉|雞肉|เนื้อวัว|เนื้อหมู|ไก่|मांस|चिकन|মাংস|گوشت|دجاج|لحم|మాంసం',
    FoodCategory.seafood:
        r'\b(seafood|fish|shrimp|prawn|lobster|salmon|tuna|poisson|fisch|pescado|peixe|ikan|udang|balık)\b|해산물|생선|새우|연어|참치|海鮮|海鲜|刺身|กุ้ง|ปลา|मछली|মাছ|مچھلی|سمك|روبيان|చేప',
  };
}

/// Extracts exactly one representative per saved document, never an entire menu.
class FoodJourneyMenuParser {
  const FoodJourneyMenuParser();

  Map<String, dynamic>? representative(Map<String, dynamic> data) {
    final raw = data['responses'];
    final responses = <String>[
      if (raw is List) ...raw.whereType<String>(),
      if (raw is String) raw,
      if (data['response'] is String) data['response'] as String,
    ];
    final decoded = <Map<String, dynamic>>[];
    for (final response in responses) {
      for (final json in _jsonResponses(response)) {
        if (json['isMenu'] == false ||
            ResultParsingService.isNonMenuResultType(
                ResultParsingService.aiResultType(json))) {
          continue;
        }
        decoded.add(json);
        final recommended = json['recommended'];
        if (recommended is List && recommended.isNotEmpty) {
          final first = _food(recommended.first);
          if (first != null) return first;
        }
      }
    }
    final primary = _food(data['primary_menu']);
    if (primary != null) return primary;
    for (final json in decoded) {
      final items = json['items'];
      if (items is List && items.isNotEmpty) {
        final first = _food(items.first);
        if (first != null) return first;
      }
    }
    for (final response in responses) {
      // Only the explicitly numbered first dish in a legacy text response.
      for (final line in response.split('\n')) {
        final match = RegExp(r'^\s*1\s*[.)\]:-]\s*(.+)$').firstMatch(line);
        if (match != null) {
          return _food(ResultParsingService.sanitizeMenuName(match.group(1)!));
        }
      }
    }
    return null;
  }

  Iterable<Map<String, dynamic>> _jsonResponses(String response) sync* {
    final candidate = ResultParsingService.extractJsonObjectFromText(response);
    if (candidate == null) return;
    // Balanced objects allow multiple JSON code blocks in one old response.
    // Braces inside quoted strings do not affect nesting.
    var depth = 0;
    var start = 0;
    var quoted = false;
    var escaped = false;
    for (var index = 0; index < candidate.length; index++) {
      final char = candidate[index];
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
        continue;
      }
      if (char == '"' && depth > 0) {
        quoted = true;
      }
      if (char == '{') {
        if (depth == 0) start = index;
        depth++;
      } else if (char == '}' && depth > 0) {
        depth--;
        if (depth == 0) {
          try {
            final value = jsonDecode(candidate.substring(start, index + 1));
            if (value is Map<String, dynamic>) yield value;
          } on FormatException {/* Invalid historical JSON is ignored. */}
        }
      }
    }
  }

  Map<String, dynamic>? _food(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return {'name': value.trim()};
    }
    if (value is Map<String, dynamic>) {
      final name = [
        value['nameOriginal'],
        value['name'],
        value['nameTranslated'],
        value['menuName'],
        value['original'],
        value['menuOriginal'],
        value['translated'],
      ].whereType<String>().where((name) => name.trim().isNotEmpty).firstOrNull;
      if (name != null) {
        return {...value, if (value['name'] == null) 'name': name};
      }
    }
    return null;
  }
}
