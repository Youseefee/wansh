import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-scheduler-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
  const schedulerSecret = Deno.env.get("SCHEDULER_SECRET")?.trim();
  const authHeader = req.headers.get("authorization")?.trim() ?? "";
  const bearerToken = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  const customSecret = req.headers.get("x-scheduler-secret")?.trim() ?? "";
  const candidate = customSecret || bearerToken;

  if (!candidate) {
    return false;
  }

  if (schedulerSecret && timingSafeEqual(candidate, schedulerSecret)) {
    return true;
  }

  if (serviceRoleKey && timingSafeEqual(candidate, serviceRoleKey)) {
    return true;
  }

  return false;
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
    console.error("[dispatch-scheduler] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
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

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.rpc(
    "expire_stale_requests_and_advance_waves",
  );

  if (error) {
    console.error("[dispatch-scheduler] RPC failed:", error.message);
    return new Response(
      JSON.stringify({
        ok: false,
        error: error.message,
        code: error.code ?? null,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  return new Response(
    JSON.stringify({
      ok: true,
      summary: data,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});
