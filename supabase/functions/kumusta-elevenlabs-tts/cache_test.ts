import { ttsCacheKey, ttsObjectPath } from "./cache.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const southernRequest = {
  text: "Xin chào",
  accent: "southern" as const,
  speed: "natural" as const,
  purpose: "lesson" as const,
  honorRequestedAccent: false,
};

const northernRequest = {
  ...southernRequest,
  accent: "northern" as const,
};

Deno.test("TTS cache separates identical text by Vietnamese accent", async () => {
  const southernKey = await ttsCacheKey(
    southernRequest,
    "6Xq32rHt6oAu98TBDKfr",
    "eleven_v4",
  );
  const northernKey = await ttsCacheKey(
    northernRequest,
    "LD1UihCXvSlUL4h8DOmk",
    "eleven_v4",
  );

  assert(southernKey !== northernKey, "Accent variants must not share a key");
  assert(southernKey.length === 64, "Cache keys must be SHA-256 hex values");
  assert(
    ttsObjectPath(southernKey, "lesson") !== ttsObjectPath(northernKey, "lesson"),
    "Accent variants must not share a Storage object path",
  );
});

Deno.test("Identical TTS requests reuse the same cache key", async () => {
  const firstKey = await ttsCacheKey(
    southernRequest,
    "6Xq32rHt6oAu98TBDKfr",
    "eleven_v4",
  );
  const secondKey = await ttsCacheKey(
    southernRequest,
    "6Xq32rHt6oAu98TBDKfr",
    "eleven_v4",
  );

  assert(firstKey === secondKey, "Identical requests must reuse their cache key");
});

Deno.test("Vocabulary cache is isolated from lesson cache", async () => {
  const vocabularyRequest = { ...southernRequest, purpose: "vocabulary" as const };
  const lessonKey = await ttsCacheKey(
    southernRequest,
    "6Xq32rHt6oAu98TBDKfr",
    "eleven_v4",
  );
  const vocabularyKey = await ttsCacheKey(
    vocabularyRequest,
    "6Xq32rHt6oAu98TBDKfr",
    "eleven_v4",
  );

  assert(lessonKey !== vocabularyKey, "Lesson and vocabulary requests must not share a cache key");
  assert(
    ttsObjectPath(lessonKey, "lesson").startsWith("v1/"),
    "Lesson audio must retain the existing cache namespace",
  );
  assert(
    ttsObjectPath(vocabularyKey, "vocabulary").startsWith("v2/"),
    "Vocabulary v3 audio must use its new cache namespace",
  );
});
