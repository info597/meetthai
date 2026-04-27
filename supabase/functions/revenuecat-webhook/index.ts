import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    console.log("RC Webhook:", JSON.stringify(body, null, 2));

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
      return new Response("Missing Supabase env", {
        status: 500,
        headers: corsHeaders,
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const event = body?.event;
    if (!event) {
      console.error("Missing event in webhook body");
      return new Response("Missing event", {
        status: 400,
        headers: corsHeaders,
      });
    }

    const userId = event.app_user_id?.toString();
    const productId = event.product_id?.toString().toLowerCase() || "";
    const eventType = event.type?.toString() || "";
    const entitlements = Array.isArray(event.entitlement_ids)
      ? event.entitlement_ids.map((e: unknown) => String(e).toLowerCase())
      : [];

    if (!userId) {
      console.error("Missing app_user_id");
      return new Response("Missing app_user_id", {
        status: 400,
        headers: corsHeaders,
      });
    }

    console.log("User:", userId);
    console.log("Event:", eventType);
    console.log("Product:", productId);
    console.log("Entitlements:", entitlements);

    // =========================
    // PLAN LOGIK
    // =========================

    let isPremium = false;
    let isGold = false;
    let planCode = "free";
    let billingPeriod: string | null = null;

    // Priorität: Entitlements
    if (entitlements.includes("gold")) {
      isGold = true;
      isPremium = true;
      planCode = "gold";
    } else if (entitlements.includes("premium")) {
      isPremium = true;
      planCode = "premium";
    }

    // Fallback: Product ID
    if (!isPremium && !isGold) {
      if (productId.includes("gold")) {
        isGold = true;
        isPremium = true;
        planCode = "gold";
      } else if (productId.includes("premium")) {
        isPremium = true;
        planCode = "premium";
      }
    }

    // Billing Period
    if (productId.includes("month")) billingPeriod = "monthly";
    else if (productId.includes("year")) billingPeriod = "yearly";
    else if (productId.includes("semi")) billingPeriod = "semiannual";

    // =========================
    // CANCEL LOGIK
    // =========================

    let cancelAtPeriodEnd = false;

    if (eventType === "CANCELLATION") {
      cancelAtPeriodEnd = true;
    }

    // =========================
    // TESTUMGEBUNG
    // =========================
    // Damit du Retention / Cancel UI testen kannst, ohne echtes Kündigen:
    //
    // Möglichkeit 1:
    // RevenueCat TEST Event + Produktname enthält "cancel_test"
    //
    // Beispiel Produktname:
    // premium_cancel_test
    // gold_cancel_test
    //
    // Dann setzt der Webhook:
    // cancel_at_period_end = true
    //
    if (eventType === "TEST" && productId.includes("cancel_test")) {
      cancelAtPeriodEnd = true;

      // optional auch Plan daraus ableiten
      if (productId.includes("gold")) {
        isGold = true;
        isPremium = true;
        planCode = "gold";
      } else if (productId.includes("premium")) {
        isPremium = true;
        isGold = false;
        planCode = "premium";
      }

      if (productId.includes("month")) billingPeriod = "monthly";
      else if (productId.includes("year")) billingPeriod = "yearly";
      else if (productId.includes("semi")) billingPeriod = "semiannual";
    }

    // =========================
    // EXPIRATION
    // =========================

    const expiresAt = event.expiration_at_ms
      ? new Date(Number(event.expiration_at_ms)).toISOString()
      : null;

    console.log("FINAL:", {
      isPremium,
      isGold,
      planCode,
      billingPeriod,
      cancelAtPeriodEnd,
      expiresAt,
    });

    // =========================
    // DB UPDATE
    // =========================

    const { error } = await supabase
      .from("profiles")
      .update({
        is_premium: isPremium,
        is_gold: isGold,
        plan_code: planCode,
        billing_period: billingPeriod,
        subscription_status: isPremium ? "active" : "expired",
        subscription_source: eventType === "TEST" ? "test_store" : "revenuecat",
        subscription_expires_at: expiresAt,
        cancel_at_period_end: cancelAtPeriodEnd,
        revenuecat_app_user_id: userId,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);

    if (error) {
      console.error("DB ERROR:", error);
      return new Response("DB error", {
        status: 500,
        headers: corsHeaders,
      });
    }

    return new Response("ok", {
      status: 200,
      headers: corsHeaders,
    });
  } catch (e) {
    console.error("Webhook ERROR:", e);
    return new Response("error", {
      status: 500,
      headers: corsHeaders,
    });
  }
});