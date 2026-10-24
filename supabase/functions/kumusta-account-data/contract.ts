import { HttpError, isPlainObject } from "../_shared/http.ts";

export const accountDataContractVersion = 1;
export const accountDeletionConfirmation = "DELETE MY ACCOUNT";
export const maximumRequestBytes = 512;
export const maximumRowsPerTable = 5_000;
export const maximumRowsAcrossExport = 20_000;
export const maximumExportBytes = 5_242_880;

export type AccountDataRequest =
  | { action: "export" }
  | { action: "delete"; confirmation: typeof accountDeletionConfirmation };

/// Deletion is also available for the anonymous Auth identity that the app
/// creates automatically. Export still requires a registered account.
export function allowsAnonymousAccountDataRequest(
  request: AccountDataRequest,
): boolean {
  return request.action === "delete";
}

export function parseAccountDataRequest(payload: unknown): AccountDataRequest {
  if (!isPlainObject(payload) || typeof payload.action !== "string") {
    throw new HttpError(400, "invalid_request", "Choose export or delete.");
  }

  if (payload.action === "export") {
    assertExactKeys(payload, ["action"]);
    return { action: "export" };
  }

  if (payload.action === "delete") {
    assertExactKeys(payload, ["action", "confirmation"]);
    if (payload.confirmation !== accountDeletionConfirmation) {
      throw new HttpError(
        400,
        "confirmation_required",
        `Enter ${accountDeletionConfirmation} to confirm deletion.`,
      );
    }
    return {
      action: "delete",
      confirmation: accountDeletionConfirmation,
    };
  }

  throw new HttpError(400, "unsupported_action", "Choose export or delete.");
}

export function assertExportWithinLimits(
  tables: Record<string, readonly unknown[]>,
  payload: unknown,
): void {
  let totalRows = 0;
  for (const [table, rows] of Object.entries(tables)) {
    if (rows.length > maximumRowsPerTable) {
      throw new HttpError(
        413,
        "export_too_large",
        `The ${table} export is too large for self-service download.`,
      );
    }
    totalRows += rows.length;
  }
  if (totalRows > maximumRowsAcrossExport) {
    throw new HttpError(
      413,
      "export_too_large",
      "This export is too large for self-service download.",
    );
  }
  if (encodedJSONByteCount(payload) > maximumExportBytes) {
    throw new HttpError(
      413,
      "export_too_large",
      "This export is too large for self-service download.",
    );
  }
}

export function encodedJSONByteCount(payload: unknown): number {
  return new TextEncoder().encode(JSON.stringify(payload)).byteLength;
}

function assertExactKeys(
  payload: Record<string, unknown>,
  expectedKeys: readonly string[],
): void {
  const expected = new Set(expectedKeys);
  const actual = Object.keys(payload);
  if (
    actual.length !== expected.size ||
    actual.some((key) => !expected.has(key))
  ) {
    throw new HttpError(
      400,
      "invalid_request",
      "The request contains unsupported fields.",
    );
  }
}
