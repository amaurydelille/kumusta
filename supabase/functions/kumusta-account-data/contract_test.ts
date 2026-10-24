/// <reference lib="deno.ns" />

import { HttpError } from "../_shared/http.ts";
import {
  accountDeletionConfirmation,
  allowsAnonymousAccountDataRequest,
  assertExportWithinLimits,
  maximumRowsPerTable,
  parseAccountDataRequest,
} from "./contract.ts";
import { revenueCatAliasesContainment, userOwnedTableSpecifications } from "./account_data.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function expectHTTPError(
  action: () => unknown,
  status: number,
  code: string,
): void {
  try {
    action();
  } catch (error) {
    assert(error instanceof HttpError, "Expected an HttpError");
    assert(error.status === status, `Expected status ${status}`);
    assert(error.code === code, `Expected code ${code}`);
    return;
  }
  throw new Error("Expected the action to throw");
}

Deno.test("export request accepts only the exact action field", () => {
  const parsed = parseAccountDataRequest({ action: "export" });
  assert(parsed.action === "export", "Export was not parsed");
  expectHTTPError(
    () => parseAccountDataRequest({ action: "export", user_id: "another-user" }),
    400,
    "invalid_request",
  );
});

Deno.test("deletion requires an exact, case-sensitive confirmation", () => {
  const parsed = parseAccountDataRequest({
    action: "delete",
    confirmation: accountDeletionConfirmation,
  });
  assert(parsed.action === "delete", "Deletion was not parsed");
  expectHTTPError(
    () =>
      parseAccountDataRequest({
        action: "delete",
        confirmation: "delete my account",
      }),
    400,
    "confirmation_required",
  );
});

Deno.test("only deletion accepts an automatically-created anonymous account", () => {
  assert(
    allowsAnonymousAccountDataRequest({
      action: "delete",
      confirmation: accountDeletionConfirmation,
    }),
    "Deletion should allow anonymous account cleanup",
  );
  assert(
    !allowsAnonymousAccountDataRequest({ action: "export" }),
    "Export should remain restricted to registered accounts",
  );
});

Deno.test("RevenueCat alias containment is encoded as JSON for a jsonb path", () => {
  const userID = "11111111-1111-4111-8111-111111111111";
  assert(
    revenueCatAliasesContainment(userID) === JSON.stringify([userID]),
    "Alias containment must be a JSON array, not PostgreSQL array syntax",
  );
});

Deno.test("oversized table exports fail instead of truncating", () => {
  const rows = Array.from({ length: maximumRowsPerTable + 1 }, () => ({}));
  const tables = { kumusta_review_events: rows };
  expectHTTPError(
    () => assertExportWithinLimits(tables, { tables }),
    413,
    "export_too_large",
  );
});

Deno.test("export inventory covers every schema-owned auth row table", () => {
  const expected = [
    "kumusta_profiles",
    "kumusta_onboarding_responses",
    "kumusta_learning_preferences",
    "kumusta_user_state",
    "kumusta_learner_states",
    "kumusta_lesson_generation_jobs",
    "kumusta_generated_lessons",
    "kumusta_user_lesson_queue",
    "kumusta_difficulty_feedback",
    "kumusta_generated_vocabulary_progress",
    "kumusta_generated_vocabulary_review_events",
    "kumusta_user_vocabulary",
    "kumusta_learning_sessions",
    "kumusta_review_events",
    "kumusta_daily_progress",
    "kumusta_app_sessions",
    "kumusta_flashcard_sessions",
    "kumusta_entitlements",
    "kumusta_analytics_events",
    "kumusta_api_rate_limits",
  ];
  assert(
    JSON.stringify(userOwnedTableSpecifications.map((item) => item.table)) ===
      JSON.stringify(expected),
    "The account export inventory drifted from the schema",
  );
});
