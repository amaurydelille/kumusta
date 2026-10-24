import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { fetchCurrentLesson, readyQueueDepth } from "./repository.ts";

// Exercise the actual PostgREST query serialization, including the explicit
// ownership relationship (the queue has two foreign keys to generated lessons).
// There is one Tagalog lesson pool per learner, so no request may filter by
// accent or any other variant column.
Deno.test("queue selection and replenishment use the learner's whole queue", async () => {
  let reads = 0;
  const admin = createClient("https://example.supabase.co", "test-key", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: (input, init) => {
        const url = new URL(String(input));
        for (const key of url.searchParams.keys()) {
          if (key.includes("accent")) {
            throw new Error(`Queue request still filters by accent: ${key}`);
          }
        }
        if (url.searchParams.get("select")?.includes("accent")) {
          throw new Error("Queue request still selects an accent column");
        }
        if (url.searchParams.get("user_id") !== "eq.learner") {
          throw new Error("Queue request lost user isolation");
        }
        if (url.searchParams.get("status") !== "in.(ready,started)") {
          throw new Error("Queue request must only consider ready or started entries");
        }
        if (init?.method === "HEAD") {
          if (
            !url.searchParams.get("select")?.includes(
              "!kumusta_lesson_queue_lesson_owner_fk!inner",
            )
          ) {
            throw new Error("Lesson filtering must use an unambiguous inner join");
          }
          for (
            const [key, expected] of Object.entries({
              "lesson.status": "eq.ready",
              "lesson.schema_version": "eq.3",
            })
          ) {
            if (url.searchParams.get(key) !== expected) {
              throw new Error(`Queue capacity counted unusable lessons: ${key}`);
            }
          }
          if (!url.searchParams.getAll("lesson.prompt_version").includes("gte.14")) {
            throw new Error("Queue capacity counted outdated prompt versions");
          }
          if (!url.searchParams.has("lesson.expires_at")) {
            throw new Error("Expired lessons filled the queue");
          }
        }
        if (init?.method !== "GET" && init?.method !== "HEAD") {
          throw new Error("An empty queue must not trigger writes");
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
  if (await fetchCurrentLesson(admin, "learner") !== null) {
    throw new Error("An empty queue must not deliver a lesson");
  }
  if (await readyQueueDepth(admin, "learner") !== 0) {
    throw new Error("An empty queue must permit replenishment");
  }
  if (reads !== 2) throw new Error("Expected selection and depth queries");
});

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
    await fetchCurrentLesson(admin, "learner", excluded, boundary) !== null || !checked
  ) {
    throw new Error("Unexpected fresh lesson result");
  }
});
