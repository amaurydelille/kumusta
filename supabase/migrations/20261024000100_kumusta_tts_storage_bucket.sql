-- Private bucket backing the shared TTS cache (kumusta-tts Edge Function).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('kumusta-tts', 'kumusta-tts', false, 3000000, array['audio/mpeg']::text[])
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
