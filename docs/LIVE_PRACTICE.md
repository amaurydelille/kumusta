# Live Tagalog practice

Live practice is a spoken conversation with Tuko, run as a speech pipeline
(`Kumusta/Features/Practice/LivePracticePipelineSession.swift`):
Soniox realtime speech-to-text → Claude Opus 5.5 → ElevenLabs
`eleven_v4_turbo`, with replies streamed sentence by sentence. The app never
holds a provider key. It calls `kumusta-live-pipeline` with its refreshed
Supabase bearer token; that function owns the sessions, issues a single-use
realtime transcription key, and streams each reply back as NDJSON text and
24 kHz PCM16 audio events. Tap once to start, talk hands-free, mute or end at
any time. The app ends a call after 10 seconds of silence.

Soniox handles Tagalog with English mixed in (Taglish) and ends a learner turn
from what was said rather than a fixed silence. Replies use the same Tagalog
voice as lessons (`qZLi51uuzx5jdu6q0ayz`, overridable with
`KUMUSTA_TTS_VOICE_ID`). Each sentence is spoken as Tagalog when it has more
Tagalog than English function words; a balanced Taglish sentence is left to the
voice model's own detection. Turns are half-duplex by default: the microphone
sends silence while Tuko answers, so the reply is not transcribed back as the
learner. `KUMUSTA_LIVE_ECHO_CANCELLATION=on` enables iOS echo cancellation so
learners can interrupt; it stays off until verified on devices.

## Deployment

- Edge Function secrets: `KUMUSTA_LESSON_AGENT_API_KEY` (Soniox),
  `KUMUSTA_LLM_LIVE_CONVERSATION_API_KEY` (Anthropic) and `KUMUSTA_TTS_API_KEY`
  (ElevenLabs). An organization-level Anthropic key also needs
  `ANTHROPIC_WORKSPACE_ID`.
- Optional: `KUMUSTA_LIVE_LLM_MODEL` (default `claude-opus-5-5`),
  `KUMUSTA_LIVE_STT_PROVIDER`, `KUMUSTA_LIVE_STT_SECONDARY_LANGUAGES` (set to
  `none` to transcribe Tagalog only), and `KUMUSTA_LIVE_ECHO_CANCELLATION`.
  A missing Soniox key fails closed instead of switching provider.
- Deploy with
  `supabase functions deploy kumusta-live-pipeline --project-ref vpitjvtfzpqfnqgzcpla --use-api`.
  `available` in the allowance response is false until the provider secrets
  are set.

## Usage and privacy

`kumusta_live_rounds` is the daily ledger and `kumusta_live_sessions` the
per-conversation audit trail; `kumusta_live_transcripts` stores ordered learner
and assistant turns. Audio is never stored by Kumusta.

The function actions are `allowance`, `start`, `transcriber`, `reply` and
`finish` (`POST` JSON with `action`):

1. `allowance` settles any open session and reports availability. There is no
   daily time allowance.
2. `start` requires an active entitlement, settles any session the app never
   closed, and opens one session of at most one hour. Starts are capped at 200
   per day against abuse only.
3. `transcriber` returns a single-use Soniox realtime key for the open session.
4. `reply` streams Tuko's answer to the learner's transcript. Generation starts
   while access is checked; nothing is spoken unless the entitlement and open
   session checks pass.
5. `finish` stores the transcript the app saw and the counts, mutes and end
   reason. It does not require an entitlement, so a subscription ending
   mid-call still settles.

A session the app never finished (crash, kill) is settled as abandoned on the
next allowance or start request.

## Coaching and safety

The learner's chosen personality (friendly, familiar, grumpy or strict), an
optional topic, and the latest locally completed lesson are bounded and placed
in the prompt as data, after the trusted coaching instructions
(`supabase/functions/kumusta-live-pipeline/coaching.ts`). Tuko speaks everyday
Metro Manila Tagalog, and safety relies on the family-friendly prompt rules,
which take priority over learner requests and personality. Spoken prompt
injection and Tagalog naturalness require native-speaker evaluation, not just
unit tests.

## Verification

```sh
deno check supabase/functions/kumusta-live-pipeline/index.ts
deno lint supabase/functions/kumusta-live-pipeline
deno test --allow-env --allow-read supabase/functions/kumusta-live-pipeline
```

On an iPhone: greeting and two-way audio, mascot lip-sync, captions, mute,
End, ending after 10 seconds of silence, backgrounding, network loss, and
killing the app mid-call then reopening (abandoned settlement).
