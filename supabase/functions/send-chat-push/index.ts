import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

let cachedAccessToken: string | null = null;
let cachedAccessTokenExpiresAt = 0;

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function fetchWithTimeout(
  input: string,
  init: RequestInit,
  timeoutMs = 8000,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort("timeout"), timeoutMs);

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

function base64UrlEncodeString(input: string): string {
  return btoa(input)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";

  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function createJwt(serviceAccount: {
  client_email: string;
  private_key: string;
  token_uri?: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: serviceAccount.token_uri || "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encodedHeader = base64UrlEncodeString(JSON.stringify(header));
  const encodedPayload = base64UrlEncodeString(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const pem = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken),
  );

  const encodedSignature = base64UrlEncodeBytes(new Uint8Array(signature));
  return `${unsignedToken}.${encodedSignature}`;
}

async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  token_uri?: string;
}): Promise<string> {
  const nowMs = Date.now();

  if (cachedAccessToken && nowMs < cachedAccessTokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }

  const jwt = await createJwt(serviceAccount);

  const tokenRes = await fetchWithTimeout(
    serviceAccount.token_uri || "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body:
        `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
    },
    10000,
  );

  const raw = await tokenRes.text();
  let parsed: Record<string, unknown> = {};

  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`Token response not JSON: ${raw}`);
  }

  if (!tokenRes.ok) {
    throw new Error(`Token request failed (${tokenRes.status}): ${raw}`);
  }

  const accessToken = parsed.access_token;

  if (typeof accessToken !== "string" || !accessToken) {
    throw new Error(`Missing access_token in token response: ${raw}`);
  }

  cachedAccessToken = accessToken;
  cachedAccessTokenExpiresAt = nowMs + 55 * 60 * 1000;

  return accessToken;
}

function normalizePushBody(messageType: string, body: string): string {
  const trimmed = body.trim();

  if (messageType === "image") return "📷 Bild";
  if (messageType === "short") return "🎬 Short";
  if (trimmed.length > 0) return trimmed;
  return "Neue Nachricht";
}

function safeDataValue(value: string): string {
  return value == null ? "" : String(value);
}

function isInvalidFcmTokenResponse(response: unknown): boolean {
  const text = JSON.stringify(response);

  return (
    text.includes("UNREGISTERED") ||
    text.includes("INVALID_ARGUMENT") ||
    text.includes("Requested entity was not found") ||
    text.includes("registration token is not a valid FCM registration token") ||
    text.includes("The registration token is not a valid FCM registration token")
  );
}

async function runLimited<T, R>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = [];
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

type PushTokenMeta = {
  token: string;
  rowId: number | null;
  platform: string;
};

type SendResult = {
  token: string;
  platform: string;
  ok: boolean;
  status: number;
  response?: unknown;
  error?: string;
  invalidToken: boolean;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    let body: Record<string, unknown>;

    try {
      body = await req.json();
    } catch (_) {
      return jsonResponse({ error: "Invalid JSON body" }, 400);
    }

    const messageId = body.message_id?.toString().trim();
    const conversationId = body.conversation_id?.toString().trim();
    const senderId = body.sender_id?.toString().trim();
    const recipientId = body.recipient_id?.toString().trim();
    const messageBody = body.body?.toString() ?? "";
    const messageType = body.message_type?.toString() ?? "text";
    const mediaUrl = body.media_url?.toString() ?? "";
    const thumbnailUrl = body.thumbnail_url?.toString() ?? "";
    const durationSeconds = body.duration_seconds?.toString() ?? "";
    const titleFromCaller = body.title?.toString()?.trim() ?? "";
    const pushBodyFromCaller = body.push_body?.toString()?.trim() ?? "";

    console.log("send-chat-push invoked", {
      messageId,
      conversationId,
      senderId,
      recipientId,
      messageType,
    });

    if (!messageId || !conversationId || !senderId || !recipientId) {
      return jsonResponse(
        {
          error:
            "message_id, conversation_id, sender_id, recipient_id required",
        },
        400,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const serviceAccountJson =
      Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "";

    if (!supabaseUrl || !serviceRoleKey || !serviceAccountJson) {
      return jsonResponse(
        {
          error:
            "Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY or GOOGLE_SERVICE_ACCOUNT_JSON",
          hasSupabaseUrl: !!supabaseUrl,
          hasServiceRoleKey: !!serviceRoleKey,
          hasGoogleServiceAccountJson: !!serviceAccountJson,
        },
        500,
      );
    }

    let serviceAccount: {
      project_id: string;
      client_email: string;
      private_key: string;
      token_uri?: string;
    };

    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch (e) {
      return jsonResponse(
        {
          error: "GOOGLE_SERVICE_ACCOUNT_JSON is not valid JSON",
          detail: e instanceof Error ? e.message : String(e),
        },
        500,
      );
    }

    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      return jsonResponse(
        {
          error:
            "GOOGLE_SERVICE_ACCOUNT_JSON missing project_id, client_email or private_key",
        },
        500,
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: blockRows, error: blockError } = await supabase
      .from("user_blocks")
      .select("id")
      .or(
        `and(blocker_user_id.eq.${senderId},blocked_user_id.eq.${recipientId}),and(blocker_user_id.eq.${recipientId},blocked_user_id.eq.${senderId})`,
      )
      .limit(1);

    if (blockError) {
      return jsonResponse({ error: blockError.message }, 500);
    }

    if (Array.isArray(blockRows) && blockRows.length > 0) {
      console.log("push skipped: blocked_pair", {
        senderId,
        recipientId,
        conversationId,
      });

      return jsonResponse({
        success: true,
        skipped: true,
        reason: "blocked_pair",
      });
    }

    const { data: presenceRows, error: presenceError } = await supabase
      .from("chat_presence")
      .select("conversation_id")
      .eq("user_id", recipientId)
      .eq("conversation_id", conversationId)
      .gte("updated_at", new Date(Date.now() - 30 * 1000).toISOString())
      .limit(1);

    if (presenceError) {
      console.error("presenceError", presenceError);
    }

    const recipientIsActiveInChat =
      Array.isArray(presenceRows) && presenceRows.length > 0;

    if (recipientIsActiveInChat) {
      console.log("push skipped: recipient_active_in_chat", {
        recipientId,
        conversationId,
      });

      return jsonResponse({
        success: true,
        skipped: true,
        reason: "recipient_active_in_chat",
      });
    }

    const { data: senderProfile, error: senderProfileError } = await supabase
      .from("profiles")
      .select("display_name, avatar_url")
      .eq("user_id", senderId)
      .maybeSingle();

    if (senderProfileError) {
      console.error("senderProfileError", senderProfileError);
    }

    const senderDisplayName =
      titleFromCaller ||
      senderProfile?.display_name?.toString()?.trim() ||
      "Neue Nachricht";

    const senderAvatarUrl =
      senderProfile?.avatar_url?.toString()?.trim() || "";

    const { data: tokenRows, error: tokenError } = await supabase
      .from("push_tokens")
      .select("id, token, fcm_token, platform")
      .eq("user_id", recipientId)
      .limit(20);

    if (tokenError) {
      return jsonResponse({ error: tokenError.message }, 500);
    }

    const uniqueTokens = new Map<string, PushTokenMeta>();

    for (const row of tokenRows ?? []) {
      const token =
        row?.fcm_token?.toString().trim() ||
        row?.token?.toString().trim() ||
        "";

      if (!token) continue;

      uniqueTokens.set(token, {
        token,
        rowId: typeof row?.id === "number" ? row.id : null,
        platform: row?.platform?.toString() ?? "unknown",
      });
    }

    const tokens = Array.from(uniqueTokens.values());

    if (tokens.length === 0) {
      console.log("push skipped: no_push_tokens", {
        recipientId,
      });

      return jsonResponse({
        success: true,
        skipped: true,
        reason: "no_push_tokens",
      });
    }

    const notificationBody =
      pushBodyFromCaller || normalizePushBody(messageType, messageBody);

    const accessToken = await getGoogleAccessToken(serviceAccount);

    const sendResults = await runLimited(tokens, 8, async (tokenMeta) => {
      const fcmPayload = {
        message: {
          token: tokenMeta.token,
          notification: {
            title: senderDisplayName,
            body: notificationBody,
          },
          data: {
            type: "chat_message",
            message_id: safeDataValue(messageId),
            conversation_id: safeDataValue(conversationId),
            sender_id: safeDataValue(senderId),
            recipient_id: safeDataValue(recipientId),
            other_user_id: safeDataValue(senderId),
            other_display_name: safeDataValue(senderDisplayName),
            other_avatar_url: safeDataValue(senderAvatarUrl),
            message_type: safeDataValue(messageType),
            body: safeDataValue(messageBody),
            media_url: safeDataValue(mediaUrl),
            thumbnail_url: safeDataValue(thumbnailUrl),
            duration_seconds: safeDataValue(durationSeconds),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          webpush: {
            notification: {
              title: senderDisplayName,
              body: notificationBody,
            },
            fcm_options: {
              link: "/#/chats",
            },
          },
          android: {
            priority: "high",
            notification: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              channel_id: "chat_messages",
              sound: "default",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        },
      };

      try {
        const fcmRes = await fetchWithTimeout(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmPayload),
          },
          10000,
        );

        const rawText = await fcmRes.text();
        let parsed: unknown = rawText;

        try {
          parsed = JSON.parse(rawText);
        } catch {
          // rawText bleibt drin
        }

        const invalidToken = !fcmRes.ok && isInvalidFcmTokenResponse(parsed);

        console.log("push send result", {
          recipientId,
          platform: tokenMeta.platform,
          ok: fcmRes.ok,
          status: fcmRes.status,
        });

        return {
          token: tokenMeta.token,
          platform: tokenMeta.platform,
          ok: fcmRes.ok,
          status: fcmRes.status,
          response: parsed,
          invalidToken,
        } satisfies SendResult;
      } catch (err) {
        console.error("push send failed", {
          recipientId,
          platform: tokenMeta.platform,
          error: err instanceof Error ? err.message : String(err),
        });

        return {
          token: tokenMeta.token,
          platform: tokenMeta.platform,
          ok: false,
          status: 0,
          error: err instanceof Error ? err.message : String(err),
          invalidToken: false,
        } satisfies SendResult;
      }
    });

    const invalidTokens = sendResults
      .filter((result) => result.invalidToken)
      .map((result) => result.token);

    if (invalidTokens.length > 0) {
      await supabase
        .from("push_tokens")
        .delete()
        .eq("user_id", recipientId)
        .or(
          `token.in.(${invalidTokens.join(",")}),fcm_token.in.(${invalidTokens.join(",")})`,
        );
    }

    const successCount = sendResults.filter((result) => result.ok).length;
    const failedCount = sendResults.length - successCount;

    console.log("send-chat-push finished", {
      recipientId,
      sent: sendResults.length,
      success: successCount,
      failed: failedCount,
      invalidTokensRemoved: invalidTokens.length,
    });

    return jsonResponse({
      success: true,
      sent: sendResults.length,
      success_count: successCount,
      failed_count: failedCount,
      invalid_tokens_removed: invalidTokens.length,
      results: sendResults.map((result) => ({
        platform: result.platform,
        ok: result.ok,
        status: result.status,
        response: result.response,
        error: result.error,
      })),
    });
  } catch (e) {
    console.error("send-chat-push fatal error", e);

    return jsonResponse(
      {
        error: e instanceof Error ? e.message : String(e),
      },
      500,
    );
  }
});
