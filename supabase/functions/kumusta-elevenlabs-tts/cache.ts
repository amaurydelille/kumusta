import { consistentVoiceSettings, type TTSPurpose, type TTSRequest } from "./contract.ts";

export const ttsCacheBucket = "kumusta-tts";
export const lessonTTSCacheVersion = "v1";
export const vocabularyTTSCacheVersion = "v2";
export const lessonTTSSettingsVersion = "voice-settings-v3-v1";
export const vocabularyTTSSettingsVersion = "voice-settings-v3-v1";
export const ttsOutputFormat = "mp3_44100_128";

export function ttsCacheVersionForPurpose(purpose: TTSPurpose): string {
  return purpose === "vocabulary" ? vocabularyTTSCacheVersion : lessonTTSCacheVersion;
}

export function ttsSettingsVersionForPurpose(purpose: TTSPurpose): string {
  return purpose === "vocabulary" ? vocabularyTTSSettingsVersion : lessonTTSSettingsVersion;
}

/// The accent is deliberately included twice: as the requested regional
/// variant and as the server-owned voice ID. This makes it impossible for a
/// Southern and Northern request for identical text to share a cache row.
export async function ttsCacheKey(
  input: TTSRequest,
  voiceID: string,
  modelID: string,
): Promise<string> {
  const cacheMaterial = [
    ttsCacheVersionForPurpose(input.purpose),
    input.text,
    input.accent,
    input.speed,
    voiceID,
    modelID,
    ttsOutputFormat,
    ttsSettingsVersionForPurpose(input.purpose),
    JSON.stringify(consistentVoiceSettings(input.speed)),
  ].join("\u0000");
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(cacheMaterial),
  );
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function ttsObjectPath(cacheKey: string, purpose: TTSPurpose): string {
  return `${ttsCacheVersionForPurpose(purpose)}/${cacheKey}.mp3`;
}
