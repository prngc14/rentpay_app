const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Model na nasa listahan ng key mo (Flash-Lite, para sa Free tier).
const MODEL_NAME = "gemini-3.5-flash-lite";
const FALLBACK_MODEL_NAME = "gemini-2.5-flash-lite";

const ENFORCE_OWNER_ONLY = true;
const USERS_COLLECTION = "users";
const ROLE_FIELDS = ["role", "userType", "accountType"];
const OWNER_VALUE = "owner";

const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_IMAGE_BYTES = 6 * 1024 * 1024; // 6 MB
const ALLOWED_IMAGE_HOSTS = ["res.cloudinary.com"];

if (getApps().length === 0) {
  initializeApp();
}

setGlobalOptions({
  maxInstances: 10,
});


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
  const currentDate = new Intl.DateTimeFormat("en-PH", {
    dateStyle: "long",
    timeZone: "Asia/Manila",
  }).format(new Date());

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

Review the visible receipt for:
- Inconsistent fonts, font sizes, spacing, or alignment
- Blurry, pasted, or mismatched areas around amounts, names, dates, or reference numbers
- Garbled, misspelled, or unnatural text (common in AI-generated images)
- Missing or oddly formatted reference number, date, or time
- Amounts or dates that are internally inconsistent or clearly impossible
- Clear visual inconsistencies with the payment platform shown on the receipt
- Signs of a screenshot of a screenshot, or heavy compression that may hide edits
${expectedBlock}${noteBlock}
Important rules:
- Return exactly one of these three verdicts:
  - GREEN: It is a readable payment receipt with no obvious visual manipulation and no clear internal inconsistencies. This only means low visible concern; it does not prove that money was received.
  - ORANGE: The image is not a payment receipt, is unreadable, has important missing details, has a possible amount mismatch, or has uncertain/weak concerns that need manual review. Do not treat a mismatch or poor image quality alone as proof of fraud.
  - RED: There are multiple strong, specific, corroborating visual signs of editing or AI generation, or a clearly impossible internal inconsistency. Describe the evidence; do not claim fraud as a proven fact.
- You cannot prove that a receipt is real or fake from an image alone. This is a screening result, not a final judgment or payment approval.
- Do not invent details that are not visible in the image.
- If the image is not a payment receipt, use ORANGE and say so clearly.
- The current date in the Philippines is ${currentDate}. Only call a transaction date "in the future" if it is later than this date. A past date is not suspicious just because it is old.
- GCash and Maya may mask part of a sender's name or phone number for privacy. Masking alone is normal and is never evidence of editing or fraud.
- Receipts may include ads, promotional banners, app controls, status/navigation bars, colored backgrounds, or be captured as screenshots. These alone are not evidence of fraud.
- Do not label a receipt RED just because its layout is unfamiliar, a detail is masked, or image quality is imperfect. Use ORANGE when you cannot confidently assess it.
- Do not assume a "standard" receipt layout unless there is a clear, specific inconsistency visible in this image.
- Keep it short and easy to understand. Reply in English.

Reply in exactly this format. Replace the verdict instruction with exactly one word: GREEN, ORANGE, or RED. Do not include angle brackets or the other choices on the VERDICT line.
VERDICT: GREEN
CONFIDENCE: <Low | Medium | High>
READ FROM RECEIPT: amount, date and time, reference number, sender, receiver (write "not visible" for anything missing)
FEEDBACK: a short explanation of why this verdict was chosen
NEXT STEP FOR OWNER: one sentence advising what to verify manually before approving the payment.
`;
}

function isTransientGeminiError(error) {
  const message = String(error?.message ?? "");
  return /\[(?:429|500|502|503|504)\b/.test(message) ||
    /\b(?:429|500|502|503|504)\s+(?:RESOURCE_EXHAUSTED|INTERNAL|UNAVAILABLE|GATEWAY_TIMEOUT)\b/i.test(message);
}

async function generateContentWithFallback(genAI, content, generationConfig) {
  const models = [MODEL_NAME, FALLBACK_MODEL_NAME];
  let lastError;

  for (let index = 0; index < models.length; index += 1) {
    const modelName = models[index];
    const model = genAI.getGenerativeModel({
      model: modelName,
      generationConfig,
    });

    try {
      const result = await model.generateContent(content);
      console.log("Gemini response generated with model:", modelName);
      return result;
    } catch (error) {
      lastError = error;
      if (index === models.length - 1 || !isTransientGeminiError(error)) {
        throw error;
      }

      console.warn(
        `Gemini model ${modelName} temporarily unavailable; retrying with ${FALLBACK_MODEL_NAME}.`,
        error?.message
      );
    }
  }

  throw lastError;
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

      // GENERATE AI RESPONSE
      const generationConfig = {
        temperature: image ? 0.2 : 0.7,
      };
      let content;

      if (image) {
        const expectedAmount = Number(payload.expectedAmount);

        content = [
          buildReceiptPrompt(message, expectedAmount),
          { inlineData: { data: image.data, mimeType: image.mimeType } },
        ];
      } else {
        content = buildChatPrompt(message);
      }

      const result = await generateContentWithFallback(
        genAI,
        content,
        generationConfig
      );
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

      throw new HttpsError(
        "internal",
        "Sorry, Juggernaut could not process your request."
      );
    }
  }
);