/// <reference lib="deno.ns" />

import type { SupabaseClient, User } from "npm:@supabase/supabase-js@2.57.4";
import { HttpError } from "../_shared/http.ts";
import {
  accountDataContractVersion,
  assertExportWithinLimits,
  maximumRowsPerTable,
} from "./contract.ts";

interface TableSpecification {
  table: string;
  userColumn: string;
  orderColumn: string;
}

const pageSize = 500;

export const userOwnedTableSpecifications: readonly TableSpecification[] = [
  { table: "kumusta_profiles", userColumn: "id", orderColumn: "id" },
  {
    table: "kumusta_onboarding_responses",
    userColumn: "user_id",
    orderColumn: "user_id",
  },
  {
    table: "kumusta_learning_preferences",
    userColumn: "user_id",
    orderColumn: "user_id",
  },
  {
    table: "kumusta_user_state",
    userColumn: "user_id",
    orderColumn: "updated_at",
  },
  {
    table: "kumusta_learner_states",
    userColumn: "user_id",
    orderColumn: "user_id",
  },
  {
    table: "kumusta_lesson_generation_jobs",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_generated_lessons",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_user_lesson_queue",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_difficulty_feedback",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_generated_vocabulary_progress",
    userColumn: "user_id",
    orderColumn: "vocabulary_id",
  },
  {
    table: "kumusta_generated_vocabulary_review_events",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_user_vocabulary",
    userColumn: "user_id",
    orderColumn: "vocabulary_id",
  },
  {
    table: "kumusta_learning_sessions",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_review_events",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_daily_progress",
    userColumn: "user_id",
    orderColumn: "progress_date",
  },
  {
    table: "kumusta_app_sessions",
    userColumn: "user_id",
    orderColumn: "started_at",
  },
  {
    table: "kumusta_flashcard_sessions",
    userColumn: "user_id",
    orderColumn: "started_at",
  },
  {
    table: "kumusta_entitlements",
    userColumn: "user_id",
    orderColumn: "entitlement_id",
  },
  {
    table: "kumusta_analytics_events",
    userColumn: "user_id",
    orderColumn: "id",
  },
  {
    table: "kumusta_api_rate_limits",
    userColumn: "user_id",
    orderColumn: "scope",
  },
] as const;

export interface AccountDataExport {
  version: number;
  generated_at: string;
  user: Record<string, unknown>;
  tables: Record<string, readonly unknown[]>;
}

export async function exportAccountData(
  admin: SupabaseClient,
  userID: string,
): Promise<AccountDataExport> {
  const [{ data: authData, error: authError }, tableEntries, revenueCatEvents] = await Promise.all([
    admin.auth.admin.getUserById(userID),
    Promise.all(
      userOwnedTableSpecifications.map(async (specification) => {
        const rows = await fetchOwnedRows(admin, specification, userID);
        return [specification.table, rows] as const;
      }),
    ),
    fetchRevenueCatAuditRows(admin, userID),
  ]);

  if (authError || !authData.user) {
    console.error("account_export_auth_read_failed", { code: authError?.code });
    throw new HttpError(
      503,
      "export_unavailable",
      "The export is temporarily unavailable.",
    );
  }

  const tables: Record<string, readonly unknown[]> = Object.fromEntries(
    tableEntries,
  );
  tables.kumusta_revenuecat_events = revenueCatEvents;
  const payload: AccountDataExport = {
    version: accountDataContractVersion,
    generated_at: new Date().toISOString(),
    user: exportableAuthUser(authData.user),
    tables,
  };
  assertExportWithinLimits(tables, payload);
  return payload;
}

export async function deleteAccountData(
  admin: SupabaseClient,
  userID: string,
): Promise<
  { version: number; deleted: true; user_id: string; deleted_at: string }
> {
  // These audit rows are not foreign-keyed to auth.users, so remove every
  // identity location before relying on auth cascade deletion for owned rows.
  for (
    const remove of [
      () =>
        admin.from("kumusta_revenuecat_events").delete().eq(
          "app_user_id",
          userID,
        ),
      () =>
        admin.from("kumusta_revenuecat_events").delete().eq(
          "payload->>original_app_user_id",
          userID,
        ),
      () =>
        admin.from("kumusta_revenuecat_events").delete().filter(
          "payload->aliases",
          "cs",
          revenueCatAliasesContainment(userID),
        ),
    ]
  ) {
    const { error } = await remove();
    if (error) {
      console.error("account_delete_audit_cleanup_failed", {
        code: error.code,
      });
      throw new HttpError(
        503,
        "deletion_unavailable",
        "Account deletion could not be completed. Please try again.",
      );
    }
  }

  const { error } = await admin.auth.admin.deleteUser(userID, false);
  if (error) {
    console.error("account_delete_auth_failed", { code: error.code });
    throw new HttpError(
      503,
      "deletion_unavailable",
      "Account deletion could not be completed. Please try again.",
    );
  }

  return {
    version: accountDataContractVersion,
    deleted: true,
    user_id: userID,
    deleted_at: new Date().toISOString(),
  };
}

async function fetchOwnedRows(
  admin: SupabaseClient,
  specification: TableSpecification,
  userID: string,
): Promise<unknown[]> {
  const rows: unknown[] = [];
  while (rows.length <= maximumRowsPerTable) {
    const from = rows.length;
    const { data, error } = await admin
      .from(specification.table)
      .select("*")
      .eq(specification.userColumn, userID)
      .order(specification.orderColumn, { ascending: true })
      .range(from, from + pageSize - 1);
    if (error) {
      console.error("account_export_table_read_failed", {
        table: specification.table,
        code: error.code,
      });
      throw new HttpError(
        503,
        "export_unavailable",
        "The export is temporarily unavailable.",
      );
    }
    const page = data ?? [];
    rows.push(...page);
    if (page.length < pageSize) break;
  }
  if (rows.length > maximumRowsPerTable) {
    throw new HttpError(
      413,
      "export_too_large",
      `The ${specification.table} export is too large for self-service download.`,
    );
  }
  return rows;
}

async function fetchRevenueCatAuditRows(
  admin: SupabaseClient,
  userID: string,
): Promise<unknown[]> {
  const pages = await Promise.all([
    fetchRevenueCatRowsByFilter(admin, userID, "app_user_id"),
    fetchRevenueCatRowsByFilter(admin, userID, "original_app_user_id"),
    fetchRevenueCatRowsByFilter(admin, userID, "aliases"),
  ]);
  const unique = new Map<string, unknown>();
  for (const row of pages.flat()) {
    const eventID = isRecord(row) && typeof row.event_id === "string"
      ? row.event_id
      : crypto.randomUUID();
    unique.set(eventID, row);
  }
  const rows = [...unique.values()];
  if (rows.length > maximumRowsPerTable) {
    throw new HttpError(
      413,
      "export_too_large",
      "The RevenueCat audit export is too large for self-service download.",
    );
  }
  return rows;
}

async function fetchRevenueCatRowsByFilter(
  admin: SupabaseClient,
  userID: string,
  filter: "app_user_id" | "original_app_user_id" | "aliases",
): Promise<unknown[]> {
  const rows: unknown[] = [];
  while (rows.length <= maximumRowsPerTable) {
    const from = rows.length;
    let query = admin
      .from("kumusta_revenuecat_events")
      .select("*")
      .order("event_id", { ascending: true })
      .range(from, from + pageSize - 1);
    query = filter === "app_user_id"
      ? query.eq("app_user_id", userID)
      : filter === "original_app_user_id"
      ? query.eq("payload->>original_app_user_id", userID)
      : query.filter(
        "payload->aliases",
        "cs",
        revenueCatAliasesContainment(userID),
      );
    const { data, error } = await query;
    if (error) {
      console.error("account_export_revenuecat_read_failed", {
        filter,
        code: error.code,
      });
      throw new HttpError(
        503,
        "export_unavailable",
        "The export is temporarily unavailable.",
      );
    }
    const page = data ?? [];
    rows.push(...page);
    if (page.length < pageSize) break;
  }
  return rows;
}

/// PostgREST's typed `contains` helper serializes JavaScript arrays using the
/// PostgreSQL-array syntax (`{value}`). A JSON path targets `jsonb`, which must
/// receive valid JSON (`["value"]`) or PostgreSQL raises 22P02. Keep this
/// encoding explicit for both deletion and export queries.
export function revenueCatAliasesContainment(userID: string): string {
  return JSON.stringify([userID]);
}

function exportableAuthUser(user: User): Record<string, unknown> {
  const providers = Array.isArray(user.app_metadata?.providers)
    ? user.app_metadata.providers.filter((provider): provider is string =>
      typeof provider === "string"
    )
    : [];
  return {
    id: user.id,
    email: user.email ?? null,
    phone: user.phone ?? null,
    created_at: user.created_at,
    updated_at: user.updated_at ?? null,
    last_sign_in_at: user.last_sign_in_at ?? null,
    providers,
    user_metadata: user.user_metadata ?? {},
    identities: (user.identities ?? []).map((identity) => ({
      id: identity.id,
      provider: identity.provider,
      created_at: identity.created_at,
      updated_at: identity.updated_at,
      identity_data: identity.identity_data ?? {},
    })),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
