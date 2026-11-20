import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface NotificationRecord {
  id?: string;
  user_id: string;
  title_ar: string;
  title_en: string;
  body_ar: string;
  body_en: string;
  type: string;
  data?: Record<string, unknown>;
  locale?: "ar" | "en";
}

interface WebhookPayload {
  type?: string;
  table?: string;
  schema?: string;
  record?: NotificationRecord;
  // Direct call fallback fields
  id?: string;
  user_id?: string;
  title_ar?: string;
  title_en?: string;
  body_ar?: string;
  body_en?: string;
  data?: Record<string, unknown>;
  locale?: "ar" | "en";
}

interface FcmServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);
  if (aBytes.length !== bBytes.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff === 0;
}

function isAuthorized(req: Request, serviceRoleKey: string): boolean {
  const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET")?.trim();
  const authHeader = req.headers.get("authorization")?.trim() ?? "";
  const bearerToken = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  const customSecret = req.headers.get("x-webhook-secret")?.trim() ?? "";
  const candidate = customSecret || bearerToken;

  if (!candidate) {
    return false;
  }

  if (webhookSecret && timingSafeEqual(candidate, webhookSecret)) {
    return true;
  }

  if (serviceRoleKey && timingSafeEqual(candidate, serviceRoleKey)) {
    return true;
  }

  return false;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getGoogleAccessToken(
  serviceAccount: FcmServiceAccount,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claimSet = base64UrlEncode(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );

  const signingInput = `${header}.${claimSet}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const body = await tokenResp.text();
    throw new Error(`Google OAuth token exchange failed (${tokenResp.status}): ${body}`);
  }

  const tokenJson = await tokenResp.json() as { access_token?: string };
  if (!tokenJson.access_token) {
    throw new Error("Google OAuth token response did not include access_token");
  }
  return tokenJson.access_token;
}

function stringifyDataPayload(
  notification: NotificationRecord,
): Record<string, string> {
  const out: Record<string, string> = {
    type: String(notification.type ?? "general"),
  };
  if (notification.id) {
    out.notification_id = String(notification.id);
  }
  if (notification.data && typeof notification.data === "object") {
    for (const [key, value] of Object.entries(notification.data)) {
      if (value !== undefined && value !== null) {
        out[key] = typeof value === "string" ? value : JSON.stringify(value);
      }
    }
  }
  return out;
}

function extractNotification(payload: WebhookPayload): NotificationRecord | null {
  const src = payload.record ?? payload;
  if (!src || !src.user_id) {
    return null;
  }
  return {
    id: src.id,
    user_id: src.user_id,
    title_ar: src.title_ar ?? src.title_en ?? "ونشي",
    title_en: src.title_en ?? src.title_ar ?? "Wenshy",
    body_ar: src.body_ar ?? src.body_en ?? "",
    body_en: src.body_en ?? src.body_ar ?? "",
    type: src.type ?? "general",
    data: src.data ?? {},
    locale: src.locale,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ ok: false, error: "Method not allowed. Use POST." }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
    console.error("[send-push-notification] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(
      JSON.stringify({ ok: false, error: "Server configuration missing" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  if (!isAuthorized(req, serviceRoleKey)) {
    return new Response(
      JSON.stringify({ ok: false, error: "Unauthorized" }),
      {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let rawBody: WebhookPayload;
  try {
    rawBody = await req.json() as WebhookPayload;
  } catch {
    return new Response(
      JSON.stringify({ ok: false, error: "Invalid JSON payload" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const notification = extractNotification(rawBody);
  if (!notification) {
    return new Response(
      JSON.stringify({ ok: false, error: "Missing required field: user_id" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Fetch user's preferred locale and active device tokens in parallel
  const [profileRes, tokensRes] = await Promise.all([
    supabase
      .from("profiles")
      .select("locale")
      .eq("id", notification.user_id)
      .maybeSingle(),
    supabase
      .from("device_tokens")
      .select("id, token, platform")
      .eq("user_id", notification.user_id)
      .eq("is_active", true),
  ]);

  if (tokensRes.error) {
    console.error("[send-push-notification] Failed to query device_tokens:", tokensRes.error.message);
    return new Response(
      JSON.stringify({ ok: false, error: tokensRes.error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const tokens = tokensRes.data ?? [];
  const fcmServiceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")?.trim();

  if (!fcmServiceAccountRaw) {
    console.info(
      `[send-push-notification] FCM_SERVICE_ACCOUNT_JSON not configured; skipped push for user=${notification.user_id}, type=${notification.type}, tokens_found=${tokens.length}`,
    );
    return new Response(
      JSON.stringify({
        ok: true,
        skipped: "fcm_not_configured",
        user_id: notification.user_id,
        tokens_found: tokens.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  if (tokens.length === 0) {
    return new Response(
      JSON.stringify({
        ok: true,
        skipped: "no_active_tokens",
        user_id: notification.user_id,
        tokens_found: 0,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let serviceAccount: FcmServiceAccount;
  try {
    serviceAccount = JSON.parse(fcmServiceAccountRaw) as FcmServiceAccount;
    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error("Missing project_id, client_email, or private_key");
    }
  } catch (err) {
    console.error("[send-push-notification] Invalid FCM_SERVICE_ACCOUNT_JSON:", err);
    return new Response(
      JSON.stringify({
        ok: false,
        error: "Invalid FCM_SERVICE_ACCOUNT_JSON secret",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let accessToken: string;
  try {
    accessToken = await getGoogleAccessToken(serviceAccount);
  } catch (err) {
    console.error("[send-push-notification] OAuth error:", err);
    return new Response(
      JSON.stringify({
        ok: false,
        error: err instanceof Error ? err.message : "OAuth failure",
      }),
      {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const locale = notification.locale ??
    (profileRes.data?.locale === "en" ? "en" : "ar");
  const title = locale === "en" ? notification.title_en : notification.title_ar;
  const body = locale === "en" ? notification.body_en : notification.body_ar;
  const fcmData = stringifyDataPayload(notification);
  const fcmEndpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  let sent = 0;
  let failed = 0;
  const staleTokenIds: string[] = [];

  await Promise.all(
    tokens.map(async (row) => {
      try {
        const resp = await fetch(fcmEndpoint, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.token,
              notification: { title, body },
              data: fcmData,
              android: {
                priority: "HIGH",
                notification: { sound: "default" },
              },
              apns: {
                payload: {
                  aps: { sound: "default" },
                },
              },
            },
          }),
        });

        if (resp.ok) {
          sent += 1;
          return;
        }

        failed += 1;
        const errBody = await resp.text();
        console.warn(
          `[send-push-notification] FCM send failed for token id=${row.id} (${resp.status}): ${errBody}`,
        );

        if (
          resp.status === 404 ||
          errBody.includes("UNREGISTERED") ||
          errBody.includes("REGISTRATION_TOKEN_NOT_REGISTERED")
        ) {
          staleTokenIds.push(row.id);
        }
      } catch (err) {
        failed += 1;
        console.error(
          `[send-push-notification] Network error sending to token id=${row.id}:`,
          err,
        );
      }
    }),
  );

  // Deactivate invalid/unregistered tokens so we stop retrying dead devices
  if (staleTokenIds.length > 0) {
    const { error: deactivateErr } = await supabase
      .from("device_tokens")
      .update({ is_active: false })
      .in("id", staleTokenIds);

    if (deactivateErr) {
      console.warn(
        "[send-push-notification] Failed to deactivate stale tokens:",
        deactivateErr.message,
      );
    }
  }

  return new Response(
    JSON.stringify({
      ok: true,
      user_id: notification.user_id,
      locale,
      tokens_found: tokens.length,
      sent,
      failed,
      deactivated_tokens: staleTokenIds.length,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});
