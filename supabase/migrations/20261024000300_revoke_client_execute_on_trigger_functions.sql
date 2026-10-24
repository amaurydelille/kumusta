-- Security definer trigger functions are only invoked by their triggers; clients
-- never need EXECUTE on them.
revoke all on function public.kumusta_touch_leaderboard_signal() from public, anon, authenticated;
