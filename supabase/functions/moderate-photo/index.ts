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

    const body = await req.json();

    const texts: string[] = [];

    if (Array.isArray(body.texts)) {
      for (const item of body.texts) {
        texts.push(String(item ?? ""));
      }
    } else {
      texts.push(String(body.text ?? ""));
    }

    const joinedText = texts.join(" ").trim();

    if (joinedText.length === 0) {
      return new Response(
        JSON.stringify({ allowed: true, reason: "Empty text allowed" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    if (containsContactInfo(joinedText)) {
      return new Response(
        JSON.stringify({
          allowed: false,
          reason: "Contact or social media information detected",
          debug: {
            normalizedText: normalizeText(joinedText),
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        allowed: true,
        reason: "OK",
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        allowed: true,
        reason: `Error allowed during test: ${String(e)}`,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }
});