import { HttpError } from "../_shared/http.ts";

export type VietnameseAccent = "southern" | "northern";
export type SpeechSpeed = "slow" | "natural" | "fast";
export type TTSPurpose = "lesson" | "vocabulary";

export interface TTSRequest {
  text: string;
  accent: VietnameseAccent;
  speed: SpeechSpeed;
  purpose: TTSPurpose;
  honorRequestedAccent: boolean;
  /// Set only for the pre-paywall first conversation. The text was built
  /// server-side from a fixed template, so it cannot be arbitrary speech.
  onboardingLine?: OnboardingConversationLine;
}

export type OnboardingConversationLine =
  | "greeting"
  | "ask_name"
  | "reply_hello"
  | "reply_name"
  | "ask_wellbeing"
  | "reply_wellbeing"
  | "nice_to_meet";

/// Personalized lines fall back to the generic "bạn" wording when no name is
/// supplied. The generic clips are shared across all learners in the cache.
const onboardingTemplates: Record<
  OnboardingConversationLine,
  { named?: (name: string) => string; generic?: string }
> = {
  greeting: { named: (name) => `Chào ${name}!`, generic: "Chào bạn!" },
  ask_name: { generic: "Bạn tên gì?" },
  reply_hello: { generic: "Chào bạn!" },
  reply_name: { named: (name) => `Mình tên là ${name}.` },
  ask_wellbeing: { generic: "Bạn khỏe không?" },
  reply_wellbeing: { generic: "Mình khỏe, cảm ơn bạn!" },
  nice_to_meet: {
    named: (name) => `Rất vui được gặp ${name}!`,
    generic: "Rất vui được gặp bạn!",
  },
};

/// A first name: letters (any script, with combining marks), single spaces,
/// hyphens, apostrophes, and dots. No digits or punctuation that could steer
/// the speech model, and short enough to stay a name.
export function normalizedOnboardingName(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") {
    throw new HttpError(400, "invalid_name", "The name is not valid.");
  }
  const name = value.normalize("NFC").trim().replace(/\s+/gu, " ");
  if (name.length === 0) return null;
  if (
    name.length > 30 ||
    name.split(" ").length > 3 ||
    !/^[\p{L}\p{M}]+(?:[ '’.-][\p{L}\p{M}]+)*\.?$/u.test(name)
  ) {
    throw new HttpError(400, "invalid_name", "The name is not valid.");
  }
  return name;
}

export function onboardingConversationText(
  line: OnboardingConversationLine,
  name: string | null,
): string {
  const template = onboardingTemplates[line];
  if (name && template.named) return template.named(name);
  if (template.generic) return template.generic;
  throw new HttpError(400, "name_required", "This line needs a name.");
}

function parseOnboardingRequest(body: Record<string, unknown>): TTSRequest {
  if (typeof body.line !== "string" || !Object.hasOwn(onboardingTemplates, body.line)) {
    throw new HttpError(400, "invalid_line", "Choose a supported onboarding line.");
  }
  if (body.accent !== "southern" && body.accent !== "northern") {
    throw new HttpError(400, "invalid_accent", "Choose Southern or Northern.");
  }
  const line = body.line as OnboardingConversationLine;
  const name = normalizedOnboardingName(body.name);
  return {
    text: onboardingConversationText(line, name),
    accent: body.accent,
    speed: "natural",
    // Share the lesson cache: identical generic lines are generated once.
    purpose: "lesson",
    // The learner picked this accent seconds ago; preferences may not exist yet.
    honorRequestedAccent: true,
    onboardingLine: line,
  };
}

/// All Vietnamese speech uses the same expressive model so lesson, practice,
/// history, and vocabulary playback have one consistent voice profile.
export const vietnameseTTSModelID = "eleven_v4" as const;

// Keep purpose-specific aliases for callers/tests that describe the audio
// surface, while making it impossible for those surfaces to drift apart.
export const vietnameseLessonTTSModelID = vietnameseTTSModelID;
export const vietnameseVocabularyTTSModelID = vietnameseTTSModelID;

export function ttsModelIDForPurpose(_purpose: TTSPurpose): string {
  return vietnameseTTSModelID;
}

export interface ConsistentVoiceSettings {
  stability: number;
  similarity_boost: number;
  style: number;
  use_speaker_boost: boolean;
  speed: number;
}

const approvedVoiceIDs: Record<VietnameseAccent, string> = {
  southern: "6Xq32rHt6oAu98TBDKfr",
  northern: "LD1UihCXvSlUL4h8DOmk",
};

export function parseTTSRequest(body: Record<string, unknown>): TTSRequest {
  if (body.purpose === "onboarding_conversation") return parseOnboardingRequest(body);
  if (
    typeof body.text !== "string" ||
    typeof body.accent !== "string" ||
    typeof body.speed !== "string"
  ) {
    throw new HttpError(
      400,
      "invalid_request",
      "Text, accent, and speed are required.",
    );
  }
  const purpose = body.purpose === undefined ? "lesson" : body.purpose;
  if (purpose !== "lesson" && purpose !== "vocabulary") {
    throw new HttpError(400, "invalid_purpose", "Choose lesson or vocabulary audio.");
  }
  const text = normalizedTTSText(body.text, purpose);
  if (
    text.length < 1 ||
    text.length > 500 ||
    hasLeadingSpeakerLabel(text) ||
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(text)
  ) {
    throw new HttpError(
      400,
      "invalid_text",
      "Text must be between 1 and 500 characters.",
    );
  }
  if (body.accent !== "southern" && body.accent !== "northern") {
    throw new HttpError(400, "invalid_accent", "Choose Southern or Northern.");
  }
  if (body.speed !== "natural" && body.speed !== "slow" && body.speed !== "fast") {
    throw new HttpError(400, "invalid_speed", "Choose slow, natural, or fast speed.");
  }
  const honorRequestedAccent = body.honorRequestedAccent === undefined
    ? false
    : body.honorRequestedAccent;
  if (typeof honorRequestedAccent !== "boolean") {
    throw new HttpError(400, "invalid_request", "Accent comparison must be a boolean.");
  }
  return { text, accent: body.accent, speed: body.speed, purpose, honorRequestedAccent };
}

/// The normalized text is both the cache-key input and the text sent to the
/// provider. Vocabulary is a saved word or short chunk, so "Chút", "chút" and
/// "chút." must share one cache entry. Lesson lines keep case and punctuation
/// because a trailing "?" or "!" changes the delivered intonation.
export function normalizedTTSText(raw: string, purpose: TTSPurpose): string {
  const text = raw.normalize("NFC").trim().replace(/\s+/gu, " ");
  if (purpose !== "vocabulary") return text;
  return text
    .toLocaleLowerCase("vi")
    .replace(/^[\p{P}\p{S}\s]+|[\p{P}\p{S}\s]+$/gu, "");
}

function hasLeadingSpeakerLabel(value: string): boolean {
  return /^[\p{L}\s·-]{1,60}[:：]\s*\S/u.test(value);
}

export function voiceIDForAccent(accent: VietnameseAccent): string {
  return approvedVoiceIDs[accent];
}

/**
 * Account preferences take precedence over a stale client accent. Invalid or
 * missing legacy values deliberately fall back to the validated request.
 */
export function effectiveAccentForRequest(
  requested: VietnameseAccent,
  stored: unknown,
  honorRequestedAccent = false,
): VietnameseAccent {
  if (honorRequestedAccent) return requested;
  return stored === "northern" || stored === "southern" ? stored : requested;
}

export function numericSpeechSpeed(speed: SpeechSpeed): number {
  switch (sourceSpeechSpeed(speed)) {
    case "slow":
    case "natural":
      return 1;
    case "fast":
      return 1.2;
  }
}

/// Slow playback is applied by the client to the natural audio artifact. The
/// server keeps this mapping too so older clients cannot create a second slow
/// TTS artifact or consume a second provider quota entry.
export function sourceSpeechSpeed(speed: SpeechSpeed): SpeechSpeed {
  return speed === "slow" ? "natural" : speed;
}

/// A deliberately conservative learning profile: high stability reduces
/// sampling variance, style=0 avoids exaggerated delivery, and speaker boost
/// preserves the approved regional female voice identity.
export function consistentVoiceSettings(speed: SpeechSpeed): ConsistentVoiceSettings {
  return {
    stability: 0.82,
    similarity_boost: 0.8,
    style: 0,
    use_speaker_boost: true,
    speed: numericSpeechSpeed(speed),
  };
}

/// ElevenLabs documents `seed` as best-effort deterministic sampling. Keeping
/// it stable for the same voice/text/speed further reduces audible variation.
export function deterministicSpeechSeed(
  voiceID: string,
  input: TTSRequest,
): number {
  const bytes = new TextEncoder().encode(
    `${voiceID}\u0000${input.speed}\u0000${input.text}`,
  );
  let hash = 2_166_136_261;
  for (const byte of bytes) {
    hash ^= byte;
    hash = Math.imul(hash, 16_777_619);
  }
  return hash >>> 0;
}
