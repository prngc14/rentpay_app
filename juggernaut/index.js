const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Model na nasa listahan ng key mo (Flash-Lite, para sa Free tier).
const MODEL_NAME = "gemini-3.5-flash-lite";

// =====================================================
// OWNER-ONLY SETTINGS
// Owner accounts lang ang puwedeng gumamit. Tinitingnan sa Firestore
// ang users/{uid} at binabasa ang role field.
// Kung iba ang pangalan ng collection o field sa database ninyo,
// palitan dito. Para i-off muna habang nagte-test: ENFORCE_OWNER_ONLY = false
// =====================================================
const ENFORCE_OWNER_ONLY = true;
const USERS_COLLECTION = "users";
const ROLE_FIELDS = ["role", "userType", "accountType"];
const OWNER_VALUE = "owner";

// =====================================================
// IMAGE SETTINGS
// =====================================================
const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_IMAGE_BYTES = 6 * 1024 * 1024; // 6 MB
const ALLOWED_IMAGE_HOSTS = ["res.cloudinary.com"];

if (getApps().length === 0) {
  initializeApp();
}

setGlobalOptions({
  maxInstances: 10,
});

// -----------------------------------------------------
// OWNER CHECK
// -----------------------------------------------------
async function assertOwner(uid) {
  if (!ENFORCE_OWNER_ONLY) return;

  const snap = await getFirestore()
    .collection(USERS_COLLECTION)
    .doc(uid)
    .get();

  const data = snap.exists ? snap.data() : null;

  let role = null;
  if (data) {
    for (const field of ROLE_FIELDS) {
      if (typeof data[field] === "string") {
        role = data[field];
        break;
      }
    }
  }

  console.log("Owner check | doc exists:", snap.exists, "| role:", role);

  if (!role || role.trim().toLowerCase() !== OWNER_VALUE) {
    throw new HttpsError(
      "permission-denied",
      "Only owner accounts can use Juggernaut."
    );
  }
}

// -----------------------------------------------------
// LOAD RECEIPT IMAGE
// Tumatanggap ng alinman sa:
//   data.imageBase64 + data.mimeType   (galing sa phone/gallery)
//   data.imageUrl                      (Cloudinary link)
// Nagbabalik ng { data, mimeType } o null kung walang larawan.
// -----------------------------------------------------
async function loadImage(payload) {
  // OPTION 1: BASE64
  if (
    typeof payload.imageBase64 === "string" &&
    payload.imageBase64.length > 0
  ) {
    const mimeType = String(payload.mimeType || "image/jpeg")
      .trim()
      .toLowerCase();

    if (!ALLOWED_IMAGE_TYPES.includes(mimeType)) {
      throw new HttpsError(
        "invalid-argument",
        "Unsupported image type. Please use JPG, PNG, or WEBP."
      );
    }

    const base64 = payload.imageBase64.replace(/^data:[^;]+;base64,/, "");
    const approxBytes = Math.floor((base64.length * 3) / 4);

    if (approxBytes > MAX_IMAGE_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "Image is too large. Please use a file under 6 MB."
      );
    }

    return { data: base64, mimeType };
  }

  // OPTION 2: CLOUDINARY URL
  if (typeof payload.imageUrl === "string" && payload.imageUrl.length > 0) {
    let url;
    try {
      url = new URL(payload.imageUrl);
    } catch (e) {
      throw new HttpsError("invalid-argument", "Invalid image URL.");
    }

    if (
      url.protocol !== "https:" ||
      !ALLOWED_IMAGE_HOSTS.includes(url.hostname)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "The receipt image must be hosted on Cloudinary."
      );
    }

    const res = await fetch(url.toString());

    if (!res.ok) {
      throw new HttpsError(
        "not-found",
        "Could not download the receipt image."
      );
    }

    const mimeType = (res.headers.get("content-type") || "")
      .split(";")[0]
      .trim()
      .toLowerCase();

    if (!ALLOWED_IMAGE_TYPES.includes(mimeType)) {
      throw new HttpsError(
        "invalid-argument",
        "Unsupported image type. Please use JPG, PNG, or WEBP."
      );
    }

    const buffer = Buffer.from(await res.arrayBuffer());

    if (buffer.length > MAX_IMAGE_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "Image is too large. Please use a file under 6 MB."
      );
    }

    return { data: buffer.toString("base64"), mimeType };
  }

  return null;
}

// -----------------------------------------------------
// PROMPTS
// -----------------------------------------------------
function buildChatPrompt(message) {
  return `
You are Juggernaut, the AI assistant of RentPay.

You help property owners with:

- Rent payments
- Payment reminders
- Rental information
- Tenant concerns
- Property management
- Checking tenant payment receipts (the owner can attach a receipt image)
- General RentPay assistance

Rules:
- Be helpful, clear, and professional.
- Keep answers easy to understand.
- Do not invent payment records.
- Do not claim that a payment was completed unless verified.
- If you do not know something, say so honestly.

User message:
${message}
`;
}

function buildReceiptPrompt(message, expectedAmount) {
  let expectedBlock = "";

  if (Number.isFinite(expectedAmount) && expectedAmount > 0) {
    expectedBlock = `
The owner expects a payment of PHP ${expectedAmount}. Tell the owner if the amount on the receipt does not match.
`;
  }

  let noteBlock = "";
  if (message) {
    noteBlock = `
Owner's note: ${message}
`;
  }

  return `
You are Juggernaut, the receipt-checking assistant of RentPay, a rental billing system.

A property owner uploaded a payment receipt screenshot submitted by a tenant (usually GCash, Maya, or a bank transfer). Examine the image carefully for signs that it may be fake, edited, or AI-generated.

Look for:
- Inconsistent fonts, font sizes, spacing, or alignment
- Blurry, pasted, or mismatched areas around amounts, names, dates, or reference numbers
- Garbled, misspelled, or unnatural text (common in AI-generated images)
- Missing or oddly formatted reference number, date, or time
- Amounts or dates that look unrealistic or inconsistent within the receipt
- A layout that does not match a real GCash, Maya, or bank receipt
- Signs of a screenshot of a screenshot, or heavy compression that may hide edits
${expectedBlock}${noteBlock}
Important rules:
- You cannot prove that a receipt is real or fake from an image alone. Give a screening result, not a final judgment.
- Do not invent details that are not visible in the image.
- If the image is not a payment receipt, say so clearly.
- Keep it short and easy to understand. Reply in English.

Reply in exactly this format:
VERDICT: <LIKELY GENUINE | SUSPICIOUS | LIKELY FAKE | CANNOT DETERMINE>
CONFIDENCE: <Low | Medium | High>
READ FROM RECEIPT: amount, date and time, reference number, sender, receiver (write "not visible" for anything missing)
RED FLAGS: a short bullet list, or "None noticed"
NEXT STEP FOR OWNER: one or two sentences, for example confirming the reference number and amount in your own GCash, Maya, or bank account before approving the payment.
`;
}

// -----------------------------------------------------
// FUNCTION
// -----------------------------------------------------
exports.juggernautChat = onCall(
  {
    region: "asia-southeast1",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 90,
    memory: "512MiB",
  },

  async (request) => {
    try {
      // CHECK FIREBASE AUTHENTICATION
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "User must be authenticated."
        );
      }

      // OWNER ONLY
      await assertOwner(request.auth.uid);

      const payload = request.data || {};

      const message =
        typeof payload.message === "string" ? payload.message.trim() : "";

      // OPTIONAL RECEIPT IMAGE
      const image = await loadImage(payload);

      // CHECK INPUT
      if (!message && !image) {
        throw new HttpsError(
          "invalid-argument",
          "A message or a receipt image is required."
        );
      }

      // GET GEMINI API KEY
      const apiKey = GEMINI_API_KEY.value();

      if (!apiKey) {
        console.error("GEMINI_API_KEY is missing.");

        throw new HttpsError(
          "failed-precondition",
          "Gemini API key is not configured."
        );
      }

      const mode = image ? "receipt-check" : "chat";

      console.log("=================================");
      console.log("JUGGERNAUT REQUEST RECEIVED");
      console.log("User UID:", request.auth.uid);
      console.log("Mode:", mode);
      console.log("=================================");

      // INITIALIZE GEMINI
      const genAI = new GoogleGenerativeAI(apiKey);

      const model = genAI.getGenerativeModel({
        model: MODEL_NAME,
        generationConfig: {
          temperature: image ? 0.2 : 0.7,
        },
      });

      // GENERATE AI RESPONSE
      let result;

      if (image) {
        const expectedAmount = Number(payload.expectedAmount);

        result = await model.generateContent([
          buildReceiptPrompt(message, expectedAmount),
          { inlineData: { data: image.data, mimeType: image.mimeType } },
        ]);
      } else {
        result = await model.generateContent(buildChatPrompt(message));
      }

      const reply = result.response.text();

      // CHECK EMPTY RESPONSE
      if (!reply || reply.trim().length === 0) {
        console.error("Gemini returned an empty response.");

        throw new HttpsError(
          "internal",
          "Gemini returned an empty response."
        );
      }

      console.log("Gemini response generated successfully.");

      // RETURN RESPONSE TO FLUTTER
      return {
        success: true,
        mode: mode,
        reply: reply.trim(),
      };
    } catch (error) {
      console.error("=================================");
      console.error("JUGGERNAUT ERROR");
      console.error("Error name:", error?.name);
      console.error("Error message:", error?.message);
      console.error("Full error:", error);
      console.error("=================================");

      // PRESERVE FIREBASE ERRORS
      if (error instanceof HttpsError) {
        throw error;
      }

      const msg = String(error?.message ?? "");

      // QUOTA / RATE LIMIT
      if (msg.includes("429") || msg.toLowerCase().includes("quota")) {
        throw new HttpsError(
          "resource-exhausted",
          "Busy si Juggernaut ngayon. Pakisubukan ulit mamaya."
        );
      }

      // RETURN INTERNAL ERROR (walang detalye para hindi lumabas sa app)
      throw new HttpsError(
        "internal",
        "Sorry, Juggernaut could not process your request."
      );
    }
  }
);