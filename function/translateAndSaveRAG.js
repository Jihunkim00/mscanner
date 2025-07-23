// translateAndSaveRAG.js

const { OpenAI } = require('openai');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require('./serviceAccount.json'))
  });
}
const db = admin.firestore();


// OpenAI 초기화 (환경변수 사용 권장)
const openai = new OpenAI({
  apiKey: "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", // 환경변수 추천!
});

/**
 * RAG 상세를 여러 번 나눠 3개 언어씩 번역하고 Firestore에 저장합니다.
 * @param {string} docId - Firestore 문서 ID
 * @param {string} detail - 원본 상세 텍스트
 * @param {string[]} geohashes - geohash 배열
 */
async function translateAndSaveRAG(docId, detail, geohashes = []) {
  // 전체 21개 언어 리스트
  const allLangs = [
    'ar','bn','de','en','es','fr','hi','id','ja','ko',
    'mr','pt','pt_BR','ru','te','th','tr','ur','vi','zh_Hans','zh_Hant'
  ];
  const chunkSize = 3; // 한 번에 처리할 언어 수
  const translations = {};

  // 언어 그룹별로 OpenAI 호출
  for (let i = 0; i < allLangs.length; i += chunkSize) {
    const langs = allLangs.slice(i, i + chunkSize);
    const systemPrompt = `
You are a translation assistant.
Translate the user input into the following languages only: ${langs.join(', ')}.
Return ONLY a flat JSON object with keys exactly: ${langs.join(', ')}.
No markdown, no code fences, no extra text.
`;
    const userPrompt = `Translate this RAG detail: """${detail}"""`;

    // OpenAI GPT 호출
    const chat = await openai.chat.completions.create({
      model: 'gpt-4.1',
      temperature: 0.2,
      max_tokens: 5000,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    });

    let payload = chat.choices[0].message.content;
    // JSON 오브젝트만 안전하게 파싱
    const start = payload.indexOf('{');
    const end = payload.lastIndexOf('}');
    const jsonStr = start !== -1 && end !== -1 ? payload.slice(start, end + 1) : payload;
    let part;
    try {
      part = JSON.parse(jsonStr);
    } catch (err) {
      console.error('GPT JSON 파싱 실패:', jsonStr);
      throw new Error('GPT JSON 파싱 실패');
    }
    Object.assign(translations, part);
  }

  // Firestore에 저장
  const docData = {
    detail_original: detail,
    geohashes,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  for (const [lang, txt] of Object.entries(translations)) {
    docData[`detail_${lang}`] = txt;
  }
  await db.collection('rag_data').doc(docId).set(docData, { merge: true });
  console.log(`✅ RAG detail saved for ${docId}`);
}

module.exports = { translateAndSaveRAG };
