# Account export and deletion

`kumusta-account-data` is a self-service, authenticated Edge Function for
account data. It is intentionally separate from the provider and webhook
functions. Export is limited to registered users; deletion also accepts the
anonymous Auth identity created automatically for a learner.

## Contract

Both operations use `POST` with a refreshed Supabase bearer token. Anonymous
identities are rejected for export, while deletion accepts the current
automatically-created anonymous identity.

Export body:

```json
{"action":"export"}
```

Deletion body:

```json
{"action":"delete","confirmation":"DELETE MY ACCOUNT"}
```

The export includes explicit Auth identity fields and every user-owned
`kumusta_` table in the current schema. RevenueCat audit rows are matched by
`app_user_id`, `original_app_user_id`, and `aliases`. Curated lessons,
vocabulary, and join rows are not user data and are excluded.

Exports fail closed with `export_too_large` instead of returning an incomplete
archive. Limits are 5,000 rows per table, 20,000 total rows, and 5 MiB encoded
JSON. Support must produce a reviewed offline export if a legitimate account
exceeds a limit.

Deletion first removes RevenueCat audit rows, which are not foreign-keyed to
Auth, then deletes the Supabase Auth user. Foreign-key cascades remove all
remaining user-owned rows. The iOS caller must erase local profile and learning
state after receiving a valid deletion receipt.

## Security properties

- The handler validates the bearer with Supabase Auth. Export rejects anonymous
  users; deletion is allowed for the current anonymous identity so automatically
  created guest accounts can also be removed.
- The user ID is taken only from the validated token, never from request JSON.
- The service-role credential is read only inside the Edge runtime.
- Request bodies and export response sizes are bounded.
- Browser origins are deny-by-default. Native requests have no `Origin` header.
- Responses use `Cache-Control: no-store` and never log exported content or user IDs.
- Deletion requires an exact, case-sensitive confirmation phrase.

Set `KUMUSTA_ALLOWED_ORIGINS` to a comma-separated list of exact HTTPS origins
only if a web client is introduced. Do not use `*`.

## Verification before deployment

From `mobile-app/kumusta`:

```sh
deno fmt --check supabase/functions/kumusta-account-data
deno lint supabase/functions/kumusta-account-data
deno check supabase/functions/kumusta-account-data/index.ts
deno test supabase/functions/kumusta-account-data/contract_test.ts
```

Run the Supabase stack locally and test with three identities: no bearer,
anonymous bearer, and a registered test user. Verify:

1. Missing/invalid bearer returns `401`.
2. Anonymous bearer returns `403 registered_account_required` for export.
3. Anonymous bearer can delete only its own account and receives a valid receipt.
4. Export contains only the registered test user's UUID and rows.
5. Wrong deletion confirmation returns `400` without mutation.
6. Correct confirmation removes the Auth user, all FK-owned rows, and matching
   RevenueCat audit rows.

## Operator rollout

1. Review the table inventory after every schema migration that adds a
   user-owned `kumusta_` table.
2. Confirm the production project exposes `SUPABASE_URL`,
   `SUPABASE_PUBLISHABLE_KEY` (or `SUPABASE_ANON_KEY`), and
   `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_SECRET_KEY`) to Edge Functions.
   Never put the service credential in iOS configuration.
3. Deploy without `--no-verify-jwt` so the gateway and handler both enforce
   authentication:

   ```sh
   supabase functions deploy kumusta-account-data
   ```

4. `SupabaseAccountDataService` is wired into the composition root and the
   Profile screen calls it directly. Do not report deletion success until the
   receipt validates, then erase local state.
5. Exercise the production function with a dedicated test account and retain
   only request IDs/status codes in operational logs.
6. Confirm with the payments/privacy owner whether the RevenueCat customer
   record also requires processor-side erasure. This function removes Kumusta's
   local entitlement projection and webhook audit records but does not call a
   RevenueCat customer-deletion API.

## Privacy manifest review

`PrivacyInfo.xcprivacy` currently uses Apple's declared manifest structure and
declares UserDefaults reason `CA92.1`. This change adds no tracking, collected
data category, or required-reason API, so the manifest is deliberately
unchanged. Re-run `plutil -lint` and review SDK privacy manifests whenever a
dependency changes.
