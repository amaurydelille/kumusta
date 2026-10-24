import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { fetchCurrentLesson, readyQueueDepth } from "./repository.ts";

// Exercise the actual PostgREST query serialization, including the explicit
// ownership relationship (the queue has two foreign keys to generated lessons).
for (const accent of ["northern", "southern"]) {
  Deno.test(`queue selection and replenishment use only ${accent} lessons`, async () => {
    let reads = 0;
    const admin = createClient("https://example.supabase.co", "test-key", {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: (input, init) => {
          const url = new URL(String(input));
          if (url.searchParams.get("lesson.accent") !== `eq.${accent}`) {
            throw new Error("Queue request omitted the selected accent");
          }
          if (
            !url.searchParams.get("select")?.includes(
              "!kumusta_lesson_queue_lesson_owner_fk!inner",
            )
          ) {
            throw new Error("Accent filtering must use an unambiguous inner join");
          }
          if (url.searchParams.get("user_id") !== "eq.learner") {
            throw new Error("Queue request lost user isolation");
          }
          if (init?.method === "HEAD") {
            for (
              const [key, expected] of Object.entries({
                "lesson.status": "eq.ready",
                "lesson.schema_version": "eq.3",
                "lesson.prompt_version": "gte.14",
                "status": "in.(ready,started)",
              })
            ) {
              if (url.searchParams.get(key) !== expected) {
                throw new Error(`Queue capacity counted unusable lessons: ${key}`);
              }
            }
            if (!url.searchParams.has("lesson.expires_at")) {
              throw new Error("Expired lessons filled the queue");
            }
          }
          if (init?.method !== "GET" && init?.method !== "HEAD") {
            throw new Error("Other-accent lessons must remain untouched");
          }
          reads++;
          return Promise.resolve(
            new Response(init?.method === "HEAD" ? null : "[]", {
              status: 200,
              headers: { "content-type": "application/json", "content-range": "*/0" },
            }),
          );
        },
      },
    });
    if (await fetchCurrentLesson(admin, "learner", accent) !== null) {
      throw new Error("An empty matching queue must not deliver a lesson");
    }
    if (await readyQueueDepth(admin, "learner", accent) !== 0) {
      throw new Error("An empty matching queue must permit replenishment");
    }
    if (reads !== 2) throw new Error("Expected selection and depth queries");
  });
}

Deno.test("fresh lesson polling excludes the displayed lesson and older queue entries", async () => {
  const boundary = "2026-09-06T08:00:00.000Z";
  const excluded = "11111111-1111-4111-8111-111111111111";
  let checked = false;
  const admin = createClient("https://example.supabase.co", "test-key", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: (input) => {
        const url = new URL(String(input));
        if (
          url.searchParams.get("generated_lesson_id") !== `neq.${excluded}` ||
          url.searchParams.get("assigned_at") !== `gte.${boundary}` ||
          url.searchParams.get("user_id") !== "eq.learner"
        ) throw new Error("Freshness filtering was lost");
        checked = true;
        return Promise.resolve(
          new Response("[]", { headers: { "content-type": "application/json" } }),
        );
      },
    },
  });
  if (
    await fetchCurrentLesson(admin, "learner", "southern", excluded, boundary) !== null || !checked
  ) {
    throw new Error("Unexpected fresh lesson result");
  }
});
