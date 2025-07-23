require('dotenv').config();
const admin = require('firebase-admin');
const { OpenAI } = require('openai');
const { translateAndSaveRAG } = require('./translateAndSaveRAG');


// ✅ Firebase Admin 중복 초기화 방지
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert('./serviceAccount.json')
  });
}
const db = admin.firestore();

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function isObjectiveContent(text) {
  const prompt = `
다음은 사용자 입력입니다. 이 텍스트가 음식점 또는 음식 메뉴에 대한 **객관적인 설명**인지 판단해 주세요.

✔️ 객관적인 설명의 예:
- 장소 구조, 위치, 역사, 건축 양식, 용도, 시설 정보
- 메뉴 구성, 재료, 조리 방식, 가격 등

❌ 제외해야 할 주관적인 설명의 예:
- 맛 평가 ("정말 맛있었어요", "별로였어요")
- 감정 표현 ("최고였어요", "다시는 안 갈 거예요")
- 후기 형태의 문장

📌 입력 언어는 다양할 수 있습니다. 번역하지 말고 의미만 파악해 주세요.
📌 객관적이면 "true", 아니면 "false"만 출력하세요.

입력:
"""${text}"""
`;

  const res = await openai.chat.completions.create({
    model: 'gpt-4.1',
    temperature: 0.2,
    messages: [{ role: 'user', content: prompt }]
  });

  return res.choices[0].message.content.trim().toLowerCase().includes('true');
}

async function processRagReviews(batchSize = 3) {
  const snapshot = await db.collection('rag_reviews')
    .where('status', '==', 'pending')
    .limit(batchSize)
    .get();

  if (snapshot.empty) {
    console.log('🔍 더 이상 처리할 pending 문서가 없습니다.');
    return;
  }

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const detail = data.detail;

    const isValid = await isObjectiveContent(detail);
    if (!isValid) {
      console.log(`⛔️ 주관적 내용: ${doc.id}`);
      await db.collection('rag_reviews').doc(doc.id).update({
        status: 'rejected'
      });
      continue;
    }


    const newDocId = db.collection('rag_data').doc().id;
    await translateAndSaveRAG(newDocId, detail, data.geohashes || []);
    await db.collection('rag_reviews').doc(doc.id).update({ status: 'reviewed' });

    console.log(`✅ 완료: ${doc.id} → ${newDocId}`);
  }
}

// CLI 파라미터로 batchSize 설정 가능
const args = process.argv.slice(2);
const batchSize = parseInt(args[0] || '3');

processRagReviews(batchSize)
  .then(() => console.log('🎉 처리 완료'))
  .catch(err => console.error('🔥 오류:', err));
