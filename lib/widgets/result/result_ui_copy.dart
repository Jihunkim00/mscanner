import 'package:flutter/widgets.dart';

class ResultUiCopy {
  static const String quickPickBadge = 'quickPickBadge';
  static const String recommendationHeaderFallback =
      'recommendationHeaderFallback';
  static const String loadingFallback = 'loadingFallback';
  static const String reasonWeakSignal = 'reasonWeakSignal';
  static const String reasonPopular = 'reasonPopular';
  static const String reasonSignature = 'reasonSignature';
  static const String reasonSeafood = 'reasonSeafood';
  static const String reasonSpicy = 'reasonSpicy';
  static const String reasonVegan = 'reasonVegan';
  static const String reasonDietary = 'reasonDietary';
  static const String reasonGrill = 'reasonGrill';
  static const String reasonStew = 'reasonStew';
  static const String reasonStyleWithLabel = 'reasonStyleWithLabel';

  static String text(
    BuildContext context,
    String key, {
    Map<String, String> args = const {},
  }) {
    final localeKey = _localeKey(Localizations.localeOf(context));
    final table = _localized[localeKey] ??
        _localized[_languageOnly(localeKey)] ??
        _localized['en']!;
    var value = table[key] ?? _localized['en']![key] ?? '';
    args.forEach((k, v) {
      value = value.replaceAll('{$k}', v);
    });
    return value;
  }

  static String _localeKey(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final script = (locale.scriptCode ?? '').toLowerCase();
    final country = (locale.countryCode ?? '').toUpperCase();

    if (language == 'zh') {
      if (script == 'hans') return 'zh-Hans';
      if (script == 'hant') return 'zh-Hant';
      if (country == 'TW' || country == 'HK' || country == 'MO') {
        return 'zh-Hant';
      }
      return 'zh';
    }
    if (language == 'pt' && country == 'BR') return 'pt-BR';
    return language;
  }

  static String _languageOnly(String localeKey) {
    final idx = localeKey.indexOf('-');
    if (idx <= 0) return localeKey;
    return localeKey.substring(0, idx);
  }

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      quickPickBadge: 'Quick pick',
      recommendationHeaderFallback: 'Top picks',
      loadingFallback: 'Loading…',
      reasonWeakSignal: 'A reliable first choice for your first order.',
      reasonPopular: 'A popular first pick that is easy to choose confidently.',
      reasonSignature:
          'A house signature that usually makes a strong first order.',
      reasonSeafood:
          'An easy choice if you want a lighter seafood-forward option.',
      reasonSpicy:
          'Great first choice if you want something with a spicy kick.',
      reasonVegan:
          'A safe first pick when you want a clean plant-forward option.',
      reasonDietary:
          'A practical first pick when you need ingredient-friendly options.',
      reasonGrill:
          'A strong first pick if you are in the mood for grilled flavor.',
      reasonStew:
          'A reliable choice when you want something warm and comforting.',
      reasonStyleWithLabel:
          'A good first pick if you are looking for a {label} style dish.',
    },
    'ko': {
      quickPickBadge: '빠른 선택',
      recommendationHeaderFallback: '추천 메뉴',
      loadingFallback: '불러오는 중…',
      reasonWeakSignal: '처음 주문할 때 무난하게 고르기 좋은 메뉴예요.',
      reasonPopular: '많이 찾는 메뉴라 첫 선택으로 부담이 적어요.',
      reasonSignature: '가게 대표 메뉴라 처음 고를 때 만족도가 높은 편이에요.',
      reasonSeafood: '해산물 위주로 가볍게 즐기고 싶을 때 잘 맞아요.',
      reasonSpicy: '매콤한 맛을 원할 때 실패 확률이 낮은 선택이에요.',
      reasonVegan: '채소 중심으로 깔끔하게 먹고 싶을 때 고르기 좋아요.',
      reasonDietary: '재료 제한을 고려해야 할 때 비교적 안심하고 고를 수 있어요.',
      reasonGrill: '구운 풍미를 좋아한다면 시작 메뉴로 잘 맞아요.',
      reasonStew: '따뜻하고 든든한 한 그릇을 원할 때 고르기 좋아요.',
      reasonStyleWithLabel: '{label} 스타일을 찾을 때 무난한 첫 선택이에요.',
    },
    'ja': {
      quickPickBadge: 'クイック選択',
      recommendationHeaderFallback: 'おすすめメニュー',
      loadingFallback: '読み込み中…',
      reasonWeakSignal: '最初の一品として選びやすいメニューです。',
      reasonPopular: '人気が高く、最初の一品として選びやすいです。',
      reasonSignature: '看板メニューなので、まず試す一品として安心です。',
      reasonSeafood: '魚介を軽めに楽しみたいときに選びやすいです。',
      reasonSpicy: '辛みのある味が欲しいときに選びやすい一品です。',
      reasonVegan: '野菜中心でさっぱり食べたいときに向いています。',
      reasonDietary: '食材条件に配慮したいときにも選びやすいです。',
      reasonGrill: '香ばしい焼き風味が好きなら最初の候補に向いています。',
      reasonStew: '温かくて満足感のある一皿が欲しいときに合います。',
      reasonStyleWithLabel: '{label} が好みなら最初の候補にしやすいです。',
    },
    'zh': {
      quickPickBadge: '快速选择',
      recommendationHeaderFallback: '推荐菜品',
      loadingFallback: '加载中…',
      reasonWeakSignal: '作为第一次点单，这是一个稳妥的选择。',
      reasonPopular: '这是很受欢迎的首选，点起来更有把握。',
      reasonSignature: '这是店里的招牌菜，第一次点通常不会出错。',
      reasonSeafood: '如果你想要更清爽的海鲜风味，这是个容易下决定的选项。',
      reasonSpicy: '想吃点辣的时候，这是个很稳的第一选择。',
      reasonVegan: '如果你偏好清爽的植物系口味，这是个安心的选择。',
      reasonDietary: '需要照顾饮食限制时，这道更容易放心选择。',
      reasonGrill: '如果你想要烤制香气，这是很好的第一选择。',
      reasonStew: '想吃温暖又有满足感的口味时，这个选择很稳妥。',
      reasonStyleWithLabel: '如果你想吃 {label} 风格，这道很适合作为第一选择。',
    },
    'zh-Hans': {
      quickPickBadge: '快速选择',
      recommendationHeaderFallback: '推荐菜品',
      loadingFallback: '加载中…',
      reasonWeakSignal: '作为第一次点单，这是一个稳妥的选择。',
      reasonPopular: '这是很受欢迎的首选，点起来更有把握。',
      reasonSignature: '这是店里的招牌菜，第一次点通常不会出错。',
      reasonSeafood: '如果你想要更清爽的海鲜风味，这是个容易下决定的选项。',
      reasonSpicy: '想吃点辣的时候，这是个很稳的第一选择。',
      reasonVegan: '如果你偏好清爽的植物系口味，这是个安心的选择。',
      reasonDietary: '需要照顾饮食限制时，这道更容易放心选择。',
      reasonGrill: '如果你想要烤制香气，这是很好的第一选择。',
      reasonStew: '想吃温暖又有满足感的口味时，这个选择很稳妥。',
      reasonStyleWithLabel: '如果你想吃 {label} 风格，这道很适合作为第一选择。',
    },
    'zh-Hant': {
      quickPickBadge: '快速選擇',
      recommendationHeaderFallback: '推薦菜品',
      loadingFallback: '載入中…',
      reasonWeakSignal: '作為第一次點餐，這是一個穩妥的選擇。',
      reasonPopular: '這是很受歡迎的首選，點起來更有把握。',
      reasonSignature: '這是店內招牌，第一次點通常不容易出錯。',
      reasonSeafood: '若你想要較清爽的海鮮風味，這是容易決定的選項。',
      reasonSpicy: '想吃點辣時，這是很穩的第一選擇。',
      reasonVegan: '若你偏好清爽的植物系口味，這是安心的選擇。',
      reasonDietary: '需要顧及飲食限制時，這道更容易安心選擇。',
      reasonGrill: '若你想要炙烤香氣，這是很好的第一選擇。',
      reasonStew: '想吃溫暖又有飽足感的口味時，這道很穩妥。',
      reasonStyleWithLabel: '若你想吃 {label} 風格，這道很適合作為第一選擇。',
    },
    'hi': {
      quickPickBadge: 'झटपट चयन',
      recommendationHeaderFallback: 'सुझाए गए व्यंजन',
      loadingFallback: 'लोड हो रहा है…',
      reasonWeakSignal: 'पहली बार ऑर्डर के लिए यह एक भरोसेमंद विकल्प है।',
      reasonPopular:
          'यह लोकप्रिय पहला विकल्प है, इसलिए चुनना आसान और भरोसेमंद है।',
      reasonSignature:
          'यह हाउस सिग्नेचर है, पहली बार के लिए आमतौर पर अच्छा रहता है।',
      reasonSeafood: 'अगर आप हल्का सीफूड स्वाद चाहते हैं, तो यह आसान चुनाव है।',
      reasonSpicy: 'अगर आपको तीखा स्वाद चाहिए, तो यह बढ़िया पहला विकल्प है।',
      reasonVegan: 'प्लांट-फॉरवर्ड हल्का विकल्प चाहिए तो यह सुरक्षित चुनाव है।',
      reasonDietary: 'खास डाइट जरूरतों में यह व्यावहारिक पहला विकल्प है।',
      reasonGrill: 'ग्रिल्ड फ्लेवर का मन हो तो यह मजबूत पहला विकल्प है।',
      reasonStew: 'गरम और संतोषजनक स्वाद चाहिए तो यह भरोसेमंद विकल्प है।',
      reasonStyleWithLabel:
          'अगर आप {label} स्टाइल चाहते हैं, तो यह अच्छा पहला विकल्प है।',
    },
    'es': {
      quickPickBadge: 'Elección rápida',
      recommendationHeaderFallback: 'Platos recomendados',
      loadingFallback: 'Cargando…',
      reasonWeakSignal: 'Una opción fiable para tu primer pedido.',
      reasonPopular: 'Una opción popular y fácil de elegir con confianza.',
      reasonSignature:
          'Una especialidad de la casa que suele funcionar muy bien al pedir por primera vez.',
      reasonSeafood:
          'Una opción fácil si quieres algo más ligero y con enfoque en mariscos.',
      reasonSpicy:
          'Gran primera elección si te apetece algo con toque picante.',
      reasonVegan:
          'Una primera opción segura si buscas algo más vegetal y ligero.',
      reasonDietary:
          'Una opción práctica si necesitas cuidar restricciones de ingredientes.',
      reasonGrill: 'Buena primera elección si te apetece sabor a la parrilla.',
      reasonStew: 'Una opción fiable si quieres algo caliente y reconfortante.',
      reasonStyleWithLabel:
          'Buena primera opción si buscas un plato de estilo {label}.',
    },
    'fr': {
      quickPickBadge: 'Choix rapide',
      recommendationHeaderFallback: 'Plats recommandés',
      loadingFallback: 'Chargement…',
      reasonWeakSignal: 'Un choix fiable pour une première commande.',
      reasonPopular:
          'Un premier choix populaire, facile à sélectionner en toute confiance.',
      reasonSignature:
          'Une spécialité de la maison, souvent un excellent premier choix.',
      reasonSeafood:
          'Un choix facile si vous voulez une option plus légère, orientée fruits de mer.',
      reasonSpicy: 'Très bon premier choix si vous voulez une touche épicée.',
      reasonVegan:
          'Un premier choix sûr si vous cherchez une option végétale et légère.',
      reasonDietary:
          'Un choix pratique si vous devez tenir compte de contraintes alimentaires.',
      reasonGrill:
          'Un bon premier choix si vous avez envie d’une saveur grillée.',
      reasonStew:
          'Un choix fiable si vous voulez quelque chose de chaud et réconfortant.',
      reasonStyleWithLabel:
          'Un bon premier choix si vous cherchez un plat de style {label}.',
    },
    'vi': {
      quickPickBadge: 'Chọn nhanh',
      recommendationHeaderFallback: 'Món gợi ý',
      loadingFallback: 'Đang tải…',
      reasonWeakSignal: 'Một lựa chọn đáng tin cho lần gọi món đầu tiên.',
      reasonPopular: 'Món phổ biến, dễ chọn ngay từ lần đầu.',
      reasonSignature:
          'Món đặc trưng của quán, thường là lựa chọn đầu tiên rất ổn.',
      reasonSeafood: 'Dễ chọn nếu bạn muốn vị hải sản nhẹ nhàng hơn.',
      reasonSpicy: 'Lựa chọn đầu tiên tốt nếu bạn muốn vị cay.',
      reasonVegan:
          'Lựa chọn an toàn nếu bạn muốn món thanh nhẹ, thiên về thực vật.',
      reasonDietary: 'Phù hợp khi bạn cần cân nhắc giới hạn thành phần.',
      reasonGrill: 'Rất hợp để chọn đầu tiên nếu bạn thích vị nướng.',
      reasonStew: 'Lựa chọn đáng tin khi bạn muốn món ấm và đậm đà.',
      reasonStyleWithLabel:
          'Lựa chọn đầu tiên tốt nếu bạn đang tìm món kiểu {label}.',
    },
    'th': {
      quickPickBadge: 'เลือกด่วน',
      recommendationHeaderFallback: 'เมนูแนะนำ',
      loadingFallback: 'กำลังโหลด…',
      reasonWeakSignal: 'เป็นตัวเลือกแรกที่ไว้ใจได้สำหรับการสั่งครั้งแรก',
      reasonPopular: 'เป็นเมนูยอดนิยม เลือกเป็นจานแรกได้อย่างมั่นใจ',
      reasonSignature: 'เป็นเมนูซิกเนเจอร์ของร้าน เหมาะมากสำหรับการลองครั้งแรก',
      reasonSeafood: 'ถ้าอยากได้รสทะเลเบา ๆ นี่คือเมนูที่ตัดสินใจง่าย',
      reasonSpicy: 'ถ้าชอบเผ็ด นี่เป็นตัวเลือกแรกที่ดีมาก',
      reasonVegan: 'ถ้าต้องการแนวพืชเป็นหลักและทานง่าย เมนูนี้ปลอดภัย',
      reasonDietary: 'เหมาะเมื่อคุณต้องคำนึงถึงข้อจำกัดด้านส่วนผสม',
      reasonGrill: 'ถ้าอยากได้กลิ่นรสย่าง เมนูนี้เหมาะเป็นตัวเลือกแรก',
      reasonStew: 'เหมาะเมื่ออยากได้เมนูอุ่น ๆ อิ่มสบาย',
      reasonStyleWithLabel:
          'ถ้าคุณมองหาเมนูสไตล์ {label} นี่เป็นตัวเลือกแรกที่ดี',
    },
    'ar': {
      quickPickBadge: 'اختيار سريع',
      recommendationHeaderFallback: 'أطباق مقترحة',
      loadingFallback: 'جارٍ التحميل…',
      reasonWeakSignal: 'خيار موثوق لطلبك الأول.',
      reasonPopular: 'خيار أول شائع وسهل الاختيار بثقة.',
      reasonSignature: 'طبق مميز للمطعم وغالبًا ما يكون خيارًا أول ممتازًا.',
      reasonSeafood: 'خيار سهل إذا أردت شيئًا أخف بنكهة بحرية.',
      reasonSpicy: 'خيار أول رائع إذا كنت تريد نكهة حارة.',
      reasonVegan: 'خيار أول آمن إذا كنت تفضل خيارًا نباتيًا أخف.',
      reasonDietary: 'خيار عملي إذا كنت تحتاج مراعاة قيود المكونات.',
      reasonGrill: 'خيار أول قوي إذا كنت ترغب بنكهة مشوية.',
      reasonStew: 'خيار موثوق إذا كنت تريد طبقًا دافئًا ومريحًا.',
      reasonStyleWithLabel: 'خيار أول جيد إذا كنت تبحث عن طبق بنمط {label}.',
    },
    'bn': {
      quickPickBadge: 'দ্রুত পছন্দ',
      recommendationHeaderFallback: 'প্রস্তাবিত আইটেম',
      loadingFallback: 'লোড হচ্ছে…',
      reasonWeakSignal: 'প্রথম অর্ডারের জন্য এটি একটি নির্ভরযোগ্য পছন্দ।',
      reasonPopular:
          'এটি জনপ্রিয় প্রথম পছন্দ, তাই আত্মবিশ্বাসের সাথে বেছে নেওয়া সহজ।',
      reasonSignature:
          'এটি রেস্টুরেন্টের সিগনেচার, প্রথমবারের জন্য ভালো পছন্দ।',
      reasonSeafood: 'হালকা সি-ফুড স্বাদ চাইলে এটি সহজ পছন্দ।',
      reasonSpicy: 'ঝাল কিছু চাইলে এটি দারুণ প্রথম পছন্দ।',
      reasonVegan: 'হালকা উদ্ভিদভিত্তিক কিছু চাইলে এটি নিরাপদ পছন্দ।',
      reasonDietary: 'উপাদান সীমাবদ্ধতা থাকলে এটি ব্যবহারিক পছন্দ।',
      reasonGrill: 'গ্রিল স্বাদ চাইলে এটি শক্তিশালী প্রথম পছন্দ।',
      reasonStew: 'গরম ও আরামদায়ক কিছু চাইলে এটি নির্ভরযোগ্য পছন্দ।',
      reasonStyleWithLabel: '{label} স্টাইলের কিছু চাইলে এটি ভালো প্রথম পছন্দ।',
    },
    'ru': {
      quickPickBadge: 'Быстрый выбор',
      recommendationHeaderFallback: 'Рекомендуемые блюда',
      loadingFallback: 'Загрузка…',
      reasonWeakSignal: 'Надёжный вариант для первого заказа.',
      reasonPopular: 'Популярный первый выбор, который легко сделать уверенно.',
      reasonSignature:
          'Фирменное блюдо заведения, обычно отличный первый заказ.',
      reasonSeafood:
          'Удобный выбор, если хочется чего-то более лёгкого с морским акцентом.',
      reasonSpicy: 'Отличный первый выбор, если хочется остроты.',
      reasonVegan:
          'Безопасный первый выбор, если нужен более лёгкий растительный вариант.',
      reasonDietary:
          'Практичный выбор, если важно учитывать ограничения по ингредиентам.',
      reasonGrill: 'Сильный первый выбор, если хочется вкуса гриля.',
      reasonStew: 'Надёжный вариант, если хочется чего-то тёплого и сытного.',
      reasonStyleWithLabel:
          'Хороший первый выбор, если вы ищете блюдо в стиле {label}.',
    },
    'pt': {
      quickPickBadge: 'Escolha rápida',
      recommendationHeaderFallback: 'Pratos recomendados',
      loadingFallback: 'Carregando…',
      reasonWeakSignal: 'Uma escolha confiável para o seu primeiro pedido.',
      reasonPopular:
          'Uma primeira escolha popular e fácil de fazer com confiança.',
      reasonSignature:
          'Um prato assinatura da casa, geralmente ótimo para o primeiro pedido.',
      reasonSeafood:
          'Uma escolha fácil se você quer algo mais leve e com foco em frutos do mar.',
      reasonSpicy:
          'Ótima primeira escolha se você quer algo com toque picante.',
      reasonVegan:
          'Uma primeira escolha segura se você busca uma opção mais vegetal e leve.',
      reasonDietary:
          'Uma escolha prática se você precisa considerar restrições de ingredientes.',
      reasonGrill:
          'Boa primeira escolha se você está com vontade de sabor grelhado.',
      reasonStew:
          'Uma escolha confiável se você quer algo quente e reconfortante.',
      reasonStyleWithLabel:
          'Boa primeira escolha se você procura um prato no estilo {label}.',
    },
    'pt-BR': {
      quickPickBadge: 'Escolha rápida',
      recommendationHeaderFallback: 'Pratos recomendados',
      loadingFallback: 'Carregando…',
      reasonWeakSignal: 'Uma escolha confiável para o seu primeiro pedido.',
      reasonPopular:
          'Uma primeira escolha popular e fácil de fazer com confiança.',
      reasonSignature:
          'Um prato assinatura da casa, geralmente ótimo para o primeiro pedido.',
      reasonSeafood:
          'Uma escolha fácil se você quer algo mais leve e com foco em frutos do mar.',
      reasonSpicy:
          'Ótima primeira escolha se você quer algo com toque picante.',
      reasonVegan:
          'Uma primeira escolha segura se você busca uma opção mais vegetal e leve.',
      reasonDietary:
          'Uma escolha prática se você precisa considerar restrições de ingredientes.',
      reasonGrill:
          'Boa primeira escolha se você está com vontade de sabor grelhado.',
      reasonStew:
          'Uma escolha confiável se você quer algo quente e reconfortante.',
      reasonStyleWithLabel:
          'Boa primeira escolha se você procura um prato no estilo {label}.',
    },
    'ur': {
      quickPickBadge: 'فوری انتخاب',
      recommendationHeaderFallback: 'تجویز کردہ آئٹمز',
      loadingFallback: 'لوڈ ہو رہا ہے…',
      reasonWeakSignal: 'پہلے آرڈر کے لیے یہ ایک قابلِ اعتماد انتخاب ہے۔',
      reasonPopular:
          'یہ ایک مقبول پہلا انتخاب ہے جسے اعتماد سے چنا جا سکتا ہے۔',
      reasonSignature:
          'یہ ریسٹورنٹ کی خاص ڈش ہے، پہلی بار کے لیے عموماً اچھا انتخاب۔',
      reasonSeafood: 'اگر آپ ہلکا سمندری ذائقہ چاہتے ہیں تو یہ آسان انتخاب ہے۔',
      reasonSpicy:
          'اگر آپ مصالحہ دار ذائقہ چاہتے ہیں تو یہ بہترین پہلا انتخاب ہے۔',
      reasonVegan:
          'اگر آپ ہلکا پودوں پر مبنی آپشن چاہتے ہیں تو یہ محفوظ انتخاب ہے۔',
      reasonDietary:
          'اگر اجزاء کی پابندیوں کا خیال رکھنا ہو تو یہ عملی انتخاب ہے۔',
      reasonGrill: 'گرلڈ ذائقہ پسند ہو تو یہ مضبوط پہلا انتخاب ہے۔',
      reasonStew: 'گرم اور تسلی بخش چیز چاہیے تو یہ قابلِ اعتماد انتخاب ہے۔',
      reasonStyleWithLabel:
          'اگر آپ {label} انداز کی ڈش چاہتے ہیں تو یہ اچھا پہلا انتخاب ہے۔',
    },
    'id': {
      quickPickBadge: 'Pilihan cepat',
      recommendationHeaderFallback: 'Menu rekomendasi',
      loadingFallback: 'Memuat…',
      reasonWeakSignal: 'Pilihan pertama yang andal untuk pesanan awal Anda.',
      reasonPopular:
          'Pilihan pertama yang populer dan mudah dipilih dengan yakin.',
      reasonSignature:
          'Menu andalan restoran, biasanya cocok untuk pesanan pertama.',
      reasonSeafood:
          'Pilihan mudah jika Anda ingin opsi seafood yang lebih ringan.',
      reasonSpicy: 'Pilihan pertama yang bagus jika Anda ingin rasa pedas.',
      reasonVegan:
          'Pilihan pertama yang aman jika Anda ingin opsi nabati yang lebih ringan.',
      reasonDietary:
          'Pilihan praktis saat Anda perlu mempertimbangkan batasan bahan.',
      reasonGrill:
          'Pilihan pertama yang kuat jika Anda sedang ingin rasa panggang.',
      reasonStew: 'Pilihan andal saat Anda ingin menu hangat dan menenangkan.',
      reasonStyleWithLabel:
          'Pilihan pertama yang baik jika Anda mencari hidangan gaya {label}.',
    },
    'de': {
      quickPickBadge: 'Schnellauswahl',
      recommendationHeaderFallback: 'Empfohlene Gerichte',
      loadingFallback: 'Wird geladen…',
      reasonWeakSignal: 'Eine verlässliche Wahl für Ihre erste Bestellung.',
      reasonPopular: 'Eine beliebte erste Wahl, die man sicher treffen kann.',
      reasonSignature:
          'Ein Signature-Gericht des Hauses und oft eine starke erste Bestellung.',
      reasonSeafood:
          'Eine einfache Wahl, wenn Sie etwas Leichteres mit Meeresfrüchten möchten.',
      reasonSpicy: 'Eine gute erste Wahl, wenn Sie etwas mit Schärfe möchten.',
      reasonVegan:
          'Eine sichere erste Wahl, wenn Sie etwas Pflanzliches und Leichtes möchten.',
      reasonDietary:
          'Eine praktische Wahl, wenn Sie Zutaten-Einschränkungen beachten müssen.',
      reasonGrill:
          'Eine starke erste Wahl, wenn Sie Lust auf Grillaroma haben.',
      reasonStew:
          'Eine verlässliche Wahl, wenn Sie etwas Warmes und Wohltuendes möchten.',
      reasonStyleWithLabel:
          'Eine gute erste Wahl, wenn Sie ein Gericht im {label}-Stil suchen.',
    },
    'mr': {
      quickPickBadge: 'जलद निवड',
      recommendationHeaderFallback: 'शिफारस केलेले पदार्थ',
      loadingFallback: 'लोड होत आहे…',
      reasonWeakSignal: 'पहिल्या ऑर्डरसाठी हा एक विश्वासार्ह पर्याय आहे.',
      reasonPopular:
          'हा लोकप्रिय पहिला पर्याय आहे, त्यामुळे आत्मविश्वासाने निवडता येतो.',
      reasonSignature:
          'हा हाऊस सिग्नेचर पदार्थ आहे, पहिल्यांदा ऑर्डरसाठी उत्तम.',
      reasonSeafood: 'हलका सीफूड पर्याय हवा असल्यास ही सोपी निवड आहे.',
      reasonSpicy: 'तिखट चव हवी असल्यास हा उत्तम पहिला पर्याय आहे.',
      reasonVegan:
          'हलका वनस्पती-आधारित पर्याय हवा असल्यास ही सुरक्षित निवड आहे.',
      reasonDietary:
          'घटकांवरील मर्यादा लक्षात घ्यायच्या असतील तर हा व्यवहार्य पर्याय आहे.',
      reasonGrill: 'ग्रिल्ड चव हवी असल्यास हा मजबूत पहिला पर्याय आहे.',
      reasonStew:
          'गरम आणि समाधानकारक काही हवे असल्यास हा विश्वासार्ह पर्याय आहे.',
      reasonStyleWithLabel:
          '{label} शैलीतील पदार्थ हवा असल्यास ही चांगली पहिली निवड आहे.',
    },
    'te': {
      quickPickBadge: 'త్వరిత ఎంపిక',
      recommendationHeaderFallback: 'సిఫార్సు చేసిన వంటకాలు',
      loadingFallback: 'లోడ్ అవుతోంది…',
      reasonWeakSignal: 'మొదటి ఆర్డర్‌కు ఇది నమ్మకమైన ఎంపిక.',
      reasonPopular:
          'ఇది ప్రజాదరణ పొందిన మొదటి ఎంపిక, కాబట్టి నమ్మకంగా ఎంచుకోవచ్చు.',
      reasonSignature:
          'ఇది హౌస్ సిగ్నేచర్ వంటకం, మొదటిసారి ఆర్డర్‌కు మంచి ఎంపిక.',
      reasonSeafood: 'తేలికైన సీఫుడ్ ఎంపిక కావాలంటే ఇది సులభమైన నిర్ణయం.',
      reasonSpicy: 'కారం రుచి కావాలంటే ఇది మంచి మొదటి ఎంపిక.',
      reasonVegan:
          'తేలికైన ప్లాంట్-ఫార్వర్డ్ ఎంపిక కోరుకుంటే ఇది సురక్షిత ఎంపిక.',
      reasonDietary:
          'పదార్థ పరిమితులు చూసుకోవాల్సినప్పుడు ఇది ఉపయోగకరమైన ఎంపిక.',
      reasonGrill: 'గ్రిల్ రుచి కావాలంటే ఇది బలమైన మొదటి ఎంపిక.',
      reasonStew: 'వేడిగా, హాయిగా ఉండే వంటకం కావాలంటే ఇది నమ్మకమైన ఎంపిక.',
      reasonStyleWithLabel: '{label} స్టైల్ వంటకం కోసం ఇది మంచి మొదటి ఎంపిక.',
    },
    'tr': {
      quickPickBadge: 'Hızlı seçim',
      recommendationHeaderFallback: 'Önerilen yemekler',
      loadingFallback: 'Yükleniyor…',
      reasonWeakSignal: 'İlk siparişiniz için güvenilir bir seçim.',
      reasonPopular: 'Güvenle seçebileceğiniz popüler bir ilk tercih.',
      reasonSignature:
          'Mekânın imza yemeği; ilk sipariş için genelde güçlü bir tercih.',
      reasonSeafood:
          'Daha hafif, deniz ürünleri odaklı bir seçenek istiyorsanız kolay bir tercih.',
      reasonSpicy: 'Acı bir tat istiyorsanız harika bir ilk seçim.',
      reasonVegan:
          'Daha hafif, bitki ağırlıklı bir seçenek için güvenli bir ilk tercih.',
      reasonDietary:
          'İçerik kısıtlarını gözetmeniz gerekiyorsa pratik bir tercih.',
      reasonGrill: 'Izgara lezzeti istiyorsanız güçlü bir ilk seçim.',
      reasonStew:
          'Sıcak ve rahatlatıcı bir şey istediğinizde güvenilir bir tercih.',
      reasonStyleWithLabel:
          '{label} tarzı bir yemek arıyorsanız iyi bir ilk seçim.',
    },
  };
}
