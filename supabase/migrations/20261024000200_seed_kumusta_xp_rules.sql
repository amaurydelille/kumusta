-- Server-managed XP award rules.
insert into public.kumusta_xp_rules (code, xp_amount, is_active, metadata)
values
  ('lesson_completed', 30, true, '{"label":"Completed lesson"}'::jsonb),
  ('vocabulary_flashcard_session_completed', 10, true, '{"label":"Completed vocabulary flashcard session"}'::jsonb),
  ('achievement_first_lesson', 50, true, '{"label":"First lesson completed","achievement_id":"first_lesson"}'::jsonb),
  ('achievement_streak_7', 100, true, '{"label":"One week strong","achievement_id":"streak_7"}'::jsonb),
  ('achievement_streak_30', 250, true, '{"label":"Monthly rhythm","achievement_id":"streak_30"}'::jsonb),
  ('achievement_streak_100', 1000, true, '{"label":"Century mark","achievement_id":"streak_100"}'::jsonb),
  ('achievement_words_10', 100, true, '{"label":"10 words","achievement_id":"words_10"}'::jsonb),
  ('achievement_words_50', 250, true, '{"label":"50 words","achievement_id":"words_50"}'::jsonb),
  ('achievement_lessons_5', 100, true, '{"label":"5 lessons","achievement_id":"lessons_5"}'::jsonb),
  ('achievement_lessons_20', 250, true, '{"label":"20 lessons","achievement_id":"lessons_20"}'::jsonb),
  ('achievement_first_pronunciation', 125, true, '{"label":"Found your voice","achievement_id":"first_pronunciation"}'::jsonb),
  ('achievement_week_complete', 300, true, '{"label":"Full week","achievement_id":"week_complete"}'::jsonb)
on conflict (code) do update
set
  xp_amount = excluded.xp_amount,
  is_active = excluded.is_active,
  metadata = excluded.metadata,
  effective_until = null,
  updated_at = now();
