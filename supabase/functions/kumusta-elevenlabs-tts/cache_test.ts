import { ttsCacheKey, ttsObjectPath } from "./cache.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const lessonRequest = {
  text: "Kumusta po kayo?",
  speed: "natural" as const,
  purpose: "lesson" as const,
};

const defaultVoiceID = "qZLi51uuzx5jdu6q0ayz";
const overrideVoiceID = "AbCdEf0123456789xyz";

Deno.test("TTS cache separates identical text by configured voice", async () => {
  const defaultKey = await ttsCacheKey(lessonRequest, defaultVoiceID, "eleven_v4");
  const overrideKey = await ttsCacheKey(lessonRequest, overrideVoiceID, "eleven_v4");

  assert(defaultKey !== overrideKey, "A voice change must not reuse old audio");
  assert(defaultKey.length === 64, "Cache keys must be SHA-256 hex values");
  assert(
    ttsObjectPath(defaultKey, "lesson") !== ttsObjectPath(overrideKey, "lesson"),
    "Voice variants must not share a Storage object path",
  );
});

Deno.test("Identical TTS requests reuse the same cache key", async () => {
  const firstKey = await ttsCacheKey(lessonRequest, defaultVoiceID, "eleven_v4");
  const secondKey = await ttsCacheKey({ ...lessonRequest }, defaultVoiceID, "eleven_v4");

  assert(firstKey === secondKey, "Identical requests must reuse their cache key");
});

Deno.test("TTS cache separates speeds and text", async () => {
  const natural = await ttsCacheKey(lessonRequest, defaultVoiceID, "eleven_v4");
  const fast = await ttsCacheKey(
    { ...lessonRequest, speed: "fast" as const },
    defaultVoiceID,
    "eleven_v4",
  );
  const other = await ttsCacheKey(
    { ...lessonRequest, text: "Salamat po." },
    defaultVoiceID,
    "eleven_v4",
  );

  assert(natural !== fast, "Speed variants must not share a key");
  assert(natural !== other, "Different text must not share a key");
});

Deno.test("Vocabulary cache is isolated from lesson cache", async () => {
  const vocabularyRequest = { ...lessonRequest, purpose: "vocabulary" as const };
  const lessonKey = await ttsCacheKey(lessonRequest, defaultVoiceID, "eleven_v4");
  const vocabularyKey = await ttsCacheKey(vocabularyRequest, defaultVoiceID, "eleven_v4");

  assert(lessonKey !== vocabularyKey, "Lesson and vocabulary requests must not share a cache key");
  assert(
    ttsObjectPath(lessonKey, "lesson").startsWith("v1/"),
    "Lesson audio must retain the existing cache namespace",
  );
  assert(
    ttsObjectPath(vocabularyKey, "vocabulary").startsWith("v2/"),
    "Vocabulary audio must use its own cache namespace",
  );
});
