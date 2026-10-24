-- Run once (supabase db query --linked -f supabase/ops/schedule-email-worker.sql)
-- after the Vault secret EMAIL_WORKER_AUTHORIZATION and the email worker are deployed.

do $migration$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'kumusta-email-worker-every-minute'
  ) then
    perform cron.schedule(
      'kumusta-email-worker-every-minute',
      '* * * * *',
      $job$
        select net.http_post(
          url := 'https://vpitjvtfzpqfnqgzcpla.supabase.co/functions/v1/kumusta-email-worker',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (
              select decrypted_secret
              from vault.decrypted_secrets
              where name = 'EMAIL_WORKER_AUTHORIZATION'
            )
          ),
          body := '{}'::jsonb
        );
      $job$
    );
  end if;
end
$migration$;
