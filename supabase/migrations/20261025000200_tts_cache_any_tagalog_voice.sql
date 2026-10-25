-- The TTS cache still only accepted VietBuddy's four accent voices, so every
-- claim for the Tagalog voice failed and no lesson audio was ever generated.
-- The voice is configured server-side (KUMUSTA_TTS_VOICE_ID), so accept any
-- well-formed ElevenLabs voice ID, matching kumusta_claim_tts_cache.
alter table public.kumusta_tts_cache
  drop constraint kumusta_tts_cache_voice_id_check;

alter table public.kumusta_tts_cache
  add constraint kumusta_tts_cache_voice_id_check
  check (voice_id ~ '^[A-Za-z0-9]{16,40}$');
