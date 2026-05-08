import { createClient } from "jsr:@supabase/supabase-js@2";

let cachedAccessToken: string | null = null;
let cachedAccessTokenExpiresAt = 0;

const jsonHeaders = {
  "Content-Type": "application/json",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function normalizeData(data: unknown): Record<string, string> {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return {};
  }

  const normalized: Record<string, string> = {};

  for (const [key, value] of Object.entries(data as Record<string, unknown>)) {
    if (!key) continue;

    if (value == null) {
      normalized[key] = "";
    } else if (typeof value === "string") {
      normalized[key] = value;
    } else {
      normalized[key] = String(value);
    }
  }

  return normalized;
}

function uniqueTokens(tokens: Array<{ fcm_token: string | null }>): string[] {
  const seen = new Set<string>();

  for (const row of tokens) {
    const token = row.fcm_token?.trim();

    if (!token) continue;

    seen.add(token);
  }

  return [...seen];
}

async function getAccessToken(): Promise<string> {
  const nowMs = Date.now();

  if (cachedAccessToken && nowMs < cachedAccessTokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }

  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    throw new Error("Missing FCM_SERVICE_ACCOUNT_JSON secret");
  }

  const serviceAccount = JSON.parse(serviceAccountJson);

  const now = Math.floor(nowMs / 1000);
  const jwtHeader = { alg: "RS256", typ: "JWT" };
  const jwtClaimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  function base64UrlEncode(input: Uint8Array | string): string {
    const bytes =
      typeof input === "string" ? new TextEncoder().encode(input) : input;
    let binary = "";

    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }

    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }

  async function importPrivateKey(pem: string): Promise<CryptoKey> {
    const pemContents = pem
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s/g, "");

    const binaryDer = Uint8Array.from(atob(pemContents), (c) =>
      c.charCodeAt(0)
    );

    return await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      {
        name: "RSASSA-PKCS1-v1_5",
        hash: "SHA-256",
      },
      false,
      ["sign"],
    );
  }

  const encodedHeader = base64UrlEncode(JSON.stringify(jwtHeader));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(jwtClaimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  const privateKey = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedToken),
  );

  const signedJwt =
    `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const tokenJson = await tokenRes.json();

  if (!tokenRes.ok) {
    throw new Error(`OAuth token error: ${JSON.stringify(tokenJson)}`);
  }

  cachedAccessToken = tokenJson.access_token;
  cachedAccessTokenExpiresAt = nowMs + 55 * 60 * 1000;

  return cachedAccessToken!;
}

function isInvalidTokenResponse(json: unknown): boolean {
  const text = JSON.stringify(json);

  return text.includes("UNREGISTERED") ||
    text.includes("registration-token-not-registered") ||
    text.includes("Requested entity was not found") ||
    text.includes("INVALID_ARGUMENT");
}

async function sendFcmMessage({
  projectId,
  accessToken,
  token,
  title,
  messageBody,
  data,
}: {
  projectId: string;
  accessToken: string;
  token: string;
  title: string;
  messageBody: string;
  data: Record<string, string>;
}): Promise<{
  token: string;
  ok: boolean;
  status: number;
  response: unknown;
  invalidToken: boolean;
}> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body: messageBody,
          },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "chat_messages",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
          webpush: {
            notification: {
              title,
              body: messageBody,
            },
          },
        },
      }),
    },
  );

  let json: unknown = null;

  try {
    json = await res.json();
  } catch (_) {
    json = { error: "Invalid FCM JSON response" };
  }

  return {
    token,
    ok: res.ok,
    status: res.status,
    response: json,
    invalidToken: !res.ok && isInvalidTokenResponse(json),
  };
}

async function runLimited<T>(
  items: string[],
  limit: number,
  worker: (item: string) => Promise<T>,
): Promise<T[]> {
  const results: T[] = [];
  let index = 0;

  async function runWorker() {
    while (index < items.length) {
      const currentIndex = index++;
      results[currentIndex] = await worker(items[currentIndex]);
    }
  }

  const workers = Array.from(
    { length: Math.min(limit, items.length) },
    () => runWorker(),
  );

  await Promise.all(workers);

  return results;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Missing Supabase environment" }, 500);
    }

    if (!serviceAccountJson) {
      return jsonResponse({ error: "Missing FCM_SERVICE_ACCOUNT_JSON secret" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    let body: Record<string, unknown>;

    try {
      body = await req.json();
    } catch (_) {
      return jsonResponse({ error: "Invalid JSON body" }, 400);
    }

    const recipientUserId = body.recipient_user_id?.toString().trim();
    const title = body.title?.toString().trim();
    const messageBody = body.body?.toString().trim();
    const data = normalizeData(body.data);

    if (!recipientUserId || !title || !messageBody) {
      return jsonResponse(
        {
          error: "recipient_user_id, title, body required",
        },
        400,
      );
    }

    const { data: tokenRows, error: tokenError } = await supabase
      .from("push_tokens")
      .select("fcm_token")
      .eq("user_id", recipientUserId)
      .limit(20);

    if (tokenError) {
      return jsonResponse({ error: tokenError.message }, 500);
    }

    const tokens = uniqueTokens(tokenRows ?? []);

    if (tokens.length === 0) {
      return jsonResponse({
        ok: true,
        sent: 0,
        success: 0,
        failed: 0,
        reason: "NO_TOKENS",
      });
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    if (!projectId) {
      return jsonResponse({ error: "Missing Firebase project_id" }, 500);
    }

    const accessToken = await getAccessToken();

    const results = await runLimited(tokens, 8, (token) =>
      sendFcmMessage({
        projectId,
        accessToken,
        token,
        title,
        messageBody,
        data,
      })
    );

    const invalidTokens = results
      .filter((result) => result.invalidToken)
      .map((result) => result.token);

    if (invalidTokens.length > 0) {
      await supabase
        .from("push_tokens")
        .delete()
        .in("fcm_token", invalidTokens);
    }

    const success = results.filter((result) => result.ok).length;
    const failed = results.length - success;

    return jsonResponse({
      ok: true,
      sent: results.length,
      success,
      failed,
      invalid_tokens_removed: invalidTokens.length,
      results: results.map((result) => ({
        ok: result.ok,
        status: result.status,
        response: result.response,
      })),
    });
  } catch (e) {
    return jsonResponse(
      {
        error: String(e),
      },
      500,
    );
  }
});
