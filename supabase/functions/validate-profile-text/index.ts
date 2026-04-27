import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

function normalize(input: string): string {
  return input
    .toLowerCase()
    .replace(/[\u200B-\u200D\uFEFF]/g, "") // zero-width entfernen
    .replace(/[^a-z0-9@.+]/g, "") // sonderzeichen weg
    .replace(/(.)\1+/g, "$1"); // doppelte chars reduzieren
}

function containsForbidden(text: string): boolean {
  const raw = text.toLowerCase();
  const compact = normalize(text);

  const patterns = [
    /whatsapp/,
    /telegram/,
    /lineid/,
    /facebook/,
    /instagram/,
    /snapchat/,
    /googlemeet/,
    /gmail/,
    /wame/,
    /tme/,
    /http/,
    /https/,
    /www/,
    /\.com/,
    /\.net/,
    /\.org/,
    /\.at/,
    /\.de/,
    /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/,
    /\+?\d[\d\s().-]{6,}\d/,
    /(^|\s)@[a-z0-9._-]{3,}/,
  ];

  for (const p of patterns) {
    if (p.test(raw)) return true;
  }

  for (const p of patterns) {
    if (p.test(compact)) return true;
  }

  return false;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ allowed: false, reason: "Method not allowed" }),
        { status: 405 }
      );
    }

    const body = await req.json();

    const fields: string[] = [
      body.display_name ?? "",
      body.job ?? "",
      body.other_job ?? "",
      body.origin_country ?? "",
      body.province ?? "",
      body.postal_code ?? "",
      body.about_me ?? "",
      body.hobbies ?? "",
      body.preferred_origin_country ?? "",
    ];

    for (const field of fields) {
      if (containsForbidden(field)) {
        return new Response(
          JSON.stringify({
            allowed: false,
            reason: "Forbidden contact info detected",
          }),
          { status: 200 }
        );
      }
    }

    return new Response(
      JSON.stringify({ allowed: true }),
      { status: 200 }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        allowed: false,
        reason: "Server error",
      }),
      { status: 500 }
    );
  }
});