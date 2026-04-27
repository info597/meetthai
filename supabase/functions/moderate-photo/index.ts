import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const forbiddenContactPatterns = [
  /\bwhatsapp\b/i,
  /\btelegram\b/i,
  /\btme\b/i,
  /\bline\b/i,
  /\blineid\b/i,
  /\bfacebook\b/i,
  /\bfbcom\b/i,
  /\binstagram\b/i,
  /\binsta\b/i,
  /\big\b/i,
  /\bsnapchat\b/i,
  /\bgooglemeet\b/i,
  /\bmeetgooglecom\b/i,
  /\bgmail\b/i,
  /\bemail\b/i,
  /\bmail\b/i,
  /\bhttp\b/i,
  /\bhttps\b/i,
  /\bwww\b/i,
  /\bwame\b/i,
  /\bcom\b/i,
  /\bnet\b/i,
  /\borg\b/i,
  /\bat\b/i,
  /\bde\b/i,
  /\bco\b/i,
  /\+?\d[\d\s().-]{6,}\d/i,
  /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i,
  /(^|\s)@[a-z0-9._-]{3,}/i,
];

function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .replace(/[|]/g, "l")
    .replace(/0/g, "o")
    .replace(/1/g, "l")
    .replace(/3/g, "e")
    .replace(/4/g, "a")
    .replace(/5/g, "s")
    .replace(/7/g, "t")
    .replace(/@/g, "a")
    .replace(/[^a-z0-9+]/g, "");
}

function containsContactInfo(text: string): boolean {
  const compact = normalizeText(text);
  const spaced = text.toLowerCase().replace(/\s+/g, " ");

  if (forbiddenContactPatterns.some((pattern) => pattern.test(spaced))) {
    return true;
  }

  if (forbiddenContactPatterns.some((pattern) => pattern.test(compact))) {
    return true;
  }

  const hardWords = [
    "whatsapp",
    "telegram",
    "lineid",
    "line",
    "facebook",
    "instagram",
    "snapchat",
    "googlemeet",
    "gmail",
    "wame",
    "tme",
  ];

  return hardWords.some((word) => compact.includes(word));
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ allowed: false, reason: "Method not allowed" }),
        { status: 405, headers: { "Content-Type": "application/json" } },
      );
    }

    const apiUser = Deno.env.get("SIGHTENGINE_API_USER");
    const apiSecret = Deno.env.get("SIGHTENGINE_API_SECRET");

    if (!apiUser || !apiSecret) {
      return new Response(
        JSON.stringify({
          allowed: false,
          nudityScore: 1,
          reason: "Sightengine credentials missing",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const body = await req.json();
    const media = body.media;

    if (!media || typeof media !== "string") {
      return new Response(
        JSON.stringify({
          allowed: false,
          nudityScore: 1,
          reason: "Missing media",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const formData = new FormData();
    formData.append("models", "nudity-2.0,text-content");
    formData.append("api_user", apiUser);
    formData.append("api_secret", apiSecret);
    formData.append("media", media);

    const response = await fetch("https://api.sightengine.com/1.0/check.json", {
      method: "POST",
      body: formData,
    });

    if (!response.ok) {
      return new Response(
        JSON.stringify({
          allowed: true,
          nudityScore: 0,
          reason: "Sightengine API error - allowed during test",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const data = await response.json();
    const nudity = data?.nudity ?? {};
    const textContent = data?.text ?? {};
    const detectedText =
      (textContent?.text ?? textContent?.content ?? "").toString();

    const score = (key: string): number => {
      const value = nudity?.[key];
      return typeof value === "number" ? value : 0;
    };

    const sexualActivity = score("sexual_activity");
    const sexualDisplay = score("sexual_display");
    const erotica = score("erotica");
    const verySuggestive = score("very_suggestive");
    const suggestive = score("suggestive");

    const strongestNudityScore = Math.max(
      sexualActivity,
      sexualDisplay,
      erotica,
      verySuggestive,
      suggestive,
    );

    let allowed = true;
    let reason = "OK";

    if (sexualActivity >= 0.85) {
      allowed = false;
      reason = "Sexual activity detected";
    } else if (sexualDisplay >= 0.9) {
      allowed = false;
      reason = "Sexual display detected";
    } else if (erotica >= 0.95) {
      allowed = false;
      reason = "Erotica detected";
    } else if (verySuggestive >= 0.98) {
      allowed = false;
      reason = "Very suggestive image detected";
    } else if (
      detectedText.trim().isNotEmpty &&
      containsContactInfo(detectedText)
    ) {
      allowed = false;
      reason = "Contact information detected in image";
    }

    return new Response(
      JSON.stringify({
        allowed,
        nudityScore: strongestNudityScore,
        reason,
        debug: {
          sexualActivity,
          sexualDisplay,
          erotica,
          verySuggestive,
          suggestive,
          detectedText,
          normalizedText: normalizeText(detectedText),
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        allowed: true,
        nudityScore: 0,
        reason: `Exception allowed during test: ${String(e)}`,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }
});