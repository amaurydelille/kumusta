# Live Vietnamese practice

> **Currently on the speech pipeline.** The app runs live practice as
> STT → LLM → TTS (`LivePracticePipelineSession.swift`): ElevenLabs Scribe v2
> realtime (VAD turn commits) → Claude Haiku 5.5 → ElevenLabs
> `eleven_v4_turbo`, streamed sentence by sentence as 16 kHz PCM through
> `kumusta-live-pipeline`, which also owns the pipeline's sessions
> (`allowance`, `start`, `finish`) without a daily limit: one hour at most per
> session, 200 starts a day, and the app ends a call after 10 s of silence.
> `kumusta-live` keeps the agent's 5-minute daily allowance for older builds. The agent session below is
> compiled out; add `KUMUSTA_LIVE_AGENT` to the app target's Active
> Compilation Conditions to switch back. Pipeline deployment: set the
> `ANTHROPIC_API_KEY` secret (optional `KUMUSTA_LIVE_LLM_MODEL`, default
> `claude-haiku-5-5`) and deploy `kumusta-live-pipeline`; it reuses
> `ELEVENLABS_API_KEY`; an organization-level Anthropic key also needs
> `ANTHROPIC_WORKSPACE_ID`. Turns are half-duplex (no barge-in): the microphone
> sends silence while the buddy answers, so no voice processing is used and
> replies play as uncompressed 24 kHz PCM (44.1 kHz PCM needs the ElevenLabs
> Pro tier). Scribe commits a turn after 0.8 s of silence; `scribe_v2_realtime`
> rejects `commit_strategy=turn_prediction`.

Live practice runs on an ElevenLabs Conversational AI agent through the
ElevenLabs Swift SDK (WebRTC via LiveKit). The app never holds the ElevenLabs
API key. It calls `kumusta-live` with its refreshed Supabase bearer token;
that function checks the entitlement, reserves today's time, and returns a
short-lived conversation token plus the server-owned coaching prompt and first
message, which the app passes to the agent as overrides. Tap once to start,
talk hands-free (or type), mute or end at any time. Leaving the screen,
backgrounding, an audio interruption, or losing the headset ends the call.

## Deployment

- Apply `20261008213459_move_kumusta_live_to_elevenlabs.sql` (after the
  earlier live migrations) and deploy `kumusta-live`.
- Edge Function secrets: `ELEVENLABS_AGENT_API_KEY` (agent-only key, separate
  from the `ELEVENLABS_API_KEY` used by TTS/STT) and,
  optionally, `ELEVENLABS_AGENT_ID` (defaults to
  `agent_01jvmdd02hextbk954kjzjcaab`). `available` in the allowance response is
  false until the key is set.
- In the ElevenLabs agent settings:
  - Security → enable authentication (private agent), so the agent can only be
    reached with a token issued by `kumusta-live`.
  - Security → overrides: allow **System prompt** and **First message**. The
    connection is rejected if these overrides are not permitted.
  - Agent language Vietnamese, with a multilingual voice/TTS model.
  - Set a maximum conversation duration (for example 60 minutes) as a provider
    side backstop; the app ends the call at the learner's remaining time.

## Usage and privacy

`kumusta_live_rounds` is the daily ledger and `kumusta_live_sessions` the
per-conversation audit trail; `kumusta_live_transcripts` stores ordered user
and assistant turns. Audio is never stored by Kumusta; ElevenLabs retention
settings for the agent apply.

The function actions are `allowance`, `start`, `activate` and `finish`
(`POST` JSON with `action`; an empty body is `allowance`):

1. `start` reserves all remaining time (per-user advisory lock, no parallel
   sessions, at most 30 starts/day) and returns `seconds` and the token.
2. `activate` is sent when the agent conversation is live. It stamps
   `started_at`, which starts the trusted wall clock, and records the
   ElevenLabs `conversation_id` as soon as it is known.
3. `finish` charges `min(reserved, now - started_at)`, refunds the rest once,
   stores the transcript the app saw and the counts/mutes/end reason.

The app's visible timer counts down from `seconds` and ends the call at zero.
A reservation that never activates is refunded after 30 seconds. An activated
session the app never finished (crash, kill) is settled on the next allowance
or start request using the ElevenLabs conversation's own call duration and
transcript, or the wall clock if those are unavailable. Mute does not pause
the allowance.

## Coaching and safety

The selected accent and latest locally completed lesson are bounded and placed
in the prompt as data, after the trusted coaching instructions. The previous
OpenAI transcript moderation was removed with the relay; safety now relies on
the family-friendly prompt rules and the agent's ElevenLabs guardrails. Spoken
prompt injection and regional pronunciation quality require native-speaker
evaluation, not just unit tests.

## Verification

```sh
rtk deno check supabase/functions/kumusta-live/index.ts
rtk deno lint supabase/functions/kumusta-live
rtk deno test supabase/functions/kumusta-live/contract_test.ts
rtk supabase db query --linked --file supabase/tests/live_practice.sql
```

On an iPhone: greeting and two-way audio, mascot lip-sync, captions, typed
messages, mute, End, timer reaching zero, backgrounding, network loss, killing
the app mid-call then reopening (abandoned settlement), and daily exhaustion.
