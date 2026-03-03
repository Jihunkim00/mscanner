// functions/src/admin.ts
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { admin };
