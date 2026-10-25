-- Onboarding and the profile editor offer 5, 7, 10 and 15 minutes a day, but
-- the preferences row only accepted 3, 5, 7 and 10, so a 15-minute plan was
-- saved as 10. Keep 3 for existing rows.
alter table public.kumusta_learning_preferences
  drop constraint kumusta_learning_preferences_daily_minutes_check;

alter table public.kumusta_learning_preferences
  add constraint kumusta_learning_preferences_daily_minutes_check
  check (daily_minutes = any (array[3, 5, 7, 10, 15]));
