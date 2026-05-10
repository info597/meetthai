import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const languageNames: Record<string, string> = {
  de: "German",
  en: "English",
  th: "Thai",
  es: "Spanish",
  fr: "French",
  it: "Italian",
  pt: "Portuguese",
  nl: "Dutch",
  ru: "Russian",
  uk: "Ukrainian",
  tr: "Turkish",
  ar: "Arabic",
  zh: "Chinese",
  ja: "Japanese",
  ko: "Korean",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeLanguageCode(value: unknown): string {
  const raw = String(value ?? "en").trim().toLowerCase();

  if (raw.length === 0) return "en";

  const code = raw.split(/[-_]/)[0];

  if (languageNames[code]) return code;

  return "en";
}

function getTargetLanguageName(code: string): string {
  return languageNames[code] ?? "English";
}

function cleanText(value: unknown): string {
  return String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", {
        status: 200,
        headers: corsHeaders,
      });
    }

    if (req.method !== "POST") {
      return jsonResponse(
        {
          error: "Method not allowed",
        },
        405,
      );
    }

    const openAiApiKey = Deno.env.get("OPENAI_API_KEY");

    if (!openAiApiKey) {
      return jsonResponse(
        {
          error: "OPENAI_API_KEY is not configured",
        },
        500,
      );
    }

    const body = await req.json();

    const text = cleanText(body.text);
    const targetLanguageCode = normalizeLanguageCode(
      body.target_language ?? body.targetLanguage ?? body.language,
    );
    const targetLanguageName = getTargetLanguageName(targetLanguageCode);

    if (text.length === 0) {
      return jsonResponse({
        translated_text: "",
        target_language: targetLanguageCode,
      });
    }

    if (text.length > 2000) {
      return jsonResponse(
        {
          error: "Text too long",
          max_length: 2000,
        },
        400,
      );
    }

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        input: [
          {
            role: "system",
            content:
              "You are a professional chat translation engine for a dating app. Translate the user's message into the requested target language. Preserve the meaning, tone, emojis, and natural conversational style. Do not add explanations. Return only the translated text.",
          },
          {
            role: "user",
            content:
              `Target language: ${targetLanguageName}\n\nText:\n${text}`,
          },
        ],
        temperature: 0.2,
        max_output_tokens: 500,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();

      return jsonResponse(
        {
          error: "Translation provider error",
          details: errorText,
        },
        502,
      );
    }

    const result = await response.json();

    const translatedText =
      result.output_text ??
      result.output?.[0]?.content?.[0]?.text ??
      result.choices?.[0]?.message?.content ??
      "";

    const finalText = cleanText(translatedText);

    if (finalText.length === 0) {
      return jsonResponse(
        {
          error: "Empty translation response",
        },
        502,
      );
    }

    return jsonResponse({
      translated_text: finalText,
      target_language: targetLanguageCode,
    });
  } catch (e) {
    return jsonResponse(
      {
        error: "Unexpected translation error",
        details: String(e),
      },
      500,
    );
  }
});
