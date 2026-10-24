// Generates the generic ("bạn") first-conversation clips for both accents
// through the deployed TTS Edge Function, so they are already in the shared
// TTS cache when a learner skips their name or a personalized clip fails.
//
// Usage (after deploying kumusta-elevenlabs-tts):
//   deno run --allow-net --allow-read scripts/prewarm-onboarding-conversation-audio.ts
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const genericLines = [
  "greeting",
  "ask_name",
  "reply_hello",
  "ask_wellbeing",
  "reply_wellbeing",
  "nice_to_meet",
] as const;

const configuration = await Deno.readTextFile("Config/Secrets.xcconfig");
const baseURL = setting("SUPABASE_PROJECT_URL");
const publishableKey = setting("SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY");

let failures = 0;
for (const accent of ["southern", "northern"] as const) {
  // One anonymous identity per accent keeps each under the pre-paywall quota.
  const client = createClient(baseURL, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.signInAnonymously();
  if (error || !data.session) throw error ?? new Error("Anonymous session missing");

  for (const line of genericLines) {
    const response = await fetch(`${baseURL}/functions/v1/kumusta-elevenlabs-tts`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${data.session.access_token}`,
        apikey: publishableKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ purpose: "onboarding_conversation", line, accent }),
    });
    const body = new Uint8Array(await response.arrayBuffer());
    const cache = response.headers.get("x-kumusta-tts-cache") ?? "-";
    if (!response.ok) failures += 1;
    console.log(
      `${accent.padEnd(8)} ${line.padEnd(16)} ${response.status} cache=${cache} bytes=${body.byteLength}`,
    );
  }
}
if (failures > 0) {
  console.error(`${failures} clip(s) failed.`);
  Deno.exit(1);
}

function setting(...keys: string[]): string {
  for (const key of keys) {
    const match = new RegExp(`^\\s*${key}\\s*=\\s*(.+?)\\s*$`, "m").exec(configuration);
    // xcconfig escapes "//" as "/$()/" so URLs survive comment parsing.
    if (match) return match[1].replaceAll("$()", "");
  }
  throw new Error(`Missing ${keys.join(" or ")} in Config/Secrets.xcconfig`);
}
